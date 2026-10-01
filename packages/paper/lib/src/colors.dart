import 'package:flutter/material.dart';

/// The suite's semantic colour roles.
///
/// Material's own `ColorScheme` is still produced (so stock Material widgets
/// look right), but every widget in this package reads from [PaperColors]
/// instead. The reason is legibility of intent: `colors.inkMuted` says what
/// the colour is for, `colorScheme.onSurfaceVariant` says where it came from.
@immutable
class PaperColors extends ThemeExtension<PaperColors> {
  const PaperColors({
    required this.brightness,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.hairline,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.positive,
    required this.caution,
    required this.danger,
  });

  /// Warm, paper-like light palette. Pure white is avoided on purpose: these
  /// are apps people stare at for 25 minutes at a stretch.
  factory PaperColors.light({required Color accent}) => PaperColors(
    brightness: Brightness.light,
    surface: const Color(0xFFFBF8F3),
    surfaceRaised: const Color(0xFFFFFDFA),
    surfaceSunken: const Color(0xFFF1EBE1),
    ink: const Color(0xFF1C1A17),
    inkMuted: const Color(0xFF6B655C),
    inkFaint: const Color(0xFF9A9389),
    hairline: const Color(0xFFE4DCD1),
    accent: accent,
    accentSoft: Color.alphaBlend(
      accent.withValues(alpha: 0.13),
      const Color(0xFFFBF8F3),
    ),
    onAccent: const Color(0xFFFFFFFF),
    positive: const Color(0xFF2F7D5B),
    caution: const Color(0xFF9A6410),
    danger: const Color(0xFFB4342A),
  );

  /// Dark palette. Kept slightly warm so the two modes feel like one product.
  factory PaperColors.dark({required Color accent}) {
    final lifted = _lift(accent);
    return PaperColors(
      brightness: Brightness.dark,
      surface: const Color(0xFF131211),
      surfaceRaised: const Color(0xFF1E1C19),
      surfaceSunken: const Color(0xFF0C0B0A),
      ink: const Color(0xFFF4F1EA),
      inkMuted: const Color(0xFFA09A90),
      inkFaint: const Color(0xFF6E685F),
      hairline: const Color(0xFF2E2B27),
      accent: lifted,
      accentSoft: Color.alphaBlend(
        lifted.withValues(alpha: 0.18),
        const Color(0xFF131211),
      ),
      onAccent: const Color(0xFF11100F),
      positive: const Color(0xFF5FBE91),
      caution: const Color(0xFFE0A84A),
      danger: const Color(0xFFE8766A),
    );
  }

  final Brightness brightness;

  /// Page background.
  final Color surface;

  /// Cards and sheets sitting above [surface].
  final Color surfaceRaised;

  /// Wells, track backgrounds, inset fields.
  final Color surfaceSunken;

  /// Primary text and icons.
  final Color ink;

  /// Secondary text; passes AA against [surface] at body sizes.
  final Color inkMuted;

  /// Decorative text only - never the sole carrier of information.
  final Color inkFaint;

  /// 1px separators and card borders.
  final Color hairline;

  /// Per-app brand colour.
  final Color accent;

  /// [accent] flattened onto the background, for fills behind accent text.
  final Color accentSoft;

  /// Text/icon colour on top of [accent].
  final Color onAccent;

  final Color positive;
  final Color caution;
  final Color danger;

  bool get isDark => brightness == Brightness.dark;

  /// Nudges a brand colour toward the light end so it keeps enough contrast
  /// against a near-black surface. Brand accents picked for white backgrounds
  /// are reliably too dark to use unchanged in dark mode.
  static Color _lift(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withLightness(hsl.lightness.clamp(0.52, 0.78))
        // Clamped rather than scaled so that lifting is idempotent: scaling
        // would bleach the colour a little more every time it round-tripped
        // through a dark palette.
        .withSaturation(hsl.saturation.clamp(0.0, 0.82))
        .toColor();
  }

  @override
  PaperColors copyWith({
    Brightness? brightness,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? hairline,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? positive,
    Color? caution,
    Color? danger,
  }) => PaperColors(
    brightness: brightness ?? this.brightness,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceSunken: surfaceSunken ?? this.surfaceSunken,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    inkFaint: inkFaint ?? this.inkFaint,
    hairline: hairline ?? this.hairline,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    onAccent: onAccent ?? this.onAccent,
    positive: positive ?? this.positive,
    caution: caution ?? this.caution,
    danger: danger ?? this.danger,
  );

  @override
  PaperColors lerp(ThemeExtension<PaperColors>? other, double t) {
    if (other is! PaperColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaperColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceSunken: c(surfaceSunken, other.surfaceSunken),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      hairline: c(hairline, other.hairline),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      onAccent: c(onAccent, other.onAccent),
      positive: c(positive, other.positive),
      caution: c(caution, other.caution),
      danger: c(danger, other.danger),
    );
  }
}
