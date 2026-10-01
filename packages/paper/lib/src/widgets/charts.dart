import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../tokens.dart';
import '../viz.dart';

/// A single headline number with its label.
///
/// Reached for in place of a chart whenever there is only one value to show -
/// a one-bar bar chart and a two-slice pie are both worse than the number.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final String value;

  /// Rendered smaller and muted beside [value], e.g. `hrs`, `%`, `days`.
  final String? unit;

  final String? caption;

  /// Paint [value] in the app accent. At most one tile in a row should.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$label: $value${unit == null ? '' : ' $unit'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.type.label),
          const SizedBox(height: Gap.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: context.type.numeric.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: emphasis ? colors.accent : colors.ink,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: Gap.xs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit!, style: context.type.caption),
                ),
              ],
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: Gap.xxs),
            Text(caption!, style: context.type.caption),
          ],
        ],
      ),
    );
  }
}

/// One column of a [BarChart].
@immutable
class Bar {
  const Bar({required this.label, required this.value, this.highlight = false});

  /// Axis label under the bar. Kept to one or two characters where possible;
  /// [BarChart] thins the strip when the columns are narrower than the text,
  /// so a long label costs its neighbours their labels rather than overlapping
  /// them. Every bar keeps its label in the semantics tree either way.
  final String label;

  /// Magnitude, in whatever unit the caller's [BarChart.formatValue] speaks.
  final double value;

  /// Draw in the accent instead of the recessive fill. Used for "today" and
  /// for the tapped bar - at most one or two per chart.
  final bool highlight;
}

/// A single-series vertical bar chart for change-over-time.
///
/// Single series, so there is no legend: the surrounding section title names
/// what is being measured. Only the highlighted and the largest bar get a
/// direct value label - a number over every column is noise.
class BarChart extends StatefulWidget {
  const BarChart({
    required this.bars,
    required this.formatValue,
    this.height = 132,
    super.key,
  });

  final List<Bar> bars;

  /// Turns a value into its display string, e.g. `90` -> `1h 30m`.
  final String Function(double value) formatValue;

  final double height;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  /// Index of the bar the user tapped. Mobile's stand-in for hover.
  int? _selected;

  /// Height reserved for the axis label strip beneath the baseline.
  static const double _labelStrip = 22;

  @override
  Widget build(BuildContext context) {
    if (widget.bars.isEmpty) return SizedBox(height: widget.height);
    return LayoutBuilder(
      builder: (context, constraints) =>
          _build(context, _labelStride(context, constraints.maxWidth)),
    );
  }

