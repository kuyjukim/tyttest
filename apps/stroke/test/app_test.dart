import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';
import 'package:stroke/app.dart';
import 'package:stroke/data/sketch_repository.dart';
import 'package:stroke/domain/canvas_transform.dart';
import 'package:stroke/domain/ink.dart';
import 'package:stroke/state/studio_store.dart';
import 'package:stroke/ui/widgets/sketch_canvas.dart';

class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
}

class Harness {
  Harness({Map<String, String>? seed})
    : clock = FakeClock(),
      raw = MemoryStore(seed) {
    var id = 0;
    store = StudioStore(
      repository: SketchRepository(raw),
      clock: () => clock.now,
      idFactory: () => 'id-${(id++).toString().padLeft(3, '0')}',
      // Write immediately rather than on a timer: a widget test that ends
      // with a timer still pending fails the harness's invariant, and
      // rightly so.
      autosaveDelay: Duration.zero,
    );
  }

  final FakeClock clock;
  final MemoryStore raw;
  late final StudioStore store;
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  Map<String, String>? seed,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = Harness(seed: seed);
  // Disposing cancels the pending autosave timer. Without this every test
  // that draws something fails the "a Timer is still pending" invariant,
  // which is the test harness correctly pointing out that the real app would
  // be holding a timer too.
  addTearDown(harness.store.dispose);
  await harness.store.initialize();
  await tester.pumpWidget(StrokeApp(store: harness.store, locale: locale));
  await tester.pumpAndSettle();
  return harness;
}

/// Finds a [PaperIconButton] by its tooltip, for reading its properties.
///
/// `find.byTooltip` matches the wrapping Tooltip, which is what taps want but
/// not what a `tester.widget<PaperIconButton>` cast wants. The brush and tool
/// buttons are a different widget entirely, so they are only ever tapped.
Finder iconButton(String tooltip) => find.byWidgetPredicate(
  (widget) => widget is PaperIconButton && widget.tooltip == tooltip,
);

