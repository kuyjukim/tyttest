import 'dart:ui';

/// One sample from the pointer.
///
/// Pressure is normalised to 0..1 before it gets here. Devices report wildly
/// different ranges - and a device with no pressure sensor reports a constant
/// 1.0 - so normalising at the boundary keeps every brush calculation in one
/// unit system.
class InkPoint {
  const InkPoint(this.position, this.pressure);

  final Offset position;

  /// 0..1. A device without pressure reports 1.
  final double pressure;

  double get dx => position.dx;
  double get dy => position.dy;

  InkPoint translate(Offset delta) => InkPoint(position + delta, pressure);

  @override
  bool operator ==(Object other) =>
      other is InkPoint &&
      other.position == position &&
      other.pressure == pressure;

  @override
  int get hashCode => Object.hash(position, pressure);

  @override
  String toString() =>
      'InkPoint(${position.dx.toStringAsFixed(1)}, '
      '${position.dy.toStringAsFixed(1)}, p=${pressure.toStringAsFixed(2)})';
}

/// How a stroke is drawn.
enum BrushKind {
  /// Tapered at both ends and thinned by pressure. The calligraphic one.
  pen,

  /// Constant width, square-ish ends. For blocking in and for arrows.
  marker,

  /// Wide, constant, and translucent, so overlaps build up.
  highlighter;

  /// How strongly pressure thins the line.
  double get pressureInfluence => switch (this) {
    BrushKind.pen => 0.65,
    BrushKind.marker => 0.15,
    BrushKind.highlighter => 0,
  };

  /// Fraction of the stroke's length over which each end tapers to a point.
  double get taperFraction => switch (this) {
    BrushKind.pen => 0.18,
    BrushKind.marker => 0.04,
    BrushKind.highlighter => 0,
  };

  /// Default opacity, so a highlighter reads as ink over ink.
  double get defaultOpacity => switch (this) {
    BrushKind.highlighter => 0.35,
    _ => 1.0,
  };

  /// Default width in canvas units.
  double get defaultWidth => switch (this) {
    BrushKind.pen => 6,
    BrushKind.marker => 12,
    BrushKind.highlighter => 26,
  };

  static BrushKind byName(String? name) {
    for (final kind in BrushKind.values) {
      if (kind.name == name) return kind;
    }
    return BrushKind.pen;
  }
}

/// A finished stroke.
class Stroke {
  Stroke({
    required this.id,
    required this.kind,
    required this.colorValue,
    required this.width,
    required this.opacity,
    required this.points,
  });

  factory Stroke.fromJson(Map<String, Object?> json) {
    final rawPoints = json['points'];
    final points = <InkPoint>[];
    if (rawPoints is List) {
      // Points are stored as a flat [x, y, pressure, x, y, pressure, ...]
      // list rather than a list of objects: a sketch runs to tens of
      // thousands of samples, and the per-object key names tripled the file
      // size for no readability anyone was going to use.
      for (var i = 0; i + 2 < rawPoints.length; i += 3) {
        final x = rawPoints[i];
        final y = rawPoints[i + 1];
        final p = rawPoints[i + 2];
        if (x is! num || y is! num || p is! num) continue;
        points.add(
          InkPoint(
            Offset(x.toDouble(), y.toDouble()),
            p.toDouble().clamp(0.0, 1.0),
          ),
        );
      }
    }
    if (points.isEmpty) throw const FormatException('Stroke has no points');

    return Stroke(
      id: json['id']! as String,
      kind: BrushKind.byName(json['kind'] as String?),
      colorValue: switch (json['color']) {
        final int value => value,
        _ => 0xFF1C1A17,
      },
      width: switch (json['width']) {
        final num value => value.toDouble().clamp(0.5, 200.0),
        _ => BrushKind.pen.defaultWidth,
      },
      opacity: switch (json['opacity']) {
        final num value => value.toDouble().clamp(0.0, 1.0),
        _ => 1.0,
      },
      points: points,
    );
  }

  final String id;
  final BrushKind kind;

  /// Packed ARGB.
  final int colorValue;

  /// Nominal width in canvas units, before pressure and taper.
  final double width;

  final double opacity;

  final List<InkPoint> points;

  Color get color => Color(colorValue).withValues(alpha: opacity);

  /// Axis-aligned bounds, padded by half the widest the stroke can get.
  ///
  /// Used to skip strokes outside the viewport and to hit-test cheaply before
  /// measuring distance to every segment.
  Rect get bounds {
    var left = points.first.dx;
    var top = points.first.dy;
    var right = left;
    var bottom = top;
    for (final point in points) {
      if (point.dx < left) left = point.dx;
      if (point.dx > right) right = point.dx;
      if (point.dy < top) top = point.dy;
      if (point.dy > bottom) bottom = point.dy;
    }
    final pad = width / 2 + 1;
    return Rect.fromLTRB(left - pad, top - pad, right + pad, bottom + pad);
  }

  Stroke translate(Offset delta) => Stroke(
    id: id,
    kind: kind,
    colorValue: colorValue,
    width: width,
    opacity: opacity,
    points: <InkPoint>[for (final point in points) point.translate(delta)],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'color': colorValue,
    'width': width,
    'opacity': opacity,
    'points': <Object?>[
      for (final point in points) ...<Object?>[
        _round(point.dx),
        _round(point.dy),
        _round(point.pressure, 2),
      ],
    ],
  };

  /// Rounds to a sensible precision before writing.
  ///
  /// Full double precision on a coordinate is about ten characters of noise
  /// per number; a tenth of a canvas unit is finer than any screen.
  static num _round(double value, [int places = 1]) {
    final factor = places == 1 ? 10 : 100;
    final rounded = (value * factor).round();
    return rounded % factor == 0 ? rounded ~/ factor : rounded / factor;
  }

  @override
  bool operator ==(Object other) => other is Stroke && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Stroke($id, ${kind.name}, ${points.length} points)';
}
