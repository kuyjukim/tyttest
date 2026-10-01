import 'package:flutter/painting.dart';

import '../domain/entry.dart';

/// Colours for the five-point mood scale.
///
/// Mood is a *diverging* quantity - negative through neutral to positive - so
/// it gets two hues around a neutral grey midpoint, never a rainbow and never
/// a hue in the middle. The pair is the documented blue/red one: warm and
/// cool read as opposite, where two cool hues would leave the midpoint
/// looking like a value rather than like "nothing".
///
/// Neither the categorical nor the single-hue ordinal validator applies to a
/// five-step diverging ramp: the categorical check rejects the grey midpoint
/// that diverging scales require, and the ordinal check rejects the two hues
/// for the same reason. What this scale was held to instead:
///
/// * every step clears 3:1 against its own surface in both modes, so no mood
///   dot is a faint smudge - checked with the palette validator's contrast
///   gate;
/// * lightness steps away from the midpoint within each arm, so the scale
///   reads as a scale rather than as five labels; and
/// * the mood name is shown beside the mark everywhere it appears - the
///   picker, the insights list, the entry row's semantics - so identity is
///   never carried by colour alone.
abstract final class MoodScale {
  static const Map<Mood, Color> _light = <Mood, Color>{
    Mood.awful: Color(0xFF8E251F),
    Mood.low: Color(0xFFC25048),
    Mood.neutral: Color(0xFF8A8178),
    Mood.good: Color(0xFF3F86D4),
    Mood.great: Color(0xFF1A4F8C),
  };

  static const Map<Mood, Color> _dark = <Mood, Color>{
    Mood.awful: Color(0xFFEE8B82),
    Mood.low: Color(0xFFD4625A),
    Mood.neutral: Color(0xFF9A948A),
    Mood.good: Color(0xFF6DA7EC),
    Mood.great: Color(0xFF3B82D9),
  };

  static Color of(Mood mood, {required bool dark}) =>
      (dark ? _dark : _light)[mood]!;
}
