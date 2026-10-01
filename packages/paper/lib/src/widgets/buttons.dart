import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../tokens.dart';

/// Visual weight of a [PaperButton].
enum PaperButtonKind {
  /// Filled with the app accent. One per screen, at most.
  primary,

  /// Accent text on a soft accent fill. For secondary affirmative actions.
  tonal,

  /// Text only. For tertiary actions and anything in a toolbar.
  ghost,

  /// Filled with the danger colour. For destructive, irreversible actions.
  danger,
}

enum PaperButtonSize { small, medium, large }

/// The suite's only button.
///
/// It exists instead of Material's five button widgets so that hit targets,
/// disabled contrast, pressed feedback and the loading state are decided once.
class PaperButton extends StatefulWidget {
  const PaperButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = PaperButtonKind.primary,
    this.size = PaperButtonSize.medium,
    this.expand = false,
    this.busy = false,
    super.key,
  });

  final String label;

  /// Null disables the button. A busy button is also non-interactive, but
  /// reads as "working" rather than "unavailable".
  final VoidCallback? onPressed;

  final IconData? icon;
  final PaperButtonKind kind;
  final PaperButtonSize size;

  /// Stretch to the full width of the parent.
  final bool expand;

  /// Swap the label for a spinner and ignore taps.
  final bool busy;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (height, padding, textStyle) = switch (widget.size) {
      PaperButtonSize.small => (
        36.0,
        Gap.md,
        context.type.label.copyWith(fontSize: 14),
      ),
      PaperButtonSize.medium => (kMinTouchTarget, Gap.lg, context.type.bodyStrong),
      PaperButtonSize.large => (
        54.0,
        Gap.xxl,
        context.type.bodyStrong.copyWith(fontSize: 17),
      ),
    };

    final (background, foreground, border) = switch (widget.kind) {
      PaperButtonKind.primary => (colors.accent, colors.onAccent, null),
      PaperButtonKind.tonal => (colors.accentSoft, colors.accent, null),
      PaperButtonKind.ghost => (
        Colors.transparent,
        colors.ink,
        BorderSide(color: colors.hairline),
      ),
      PaperButtonKind.danger => (colors.danger, Colors.white, null),
    };

    // Disabled state desaturates toward the background rather than just
    // dropping opacity, which keeps text legible on both themes.
    final effectiveBackground = _enabled
        ? background
        : Color.alphaBlend(background.withValues(alpha: 0.28), colors.surface);
    final effectiveForeground = _enabled ? foreground : colors.inkFaint;

    final content = widget.busy
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveForeground),
            ),
          )
        : Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: effectiveForeground),
                const SizedBox(width: Gap.sm),
              ],
              Text(
                widget.label,
                style: textStyle.copyWith(color: effectiveForeground),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          // A 2% dip is enough to feel like a press on a physical device and
          // small enough not to read as a bounce.
          scale: _pressed ? 0.98 : 1,
          duration: Motion.time(context, Tempo.quick),
          curve: Ease.standard,
          child: AnimatedContainer(
            duration: Motion.time(context, Tempo.quick),
            height: height,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: padding),
            decoration: BoxDecoration(
              color: effectiveBackground,
              borderRadius: Radii.allSm,
              border: border == null ? null : Border.fromBorderSide(border),
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// A square, icon-only tap target that always meets the minimum touch size
/// even when the glyph inside is small.
class PaperIconButton extends StatelessWidget {
  const PaperIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.size = 22,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Doubles as the semantic label, so it is required rather than optional:
  /// an icon-only button with no label is invisible to a screen reader.
  final String tooltip;

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = onPressed == null
        ? context.colors.inkFaint
        : (color ?? context.colors.ink);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: kMinTouchTarget / 2 + 4,
          containedInkWell: false,
          child: SizedBox(
            height: kMinTouchTarget,
            width: kMinTouchTarget,
            child: Center(child: Icon(icon, size: size, color: tint)),
          ),
        ),
      ),
    );
  }
}
