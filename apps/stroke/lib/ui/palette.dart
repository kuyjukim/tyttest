import 'dart:ui';

/// The ink colours the brush picker offers.
///
/// This is *not* the chart palette: those slots are tuned so that adjacent
/// series stay distinguishable, which is the wrong problem here. An ink
/// palette needs a true black, a usable white for drawing on a dark page, and
/// hues that look like ink rather than like data.
abstract final class InkPalette {
  static const List<Color> colours = <Color>[
    Color(0xFF1C1A17), // ink black
    Color(0xFF6B655C), // graphite
    Color(0xFFFFFFFF), // white, for dark paper
    Color(0xFFC2255C), // crimson
    Color(0xFFEB6834), // vermilion
    Color(0xFFEDA100), // amber
    Color(0xFF1BAF7A), // jade
    Color(0xFF2A78D6), // cobalt
    Color(0xFF4A3AA7), // indigo
  ];

  static int get defaultColour => colours.first.toARGB32();
}
