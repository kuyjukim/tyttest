import 'dart:math' as math;
import 'dart:ui';

import 'ink.dart';

/// The geometry behind a stroke: thinning, smoothing, width and hit testing.
///
/// All pure functions on plain geometry, so the interesting parts of a
/// drawing app can be tested without a canvas.
abstract final class StrokeMath {
  /// Drops samples closer together than [minDistance].
  ///
  /// A finger held still emits dozens of samples within a pixel; smoothing
  /// through them produces visible wobble, and keeping them triples the file.
  /// The first and last points are always kept, so a tap still draws a dot
  /// and a stroke still ends where the finger lifted.
  static List<InkPoint> thin(
    List<InkPoint> points, {
    double minDistance = 1.5,
  }) {
    if (points.length < 3) return List<InkPoint>.of(points);
    final kept = <InkPoint>[points.first];
    final threshold = minDistance * minDistance;
    for (var i = 1; i < points.length - 1; i++) {
      final delta = points[i].position - kept.last.position;
      if (delta.distanceSquared >= threshold) kept.add(points[i]);
    }
    kept.add(points.last);
    return kept;
  }

  /// A smooth path through [points] using Catmull-Rom segments converted to
  /// cubic Béziers.
  ///
  /// Catmull-Rom because it passes *through* its control points: a smoothing
  /// spline that only approximates them makes the ink lag behind the finger,
  /// which feels like input latency even when there is none. The ends are
  /// duplicated so the first and last segments curve like the rest.
  static Path centrelinePath(List<InkPoint> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points.first.dx, points.first.dy);
      return path;
    }

    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1].position;
      final p1 = points[i].position;
      final p2 = points[i + 1].position;
      final p3 = points[i + 2 >= points.length ? points.length - 1 : i + 2]
          .position;

      // The sixth is the standard Catmull-Rom to Bézier conversion for a
      // uniform parameterisation.
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  /// Per-point widths, from pressure and from an end taper.
  ///
  /// The taper is measured in arc length rather than in samples, so a stroke
  /// drawn slowly (many samples) tapers over the same distance as the same
  /// shape drawn fast.
  static List<double> widths(
    List<InkPoint> points, {
    required double baseWidth,
    required double pressureInfluence,
    required double taperFraction,
  }) {
    if (points.isEmpty) return const <double>[];
    if (points.length == 1) return <double>[baseWidth * 0.6];

    final cumulative = <double>[0];
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i].position - points[i - 1].position).distance;
      cumulative.add(total);
    }

    final taperLength = total * taperFraction.clamp(0.0, 0.5);
    final result = <double>[];
    for (var i = 0; i < points.length; i++) {
      // Pressure: at influence 0 the width is constant; at 1 a feather-light
      // touch is a hairline.
      final pressure = points[i].pressure.clamp(0.0, 1.0);
      var factor = 1 - pressureInfluence + pressureInfluence * pressure;

      if (taperLength > 0) {
        final fromStart = cumulative[i];
        final fromEnd = total - cumulative[i];
        final nearest = fromStart < fromEnd ? fromStart : fromEnd;
        if (nearest < taperLength) {
          // Square root rather than linear: a linear taper looks like a
          // wedge, this looks like a nib leaving the paper.
          factor *= math.sqrt(nearest / taperLength).clamp(0.08, 1.0);
        }
      }

      result.add((baseWidth * factor).clamp(0.3, baseWidth));
    }
    return result;
  }

  /// Builds the filled outline of a variable-width stroke.
  ///
  /// A stroked path cannot vary its width along its length, so the only way
  /// to get a tapered line is to generate the outline and fill it: walk one
  /// side, then the other in reverse, with round caps at both ends.
  static Path outline(List<InkPoint> points, List<double> widths) {
    assert(
      points.length == widths.length,
      'every point needs its own width',
    );
    final path = Path();
    if (points.isEmpty) return path;

    if (points.length == 1) {
      // A tap is a dot.
      path.addOval(
        Rect.fromCircle(
          center: points.first.position,
          radius: math.max(widths.first / 2, 0.3),
        ),
      );
      return path;
    }

    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final normal = _normalAt(points, i);
      final half = widths[i] / 2;
      left.add(points[i].position + normal * half);
      right.add(points[i].position - normal * half);
    }

    path.moveTo(left.first.dx, left.first.dy);
    for (var i = 1; i < left.length; i++) {
      path.lineTo(left[i].dx, left[i].dy);
    }
    // Round the far end rather than cutting it square.
    path.arcToPoint(
      right.last,
      radius: Radius.circular(math.max(widths.last / 2, 0.1)),
      clockwise: false,
    );
    for (var i = right.length - 2; i >= 0; i--) {
      path.lineTo(right[i].dx, right[i].dy);
    }
    path.arcToPoint(
      left.first,
      radius: Radius.circular(math.max(widths.first / 2, 0.1)),
      clockwise: false,
    );
    path.close();
    return path;
  }

  /// Unit normal to the stroke at [index].
  ///
  /// Uses the neighbours either side so the normal is continuous; a normal
  /// taken from a single segment jumps at every corner and leaves notches in
  /// the outline.
  static Offset _normalAt(List<InkPoint> points, int index) {
    final before = points[index == 0 ? 0 : index - 1].position;
    final after =
        points[index == points.length - 1 ? index : index + 1].position;
    var tangent = after - before;
    if (tangent.distanceSquared < 1e-12) {
      // Coincident neighbours: fall back to any consistent direction rather
      // than dividing by zero.
      tangent = const Offset(1, 0);
    }
    final length = tangent.distance;
    return Offset(-tangent.dy / length, tangent.dx / length);
  }

  /// Shortest distance from [point] to the polyline through [points].
  static double distanceToPolyline(List<InkPoint> points, Offset point) {
    if (points.isEmpty) return double.infinity;
    if (points.length == 1) {
      return (points.first.position - point).distance;
    }
    var best = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = _distanceToSegment(
        point,
        points[i].position,
        points[i + 1].position,
      );
      if (d < best) best = d;
    }
    return best;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared < 1e-12) return (p - a).distance;
    // Projection parameter, clamped to the segment.
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared)
        .clamp(0.0, 1.0);
    final projection = a + ab * t;
    return (p - projection).distance;
  }

  /// Whether an eraser of [radius] centred at [point] touches [stroke].
  ///
  /// Half the stroke's width counts, so a fat marker line is erased by
  /// brushing its edge rather than needing a hit on its centreline.
  static bool hits(Stroke stroke, Offset point, double radius) {
    final reach = radius + stroke.width / 2;
    // Bounds first: for a sketch with hundreds of strokes this rejects
    // almost all of them without measuring a single segment.
    if (!stroke.bounds.inflate(radius).contains(point)) return false;
    return distanceToPolyline(stroke.points, point) <= reach;
  }

  /// Total length of the polyline, for the taper and for statistics.
  static double length(List<InkPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i].position - points[i - 1].position).distance;
    }
    return total;
  }
}