/// Drags across the canvas, which draws a stroke with the current tool.
Future<void> dragOnCanvas(
  WidgetTester tester, {
  Offset from = const Offset(140, 300),
  Offset to = const Offset(260, 420),
  int steps = 8,
}) async {
  final gesture = await tester.startGesture(from);
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(from + (to - from) * (i / steps));
    await tester.pump(const Duration(milliseconds: 8));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('gallery', () {
    testWidgets('offers the first sketch and opens the editor', (tester) async {
      final harness = await pumpApp(tester);

      expect(find.text('Nothing drawn yet'), findsOneWidget);

      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      expect(harness.store.sketch, isNotNull);
      expect(find.byType(SketchCanvas), findsOneWidget);
      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('lists a saved sketch with its stroke count', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      await dragOnCanvas(tester);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 stroke'), findsOneWidget);
      expect(harness.store.sketch, isNull);
    });

    testWidgets('deleting asks first', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this sketch?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(harness.store.gallery, hasLength(1));

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(harness.store.gallery, isEmpty);
      expect(find.text('Nothing drawn yet'), findsOneWidget);
    });
  });

  group('drawing', () {
    testWidgets('a drag leaves a stroke and enables undo', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      await dragOnCanvas(tester);

      expect(harness.store.sketch!.strokeCount, 1);
      final stroke = harness.store.sketch!.activeLayer.strokes.single;
      expect(stroke.points.length, greaterThan(1));
      expect(stroke.kind, BrushKind.pen);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(harness.store.sketch!.strokeCount, 0);

      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(harness.store.sketch!.strokeCount, 1);
    });

    testWidgets('undo and redo are disabled when there is nothing to do',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<PaperIconButton>(iconButton('Undo')).onPressed,
        isNull,
      );
      expect(
        tester.widget<PaperIconButton>(iconButton('Redo')).onPressed,
        isNull,
      );
    });

    testWidgets('a tap leaves a dot', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(180, 320));
      await tester.pumpAndSettle();

      expect(harness.store.sketch!.strokeCount, 1);
      expect(harness.store.sketch!.activeLayer.strokes.single.points, hasLength(1));
    });

    testWidgets('the selected brush and colour are what gets drawn',
        (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Highlighter'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Colour 7'));
      await tester.pumpAndSettle();

      await dragOnCanvas(tester);

      final stroke = harness.store.sketch!.activeLayer.strokes.single;
      expect(stroke.kind, BrushKind.highlighter);
      expect(stroke.colorValue, 0xFF1BAF7A);
      expect(stroke.opacity, lessThan(1));
    });

    testWidgets('a second finger cancels the stroke instead of leaving a mark',
        (tester) async {
      // Starting a pinch must not deposit a stray line, which is what
      // happens if the first finger's stroke is committed when the gesture
      // turns out to be a zoom.
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      final first = await tester.startGesture(const Offset(150, 300));
      await first.moveBy(const Offset(10, 10));
      await tester.pump();
      final second = await tester.startGesture(const Offset(250, 400));
      await tester.pump();

      expect(harness.store.isDrawing, isFalse);

      await first.moveBy(const Offset(-20, -20));
      await second.moveBy(const Offset(20, 20));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(harness.store.sketch!.strokeCount, 0);
      expect(
        harness.store.transform.scale,
        isNot(1.0),
        reason: 'the pinch zoomed instead',
      );
    });

    testWidgets('the eraser removes a stroke in one undoable step',
        (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      await dragOnCanvas(tester);
      expect(harness.store.sketch!.strokeCount, 1);
      final depth = harness.store.history.depth;

      await tester.tap(find.byTooltip('Eraser'));
      await tester.pumpAndSettle();
      await dragOnCanvas(tester);

      expect(harness.store.sketch!.strokeCount, 0);
      expect(harness.store.history.depth, depth + 1);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(harness.store.sketch!.strokeCount, 1);
    });

    testWidgets('the move tool pans without drawing', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      final before = harness.store.transform.offset;

      await tester.tap(find.byTooltip('Move'));
      await tester.pumpAndSettle();
      await dragOnCanvas(tester);

      expect(harness.store.sketch!.strokeCount, 0);
      expect(harness.store.transform.offset, isNot(before));
    });

    testWidgets('the brush size slider changes the stroke width',
        (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Slider).first, const Offset(200, 0));
      await tester.pumpAndSettle();
      final width = harness.store.brush.width;
      expect(width, greaterThan(BrushKind.pen.defaultWidth));

      await dragOnCanvas(tester);
      expect(harness.store.sketch!.activeLayer.strokes.single.width, width);
    });

    testWidgets('fit to screen sizes the page to the viewport', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Fit to screen'));
      await tester.pumpAndSettle();

      expect(harness.store.transform.scale, lessThan(1));
      expect(
        harness.store.transform.scale,
        greaterThanOrEqualTo(CanvasTransform.minScale),
      );
    });
  });

  group('layers', () {
    testWidgets('a layer can be added, hidden and deleted', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Layers'));
      await tester.pumpAndSettle();
      expect(find.text('Layer 1'), findsOneWidget);

      await tester.tap(find.widgetWithText(PaperButton, 'Add layer'));
      await tester.pumpAndSettle();
      expect(harness.store.sketch!.layers, hasLength(2));
      expect(find.text('Layer 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide layer').first);
      await tester.pumpAndSettle();
      expect(harness.store.sketch!.layers[1].visible, isFalse);

      await tester.tap(find.byTooltip('Delete layer').first);
      await tester.pumpAndSettle();
      expect(harness.store.sketch!.layers, hasLength(1));
    });

    testWidgets('a new stroke lands on the layer that is selected',
        (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Layers'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Add layer'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await dragOnCanvas(tester);

      expect(harness.store.sketch!.layers[0].strokes, isEmpty);
      expect(harness.store.sketch!.layers[1].strokes, hasLength(1));
    });

    testWidgets('the layer list is topmost first', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Layers'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Add layer'));
      await tester.pumpAndSettle();

      final layer1 = tester.getTopLeft(find.text('Layer 1')).dy;
      final layer2 = tester.getTopLeft(find.text('Layer 2')).dy;
      expect(
        layer2,
        lessThan(layer1),
        reason: 'the list should read the way the drawing looks',
      );
    });
  });

  group('persistence', () {
    testWidgets('leaving the editor saves the drawing', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      final id = harness.store.sketch!.id;
      await dragOnCanvas(tester);

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      final reloaded = await SketchRepository(harness.raw).load(id);
      expect(reloaded!.strokeCount, 1);
    });

    testWidgets('reopening restores the strokes', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();
      await dragOnCanvas(tester);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('1 stroke'));
      await tester.pumpAndSettle();

      expect(harness.store.sketch!.strokeCount, 1);
      expect(find.byType(SketchCanvas), findsOneWidget);
    });

    testWidgets('renaming from the editor sticks', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('New sketch'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Untitled'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Study of hands',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.store.sketch!.name, 'Study of hands');
      expect(find.text('Study of hands'), findsOneWidget);
    });
  });

  group('localisation', () {
    testWidgets('runs in Korean', (tester) async {
      final harness = await pumpApp(tester, locale: const Locale('ko'));

      expect(find.text('아직 그린 그림이 없습니다'), findsOneWidget);
      await tester.tap(find.text('새 스케치'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('펜'), findsOneWidget);
      await dragOnCanvas(tester);
      expect(harness.store.sketch!.strokeCount, 1);

      await tester.tap(find.byTooltip('레이어'));
      await tester.pumpAndSettle();
      expect(find.textContaining('획 1개'), findsWidgets);
    });
  });
}
