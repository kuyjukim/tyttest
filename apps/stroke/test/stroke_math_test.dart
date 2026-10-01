import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroke/domain/ink.dart';
import 'package:stroke/domain/stroke_math.dart';

List<InkPoint> line({
  required int count,
  double spacing = 10,
  double pressure = 1,
}) => <InkPoint>[
  for (var i = 0; i < count; i++)
    InkPoint(Offset(i * spacing, 0), pressure),
];

Stroke strokeOf(
  List<InkPoint> points, {
  BrushKind kind = BrushKind.pen,
  double width = 6,
}) => Stroke(
  id: 's',
  kind: kind,
  colorValue: 0xFF000000,
  width: width,
  opacity: 1,
  points: points,
);

void main() {
  group('thin', () {
    test('keeps the ends and drops samples that are too close', () {
      final jitter = <InkPoint>[
        const InkPoint(Offset.zero, 1),
        const InkPoint(Offset(0.2, 0), 1),
        const InkPoint(Offset(0.4, 0), 1),
        const InkPoint(Offset(20, 0), 1),
        const InkPoint(Offset(20.1, 0), 1),
      ];
      final thinned = StrokeMath.thin(jitter);

      expect(thinned.first, jitter.first);
      expect(thinned.last, jitter.last);
      expect(thinned.length, 3, reason: 'the sub-pixel samples go');
    });

    test('leaves two points and a single point alone', () {
      expect(StrokeMath.thin(line(count: 1)).length, 1);
      expect(StrokeMath.thin(line(count: 2, spacing: 0.1)).length, 2);
    });

    test('a long slow stroke thins substantially', () {
      final dense = <InkPoint>[
        for (var i = 0; i < 400; i++) InkPoint(Offset(i * 0.25, 0), 1),
      ];
      final thinned = StrokeMath.thin(dense);
      expect(thinned.length, lessThan(dense.length / 3));
      expect(thinned.last.position.dx, dense.last.position.dx);
    });

    test('keeps everything when samples are already far apart', () {
      final sparse = line(count: 10, spacing: 12);
      expect(StrokeMath.thin(sparse).length, 10);
    });

    test('never returns the caller\'s own list', () {
      final input = line(count: 2);
      expect(StrokeMath.thin(input), isNot(same(input)));
    });
  });

  group('centrelinePath', () {
    test('is empty for no points and a point for one', () {
      expect(StrokeMath.centrelinePath(const <InkPoint>[]).computeMetrics(),
          isEmpty);
      final dot = StrokeMath.centrelinePath(line(count: 1));
      expect(dot.getBounds().isEmpty, isTrue);
    });

    test('passes through every input point', () {
      // Catmull-Rom interpolates its control points; a spline that only
      // approximates them makes the ink lag behind the finger.
      final points = <InkPoint>[
        const InkPoint(Offset.zero, 1),
        const InkPoint(Offset(10, 20), 1),
        const InkPoint(Offset(30, 5), 1),
        const InkPoint(Offset(50, 40), 1),
      ];
      final path = StrokeMath.centrelinePath(points);

      for (final point in points) {
        expect(
          path.contains(point.position) ||
              _nearestDistance(path, point.position) < 0.5,
          isTrue,
          reason: 'path should reach ${point.position}',
        );
      }
    });

    test('a straight input stays straight', () {
      final path = StrokeMath.centrelinePath(line(count: 6));
      final bounds = path.getBounds();
      expect(bounds.height, lessThan(0.001));
      expect(bounds.width, closeTo(50, 0.001));
    });

    test('two points are joined by a line', () {
      final path = StrokeMath.centrelinePath(line(count: 2, spacing: 40));
      expect(path.getBounds().width, closeTo(40, 0.001));
    });
  });

  group('widths', () {
    test('are constant when nothing varies them', () {
      final result = StrokeMath.widths(
        line(count: 5),
        baseWidth: 8,
        pressureInfluence: 0,
        taperFraction: 0,
      );
      expect(result, everyElement(closeTo(8, 1e-9)));
    });

    test('scale with pressure', () {
      final soft = StrokeMath.widths(
        line(count: 5, pressure: 0.2),
        baseWidth: 10,
        pressureInfluence: 0.65,
        taperFraction: 0,
      );
      final firm = StrokeMath.widths(
        line(count: 5, pressure: 1),
        baseWidth: 10,
        pressureInfluence: 0.65,
        taperFraction: 0,
      );
      expect(soft.first, lessThan(firm.first));
      expect(firm.first, closeTo(10, 1e-9));
    });

    test('taper toward both ends and are widest in the middle', () {
      final result = StrokeMath.widths(
        line(count: 21),
        baseWidth: 10,
        pressureInfluence: 0,
        taperFraction: 0.2,
      );
      expect(result.first, lessThan(result[10]));
      expect(result.last, lessThan(result[10]));
      expect(result[10], closeTo(10, 1e-9));
      expect(
        result.first,
        closeTo(result.last, 1e-9),
        reason: 'the taper is symmetric',
      );
    });

    test('taper by arc length, not by sample count', () {
      // The same shape sampled twice as densely must taper over the same
      // distance, or a slowly drawn line would look different from a fast one.
      final sparse = StrokeMath.widths(
        line(count: 11, spacing: 10),
        baseWidth: 10,
        pressureInfluence: 0,
        taperFraction: 0.2,
      );
      final dense = StrokeMath.widths(
        line(count: 21, spacing: 5),
        baseWidth: 10,
        pressureInfluence: 0,
        taperFraction: 0.2,
      );
      // Point 2 of the sparse list and point 4 of the dense one are at the
      // same place on the line.
      expect(sparse[2], closeTo(dense[4], 1e-9));
    });

    test('never go to zero or above the nominal width', () {
      final result = StrokeMath.widths(
        line(count: 30, pressure: 0),
        baseWidth: 4,
        pressureInfluence: 1,
        taperFraction: 0.5,
      );
      expect(result, everyElement(greaterThan(0)));
      expect(result, everyElement(lessThanOrEqualTo(4)));
    });

    test('a zero-length stroke does not divide by zero', () {
      final stacked = <InkPoint>[
        for (var i = 0; i < 5; i++) const InkPoint(Offset(7, 7), 1),
      ];
      final result = StrokeMath.widths(
        stacked,
        baseWidth: 8,
        pressureInfluence: 0.5,
        taperFraction: 0.3,
      );
      expect(result.length, 5);
      expect(result.every((w) => w.isFinite && w > 0), isTrue);
    });

    test('handle an empty and a single-point stroke', () {
      expect(
        StrokeMath.widths(
          const <InkPoint>[],
          baseWidth: 8,
          pressureInfluence: 0.5,
          taperFraction: 0.2,
        ),
        isEmpty,
      );
      expect(
        StrokeMath.widths(
          line(count: 1),
          baseWidth: 8,
          pressureInfluence: 0.5,
          taperFraction: 0.2,
        ).single,
        closeTo(4.8, 1e-9),
      );
    });
  });

  group('outline', () {
    test('a tap becomes a dot of the right size', () {
      final path = StrokeMath.outline(line(count: 1), <double>[8]);
      final bounds = path.getBounds();
      expect(bounds.width, closeTo(8, 0.001));
      expect(bounds.height, closeTo(8, 0.001));
    });

    test('a straight stroke is as wide as its width and as long as its line',
        () {
      final points = line(count: 6);
      final widths = List<double>.filled(points.length, 6);
      final bounds = StrokeMath.outline(points, widths).getBounds();

      expect(bounds.height, closeTo(6, 0.5));
      // Length plus the two round caps.
      expect(bounds.width, closeTo(50 + 6, 1.5));
    });

    test('a tapered stroke is narrower at its ends than in the middle', () {
      final points = line(count: 21);
      final widths = StrokeMath.widths(
        points,
        baseWidth: 12,
        pressureInfluence: 0,
        taperFraction: 0.25,
      );
      final path = StrokeMath.outline(points, widths);

      // Sample the filled area in a thin column near the end and near the
      // middle: the tapered end should cover fewer rows.
      expect(
        _coveredHeight(path, x: points[1].dx),
        lessThan(_coveredHeight(path, x: points[10].dx)),
      );
    });

    test('contains its own centreline', () {
      final points = <InkPoint>[
        const InkPoint(Offset(10, 10), 1),
        const InkPoint(Offset(40, 30), 1),
        const InkPoint(Offset(70, 10), 1),
      ];
      final path = StrokeMath.outline(
        points,
        List<double>.filled(points.length, 8),
      );
      for (final point in points) {
        expect(
          path.contains(point.position),
          isTrue,
          reason: 'the outline must enclose ${point.position}',
        );
      }
    });

    test('survives coincident points without producing NaN', () {
      final points = <InkPoint>[
        const InkPoint(Offset(5, 5), 1),
        const InkPoint(Offset(5, 5), 1),
        const InkPoint(Offset(5, 5), 1),
        const InkPoint(Offset(25, 5), 1),
      ];
      final bounds = StrokeMath.outline(
        points,
        List<double>.filled(points.length, 4),
      ).getBounds();

      expect(bounds.isFinite, isTrue);
      expect(bounds.left.isNaN, isFalse);
    });

    test('a doubled-back stroke still produces a finite outline', () {
      final points = <InkPoint>[
        const InkPoint(Offset.zero, 1),
        const InkPoint(Offset(20, 0), 1),
        const InkPoint(Offset(0, 0), 1),
      ];
      final bounds = StrokeMath.outline(
        points,
        List<double>.filled(points.length, 6),
      ).getBounds();
      expect(bounds.isFinite, isTrue);
    });
  });

  group('distance and hit testing', () {
    test('distance to a polyline is measured to the nearest segment', () {
      final points = line(count: 3, spacing: 10);
      expect(StrokeMath.distanceToPolyline(points, const Offset(10, 5)), 5);
      expect(
        StrokeMath.distanceToPolyline(points, const Offset(-10, 0)),
        10,
        reason: 'past the end, the distance is to the endpoint',
      );
      expect(
        StrokeMath.distanceToPolyline(points, const Offset(5, 0)),
        0,
        reason: 'on the line between two samples',
      );
    });

    test('an empty polyline is infinitely far away', () {
      expect(
        StrokeMath.distanceToPolyline(const <InkPoint>[], Offset.zero),
        double.infinity,
      );
    });

    test('a single-point polyline measures to that point', () {
      expect(
        StrokeMath.distanceToPolyline(line(count: 1), const Offset(3, 4)),
        5,
      );
    });

    test('the eraser counts half the stroke width as reach', () {
      final thick = strokeOf(line(count: 3), width: 20);
      // 11 away from the centreline: outside the centreline but inside the
      // ink, since the stroke is 20 wide.
      expect(StrokeMath.hits(thick, const Offset(10, 9), 0), isTrue);
      expect(StrokeMath.hits(thick, const Offset(10, 30), 0), isFalse);
      expect(
        StrokeMath.hits(thick, const Offset(10, 25), 16),
        isTrue,
        reason: 'a big eraser reaches further',
      );
    });

    test('the eraser misses a stroke far outside its bounds cheaply', () {
      final stroke = strokeOf(line(count: 200, spacing: 5));
      expect(StrokeMath.hits(stroke, const Offset(-500, -500), 8), isFalse);
    });

    test('a dot can be erased', () {
      final dot = strokeOf(line(count: 1), width: 10);
      expect(StrokeMath.hits(dot, Offset.zero, 2), isTrue);
      expect(StrokeMath.hits(dot, const Offset(40, 0), 2), isFalse);
    });
  });

  group('length', () {
    test('sums the segments', () {
      expect(StrokeMath.length(line(count: 5, spacing: 10)), closeTo(40, 1e-9));
      expect(StrokeMath.length(line(count: 1)), 0);
      expect(StrokeMath.length(const <InkPoint>[]), 0);
    });

    test('measures a diagonal correctly', () {
      final diagonal = <InkPoint>[
        const InkPoint(Offset.zero, 1),
        const InkPoint(Offset(3, 4), 1),
      ];
      expect(StrokeMath.length(diagonal), closeTo(5, 1e-9));
    });
  });

  group('Stroke', () {
    test('bounds include half the width as padding', () {
      final stroke = strokeOf(line(count: 3, spacing: 10), width: 8);
      expect(stroke.bounds.left, closeTo(-5, 1e-9));
      expect(stroke.bounds.right, closeTo(25, 1e-9));
    });

    test('round-trips through JSON, including odd pressures', () {
      final original = Stroke(
        id: 'abc',
        kind: BrushKind.highlighter,
        colorValue: 0xFF336699,
        width: 26,
        opacity: 0.35,
        points: <InkPoint>[
          const InkPoint(Offset(1.25, 2.75), 0.5),
          const InkPoint(Offset(100.4, -3.1), 1),
        ],
      );
      final restored = Stroke.fromJson(original.toJson());

      expect(restored.id, 'abc');
      expect(restored.kind, BrushKind.highlighter);
      expect(restored.colorValue, 0xFF336699);
      expect(restored.opacity, closeTo(0.35, 1e-9));
      expect(restored.points.length, 2);
      expect(restored.points.first.position.dx, closeTo(1.3, 0.06));
      expect(restored.points.last.position.dy, closeTo(-3.1, 0.06));
    });

    test('stores points flat, which is most of the file size', () {
      final stroke = strokeOf(line(count: 100));
      final points = stroke.toJson()['points']! as List<Object?>;
      expect(points.length, 300, reason: 'x, y, pressure per sample');
    });

    test('refuses a stroke with no usable points', () {
      expect(
        () => Stroke.fromJson(<String, Object?>{'id': 'x', 'points': <Object?>[]}),
        throwsFormatException,
      );
      expect(
        () => Stroke.fromJson(<String, Object?>{
          'id': 'x',
          'points': <Object?>['a', 'b', 'c'],
        }),
        throwsFormatException,
      );
    });

    test('clamps hostile stored values instead of trusting them', () {
      final stroke = Stroke.fromJson(<String, Object?>{
        'id': 'x',
        'kind': 'airbrush',
        'width': 99999,
        'opacity': 7,
        'points': <Object?>[0, 0, 42],
      });
      expect(stroke.kind, BrushKind.pen);
      expect(stroke.width, 200);
      expect(stroke.opacity, 1);
      expect(stroke.points.single.pressure, 1);
    });

    test('translate moves every point and keeps the identity', () {
      final stroke = strokeOf(line(count: 3));
      final moved = stroke.translate(const Offset(5, -5));
      expect(moved.points.first.position, const Offset(5, -5));
      expect(moved.id, stroke.id);
    });
  });

  group('BrushKind', () {
    test('a highlighter is translucent and does not taper', () {
      expect(BrushKind.highlighter.defaultOpacity, lessThan(1));
      expect(BrushKind.highlighter.taperFraction, 0);
      expect(BrushKind.highlighter.pressureInfluence, 0);
    });

    test('a pen tapers and responds to pressure most', () {
      expect(
        BrushKind.pen.pressureInfluence,
        greaterThan(BrushKind.marker.pressureInfluence),
      );
      expect(BrushKind.pen.taperFraction, greaterThan(0));
    });

    test('byName is total and falls back to the pen', () {
      for (final kind in BrushKind.values) {
        expect(BrushKind.byName(kind.name), kind);
      }
      expect(BrushKind.byName('crayon'), BrushKind.pen);
      expect(BrushKind.byName(null), BrushKind.pen);
    });
  });
}

/// Approximate distance from [path] to [target], by walking its metrics.
double _nearestDistance(Path path, Offset target) {
  var best = double.infinity;
  for (final metric in path.computeMetrics()) {
    const samples = 200;
    for (var i = 0; i <= samples; i++) {
      final position = metric.getTangentForOffset(
        metric.length * i / samples,
      )?.position;
      if (position == null) continue;
      final distance = (position - target).distance;
      if (distance < best) best = distance;
    }
  }
  return best;
}

/// How tall the filled region of [path] is at a given x, by sampling.
double _coveredHeight(Path path, {required double x}) {
  var covered = 0;
  for (var y = -40; y <= 40; y++) {
    if (path.contains(Offset(x, y / 2))) covered++;
  }
  return covered / 2;
}
