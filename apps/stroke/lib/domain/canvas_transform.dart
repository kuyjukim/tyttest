import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Maps between screen coordinates and canvas coordinates.
///
/// Strokes are stored in canvas units, which is what makes zooming
/// non-destructive and keeps a drawing resolution-independent: the same file
/// renders at 1x on a phone and at 3x on a tablet without resampling a single
/// point.
@immutable
class CanvasTransform {
  const CanvasTransform({this.scale = 1, this.offset = Offset.zero});

  /// Zoom bounds. Below the minimum a stroke is sub-pixel and the drawing is
  /// a smudge; above the maximum the canvas is a wall of one colour.
  static const double minScale = 0.2;
  static const double maxScale = 16;

  final double scale;

  /// Where canvas (0, 0) sits on screen.
  final Offset offset;

  Offset toCanvas(Offset screenPoint) => (screenPoint - offset) / scale;

  Offset toScreen(Offset canvasPoint) => canvasPoint * scale + offset;

  /// Distance in canvas units for a distance in screen pixels.
  ///
  /// Used so that an eraser or a hit test has the same on-screen reach
  /// whatever the zoom - at 4x, a 20-pixel fingertip covers 5 canvas units.
  double toCanvasDistance(double screenDistance) => screenDistance / scale;

  CanvasTransform translated(Offset delta) =>
      CanvasTransform(scale: scale, offset: offset + delta);

  /// Scales by [factor], keeping the canvas point under [focalScreenPoint]
  /// under it afterwards.
  ///
  /// Zooming that does not respect the focal point feels like the canvas is
  /// being yanked away, because the thing the user is looking at moves.
  CanvasTransform zoomedAround(Offset focalScreenPoint, double factor) {
    final target = (scale * factor).clamp(minScale, maxScale);
    if (target == scale) return this;
    // Solve toScreen(canvasFocal) == focalScreenPoint for the new offset.
    final canvasFocal = toCanvas(focalScreenPoint);
    return CanvasTransform(
      scale: target,
      offset: focalScreenPoint - canvasFocal * target,
    );
  }

  /// A transform that fits [content] inside [viewport] with [padding].
  static CanvasTransform fit({
    required Size content,
    required Size viewport,
    double padding = 16,
  }) {
    if (content.isEmpty || viewport.isEmpty) return const CanvasTransform();
    final available = Size(
      math.max(viewport.width - padding * 2, 1),
      math.max(viewport.height - padding * 2, 1),
    );
    final scale = math
        .min(available.width / content.width, available.height / content.height)
        .clamp(minScale, maxScale);
    // Centre whatever is left over.
    final drawn = Size(content.width * scale, content.height * scale);
    return CanvasTransform(
      scale: scale,
      offset: Offset(
        (viewport.width - drawn.width) / 2,
        (viewport.height - drawn.height) / 2,
      ),
    );
  }

  /// Pulls the canvas back when it has been dragged entirely out of view.
  ///
  /// Not a hard clamp to the edges: being able to push the page off-centre is
  /// useful when drawing near a margin. This only guarantees that some of the
  /// canvas is always reachable, so a stray fling cannot lose the drawing.
  CanvasTransform keepOnScreen({
    required Size content,
    required Size viewport,
    double minVisible = 48,
  }) {
    final drawn = Size(content.width * scale, content.height * scale);
    final minX = minVisible - drawn.width;
    final maxX = viewport.width - minVisible;
    final minY = minVisible - drawn.height;
    final maxY = viewport.height - minVisible;
    return CanvasTransform(
      scale: scale,
      offset: Offset(
        offset.dx.clamp(math.min(minX, maxX), math.max(minX, maxX)),
        offset.dy.clamp(math.min(minY, maxY), math.max(minY, maxY)),
      ),
    );
  }

  Matrix4 get matrix => Matrix4.identity()
    ..translateByDouble(offset.dx, offset.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);

  /// The canvas-space rectangle currently visible in a [viewport].
  Rect visibleCanvasRect(Size viewport) => Rect.fromPoints(
    toCanvas(Offset.zero),
    toCanvas(Offset(viewport.width, viewport.height)),
  );

  @override
  bool operator ==(Object other) =>
      other is CanvasTransform &&
      other.scale == scale &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(scale, offset);

  @override
  String toString() =>
      'CanvasTransform(scale: ${scale.toStringAsFixed(2)}, offset: $offset)';
}
