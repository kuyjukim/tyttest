import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// A hairline rule that is one *physical* pixel on every screen.
///
/// A 1.0-logical-pixel divider is a blurry 3px smear on a 3x display; this
/// divides by the device pixel ratio so the rule stays crisp.
class Hairline extends StatelessWidget {
  const Hairline({this.indent = 0, this.color, super.key});

  final double indent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final thickness = 1 / MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: thickness, color: color ?? context.colors.hairline),
    );
  }
}

/// A raised surface with a hairline border and no drop shadow.
///
/// Shadows are avoided throughout the suite: they read as heavy in light mode
/// and are nearly invisible in dark mode, so a border carries the elevation in
/// both.
class PaperCard extends StatelessWidget {
  const PaperCard({
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.onTap,
    this.accent = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Tint the card with the app accent, for the one card on a screen that is
  /// the answer to "what should I look at".
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? colors.accentSoft : colors.surfaceRaised,
        borderRadius: Radii.allMd,
        border: Border.all(
          color: accent
              ? colors.accent.withValues(alpha: 0.28)
              : colors.hairline,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      borderRadius: Radii.allMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: decorated),
    );
  }
}

/// An all-caps-ish section label with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm, top: Gap.xl),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.type.label.copyWith(
                letterSpacing: 0.6,
                color: context.colors.inkMuted,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Standard page chrome: a large title that stays put, a flat app bar, and
/// safe-area-aware padding.
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.leading,
    this.floatingAction,
    this.bottomBar,
    this.padded = true,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? floatingAction;
  final Widget? bottomBar;

  /// Apply the standard horizontal page gutter. Turn off for edge-to-edge
  /// content such as a canvas or a full-bleed list.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: Text(title, style: context.type.heading),
        leading: leading,
        actions: [...actions, const SizedBox(width: Gap.xs)],
      ),
      floatingActionButton: floatingAction,
      bottomNavigationBar: bottomBar,
      body: SafeArea(
        top: false,
        child: padded
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: body,
              )
            : body,
      ),
    );
  }
}
