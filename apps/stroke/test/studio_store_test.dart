import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';
import 'package:stroke/data/sketch_repository.dart';
import 'package:stroke/domain/ink.dart';
import 'package:stroke/domain/sketch.dart';
import 'package:stroke/state/studio_store.dart';

class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
  void advance(Duration by) => now = now.add(by);
}

({StudioStore store, FakeClock clock, MemoryStore raw}) build({
  Map<String, String>? seed,
}) {
  final clock = FakeClock();
  final raw = MemoryStore(seed);
  var id = 0;
  return (
    store: StudioStore(
      repository: SketchRepository(raw),
      clock: () => clock.now,
      idFactory: () => 'id-${(id++).toString().padLeft(3, '0')}',
      // Autosave is driven by flush() in these tests; a timer would make
      // every assertion a race.
      autosaveDelay: const Duration(hours: 1),
    ),
    clock: clock,
    raw: raw,
  );
}

/// Draws a short stroke through the store.
void drawStroke(StudioStore store, {double x = 0, int points = 5}) {
  store.beginStroke(Offset(x, 0), 1);
  for (var i = 1; i < points; i++) {
    store.extendStroke(Offset(x + i * 12, i * 6), 1);
  }
  store.endStroke();
}

void main() {
  group('gallery', () {
    test('starts empty', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      expect(store.ready, isTrue);
      expect(store.gallery, isEmpty);
      expect(store.sketch, isNull);
    });

    test('a new sketch is created, opened and listed', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();

      final sketch = await store.createSketch(name: 'First');

      expect(store.sketch, same(sketch));
      expect(sketch.layers, hasLength(1));
      expect(store.gallery.map((s) => s.name), <String>['First']);
      expect(store.hasUnsavedChanges, isFalse, reason: 'created and saved');
    });

    test('is newest first', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();

      await store.createSketch(name: 'Older');
      clock.advance(const Duration(hours: 2));
      await store.createSketch(name: 'Newer');
      await store.closeSketch();

      expect(store.gallery.map((s) => s.name), <String>['Newer', 'Older']);
    });

    test('opening a sketch that is gone refreshes instead of crashing',
        () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      final sketch = await store.createSketch();
      await store.closeSketch();

      await raw.delete(SketchRepository.keyFor(sketch.id));
      await store.openSketch(sketch.id);

      expect(store.sketch, isNull);
      expect(store.gallery, isEmpty);
    });

    test('deleting removes it from disk and from the gallery', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      final sketch = await store.createSketch();
      drawStroke(store);
      await store.flush();

      await store.deleteSketch(sketch.id);

      expect(store.gallery, isEmpty);
      expect(store.sketch, isNull);
      expect(raw.snapshot[SketchRepository.keyFor(sketch.id)], isNull);
    });

    test('renaming is saved and reflected in the gallery', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch(name: 'Untitled');

      await store.renameSketch('  Study of hands  ');

      expect(store.sketch!.name, 'Study of hands');
      expect(store.gallery.single.name, 'Study of hands');

      await store.renameSketch('   ');
      expect(store.sketch!.name, 'Untitled', reason: 'a blank name falls back');
    });
  });

  group('drawing', () {
    test('a stroke lands on the active layer and marks the file dirty',
        () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      drawStroke(store);

      expect(store.sketch!.strokeCount, 1);
      expect(store.sketch!.activeLayer.strokes.single.points.length, 5);
      expect(store.hasUnsavedChanges, isTrue);
      expect(store.history.canUndo, isTrue);
    });

    test('a tap becomes a one-point stroke rather than nothing', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      store.beginStroke(const Offset(10, 10), 0.5);
      store.endStroke();

      expect(store.sketch!.strokeCount, 1);
      expect(store.sketch!.activeLayer.strokes.single.points.length, 1);
    });

    test('the live stroke is visible while drawing and gone after', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      store.beginStroke(Offset.zero, 1);
      store.extendStroke(const Offset(10, 10), 1);
      expect(store.isDrawing, isTrue);
      expect(store.liveStroke, hasLength(2));

      store.endStroke();
      expect(store.isDrawing, isFalse);
      expect(store.liveStroke, isEmpty);
    });

    test('a cancelled stroke leaves nothing behind', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      store.beginStroke(Offset.zero, 1);
      store.extendStroke(const Offset(10, 10), 1);
      store.cancelStroke();

      expect(store.sketch!.strokeCount, 0);
      expect(store.history.canUndo, isFalse);
      expect(store.isDrawing, isFalse);
    });

    test('drawing does nothing while the eraser or pan tool is selected',
        () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      for (final tool in <Tool>[Tool.erase, Tool.pan]) {
        store.selectTool(tool);
        drawStroke(store);
        expect(store.sketch!.strokeCount, 0, reason: '$tool');
      }
    });

    test('nothing happens with no sketch open', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      drawStroke(store);
      store.undo();
      store.redo();
      expect(store.sketch, isNull);
    });

    test('stores the brush settings in effect at the time', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      store.selectBrush(BrushKind.highlighter);
      store.setBrushColor(0xFFEDA100);
      store.setBrushWidth(30);
      drawStroke(store);

      final stroke = store.sketch!.activeLayer.strokes.single;
      expect(stroke.kind, BrushKind.highlighter);
      expect(stroke.colorValue, 0xFFEDA100);
      expect(stroke.width, 30);
      expect(
        stroke.opacity,
        BrushKind.highlighter.defaultOpacity,
        reason: 'a highlighter is translucent so overlaps build up',
      );
    });

    test('brush width is clamped to something drawable', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      store.setBrushWidth(10000);
      expect(store.brush.width, 120);
      store.setBrushWidth(-5);
      expect(store.brush.width, 0.5);
    });

    test('tapping the selected brush returns to the draw tool', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      store.selectTool(Tool.erase);
      store.selectBrush(store.brush.kind);
      expect(store.tool, Tool.draw);
    });
  });

  group('erasing', () {
    Future<StudioStore> withThreeStrokes() async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();
      for (var i = 0; i < 3; i++) {
        drawStroke(store, x: i * 200);
      }
      return store;
    }

    test('a swipe over several strokes is one undo step', () async {
      final store = await withThreeStrokes();
      final depthBefore = store.history.depth;
      store.selectTool(Tool.erase);

      // Drag across the first two strokes.
      store.eraseAt(const Offset(10, 5), 30);
      store.eraseAt(const Offset(210, 5), 30);
      store.endErase();

      expect(store.sketch!.strokeCount, 1);
      expect(
        store.history.depth,
        depthBefore + 1,
        reason: 'one swipe, one undo',
      );

      store.undo();
      expect(store.sketch!.strokeCount, 3);
    });

    test('undo puts erased strokes back in their original order', () async {
      final store = await withThreeStrokes();
      final idsBefore =
          store.sketch!.activeLayer.strokes.map((s) => s.id).toList();
      store.selectTool(Tool.erase);

      store.eraseAt(const Offset(210, 5), 30);
      store.endErase();
      store.undo();

      expect(
        store.sketch!.activeLayer.strokes.map((s) => s.id).toList(),
        idsBefore,
        reason: 'order decides what covers what',
      );
    });

    test('an eraser that touches nothing records no command', () async {
      final store = await withThreeStrokes();
      final depth = store.history.depth;
      store.selectTool(Tool.erase);

      store.eraseAt(const Offset(-900, -900), 10);
      store.endErase();

      expect(store.history.depth, depth);
      expect(store.sketch!.strokeCount, 3);
    });

    test('erasing only touches the active layer', () async {
      final store = await withThreeStrokes();
      store.addLayer();
      drawStroke(store, x: 0);
      expect(store.sketch!.layers, hasLength(2));

      store.selectTool(Tool.erase);
      store.eraseAt(const Offset(10, 5), 40);
      store.endErase();

      expect(store.sketch!.layers[0].strokes, hasLength(3));
      expect(store.sketch!.layers[1].strokes, isEmpty);
    });

    test('erase does nothing unless the eraser is selected', () async {
      final store = await withThreeStrokes();
      store.eraseAt(const Offset(10, 5), 30);
      expect(store.sketch!.strokeCount, 3);
    });
  });

  group('layers', () {
    test('adding selects the new layer and is capped', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      for (var i = 1; i < Sketch.maxLayers; i++) {
        store.addLayer();
      }
      expect(store.sketch!.layers, hasLength(Sketch.maxLayers));
      expect(store.canAddLayer, isFalse);

      store.addLayer();
      expect(store.sketch!.layers, hasLength(Sketch.maxLayers));
    });

    test('deleting the only layer clears it instead, so there is somewhere '
        'to draw', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();
      drawStroke(store);

      store.removeLayer(0);

      expect(store.sketch!.layers, hasLength(1));
      expect(store.sketch!.strokeCount, 0);

      store.undo();
      expect(store.sketch!.strokeCount, 1);
    });

    test('clearing an empty layer records nothing', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();
      store.clearLayer(0);
      expect(store.history.canUndo, isFalse);
    });

    test('properties round-trip through undo', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      store.setLayerProperties(0, visible: false, opacity: 0.3, name: 'Rough');
      expect(store.sketch!.layers[0].visible, isFalse);
      expect(store.sketch!.layers[0].name, 'Rough');

      store.undo();
      expect(store.sketch!.layers[0].visible, isTrue);
      expect(store.sketch!.layers[0].name, 'Layer 1');
    });

    test('out-of-range layer operations are ignored', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();

      store.removeLayer(9);
      store.clearLayer(-1);
      store.setLayerProperties(42, visible: false);
      store.selectLayer(99);

      expect(store.sketch!.layers, hasLength(1));
      expect(store.sketch!.activeLayerIndex, 0);
      expect(store.history.canUndo, isFalse);
    });

    test('reordering changes which layer is on top', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.createSketch();
      store.addLayer();
      final ids = store.sketch!.layers.map((l) => l.id).toList();

      store.reorderLayer(0, 1);
      expect(
        store.sketch!.layers.map((l) => l.id),
        <String>[ids[1], ids[0]],
      );
    });
  });

  group('persistence', () {
    test('flush writes the drawing and clears the dirty flag', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      final sketch = await store.createSketch();
      drawStroke(store);
      expect(store.hasUnsavedChanges, isTrue);

      await store.flush();

      expect(store.hasUnsavedChanges, isFalse);
      final onDisk = jsonDecode(
        raw.snapshot[SketchRepository.keyFor(sketch.id)]!,
      ) as Map<String, Object?>;
      expect(onDisk['name'], 'Untitled');
      expect(store.gallery.single.strokeCount, 1);
    });

    test('a cold start finds the drawing and its strokes', () async {
      final (store: first, clock: _, raw: raw) = build();
      await first.initialize();
      final sketch = await first.createSketch(name: 'Kept');
      drawStroke(first, points: 8);
      await first.closeSketch();

      final (store: second, clock: _, raw: _) = build(seed: raw.snapshot);
      await second.initialize();
      expect(second.gallery.single.name, 'Kept');

      await second.openSketch(sketch.id);
      expect(second.sketch!.strokeCount, 1);
      expect(second.history.canUndo, isFalse, reason: 'history is per session');
    });

    test('closing saves without being asked', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      final sketch = await store.createSketch();
      drawStroke(store);

      await store.closeSketch();

      final reloaded = await SketchRepository(raw).load(sketch.id);
      expect(reloaded!.strokeCount, 1);
    });

    test('switching sketches saves the one being left', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      final first = await store.createSketch(name: 'First');
      drawStroke(store);

      await store.createSketch(name: 'Second');

      final reloaded = await SketchRepository(raw).load(first.id);
      expect(reloaded!.strokeCount, 1);
    });

    test('flush with nothing open or nothing changed is a no-op', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.flush();
      expect(raw.snapshot, isEmpty);

      await store.createSketch();
      final before = raw.snapshot[SketchRepository.indexKey];
      await store.flush();
      expect(raw.snapshot[SketchRepository.indexKey], before);
    });

    test('autosave writes after the delay without being asked', () async {
      final clock = FakeClock();
      final raw = MemoryStore();
      var id = 0;
      final store = StudioStore(
        repository: SketchRepository(raw),
        clock: () => clock.now,
        idFactory: () => 'id-${id++}',
        autosaveDelay: const Duration(milliseconds: 20),
      );
      addTearDown(store.dispose);

      await store.initialize();
      final sketch = await store.createSketch();
      drawStroke(store);
      expect(store.hasUnsavedChanges, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(store.hasUnsavedChanges, isFalse);
      final reloaded = await SketchRepository(raw).load(sketch.id);
      expect(reloaded!.strokeCount, 1);
    });

    test('updatedAt advances on save', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      await store.createSketch();
      final created = store.sketch!.updatedAt;

      clock.advance(const Duration(hours: 3));
      drawStroke(store);
      await store.flush();

      expect(store.sketch!.updatedAt.isAfter(created), isTrue);
    });
  });

  group('repository reconciliation', () {
    test('a sketch on disk but missing from the index still appears',
        () async {
      // The crash-between-two-writes case: the drawing exists, the index does
      // not mention it. Losing it would be the worse failure.
      final sketch = Sketch.blank(
        id: 'orphan',
        layerId: 'l1',
        name: 'Rescued',
        now: DateTime(2026, 9, 1),
      );
      final raw = MemoryStore({
        SketchRepository.keyFor('orphan'): jsonEncode(sketch.toJson()),
      });

      final listed = await SketchRepository(raw).listSketches();

      expect(listed.map((s) => s.name), <String>['Rescued']);
      expect(
        raw.snapshot[SketchRepository.indexKey],
        isNotNull,
        reason: 'the index is repaired on the way past',
      );
    });

    test('an index row with no drawing behind it is dropped', () async {
      final raw = MemoryStore({
        SketchRepository.indexKey: jsonEncode(<Object?>[
          <String, Object?>{
            'id': 'ghost',
            'name': 'Ghost',
            'updatedAt': '2026-09-01T00:00:00.000',
            'strokeCount': 3,
          },
        ]),
      });

      final listed = await SketchRepository(raw).listSketches();

      expect(listed, isEmpty, reason: 'a row that opens nothing is worse '
          'than no row');
      expect(raw.snapshot[SketchRepository.indexKey], jsonEncode(<Object?>[]));
    });

    test('a corrupt index is rebuilt from what is on disk', () async {
      final sketch = Sketch.blank(
        id: 'real',
        layerId: 'l1',
        name: 'Real',
        now: DateTime(2026, 9, 1),
      );
      final raw = MemoryStore({
        SketchRepository.indexKey: 'not json',
        SketchRepository.keyFor('real'): jsonEncode(sketch.toJson()),
      });

      expect(
        (await SketchRepository(raw).listSketches()).map((s) => s.name),
        <String>['Real'],
      );
    });

    test('a corrupt drawing file reads as absent rather than throwing',
        () async {
      final raw = MemoryStore({
        SketchRepository.keyFor('broken'): 'not json',
      });
      final repository = SketchRepository(raw);

      expect(await repository.load('broken'), isNull);
      expect(await repository.listSketches(), isEmpty);
    });
  });
}
