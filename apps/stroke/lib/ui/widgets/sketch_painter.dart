import 'package:flutter/material.dart';

import '../../domain/canvas_transform.dart';
import '../../domain/ink.dart';
import '../../domain/sketch.dart';
import '../../domain/stroke_math.dart';

/// Builds and remembers the [Path] for each stroke.
///
/// Rebuilding the outline of every stroke on every frame is the thing that
/// makes a drawing app feel heavy: the geometry is fixed once the finger
/// lifts, so it is computed once and kept. Keyed by stroke id, which is
/// stable across undo and redo, so an undone stroke keeps its path for when
/// it comes back.
class StrokeCache {
  final Map<String, Path> _paths = <String, Path>{};

  int get size => _paths.length;

  Path pathFor(Stroke stroke) => _paths.putIfAbsent(stroke.id, () {
    final widths = StrokeMath.widths(
      stroke.points,
      baseWidth: stroke.width,
      pressureInfluence: stroke.kind.pressureInfluence,
      taperFraction: stroke.kind.taperFraction,
    );
    return StrokeMath.outline(stroke.points, widths);
  });

  /// Drops paths for strokes that are no longer anywhere in [sketch].
  ///
  /// Called after an erase rather than on every frame: walking every stroke
  /// to find the survivors costs more than the memory it reclaims if it is
  /// done sixty times a second.
  void retain(Sketch sketch) {
    final alive = <String>{
      for (final layer in sketch.layers)
        for (final stroke in layer.strokes) stroke.id,
    };
    _paths.removeWhere((id, _) => !alive.contains(id));
  }

  void clear() => _paths.clear();
}

/// Draws the paper, the layers and the stroke in progress.
class SketchPainter extends CustomPainter {
  SketchPainter({
    required this.sketch,
    required this.transform,
    required this.cache,
    required this.paperColor,
    required this.edgeColor,
    this.live = const <InkPoint>[],
    this.liveStroke,
  });

  final Sketch sketch;
  final CanvasTransform transform;
  final StrokeCache cache;
  final Color paperColor;
  final Color edgeColor;

  /// Points of the stroke being drawn, in canvas units.
  final List<InkPoint> live;

  /// A stroke carrying the live brush settings, for the preview.
  final Stroke? liveStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Rect.fromLTWH(0, 0, sketch.size.width, sketch.size.height);
    final visible = transform.visibleCanvasRect(size);

    canvas
      ..save()
      ..transform(transform.matrix.storage);

    // The page itself, so the drawing has an edge rather than floating on the
    // app's background.
    canvas
      ..drawRect(paper, Paint()..color = paperColor)
      ..drawRect(
        paper,
        Paint()
          ..color = edgeColor
          ..style = PaintingStyle.stroke
          // Constant on screen whatever the zoom; a hairline that thickens
          // when you zoom in reads as part of the drawing.
          ..strokeWidth = 1 / transform.scale,
      );

    // Clipped to the page, so a stroke that ran off the edge stays off it.
    canvas
      ..save()
      ..clipRect(paper);

    for (final layer in sketch.layers) {
      if (!layer.visible || layer.strokes.isEmpty) continue;

      final needsGroup = layer.opacity < 1;
      if (needsGroup) {
        // One group per layer, so a half-opaque layer fades as a whole
        // instead of each stroke fading over the ones beneath it.
        canvas.saveLayer(
          paper,
          Paint()..color = const Color(0xFF000000).withValues(
            alpha: layer.opacity,
          ),
        );
      }

      for (final stroke in layer.strokes) {
        if (!stroke.bounds.overlaps(visible)) continue;
        canvas.drawPath(cache.pathFor(stroke), Paint()..color = stroke.color);
      }

      if (needsGroup) canvas.restore();
    }

    final preview = liveStroke;
    if (preview != null && live.isNotEmpty) {
      final widths = StrokeMath.widths(
        live,
        baseWidth: preview.width,
        pressureInfluence: preview.kind.pressureInfluence,
        taperFraction: preview.kind.taperFraction,
      );
      canvas.drawPath(
        StrokeMath.outline(live, widths),
        Paint()..color = preview.color,
      );
    }

    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(SketchPainter old) =>
      // The sketch is mutated in place, so identity is not enough; the stroke
      // count and the live point count are what actually change between
      // frames while drawing.
      old.sketch != sketch ||
      old.transform != transform ||
      old.sketch.strokeCount != sketch.strokeCount ||
      old.live.length != live.length ||
      old.liveStroke?.colorValue != liveStroke?.colorValue ||
      old.paperColor != paperColor ||
      _layersDiffer(old.sketch, sketch);

  static bool _layersDiffer(Sketch a, Sketch b) {
    if (a.layers.length != b.layers.length) return true;
    for (var i = 0; i < a.layers.length; i++) {
      if (a.layers[i].visible != b.layers[i].visible) return true;
      if (a.layers[i].opacity != b.layers[i].opacity) return true;
      if (a.layers[i].strokes.length != b.layers[i].strokes.length) return true;
    }
    return false;
  }
}
