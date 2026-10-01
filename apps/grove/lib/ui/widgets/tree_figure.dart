import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/species.dart';

/// Everything needed to draw one tree.
@immutable
class TreeFigure {
  const TreeFigure({
    required this.species,
    required this.seed,
    required this.growth,
    this.withered = false,
  });

  final Species species;

  /// Stable per-tree seed. The same seed always draws the same tree, so a
  /// planted tree does not reshuffle every time it scrolls back into view.
  final int seed;

  /// 0 (bare ground) to 1 (fully grown).
  final double growth;

  /// Draws the tree as it ends up when a session is abandoned: grey, bare and
  /// drooping.
  final bool withered;

  @override
  bool operator ==(Object other) =>
      other is TreeFigure &&
      other.species == species &&
      other.seed == seed &&
      other.growth == growth &&
      other.withered == withered;

  @override
  int get hashCode => Object.hash(species, seed, growth, withered);
}

/// Draws a tree procedurally from [TreeFigure].
///
/// A recursive structure rather than an illustration, for three reasons:
/// a session's tree can be drawn at any growth fraction, so the timer screen
/// animates continuously instead of snapping between a handful of stage
/// images; a new species is a row of parameters rather than a new asset set;
/// and nothing has to ship in the bundle, which keeps the download small for
/// an app whose whole pitch is that it works offline.
///
/// Growth is staged: the trunk extends first, then each generation of
/// branches, then the foliage. That ordering is what makes watching it
/// readable - something visibly changes every couple of minutes rather than
/// everything inching outward at once.
class TreePainter extends CustomPainter {
  TreePainter({
    required this.figure,
    required this.groundColor,
    this.sway = 0,
    this.showGround = true,
    this.depthLimit,
  });

  final TreeFigure figure;

  /// Colour of the mound the tree stands on.
  final Color groundColor;

  /// Phase of the idle breeze, in radians. Zero means perfectly still, which
  /// is what reduced-motion mode passes.
  final double sway;

  final bool showGround;

  /// Caps the recursion, for thumbnails.
  ///
  /// A garden row draws dozens of trees at 40 logical pixels, where the sixth
  /// generation of branches is a fraction of a pixel wide and costs hundreds
  /// of path segments to draw. Capping keeps the silhouette and drops the
  /// work.
  final int? depthLimit;

  int get _depth =>
      depthLimit == null || depthLimit! > figure.species.depth
      ? figure.species.depth
      : (depthLimit! < 1 ? 1 : depthLimit!);

  /// Stages: the trunk, one per branch generation, then the foliage.
  int get _stageCount => _depth + 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final growth = figure.growth.clamp(0.0, 1.0);
    final species = figure.species;
    final random = math.Random(figure.seed);

    if (showGround) _paintGround(canvas, size, growth);
    if (growth <= 0) return;

    final wood = Path();
    final foliage = <_Leaf>[];

    // The trunk is a fixed share of the available height so that a fully
    // grown tree fills the box the same way at every size.
    final trunkLength = size.height * 0.34;
    final trunkWidth = trunkLength * species.slenderness;

    _branch(
      wood: wood,
      foliage: foliage,
      random: random,
      origin: Offset(size.width / 2, size.height),
      angle: 0,
      length: trunkLength,
      width: trunkWidth,
      generation: 0,
      growth: growth,
    );

    final woodColor = figure.withered
        ? _drain(species.trunkColor, 0.72)
        : species.trunkColor;
    canvas.drawPath(wood, Paint()..color = woodColor);

