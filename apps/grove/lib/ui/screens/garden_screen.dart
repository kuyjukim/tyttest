import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paper/paper.dart';

import '../../domain/session.dart';
import '../../domain/stats.dart';
import '../../state/garden_store.dart';
import '../strings.dart';
import '../widgets/tree_figure.dart';
import '../widgets/tree_view.dart';

/// Every session ever, grouped by day, newest first.
///
/// Abandoned sessions are shown alongside the planted ones rather than
/// hidden. A garden that only ever shows successes is a flattering lie, and
/// the stumps are what give the planted trees their weight.
class GardenScreen extends StatelessWidget {
  const GardenScreen({required this.onStartFocusing, super.key});

  final VoidCallback onStartFocusing;

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<GardenStore>(context);
    final strings = S.of(context);
    final grouped = Stats.byDay(store.sessions);

    if (grouped.isEmpty) {
      return EmptyState(
        icon: Icons.park_outlined,
        title: strings.gardenEmptyTitle,
        message: strings.gardenEmptyBody,
        actionLabel: strings.gardenEmptyAction,
        onAction: onStartFocusing,
      );
    }

    final days = grouped.keys.toList(growable: false);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Gap.x3l),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return _DaySection(
          day: day,
          sessions: grouped[day]!,
          today: store.today,
          strings: strings,
        );
      },
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.sessions,
    required this.today,
    required this.strings,
  });

  final Day day;
  final List<FocusSession> sessions;
  final Day today;
  final S strings;

  String get _heading {
    if (day == today) return strings.today;
    if (day == today.previous) return strings.yesterday;
    return DateFormat.MMMEd().format(day.startOfDay);
  }

  @override
  Widget build(BuildContext context) {
    final planted = sessions.where((s) => s.isCompleted).length;
    final withered = sessions.length - planted;
    final focused = Stats.totalFocused(sessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _heading,
          trailing: Text(strings.span(focused), style: context.type.numeric),
        ),
        PaperCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
                  itemBuilder: (context, index) => _TreeTile(
                    session: sessions[index],
                    strings: strings,
                  ),
                ),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                withered == 0
                    ? strings.plantedCount(planted)
                    : '${strings.plantedCount(planted)} · '
                          '${strings.witheredCount(withered)}',
                style: context.type.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TreeTile extends StatelessWidget {
  const _TreeTile({required this.session, required this.strings});

  final FocusSession session;
  final S strings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${strings.speciesName(session.species)}, '
          '${session.isCompleted ? strings.sessionCompleted : strings.sessionAbandoned}, '
          '${strings.span(session.elapsed)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _showDetail(context),
        child: SizedBox(
          width: 64,
          child: TreeView(
            figure: TreeFigure(
              species: session.species,
              seed: session.seed,
              growth: session.isCompleted ? 1 : session.completion,
              withered: !session.isCompleted,
            ),
            // Thumbnails: three generations keep the silhouette and skip a
            // few hundred sub-pixel path segments per tree.
            depthLimit: 3,
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final time = DateFormat.jm().format(session.startedAt);
    showPaperSheet<void>(
      context: context,
      title: strings.speciesName(session.species),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: TreeView(
              figure: TreeFigure(
                species: session.species,
                seed: session.seed,
                growth: session.isCompleted ? 1 : session.completion,
                withered: !session.isCompleted,
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          _DetailRow(
            label: session.isCompleted
                ? strings.sessionCompleted
                : strings.sessionAbandoned,
            value: strings.span(session.elapsed),
            emphasis: session.isCompleted,
          ),
          const Hairline(),
          _DetailRow(label: time, value: strings.span(session.planned)),
          if (session.tag != null) ...[
            const Hairline(),
            _DetailRow(label: strings.byTag, value: session.tag!),
          ],
          const SizedBox(height: Gap.lg),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.type.body.copyWith(
                color: emphasis ? context.colors.accent : context.colors.ink,
                fontWeight: emphasis ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(value, style: context.type.numeric),
        ],
      ),
    );
  }
}
