import 'dart:ui' show Color;

/// How a species' foliage is drawn.
enum Canopy {
  /// Round clusters at the branch tips. Deciduous look.
  cluster,

  /// Short needles along the whole branch. Conifer look.
  needle,

  /// Wide fan-shaped leaves, one per tip.
  fan,

  /// Long trailing strands that hang below the branch.
  trailing,
}

/// A tree the player can plant.
///
/// The fields are the parameters the procedural painter draws from, so adding
/// a species is a data change rather than new drawing code. Unlock thresholds
/// are in *completed* focus minutes: abandoned sessions deliberately earn
/// nothing, since the whole premise is that finishing is what counts.
enum Species {
  sprout(
    unlockMinutes: 0,
    depth: 4,
    branchAngle: 0.46,
    lengthRatio: 0.74,
    trunkColor: Color(0xFF7C6A52),
    leafColor: Color(0xFF6FAE5A),
    canopy: Canopy.cluster,
    slenderness: 0.062,
  ),
  pine(
    unlockMinutes: 120,
    depth: 5,
    branchAngle: 0.34,
    lengthRatio: 0.70,
    trunkColor: Color(0xFF6B5B47),
    leafColor: Color(0xFF2F6B4A),
    canopy: Canopy.needle,
    slenderness: 0.052,
  ),
  maple(
    unlockMinutes: 420,
    depth: 6,
    branchAngle: 0.52,
    lengthRatio: 0.73,
    trunkColor: Color(0xFF6E5540),
    leafColor: Color(0xFFCC5A35),
    canopy: Canopy.cluster,
    slenderness: 0.070,
  ),
  ginkgo(
    unlockMinutes: 900,
    depth: 6,
    branchAngle: 0.44,
    lengthRatio: 0.75,
    trunkColor: Color(0xFF7A6B55),
    leafColor: Color(0xFFE0B341),
    canopy: Canopy.fan,
    slenderness: 0.058,
  ),
  willow(
    unlockMinutes: 1800,
    depth: 6,
    branchAngle: 0.60,
    lengthRatio: 0.76,
    trunkColor: Color(0xFF5F5340),
    leafColor: Color(0xFF7FA05C),
    canopy: Canopy.trailing,
    slenderness: 0.055,
  ),
  cherry(
    unlockMinutes: 3000,
    depth: 6,
    branchAngle: 0.56,
    lengthRatio: 0.72,
    trunkColor: Color(0xFF5A4639),
    leafColor: Color(0xFFE8A0BC),
    canopy: Canopy.cluster,
    slenderness: 0.064,
  ),
  baobab(
    unlockMinutes: 6000,
    depth: 5,
    branchAngle: 0.66,
    lengthRatio: 0.66,
    trunkColor: Color(0xFF8A7B63),
    leafColor: Color(0xFF5E8F4E),
    canopy: Canopy.cluster,
    slenderness: 0.125,
  );

  const Species({
    required this.unlockMinutes,
    required this.depth,
    required this.branchAngle,
    required this.lengthRatio,
    required this.trunkColor,
    required this.leafColor,
    required this.canopy,
    required this.slenderness,
  });

  /// Completed focus minutes required before this species can be planted.
  final int unlockMinutes;

  /// Recursion depth of the branch structure.
  final int depth;

  /// Half-spread of a fork, in radians.
  final double branchAngle;

  /// How much shorter each generation of branch is than its parent.
  final double lengthRatio;

  final Color trunkColor;
  final Color leafColor;
  final Canopy canopy;

  /// Trunk width as a fraction of trunk height. Higher is stouter.
  final double slenderness;

  /// Species available at [completedMinutes] of lifetime focus.
  static List<Species> unlockedAt(int completedMinutes) => <Species>[
    for (final s in Species.values)
      if (s.unlockMinutes <= completedMinutes) s,
  ];

  /// The next species to unlock, or null when everything is unlocked.
  static Species? nextLockedAfter(int completedMinutes) {
    for (final s in Species.values) {
      if (s.unlockMinutes > completedMinutes) return s;
    }
    return null;
  }

  static Species? byName(String name) {
    for (final s in Species.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}