    if (!figure.withered) {
      _paintFoliage(canvas, foliage, species);
    }
  }

  /// Progress of stage [index], eased, in 0..1.
  double _stage(int index, double growth) {
    final span = 1 / _stageCount;
    final raw = ((growth - index * span) / span).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(raw);
  }

  void _branch({
    required Path wood,
    required List<_Leaf> foliage,
    required math.Random random,
    required Offset origin,
    required double angle,
    required double length,
    required double width,
    required int generation,
    required double growth,
  }) {
    final species = figure.species;
    final extension = _stage(generation, growth);
    if (extension <= 0) return;

    // Each branch leans a little, deterministically, so no two trees from
    // different seeds look alike.
    final lean = (random.nextDouble() - 0.5) * 0.18;
    // A withered tree droops: every branch is pulled toward the ground.
    final droop = figure.withered ? 0.30 * generation : 0.0;
    // The breeze builds with height, so the trunk barely moves and the tips
    // travel; a uniform offset would look like the whole tree sliding.
    final breeze = sway == 0
        ? 0.0
        : math.sin(sway + generation * 0.9) * 0.016 * generation;

    final effectiveAngle = angle + lean + droop * angle.sign + breeze;
    final grownLength = length * extension;
    final tip =
        origin +
        Offset(math.sin(effectiveAngle), -math.cos(effectiveAngle)) *
            grownLength;

    final tipWidth = width * 0.68;
    _addTaperedSegment(wood, origin, tip, width, tipWidth, effectiveAngle);

    if (generation >= _depth) {
      // A tip: foliage belongs here, and appears during the last stage.
      final leafStage = _stage(_stageCount - 1, growth);
      if (leafStage > 0) {
        foliage.add(
          _Leaf(
            position: tip,
            direction: effectiveAngle,
            scale: leafStage,
            size: length * 0.55,
            variant: random.nextDouble(),
          ),
        );
      }
      return;
    }

    // Two children normally; a third, short and central, often enough to keep
    // the silhouette from reading as a perfect binary fan.
    final childCount = random.nextDouble() < 0.28 ? 3 : 2;
    final spread = species.branchAngle;
    for (var i = 0; i < childCount; i++) {
      final fraction = childCount == 1 ? 0.5 : i / (childCount - 1);
      final offsetAngle = (fraction - 0.5) * 2 * spread;
      final shortening = childCount == 3 && i == 1 ? 0.78 : 1.0;
      _branch(
        wood: wood,
        foliage: foliage,
        random: random,
        origin: tip,
        angle: effectiveAngle + offsetAngle,
        length: length * species.lengthRatio * shortening,
        width: tipWidth,
        generation: generation + 1,
        growth: growth,
      );
    }
  }

  /// Adds a filled quad from [from] to [to], tapering from [baseWidth] to
  /// [tipWidth].
  ///
  /// Filled rather than stroked: a stroked line of constant width makes a
  /// tree look like wire, and tapering is most of what makes it look grown.
  void _addTaperedSegment(
    Path path,
    Offset from,
    Offset to,
    double baseWidth,
    double tipWidth,
    double angle,
  ) {
    final normal = Offset(math.cos(angle), math.sin(angle));
    final b = normal * (baseWidth / 2);
    final t = normal * (tipWidth / 2);
    path
      ..moveTo(from.dx - b.dx, from.dy - b.dy)
      ..lineTo(from.dx + b.dx, from.dy + b.dy)
      ..lineTo(to.dx + t.dx, to.dy + t.dy)
      ..lineTo(to.dx - t.dx, to.dy - t.dy)
      ..close();
  }

  void _paintFoliage(Canvas canvas, List<_Leaf> leaves, Species species) {
    final paint = Paint();
    for (final leaf in leaves) {
      // Two tones of the species colour, so a canopy has some depth without
      // needing a gradient or a shadow.
      paint.color = leaf.variant < 0.45
          ? species.leafColor
          : _shift(species.leafColor, leaf.variant < 0.72 ? 1.12 : 0.88);

      switch (species.canopy) {
        case Canopy.cluster:
          canvas.drawCircle(
            leaf.position,
            leaf.size * 0.5 * leaf.scale * (0.78 + leaf.variant * 0.44),
            paint,
          );
        case Canopy.needle:
          _drawNeedles(canvas, leaf, paint);
        case Canopy.fan:
          _drawFan(canvas, leaf, paint);
        case Canopy.trailing:
          _drawTrailing(canvas, leaf, paint);
      }
    }
  }

  void _drawNeedles(Canvas canvas, _Leaf leaf, Paint paint) {
    final length = leaf.size * 0.62 * leaf.scale;
    final stroke = Paint()
      ..color = paint.color
      ..strokeWidth = math.max(0.7, leaf.size * 0.06)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = -2; i <= 2; i++) {
      final angle = leaf.direction + i * 0.42;
      canvas.drawLine(
        leaf.position,
        leaf.position +
            Offset(math.sin(angle), -math.cos(angle)) * length,
        stroke,
      );
    }
  }

  void _drawFan(Canvas canvas, _Leaf leaf, Paint paint) {
    final radius = leaf.size * 0.6 * leaf.scale;
    final rect = Rect.fromCircle(center: leaf.position, radius: radius);
    // A ginkgo leaf is a fan: a wide arc notched at the stem.
    canvas.drawArc(
      rect,
      leaf.direction - math.pi / 2 - 0.6,
      1.2,
      true,
      paint,
    );
  }

  void _drawTrailing(Canvas canvas, _Leaf leaf, Paint paint) {
    final stroke = Paint()
      ..color = paint.color
      ..strokeWidth = math.max(0.8, leaf.size * 0.07)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final drop = leaf.size * 1.25 * leaf.scale;
    for (var i = -1; i <= 1; i++) {
      final start = leaf.position + Offset(i * leaf.size * 0.22, 0);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          start.dx + i * leaf.size * 0.2,
          start.dy + drop * 0.6,
          start.dx + i * leaf.size * 0.1,
          start.dy + drop,
        );
      canvas.drawPath(path, stroke);
    }
  }

  void _paintGround(Canvas canvas, Size size, double growth) {
    final width = size.width * (0.26 + 0.1 * growth);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height),
      width: width,
      height: size.height * 0.055,
    );
    canvas.drawOval(rect, Paint()..color = groundColor);
  }

  /// Pulls a colour toward grey by [amount], for withered wood.
  static Color _drain(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation * (1 - amount))
        .withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0))
        .toColor();
  }

  /// Lightens ([factor] > 1) or darkens a colour, staying in gamut.
  static Color _shift(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) =>
      oldDelegate.figure != figure ||
      oldDelegate.sway != sway ||
      oldDelegate.groundColor != groundColor ||
      oldDelegate.showGround != showGround ||
      oldDelegate.depthLimit != depthLimit;
}

/// A foliage placement produced while walking the branch structure.
@immutable
class _Leaf {
  const _Leaf({
    required this.position,
    required this.direction,
    required this.scale,
    required this.size,
    required this.variant,
  });

  final Offset position;

  /// Angle of the branch this sits on, so needles and fans point outward.
  final double direction;

  /// 0 to 1 as the foliage stage runs.
  final double scale;

  final double size;

  /// Stable 0..1 roll used to vary tone and size within a canopy.
  final double variant;
}
