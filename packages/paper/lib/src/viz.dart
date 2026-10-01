import 'package:flutter/painting.dart';

/// Colour slots for charts, assigned by *identity* in fixed order.
///
/// Rules this palette is built to, which callers must not break:
///
/// * Slots are handed out in order and never cycled. Past [slots] length the
///   caller folds the tail into a single "Other" bucket rather than inventing
///   a hue.
/// * Colour follows the entity, not its rank. A filter that drops series must
///   not repaint the survivors, so an entity stores its slot index once and
///   keeps it.
/// * Both modes are *selected*, not derived. The dark column is the same eight
///   hues re-stepped for a near-black surface; flipping lightness
///   algorithmically produces muddy, low-contrast fills.
///
/// Validated with the data-viz palette validator against this suite's own
/// surfaces (light `#FBF8F3`, dark `#131211`) on the adjacent pairlist, which
/// is the right list for bars and stacks:
///
/// * light - worst adjacent CVD ΔE 9.1 (protan), worst adjacent normal-vision
///   ΔE 19.6; aqua, yellow and magenta fall below 3:1 against the light
///   surface, so every chart using them ships visible direct labels.
/// * dark - worst adjacent CVD ΔE 8.4, worst adjacent normal-vision ΔE 19.3,
///   all eight at or above 3:1.
///
/// Scatter-type charts, where any two series can end up adjacent, are capped
/// at the first three slots; none of the apps here draws one.
abstract final class Viz {
  static const List<Color> _light = <Color>[
    Color(0xFF2A78D6), // blue
    Color(0xFFEB6834), // orange
    Color(0xFF1BAF7A), // aqua
    Color(0xFFEDA100), // yellow
    Color(0xFFE87BA4), // magenta
    Color(0xFF008300), // green
    Color(0xFF4A3AA7), // violet
    Color(0xFFE34948), // red
  ];

  static const List<Color> _dark = <Color>[
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
  ];

  /// Human-readable slot names, for the colour picker in each app.
  static const List<String> names = <String>[
    'Blue',
    'Orange',
    'Aqua',
    'Yellow',
    'Magenta',
    'Green',
    'Violet',
    'Red',
  ];

  static int get slots => _light.length;

  /// The colour for slot [index] in the requested mode.
  ///
  /// [index] is taken modulo [slots] only as a last-resort guard against a
  /// corrupt stored value; callers are expected to stay inside the range and
  /// fold overflow into "Other".
  static Color slot(int index, {required bool dark}) {
    final table = dark ? _dark : _light;
    return table[index.abs() % table.length];
  }

  /// The neutral used for the "Other" bucket and for de-emphasised series.
  static Color other({required bool dark}) =>
      dark ? const Color(0xFF55514B) : const Color(0xFFBDB5A9);
}
