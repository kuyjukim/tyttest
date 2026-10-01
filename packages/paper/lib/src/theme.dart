import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds the [ThemeData] every app in the suite runs on.
///
/// Each app passes its own `accent`; everything else is shared so that the
/// four apps read as one family.
abstract final class PaperTheme {
  static ThemeData light({required Color accent, String? fontFamily}) =>
      _build(PaperColors.light(accent: accent), fontFamily);

  static ThemeData dark({required Color accent, String? fontFamily}) =>
      _build(PaperColors.dark(accent: accent), fontFamily);

  static ThemeData of({
    required Color accent,
    required Brightness brightness,
    String? fontFamily,
  }) => brightness == Brightness.dark
      ? dark(accent: accent, fontFamily: fontFamily)
      : light(accent: accent, fontFamily: fontFamily);

  static ThemeData _build(PaperColors c, [String? fontFamily]) {
    final type = PaperType.standard(
      ink: c.ink,
      muted: c.inkMuted,
      fontFamily: fontFamily,
    );
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.ink,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.isDark ? const Color(0xFF11100F) : const Color(0xFFFFFFFF),
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surfaceSunken,
      onSurfaceVariant: c.inkMuted,
      outline: c.hairline,
      outlineVariant: c.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      extensions: <ThemeExtension<Object?>>[c, type],
      // InkRipple, not InkSparkle. InkSparkle is Android 12's splash and it
      // loads a fragment shader asset at first touch - an asset dependency,
      // and a platform-specific flourish, in a design system that is
      // deliberately neither. A plain ripple is consistent on both platforms
      // and costs nothing to load.
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        displayLarge: type.display,
        headlineMedium: type.title,
        titleLarge: type.heading,
        titleMedium: type.bodyStrong,
        bodyLarge: type.body,
        bodyMedium: type.body,
        labelLarge: type.label,
        bodySmall: type.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: type.heading,
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.ink, size: 22),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: type.body.copyWith(color: c.surface),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.allSm),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.isDark
            ? const Color(0xB3000000)
            : const Color(0x66231F1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radii.xl),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.24),
        selectionHandleColor: c.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        hintStyle: type.body.copyWith(color: c.inkFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.allSm,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),
    );
  }
}

/// Short, intention-revealing access to the suite's tokens.
///
/// `context.colors.inkMuted` beats
/// `Theme.of(context).extension<PaperColors>()!.inkMuted` at every call site,
/// and there are a lot of call sites.
extension PaperThemeAccess on BuildContext {
  PaperColors get colors =>
      Theme.of(this).extension<PaperColors>() ??
      PaperColors.light(accent: const Color(0xFF2F7D5B));

  PaperType get type =>
      Theme.of(this).extension<PaperType>() ??
      PaperType.standard(ink: colors.ink, muted: colors.inkMuted);
}
