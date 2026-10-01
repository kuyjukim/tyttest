import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/canvas_transform.dart';
import '../../domain/ink.dart';
import '../../state/studio_store.dart';
import 'sketch_painter.dart';

/// The drawing surface.
///
/// Pointer events are handled directly rather than through gesture
/// recognisers. A drawing canvas has to distinguish "one finger, so draw"
/// from "two fingers, so pan and zoom" on the first move, and the gesture
/// arena resolves that by waiting - which shows up as the first few
/// millimetres of every stroke going missing.
class SketchCanvas extends StatefulWidget {
  const SketchCanvas({super.key});

  /// Screen-pixel radius of the eraser, so it feels the same at every zoom.
  static const double eraserScreenRadius = 14;

  @override
  State<SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<SketchCanvas> {
  final StrokeCache _cache = StrokeCache();

  /// Live pointer positions, in screen space, keyed by pointer id.
  final Map<int, Offset> _pointers = <int, Offset>{};

  /// The pointer currently drawing, if any.
  int? _drawingPointer;

  /// Midpoint and spread of a two-finger gesture, from the previous frame.
  Offset? _lastFocal;
  double? _lastSpread;

  String? _cachedSketchId;

  StudioStore get _store => Scope.read<StudioStore>(context);

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<StudioStore>(context);
    final sketch = store.sketch;
    if (sketch == null) return const SizedBox.shrink();

    if (_cachedSketchId != sketch.id) {
      _cachedSketchId = sketch.id;
      _cache.clear();
    }

    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        // First build: sit the page in the middle at a sensible zoom.
        if (store.transform == const CanvasTransform() && !viewport.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_store.transform != const CanvasTransform()) return;
            _store.setTransform(
              CanvasTransform.fit(content: sketch.size, viewport: viewport),
            );
          });
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _onDown(event, viewport),
          onPointerMove: (event) => _onMove(event, viewport),
          onPointerUp: (event) => _onUp(event, viewport),
          onPointerCancel: (event) => _onUp(event, viewport),
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            // Trackpad and mouse wheel zoom, which is how this gets used on
            // a desktop.
            final factor = event.scrollDelta.dy > 0 ? 0.9 : 1 / 0.9;
            _store.setTransform(
              _store.transform
                  .zoomedAround(event.localPosition, factor)
                  .keepOnScreen(content: sketch.size, viewport: viewport),
            );
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: SketchPainter(
                sketch: sketch,
                transform: store.transform,
                cache: _cache,
                paperColor: colors.isDark
                    ? const Color(0xFF26231F)
                    : const Color(0xFFFFFDFA),
                edgeColor: colors.hairline,
                live: store.liveStroke,
                liveStroke: Stroke(
                  id: 'live',
                  kind: store.brush.kind,
                  colorValue: store.brush.colorValue,
                  width: store.brush.width,
                  opacity: store.brush.opacity,
                  points: const <InkPoint>[InkPoint(Offset.zero, 1)],
                ),
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  /// Normalises a device's pressure range to 0..1.
  ///
  /// Devices report wildly different ranges, and one with no sensor reports a
  /// constant with min equal to max - which is a division by zero waiting to
  /// happen in the obvious implementation.
  static double _pressureOf(PointerEvent event) {
    final span = event.pressureMax - event.pressureMin;
    if (span <= 0) return 1;
    return ((event.pressure - event.pressureMin) / span).clamp(0.0, 1.0);
  }

  void _onDown(PointerDownEvent event, Size viewport) {
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2) {
      // A second finger landed: this is a pinch, not a stroke. Throw away
      // whatever the first finger had started, so a two-finger zoom never
      // leaves a stray mark.
      _store.cancelStroke();
      _drawingPointer = null;
      _beginTwoFinger();
      return;
    }

    final store = _store;
    final canvasPoint = store.transform.toCanvas(event.localPosition);
    switch (store.tool) {
      case Tool.draw:
        _drawingPointer = event.pointer;
        store.beginStroke(canvasPoint, _pressureOf(event));
      case Tool.erase:
        _drawingPointer = event.pointer;
        store.eraseAt(
          canvasPoint,
          store.transform.toCanvasDistance(SketchCanvas.eraserScreenRadius),
        );
      case Tool.pan:
        _drawingPointer = null;
    }
  }

  void _onMove(PointerMoveEvent event, Size viewport) {
    final previous = _pointers[event.pointer];
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2) {
      _updateTwoFinger(viewport);
      return;
    }

    final store = _store;
    if (store.tool == Tool.pan) {
      if (previous == null) return;
      store.setTransform(
        store.transform
            .translated(event.localPosition - previous)
            .keepOnScreen(content: store.sketch!.size, viewport: viewport),
      );
      return;
    }

    if (event.pointer != _drawingPointer) return;
    final canvasPoint = store.transform.toCanvas(event.localPosition);
    switch (store.tool) {
      case Tool.draw:
        store.extendStroke(canvasPoint, _pressureOf(event));
      case Tool.erase:
        store.eraseAt(
          canvasPoint,
          store.transform.toCanvasDistance(SketchCanvas.eraserScreenRadius),
        );
      case Tool.pan:
        break;
    }
  }

  void _onUp(PointerEvent event, Size viewport) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _lastFocal = null;
      _lastSpread = null;
    }

    if (event.pointer != _drawingPointer) return;
    _drawingPointer = null;

    final store = _store;
    switch (store.tool) {
      case Tool.draw:
        store.endStroke();
      case Tool.erase:
        store.endErase();
        _cache.retain(store.sketch!);
      case Tool.pan:
        break;
    }
  }

  void _beginTwoFinger() {
    final positions = _pointers.values.toList();
    _lastFocal = _midpoint(positions);
    _lastSpread = _spread(positions, _lastFocal!);
  }

  void _updateTwoFinger(Size viewport) {
    final positions = _pointers.values.toList();
    final focal = _midpoint(positions);
    final spread = _spread(positions, focal);
    final previousFocal = _lastFocal;
    final previousSpread = _lastSpread;
    _lastFocal = focal;
    _lastSpread = spread;
    if (previousFocal == null || previousSpread == null) return;

    final store = _store;
    var next = store.transform.translated(focal - previousFocal);
    if (previousSpread > 8 && spread > 8) {
      // Below a few pixels of spread the ratio is mostly noise, and a pinch
      // that small is a two-finger pan.
      next = next.zoomedAround(focal, spread / previousSpread);
    }
    store.setTransform(
      next.keepOnScreen(content: store.sketch!.size, viewport: viewport),
    );
  }

  static Offset _midpoint(List<Offset> points) {
    var sum = Offset.zero;
    for (final point in points) {
      sum += point;
    }
    return sum / points.length.toDouble();
  }

  static double _spread(List<Offset> points, Offset centre) {
    var total = 0.0;
    for (final point in points) {
      total += (point - centre).distance;
    }
    return total / points.length;
  }
}
