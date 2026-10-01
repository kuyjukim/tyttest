import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroke/domain/canvas_transform.dart';
import 'package:stroke/domain/commands.dart';
import 'package:stroke/domain/ink.dart';
import 'package:stroke/domain/sketch.dart';

var _id = 0;
String nextId() => 'id-${_id++}';

Stroke strokeOf({String? id, double x = 0}) => Stroke(
  id: id ?? nextId(),
  kind: BrushKind.pen,
  colorValue: 0xFF1C1A17,
  width: 6,
  opacity: 1,
  points: <InkPoint>[
    InkPoint(Offset(x, 0), 1),
    InkPoint(Offset(x + 10, 10), 1),
  ],
);

Sketch blank({int layers = 1}) {
  final sketch = Sketch.blank(
    id: 'sketch',
    layerId: 'layer-0',
    name: 'Test',
    now: DateTime(2026, 10, 1),
  );
  for (var i = 1; i < layers; i++) {
    sketch.layers.add(Layer(id: 'layer-$i', name: 'Layer ${i + 1}'));
  }
  return sketch;
}

void main() {
  setUp(() => _id = 0);

  group('Sketch', () {
    test('a blank sketch has one layer and nothing on it', () {
      final sketch = blank();
      expect(sketch.layers, hasLength(1));
      expect(sketch.isEmpty, isTrue);
      expect(sketch.strokeCount, 0);
      expect(sketch.activeLayer.id, 'layer-0');
    });

    test('activeLayer survives an out-of-range index', () {
      final sketch = blank()..activeLayerIndex = 99;
      expect(sketch.activeLayer.id, 'layer-0');
    });

    test('counts strokes across layers', () {
      final sketch = blank(layers: 3);
      sketch.layers[0].strokes.add(strokeOf());
      sketch.layers[2].strokes
        ..add(strokeOf())
        ..add(strokeOf());
      expect(sketch.strokeCount, 3);
      expect(sketch.isEmpty, isFalse);
    });

    test('contentBounds covers the canvas when empty and the ink when not',
        () {
      final sketch = blank();
      expect(sketch.contentBounds.width, Sketch.defaultSize.width);

      sketch.layers[0].strokes.add(strokeOf(x: 100));
      final bounds = sketch.contentBounds;
      expect(bounds.left, lessThan(100));
      expect(bounds.right, greaterThan(110));
    });

    test('round-trips through JSON with its strokes', () {
      final sketch = blank(layers: 2);
      sketch.layers[0].strokes.add(strokeOf(id: 'a'));
      sketch.layers[1]
        ..strokes.add(strokeOf(id: 'b'))
        ..visible = false
        ..opacity = 0.4
        ..name = 'Shading';
      sketch.activeLayerIndex = 1;

      final restored = Sketch.fromJson(
        jsonDecode(jsonEncode(sketch.toJson())) as Map<String, Object?>,
      );

      expect(restored.id, 'sketch');
      expect(restored.layers, hasLength(2));
      expect(restored.layers[1].name, 'Shading');
      expect(restored.layers[1].visible, isFalse);
      expect(restored.layers[1].opacity, closeTo(0.4, 1e-9));
      expect(restored.strokeCount, 2);
      expect(restored.activeLayerIndex, 1);
      expect(restored.size, sketch.size);
    });

    test('a file with no readable layers still opens with somewhere to draw',
        () {
      final restored = Sketch.fromJson(<String, Object?>{
        'id': 'x',
        'name': 'Broken',
        'layers': <Object?>['not a layer', 42],
      });
      expect(restored.layers, hasLength(1));
      expect(restored.isEmpty, isTrue);
    });

    test('one unreadable stroke does not cost the rest of the drawing', () {
      final restored = Sketch.fromJson(<String, Object?>{
        'id': 'x',
        'name': 'Partly broken',
        'layers': <Object?>[
          <String, Object?>{
            'id': 'l1',
            'name': 'Layer 1',
            'strokes': <Object?>[
              strokeOf(id: 'good').toJson(),
              <String, Object?>{'id': 'bad'},
              'not a stroke',
            ],
          },
        ],
      });
      expect(restored.strokeCount, 1);
      expect(restored.layers.single.strokes.single.id, 'good');
    });

    test('clamps an absurd stored canvas size and layer index', () {
      final restored = Sketch.fromJson(<String, Object?>{
        'id': 'x',
        'width': 99999,
        'height': 1,
        'activeLayerIndex': 42,
      });
      expect(restored.size.width, 8192);
      expect(restored.size.height, 64);
      expect(restored.activeLayerIndex, 0);
    });
  });

  group('UndoStack', () {
    test('starts empty and reports so', () {
      final stack = UndoStack();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
      expect(stack.undo(blank()), isNull);
      expect(stack.redo(blank()), isNull);
      expect(stack.nextUndoLabel, isNull);
    });

    test('applies, undoes and redoes a stroke', () {
      final sketch = blank();
      final stack = UndoStack();
      final stroke = strokeOf(id: 'a');

      stack.run(AddStroke(layerId: 'layer-0', stroke: stroke), sketch);
      expect(sketch.strokeCount, 1);
      expect(stack.canUndo, isTrue);
      expect(stack.nextUndoLabel, 'Stroke');

      stack.undo(sketch);
      expect(sketch.strokeCount, 0);
      expect(stack.canRedo, isTrue);

      stack.redo(sketch);
      expect(sketch.strokeCount, 1);
      expect(sketch.layers[0].strokes.single.id, 'a');
    });

    test('undoes a long run of strokes back to empty and forward again', () {
      final sketch = blank();
      final stack = UndoStack();
      for (var i = 0; i < 50; i++) {
        stack.run(
          AddStroke(layerId: 'layer-0', stroke: strokeOf(id: 's$i')),
          sketch,
        );
      }
      expect(sketch.strokeCount, 50);

      while (stack.canUndo) {
        stack.undo(sketch);
      }
      expect(sketch.strokeCount, 0);

      while (stack.canRedo) {
        stack.redo(sketch);
      }
      expect(sketch.strokeCount, 50);
      expect(
        sketch.layers[0].strokes.map((s) => s.id).toList(),
        <String>[for (var i = 0; i < 50; i++) 's$i'],
        reason: 'redo must restore the original order',
      );
    });

    test('doing something new discards the redo chain', () {
      final sketch = blank();
      final stack = UndoStack();
      stack.run(
        AddStroke(layerId: 'layer-0', stroke: strokeOf(id: 'a')),
        sketch,
      );
      stack.undo(sketch);
      expect(stack.canRedo, isTrue);

      stack.run(
        AddStroke(layerId: 'layer-0', stroke: strokeOf(id: 'b')),
        sketch,
      );

      expect(
        stack.canRedo,
        isFalse,
        reason: 'redoing onto a changed document would be incoherent',
      );
      expect(sketch.layers[0].strokes.single.id, 'b');
    });

    test('forgets the oldest command past its capacity', () {
      final sketch = blank();
      final stack = UndoStack(capacity: 3);
      for (var i = 0; i < 5; i++) {
        stack.run(
          AddStroke(layerId: 'layer-0', stroke: strokeOf(id: 's$i')),
          sketch,
        );
      }
      expect(stack.depth, 3);

      var undone = 0;
      while (stack.canUndo) {
        stack.undo(sketch);
        undone++;
      }
      expect(undone, 3);
      expect(
        sketch.strokeCount,
        2,
        reason: 'the two forgotten strokes stay on the canvas',
      );
    });

    test('clear forgets both directions', () {
      final sketch = blank();
      final stack = UndoStack();
      stack.run(AddStroke(layerId: 'layer-0', stroke: strokeOf()), sketch);
      stack.undo(sketch);
      stack.clear();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
    });

    test('a command against a deleted layer is a no-op, not a crash', () {
      final sketch = blank();
      final stack = UndoStack();
      stack.run(AddStroke(layerId: 'ghost', stroke: strokeOf()), sketch);
      expect(sketch.strokeCount, 0);
      expect(stack.undo(sketch), isNotNull);
    });
  });

  group('EraseStrokes', () {
    test('restores erased strokes to their original place in the stack', () {
      // Order is what covers what, so putting an erased stroke back on top
      // would silently change the drawing.
      final sketch = blank();
      final strokes = <Stroke>[
        for (var i = 0; i < 5; i++) strokeOf(id: 's$i'),
      ];
      sketch.layers[0].strokes.addAll(strokes);

      final stack = UndoStack();
      stack.run(
        EraseStrokes(
          layerId: 'layer-0',
          removed: <(int, Stroke)>[(1, strokes[1]), (3, strokes[3])],
        ),
        sketch,
      );
      expect(
        sketch.layers[0].strokes.map((s) => s.id),
        <String>['s0', 's2', 's4'],
      );

      stack.undo(sketch);
      expect(
        sketch.layers[0].strokes.map((s) => s.id),
        <String>['s0', 's1', 's2', 's3', 's4'],
      );
    });

    test('erasing everything and undoing restores the whole layer', () {
      final sketch = blank();
      final strokes = <Stroke>[
        for (var i = 0; i < 4; i++) strokeOf(id: 's$i'),
      ];
      sketch.layers[0].strokes.addAll(strokes);

      final stack = UndoStack();
      stack.run(
        ClearLayer(layerId: 'layer-0', previous: List<Stroke>.of(strokes)),
        sketch,
      );
      expect(sketch.strokeCount, 0);

      stack.undo(sketch);
      expect(sketch.layers[0].strokes.map((s) => s.id), strokes.map((s) => s.id));
    });
  });

  group('layer commands', () {
    test('adding a layer selects it and undoing restores the selection', () {
      final sketch = blank();
      final stack = UndoStack();

      stack.run(
        AddLayer(layer: Layer(id: 'layer-1', name: 'Layer 2'), atIndex: 1),
        sketch,
      );
      expect(sketch.layers, hasLength(2));
      expect(sketch.activeLayerIndex, 1);

      stack.undo(sketch);
      expect(sketch.layers, hasLength(1));
      expect(sketch.activeLayerIndex, 0);
    });

    test('removing a layer puts it back at its own index on undo', () {
      final sketch = blank(layers: 3);
      sketch.layers[1].strokes.add(strokeOf(id: 'kept'));
      final stack = UndoStack();

      stack.run(
        RemoveLayer(
          layer: sketch.layers[1],
          atIndex: 1,
          previousActive: sketch.activeLayerIndex,
        ),
        sketch,
      );
      expect(sketch.layers.map((l) => l.id), <String>['layer-0', 'layer-2']);

      stack.undo(sketch);
      expect(
        sketch.layers.map((l) => l.id),
        <String>['layer-0', 'layer-1', 'layer-2'],
      );
      expect(sketch.layers[1].strokes.single.id, 'kept');
    });

    test('reordering is reversible', () {
      final sketch = blank(layers: 3);
      final stack = UndoStack();

      stack.run(ReorderLayer(from: 0, to: 2), sketch);
      expect(
        sketch.layers.map((l) => l.id),
        <String>['layer-1', 'layer-2', 'layer-0'],
      );

      stack.undo(sketch);
      expect(
        sketch.layers.map((l) => l.id),
        <String>['layer-0', 'layer-1', 'layer-2'],
      );
    });

    test('an out-of-range reorder does nothing', () {
      final sketch = blank(layers: 2);
      final stack = UndoStack();
      stack.run(ReorderLayer(from: 0, to: 9), sketch);
      expect(sketch.layers.map((l) => l.id), <String>['layer-0', 'layer-1']);
    });

    test('layer properties revert together', () {
      final sketch = blank();
      final stack = UndoStack();
      final layer = sketch.layers[0];

      stack.run(
        SetLayerProperties(
          layerId: layer.id,
          wasVisible: layer.visible,
          wasOpacity: layer.opacity,
          wasName: layer.name,
          visible: false,
          opacity: 0.25,
          name: 'Rough',
        ),
        sketch,
      );
      expect(layer.visible, isFalse);
      expect(layer.opacity, 0.25);
      expect(layer.name, 'Rough');

      stack.undo(sketch);
      expect(layer.visible, isTrue);
      expect(layer.opacity, 1);
      expect(layer.name, 'Layer 1');
    });

    test('an opacity outside the range is clamped', () {
      final sketch = blank();
      UndoStack().run(
        SetLayerProperties(
          layerId: 'layer-0',
          wasVisible: true,
          wasOpacity: 1,
          wasName: 'Layer 1',
          opacity: 7,
        ),
        sketch,
      );
      expect(sketch.layers[0].opacity, 1);
    });
  });

  group('CanvasTransform', () {
    test('screen and canvas coordinates round-trip', () {
      const transform = CanvasTransform(scale: 2.5, offset: Offset(30, -12));
      for (final point in <Offset>[
        Offset.zero,
        const Offset(100, 200),
        const Offset(-50, 17.5),
      ]) {
        final roundTrip = transform.toCanvas(transform.toScreen(point));
        expect(roundTrip.dx, closeTo(point.dx, 1e-9));
        expect(roundTrip.dy, closeTo(point.dy, 1e-9));
      }
    });

    test('the identity transform is a no-op', () {
      const transform = CanvasTransform();
      expect(transform.toCanvas(const Offset(5, 6)), const Offset(5, 6));
      expect(transform.toScreen(const Offset(5, 6)), const Offset(5, 6));
    });

    test('zooming keeps the point under the finger still', () {
      // The property that makes pinch-zoom feel attached to the hand.
      const before = CanvasTransform(scale: 1, offset: Offset(10, 10));
      const focal = Offset(200, 300);
      final canvasUnderFinger = before.toCanvas(focal);

      final after = before.zoomedAround(focal, 2.5);
      final stillUnderFinger = after.toScreen(canvasUnderFinger);

      expect(stillUnderFinger.dx, closeTo(focal.dx, 1e-9));
      expect(stillUnderFinger.dy, closeTo(focal.dy, 1e-9));
      expect(after.scale, closeTo(2.5, 1e-9));
    });

    test('zoom is clamped and returns the same object at the limit', () {
      const transform = CanvasTransform();
      final tiny = transform.zoomedAround(Offset.zero, 0.0001);
      expect(tiny.scale, CanvasTransform.minScale);

      final huge = transform.zoomedAround(Offset.zero, 10000);
      expect(huge.scale, CanvasTransform.maxScale);
      expect(huge.zoomedAround(Offset.zero, 2), same(huge));
    });

    test('zooming out and back in returns to where it started', () {
      const start = CanvasTransform(scale: 2, offset: Offset(17, -4));
      const focal = Offset(120, 90);
      final round = start.zoomedAround(focal, 0.5).zoomedAround(focal, 2);
      expect(round.scale, closeTo(start.scale, 1e-9));
      expect(round.offset.dx, closeTo(start.offset.dx, 1e-9));
      expect(round.offset.dy, closeTo(start.offset.dy, 1e-9));
    });

    test('distance converts with the zoom, so the eraser feels the same', () {
      const zoomed = CanvasTransform(scale: 4);
      expect(zoomed.toCanvasDistance(20), 5);
      expect(const CanvasTransform(scale: 0.5).toCanvasDistance(20), 40);
    });

    test('fit centres the content and respects the padding', () {
      final transform = CanvasTransform.fit(
        content: const Size(1000, 1000),
        viewport: const Size(500, 800),
        padding: 10,
      );
      // Width is the binding dimension: 480 available for 1000 units.
      expect(transform.scale, closeTo(0.48, 1e-9));
      final drawn = 1000 * transform.scale;
      expect(transform.offset.dx, closeTo((500 - drawn) / 2, 1e-9));
      expect(transform.offset.dy, closeTo((800 - drawn) / 2, 1e-9));
    });

    test('fit survives a degenerate viewport or content', () {
      expect(
        CanvasTransform.fit(content: Size.zero, viewport: const Size(10, 10)),
        const CanvasTransform(),
      );
      expect(
        CanvasTransform.fit(content: const Size(10, 10), viewport: Size.zero),
        const CanvasTransform(),
      );
    });

    test('keepOnScreen pulls a flung canvas back into reach', () {
      const content = Size(1000, 1000);
      const viewport = Size(400, 800);

      final lost = const CanvasTransform(
        scale: 1,
        offset: Offset(99999, -99999),
      ).keepOnScreen(content: content, viewport: viewport);

      // Some of the canvas has to intersect the viewport.
      final drawn = Rect.fromLTWH(
        lost.offset.dx,
        lost.offset.dy,
        content.width,
        content.height,
      );
      expect(
        drawn.overlaps(Rect.fromLTWH(0, 0, viewport.width, viewport.height)),
        isTrue,
      );
    });

    test('keepOnScreen leaves a sensible position untouched', () {
      const sensible = CanvasTransform(scale: 1, offset: Offset(20, 30));
      expect(
        sensible.keepOnScreen(
          content: const Size(1000, 1000),
          viewport: const Size(400, 800),
        ),
        sensible,
      );
    });

    test('visibleCanvasRect describes what the viewport can see', () {
      const transform = CanvasTransform(scale: 2, offset: Offset(-100, -200));
      final rect = transform.visibleCanvasRect(const Size(400, 600));
      expect(rect.left, closeTo(50, 1e-9));
      expect(rect.top, closeTo(100, 1e-9));
      expect(rect.width, closeTo(200, 1e-9));
      expect(rect.height, closeTo(300, 1e-9));
    });

    test('equality is by value', () {
      expect(
        const CanvasTransform(scale: 2, offset: Offset(1, 2)),
        const CanvasTransform(scale: 2, offset: Offset(1, 2)),
      );
      expect(
        const CanvasTransform(scale: 2),
        isNot(const CanvasTransform(scale: 3)),
      );
    });
  });
}
