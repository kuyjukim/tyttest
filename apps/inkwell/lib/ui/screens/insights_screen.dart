import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paper/paper.dart';

import '../../domain/entry.dart';
import '../../state/vault_store.dart';
import '../mood_scale.dart';
import '../strings.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  /// Days the activity chart covers.
  static const int window = 14;

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<VaultStore>(context);
    final strings = S.of(context);
    final journal = store.journal;
    if (journal == null) return const SizedBox.shrink();

    if (journal.entries.isEmpty) {
      return EmptyState(
        icon: Icons.insights_outlined,
        title: strings.tabInsights,
        message: strings.insightsEmpty,
      );
    }

    final today = store.today;
    final words = journal.entries.fold<int>(0, (sum, e) => sum + e.wordCount);
    final perDay = <Day, int>{};
    for (final entry in journal.entries) {
      perDay.update(entry.day, (v) => v + 1, ifAbsent: () => 1);
    }
    final start = today.addDays(-(window - 1));

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.x3l),
      children: [
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: strings.streakLabel,
                value: '${journal.writingStreak(today)}',
                unit: strings.days,
                emphasis: true,
              ),
            ),
            Expanded(
              child: StatTile(
                label: strings.entriesLabel,
                value: '${journal.entries.length}',
              ),
            ),
            Expanded(
              child: StatTile(
                label: strings.wordsLabel,
                value: _compact(words),
              ),
            ),
          ],
        ),
        SectionHeader(title: strings.writingActivity),
        // One series, so no legend; the section title says what is counted.
        BarChart(
          bars: [
            for (final day in start.through(today))
              Bar(
                label: DateFormat.E().format(day.startOfDay).substring(0, 1),
                value: (perDay[day] ?? 0).toDouble(),
                highlight: day == today,
              ),
          ],
          height: 110,
          formatValue: (value) => '${value.round()}',
        ),
        _MoodMix(entries: journal.entries, strings: strings),
      ],
    );
  }

  /// `1.2k` past a thousand, so a stat tile never wraps.
  static String _compact(int value) {
    if (value < 1000) return '$value';
    final thousands = value / 1000;
    return thousands >= 10
        ? '${thousands.round()}k'
        : '${thousands.toStringAsFixed(1)}k';
  }
}

/// How often each mood was recorded.
///
/// A ranked row per mood rather than a donut: five close values in a ring are
/// unreadable, and each row here carries its own name and count, which is
/// also what keeps the scale from depending on colour alone.
class _MoodMix extends StatelessWidget {
  const _MoodMix({required this.entries, required this.strings});

  final List<Entry> entries;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final counts = <Mood, int>{};
    for (final entry in entries) {
      final mood = entry.mood;
      if (mood == null) continue;
      counts.update(mood, (v) => v + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final peak = counts.values.reduce((a, b) => a > b ? a : b);
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: strings.moodMix),
        for (final mood in Mood.values)
          if (counts[mood] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Semantics(
                label: '${strings.moodName(mood)}: ${counts[mood]}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: MoodScale.of(mood, dark: colors.isDark),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            strings.moodName(mood),
                            style: context.type.body,
                          ),
                        ),
                        Text('${counts[mood]}', style: context.type.numeric),
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
                          widthFactor: counts[mood]! / peak,
                          child: ColoredBox(
                            color: MoodScale.of(mood, dark: colors.isDark),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
