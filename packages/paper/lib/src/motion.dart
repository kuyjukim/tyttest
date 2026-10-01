import 'package:flutter/widgets.dart';

/// Reduced-motion aware animation helpers.
///
/// Three of the four apps in this suite lean on animation to justify their
/// price, which makes honouring "Reduce Motion" a correctness concern rather
/// than a nicety: a user who has switched it on should still see state change,
/// just without the travel.
abstract final class Motion {
  /// True when the platform asks us not to animate.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// [duration], or zero when motion is reduced.
  static Duration time(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// [curve], flattened to linear when motion is reduced, so that any
  /// mid-flight animation still lands on the right value.
  static Curve curve(BuildContext context, Curve curve) =>
      reduced(context) ? Curves.linear : curve;

  /// Scales a decorative travel distance (a slide-in offset, a parallax
  /// amount) to zero when motion is reduced.
  static double travel(BuildContext context, double distance) =>
      reduced(context) ? 0 : distance;
}

/// An [AnimatedSwitcher] that cross-fades without sliding, and does nothing
/// at all under reduced motion.
class SoftSwap extends StatelessWidget {
  const SoftSwap({required this.child, this.duration, super.key});

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.time(
        context,
        duration ?? const Duration(milliseconds: 220),
      ),
      switchInCurve: Motion.curve(context, Curves.easeOutCubic),
      switchOutCurve: Motion.curve(context, Curves.easeInCubic),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: <Widget>[...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}
