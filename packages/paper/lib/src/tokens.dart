import 'package:flutter/widgets.dart';

/// Spacing scale. Every gap in the suite comes from this ladder so that
/// rhythm stays consistent across four separate apps.
///
/// The steps are deliberately sparse: when a layout "needs" something between
/// two steps it is almost always a sign the hierarchy is wrong.
abstract final class Gap {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3l = 32;
  static const double x4l = 40;
  static const double x5l = 48;
  static const double x6l = 64;
}

/// Corner radii. `pill` is intentionally huge rather than computed so it can
/// be used in a `const` context.
abstract final class Radii {
  static const Radius xs = Radius.circular(6);
  static const Radius sm = Radius.circular(10);
  static const Radius md = Radius.circular(14);
  static const Radius lg = Radius.circular(20);
  static const Radius xl = Radius.circular(28);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius allXs = BorderRadius.all(xs);
  static const BorderRadius allSm = BorderRadius.all(sm);
  static const BorderRadius allMd = BorderRadius.all(md);
  static const BorderRadius allLg = BorderRadius.all(lg);
  static const BorderRadius allXl = BorderRadius.all(xl);
  static const BorderRadius allPill = BorderRadius.all(pill);
}

/// Animation durations.
///
/// Named `Tempo` rather than `Durations` because `package:flutter/animation.dart`
/// already exports a `Durations` class, and an ambiguous import in every
/// widget file is a poor trade for a nicer name.
///
/// Anything longer than [lazy] reads as the app being slow rather than
/// expressive, so growth animations that genuinely need minutes (a tree
/// growing over a focus session) are driven by elapsed time, not by a
/// [Duration] from this list.
abstract final class Tempo {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration lazy = Duration(milliseconds: 600);
}

/// Easing curves. Named `Ease` for the same reason [Tempo] is not `Durations`.
abstract final class Ease {
  /// Default for anything entering or moving on screen.
  static const Curve standard = Curves.easeOutCubic;

  /// For elements that should feel driven rather than eased - sheets, thumbs.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// For elements leaving the screen; faster out than in.
  static const Curve exit = Curves.easeInCubic;

  /// Slight overshoot, used sparingly for rewards and confirmations.
  static const Curve overshoot = Curves.easeOutBack;
}

/// Minimum hit target on both platforms' accessibility guidance.
const double kMinTouchTarget = 44;
