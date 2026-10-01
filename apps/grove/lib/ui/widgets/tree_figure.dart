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

  int get _depth => depthLimit == null || depthLimit! > figure.species.depth
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

    // A share of the height, but never more than the box can hold. A dense
    // canopy is much wider than the branches under it, and how much wider
    // depends on the species, the seed and the recursion depth - so it is
    // measured rather than guessed at, and the trunk is shortened until the
    // whole tree fits. Picking a fraction that suits one species clips
    // another.
    final extent = _extent();
    final trunkLength = math.min(
      size.height * 0.34,
      math.min(
        size.width * 0.98 / math.max(extent.width, 0.001),
        size.height * 0.98 / math.max(-extent.top, 0.001),
      ),
    );
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

  /// How far a grown tree of this exact shape reaches, in units of trunk
  /// length, with the base of the trunk at the origin.
  ///
  /// Cached, because it depends only on the shape - species, seed, depth and
  /// whether it withered - and not on growth or on the size it is drawn at,
  /// while working it out means walking the whole structure.
  static final Map<Object, Rect> _extents = <Object, Rect>{};

  Rect _extent() {
    final key = (figure.species, figure.seed, _depth, figure.withered);
    final cached = _extents[key];
    if (cached != null) return cached;

    // Walked by the same code that draws it, at full growth and with a trunk
    // one unit long. A tree part way through growing is strictly inside the
    // grown one, since growth only ever shortens a branch.
    final wood = Path();
    final foliage = <_Leaf>[];
    _branch(
      wood: wood,
      foliage: foliage,
      random: math.Random(figure.seed),
      origin: Offset.zero,
      angle: 0,
      length: 1,
      width: figure.species.slenderness,
      generation: 0,
      growth: 1,
    );
    var rect = wood.getBounds();
    for (final leaf in foliage) {
      // 1.5 covers the largest reach of any canopy shape - a willow's
      // strands, which hang further than a cluster is wide - and the slack
      // on the others is margin rather than error.
      rect = rect.expandToInclude(
        Rect.fromCircle(center: leaf.position, radius: leaf.size * 1.5),
      );
    }

    // Bounded, because a garden holds a tree per session and each has its own
    // seed. Clearing wholesale costs one walk per visible tree afterwards,
    // which is what the first frame does anyway.
    if (_extents.length > 256) _extents.clear();
    return _extents[key] = rect;
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
    // No early return when this generation has not started yet. Its random
    // numbers are spent either way, so the sequence - and so the shape - is
    // the same at every growth. Returning here instead is what made a
    // growing tree quietly reshuffle the branches it had already drawn, and
    // it would also leave the measured extent describing a different tree
    // from the one on screen.
    final extension = _stage(generation, growth);
    final visible = extension > 0;

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
    if (visible) {
      _addTaperedSegment(wood, origin, tip, width, tipWidth, effectiveAngle);
    }

    // Foliage hangs on the outer three generations, and the outermost
    // carries a small cluster rather than a single leaf. One leaf per tip
    // reads as dots on a stick however large the dots are; what makes a
    // canopy is many overlapping shapes with no gaps between them.
    if (generation >= _depth - 2) {
      final leafStage = _stage(_stageCount - 1, growth);
      {
        // Inner rings are smaller, so they fill the canopy instead of
        // widening its outline.
        final size =
            length *
            switch (_depth - generation) {
              0 => 0.95,
              1 => 0.70,
              _ => 0.52,
            };
        final clump = generation >= _depth ? 3 : 1;
        for (var i = 0; i < clump; i++) {
          // Scattered around the tip rather than stacked on it; the offset
          // is a fraction of the leaf, so it never detaches from its branch.
          final spread = i == 0
              ? Offset.zero
              : Offset(
                  (random.nextDouble() - 0.5) * size * 0.78,
                  (random.nextDouble() - 0.5) * size * 0.78,
                );
          final leaf = _Leaf(
            position: tip + spread,
            direction: effectiveAngle,
            scale: leafStage,
            size: size * (i == 0 ? 1.0 : 0.72 + random.nextDouble() * 0.3),
            variant: random.nextDouble(),
          );
          // Built, and its random numbers spent, even when the foliage stage
          // has not started. Consuming the same numbers at every growth is
          // what makes the shape identical throughout, which is what lets it
          // be measured once and drawn at any stage.
          if (leafStage > 0) foliage.add(leaf);
        }
      }
    }
    if (generation >= _depth) return;

    // Four children often, three otherwise. A binary fork spends its whole
    // budget on outline and leaves the inside of the tree empty.
    final childCount = random.nextDouble() < 0.40 ? 4 : 3;
    final spread = species.branchAngle;
    for (var i = 0; i < childCount; i++) {
      final fraction = childCount == 1 ? 0.5 : i / (childCount - 1);
      final offsetAngle = (fraction - 0.5) * 2 * spread;
      // The inner children are shorter, so the fork reads as a crown rather
      // than as a fan of equal spokes.
      final shortening = (i > 0 && i < childCount - 1) ? 0.80 : 1.0;
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

  /// Paints the whole canopy in three draws instead of one per leaf.
  ///
  /// A full canopy is a few thousand shapes, and this repaints while a
  /// session runs. Three filled or stroked paths cost about what three
  /// shapes cost; three thousand canvas calls do not. Tone is what the
  /// grouping is by, since there are only ever three of them.
  void _paintFoliage(Canvas canvas, List<_Leaf> leaves, Species species) {
    final paths = <Path>[Path(), Path(), Path()];
    final widths = <double>[0, 0, 0];

    for (final leaf in leaves) {
      final tone = leaf.variant < 0.45 ? 0 : (leaf.variant < 0.72 ? 1 : 2);
      final path = paths[tone];
      switch (species.canopy) {
        case Canopy.cluster:
          path.addOval(
            Rect.fromCircle(
              center: leaf.position,
              radius:
                  leaf.size * 0.72 * leaf.scale * (0.80 + leaf.variant * 0.46),
            ),
          );
        case Canopy.fan:
          _addFan(path, leaf);
        case Canopy.needle:
          _addNeedles(path, leaf);
          widths[tone] = math.max(widths[tone], math.max(0.8, leaf.size * 0.075));
        case Canopy.trailing:
          _addTrailing(path, leaf);
          widths[tone] = math.max(widths[tone], math.max(0.8, leaf.size * 0.07));
      }
    }

    final stroked =
        species.canopy == Canopy.needle || species.canopy == Canopy.trailing;
    for (var tone = 0; tone < paths.length; tone++) {
      // Two tones of the species colour either side of it, so a canopy has
      // some depth without needing a gradient or a shadow.
      final paint = Paint()
        ..color = switch (tone) {
          0 => species.leafColor,
          1 => _shift(species.leafColor, 1.12),
          _ => _shift(species.leafColor, 0.88),
        };
      if (stroked) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = widths[tone]
          ..strokeCap = StrokeCap.round;
      }
      canvas.drawPath(paths[tone], paint);
    }
  }

  /// Short needles fanned along the branch. A conifer.
  void _addNeedles(Path path, _Leaf leaf) {
    final length = leaf.size * 0.82 * leaf.scale;
    for (var i = -3; i <= 3; i++) {
      final angle = leaf.direction + i * 0.34;
      path
        ..moveTo(leaf.position.dx, leaf.position.dy)
        ..lineTo(
          leaf.position.dx + math.sin(angle) * length,
          leaf.position.dy - math.cos(angle) * length,
        );
    }
  }

  /// A ginkgo leaf: a wide arc notched at the stem.
  void _addFan(Path path, _Leaf leaf) {
    final radius = leaf.size * 0.82 * leaf.scale;
    path
      ..moveTo(leaf.position.dx, leaf.position.dy)
      ..arcTo(
        Rect.fromCircle(center: leaf.position, radius: radius),
        leaf.direction - math.pi / 2 - 0.6,
        1.2,
        false,
      )
      ..close();
  }

  /// Long strands hanging below the branch. A willow.
  void _addTrailing(Path path, _Leaf leaf) {
    final drop = leaf.size * 1.45 * leaf.scale;
    for (var i = -2; i <= 2; i++) {
      final start = leaf.position + Offset(i * leaf.size * 0.22, 0);
      path
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          start.dx + i * leaf.size * 0.2,
          start.dy + drop * 0.6,
          start.dx + i * leaf.size * 0.1,
          start.dy + drop,
        );
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
    return hsl
        .withLightness((hsl.lightness * factor).clamp(0.0, 1.0))
        .toColor();
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