  /// How many columns apart the axis labels stand.
  ///
  /// A week of bars has room for all seven. A month of daily bars on a phone
  /// gives each column about thirteen logical pixels - narrower than the two
  /// digits of "18" - and a strip that labels all of them wraps each number
  /// onto two lines and clips the second. So the strip labels every nth
  /// column instead, with n the smallest stride that leaves the widest label
  /// clear of its neighbour.
  int _labelStride(BuildContext context, double width) {
    final columns = widget.bars.length;
    if (columns == 0 || !width.isFinite || width <= 0) return 1;

    // Every label, not the one with the most characters: "11" is narrower
    // than "8" in some faces, and the labels are not always digits.
    final style = context.type.caption;
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final bar in widget.bars) {
      final painter = TextPainter(
        text: TextSpan(text: bar.label, style: style),
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    const breathing = 6.0;
    final column = width / columns;
    if (widest + breathing <= column) return 1;
    return ((widest + breathing) / column).ceil();
  }

  Widget _build(BuildContext context, int stride) {
    final colors = context.colors;

    final peak = widget.bars
        .map((b) => b.value)
        .reduce((a, b) => a > b ? a : b);
    final peakIndex = widget.bars.indexWhere((b) => b.value == peak);
    // An all-zero week must not divide by zero, and should render as a row of
    // empty tracks rather than as full-height bars.
    final scale = peak <= 0 ? 0.0 : 1 / peak;

    // Count the stride from the highlighted bar rather than from the left
    // edge, so that today is always one of the days named. Dart's modulo is
    // never negative, so bars before the anchor fall where you would expect.
    final anchor = math.max(0, widget.bars.indexWhere((b) => b.highlight));

    return SizedBox(
      height: widget.height + _labelStrip,
      child: Stack(
        children: [
          // The only axis chrome: a hairline baseline. No gridlines, no
          // y-axis, no frame.
          Positioned(
            left: 0,
            right: 0,
            top: widget.height,
            child: Container(height: 1, color: colors.hairline),
          ),
          Row(
            children: [
              for (final (index, bar) in widget.bars.indexed)
                Expanded(
                  child: Semantics(
                    label: '${bar.label}: ${widget.formatValue(bar.value)}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // The whole column is the tap target, label included:
                      // the bar alone is a sliver on a light day.
                      onTap: () => setState(
                        () => _selected = _selected == index ? null : index,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: _BarColumn(
                              bar: bar,
                              fraction: bar.value * scale,
                              // Label the peak always, plus whatever is tapped.
                              showValue:
                                  index == peakIndex || index == _selected,
                              valueText: widget.formatValue(bar.value),
                              selected: index == _selected,
                            ),
                          ),
                          SizedBox(
                            height: _labelStrip,
                            child: (index - anchor) % stride != 0
                                ? null
                                // A label may be wider than the column it
                                // belongs to - "10" is, on a month of days.
                                // The stride has already emptied the columns
                                // on either side, so let it spill into them
                                // rather than shear the last digit off.
                                : OverflowBox(
                                    maxWidth: double.infinity,
                                    child: Text(
                                      bar.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: context.type.caption.copyWith(
                                        color: bar.highlight
                                            ? colors.ink
                                            : colors.inkMuted,
                                        fontWeight: bar.highlight
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.bar,
    required this.fraction,
    required this.showValue,
    required this.valueText,
    required this.selected,
  });

  final Bar bar;
  final double fraction;
  final bool showValue;
  final String valueText;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final emphasised = bar.highlight || selected;
    return Padding(
      // 2px of surface either side keeps adjacent fills from touching.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showValue)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: Text(
                valueText,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: context.type.caption.copyWith(
                  // Value labels wear text ink, never the series colour.
                  color: colors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // A bar with a real but tiny value still deserves a visible
                // sliver; only a true zero collapses to nothing.
                final raw = constraints.maxHeight * fraction;
                final height = bar.value <= 0
                    ? 0.0
                    : raw.clamp(3.0, constraints.maxHeight);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: Motion.time(context, Tempo.slow),
                    curve: Ease.emphasized,
                    height: height,
                    decoration: BoxDecoration(
                      color: emphasised ? colors.accent : colors.surfaceSunken,
                      // Rounded data-end, square against the baseline.
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of a [RankedBarList].
@immutable
class RankedBar {
  const RankedBar({
    required this.label,
    required this.value,
    required this.display,
    required this.slot,
  });

  final String label;
  final double value;

  /// Pre-formatted value, shown at the end of the row.
  final String display;

  /// Fixed [Viz] slot for this entity. Stored on the entity so re-sorting or
  /// filtering never repaints it.
  final int slot;
}

/// Ranked horizontal bars - the suite's answer to "which categories did this
/// total come from".
///
/// Horizontal rather than a donut because the labels are long, the values are
/// often close, and a bar lets every row carry its own name and number. That
/// direct labelling is also what licenses the three light-mode slots that sit
/// below 3:1 contrast.
class RankedBarList extends StatelessWidget {
  const RankedBarList({required this.bars, this.maxRows = 8, super.key});

  final List<RankedBar> bars;

  /// Rows past this are folded into a single neutral "Other" row.
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final sorted = [...bars]..sort((a, b) => b.value.compareTo(a.value));
    final shown = sorted.take(maxRows).toList();
    final peak = shown.first.value;

    return Column(
      children: [
        for (final bar in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: _RankedRow(
              bar: bar,
              fraction: peak <= 0 ? 0 : bar.value / peak,
            ),
          ),
      ],
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({required this.bar, required this.fraction});

  final RankedBar bar;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = Viz.slot(bar.slot, dark: colors.isDark);
    return Semantics(
      label: '${bar.label}: ${bar.display}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  bar.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.body,
                ),
              ),
              Text(bar.display, style: context.type.numeric),
            ],
          ),
          const SizedBox(height: Gap.sm),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: Container(
              height: 6,
              color: colors.surfaceSunken,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: Motion.time(context, Tempo.slow),
                  curve: Ease.emphasized,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One slim stacked bar: part-to-whole at a glance, nothing more.
///
/// Capped at six segments plus "Other" because adjacent classes blur past
/// that, and every segment is 2px clear of its neighbour.
class ShareBar extends StatelessWidget {
  const ShareBar({required this.segments, this.height = 10, super.key});

  /// Value/slot pairs. Order is the caller's; it is drawn as given.
  final List<(double value, int slot)> segments;

  final double height;

  static const int maxSegments = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = segments.fold<double>(0, (sum, s) => sum + s.$1);
    if (total <= 0) {
      return ClipRRect(
        borderRadius: Radii.allPill,
        child: Container(height: height, color: colors.surfaceSunken),
      );
    }

    final head = segments.take(maxSegments).toList();
    final tail = segments.skip(maxSegments).fold<double>(0, (s, e) => s + e.$1);

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (final (index, segment) in head.indexed) ...[
            if (index > 0) const SizedBox(width: 2),
            Expanded(
              flex: (segment.$1 * 1000).round().clamp(1, 1 << 30),
              child: _Segment(color: Viz.slot(segment.$2, dark: colors.isDark)),
            ),
          ],
          if (tail > 0) ...[
            const SizedBox(width: 2),
            Expanded(
              flex: (tail * 1000).round().clamp(1, 1 << 30),
              child: _Segment(color: Viz.other(dark: colors.isDark)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.all(Radius.circular(3)),
    child: ColoredBox(color: color),
  );
}
