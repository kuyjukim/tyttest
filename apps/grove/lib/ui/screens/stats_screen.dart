import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paper/paper.dart';

import '../../domain/session.dart';
import '../../domain/stats.dart';
import '../../state/garden_store.dart';
import '../strings.dart';

/// How many days the chart covers.
enum _Range {
  week(7),
  month(30);

  const _Range(this.days);
  final int days;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Range _range = _Range.week;

  /// Captured in build: the axis-label helper below has no context of its
  /// own, and formatting a weekday for the wrong locale is how a fully
  /// translated screen ends up with English dates on it.
  String _localeTag = 'en';

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<GardenStore>(context);
    final strings = S.of(context);
    _localeTag = context.localeTag;

    if (store.sessions.isEmpty) {
      return EmptyState(
        icon: Icons.insights_outlined,
        title: strings.statsTitle,
        message: strings.noStatsYet,
      );
    }

    final streak = store.streak;
    final totals = Stats.window(
      store.sessions,
      endingOn: store.today,
      days: _range.days,
    );
    final best = Stats.bestDay(store.sessions);

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.x3l),
      children: [
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: strings.statTodayLabel,
                value: strings.span(store.todayTotal.focused),
                emphasis: true,
              ),
            ),
            Expanded(
              child: StatTile(
                label: strings.statStreakLabel,
                value: '${streak.current}',
                unit: strings.streakUnitDays,
                caption: streak.longest > streak.current
                    ? '${strings.bestDay}: ${streak.longest}'
                    : null,
              ),
            ),
            Expanded(
              child: StatTile(
                label: strings.statLifetimeLabel,
                value: strings.span(store.totalFocused),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xxl),
        SegmentedToggle<_Range>(
          segments: [
            (_Range.week, strings.rangeWeek),
            (_Range.month, strings.rangeMonth),
          ],
          value: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        const SizedBox(height: Gap.xl),
        // A single series, so no legend: the section above names what is
        // being measured, and only the peak and the tapped column are
        // labelled.
        BarChart(
          bars: [
            for (final total in totals)
              Bar(
                label: _axisLabel(total.day.startOfDay),
                value: total.focused.inMinutes.toDouble(),
                highlight: total.day == store.today,
              ),
          ],
          formatValue: (minutes) =>
              strings.span(Duration(minutes: minutes.round())),
        ),
        if (best != null) ...[
          SectionHeader(title: strings.bestDay),
          PaperCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMEd(context.localeTag).format(best.day.startOfDay),
                    style: context.type.body,
                  ),
                ),
                Text(
                  strings.span(best.focused),
                  style: context.type.numeric.copyWith(
                    color: context.colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        _TagBreakdown(sessions: store.sessions, strings: strings),
      ],
    );
  }

  /// A weekday initial for a 7-day chart, a day number for a 30-day one.
  ///
  /// Seven weekday letters fit; thirty do not, and a chart whose labels
  /// collide is worse than one with sparser labels.
  String _axisLabel(DateTime day) => _range == _Range.week
      ? DateFormat.E(_localeTag).format(day).substring(0, 1)
      : '${day.day}';
}

/// What the user actually focused on, ranked.
///
/// Horizontal bars rather than a donut: tags are long, their values are often
/// close, and every row carrying its own name and number is what makes the
/// chart readable without a legend.
class _TagBreakdown extends StatelessWidget {
  const _TagBreakdown({required this.sessions, required this.strings});

  final List<FocusSession> sessions;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final minutesByTag = <String, int>{};
    for (final session in sessions) {
      final tag = session.tag;
      if (!session.isCompleted || tag == null || tag.isEmpty) continue;
      minutesByTag.update(
        tag,
        (value) => value + session.elapsed.inMinutes,
        ifAbsent: () => session.elapsed.inMinutes,
      );
    }
    if (minutesByTag.isEmpty) return const SizedBox.shrink();

    // Slot assignment follows the tag's position in a stable alphabetical
    // ordering, not its rank, so filtering or a quiet week never repaints the
    // survivors.
    final names = minutesByTag.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: strings.byTag),
        RankedBarList(
          bars: [
            for (final (index, name) in names.indexed)
              RankedBar(
                label: name,
                value: minutesByTag[name]!.toDouble(),
                display: strings.span(Duration(minutes: minutesByTag[name]!)),
                slot: index % Viz.slots,
              ),
          ],
        ),
      ],
    );
  }
}
