import 'package:flutter/material.dart';

/// The suite's type scale.
///
/// No font asset is bundled on purpose. These ship as paid apps whose selling
/// point is that they work offline forever, and `google_fonts` resolves faces
/// over the network on first run. The platform face (SF on iOS, Roboto on
/// Android) is both free and the one users already read all day.
@immutable
class PaperType extends ThemeExtension<PaperType> {
  const PaperType({
    required this.display,
    required this.title,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.numeric,
    required this.numericLarge,
  });

  /// [fontFamily] is normally null, which means the platform face - SF on
  /// iOS, Roboto on Android - and is why this suite bundles no font. It is
  /// settable so that a build which *must* control the face, such as a
  /// screenshot run on a machine with no platform font, can supply one
  /// without every style in the app growing a special case.
  factory PaperType.standard({
    required Color ink,
    required Color muted,
    String? fontFamily,
  }) {
    return PaperType(
      display: TextStyle(
        fontFamily: fontFamily,
        color: ink,
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
      title: TextStyle(
        fontFamily: fontFamily,
        color: ink,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      heading: TextStyle(
        fontFamily: fontFamily,
        color: ink,
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      body: TextStyle(
        fontFamily: fontFamily,
        color: ink,
        fontSize: 16,
        height: 1.5,
      ),
      bodyStrong: TextStyle(
        fontFamily: fontFamily,
        color: ink,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
      label: TextStyle(
        fontFamily: fontFamily,
        color: muted,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      caption: TextStyle(
        fontFamily: fontFamily,
        color: muted,
        fontSize: 12,
        height: 1.35,
      ),
      // Tabular figures matter more than they sound: without them a running
      // timer or a column of amounts jitters horizontally on every tick.
      numeric: TextStyle(
        fontFamily: fontFamily,
        color: ink,
        fontSize: 17,
        height: 1.2,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      numericLarge: TextStyle(
        fontFamily: fontFamily,
        color: ink,
        fontSize: 56,
        height: 1.0,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle caption;

  /// Inline numbers: list rows, stat tiles.
  final TextStyle numeric;

  /// Hero numbers: a countdown, a balance.
  final TextStyle numericLarge;

  @override
  PaperType copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? numeric,
    TextStyle? numericLarge,
  }) => PaperType(
    display: display ?? this.display,
    title: title ?? this.title,
    heading: heading ?? this.heading,
    body: body ?? this.body,
    bodyStrong: bodyStrong ?? this.bodyStrong,
    label: label ?? this.label,
    caption: caption ?? this.caption,
    numeric: numeric ?? this.numeric,
    numericLarge: numericLarge ?? this.numericLarge,
  );

  @override
  PaperType lerp(ThemeExtension<PaperType>? other, double t) {
    if (other is! PaperType) return this;
    return PaperType(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      numeric: TextStyle.lerp(numeric, other.numeric, t)!,
      numericLarge: TextStyle.lerp(numericLarge, other.numericLarge, t)!,
    );
  }
}
