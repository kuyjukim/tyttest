import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paper/paper.dart';

import '../../domain/entry.dart';
import '../../state/vault_store.dart';
import '../strings.dart';
import '../widgets/mood_dot.dart';
import 'editor_screen.dart';

/// Every entry, newest first, grouped by month, with search.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(String? entryId) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EditorScreen(entryId: entryId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<VaultStore>(context);
    final strings = S.of(context);
    final journal = store.journal;

    if (journal == null) return const SizedBox.shrink();

    if (journal.entries.isEmpty) {
      return EmptyState(
        icon: Icons.edit_note_rounded,
        title: strings.journalEmptyTitle,
        message: strings.journalEmptyBody,
        actionLabel: strings.journalEmptyAction,
        onAction: () => _open(null),
      );
    }

    final searching = _query.trim().isNotEmpty;
    final results = journal.search(_query);
    final resurfaced = searching
        ? const <Entry>[]
        : journal.onThisDay(store.today);

    return Column(
      children: [
        const SizedBox(height: Gap.sm),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: strings.searchHint,
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: searching
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: strings.searchHint,
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    strings.journalEmptyTitle,
                    style: context.type.body.copyWith(
                      color: context.colors.inkMuted,
                    ),
                  ),
                )
              : _EntryList(
                  entries: results,
                  resurfaced: resurfaced,
                  today: store.today,
                  strings: strings,
                  grouped: !searching,
                  onOpen: _open,
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.lg, top: Gap.sm),
          child: PaperButton(
            label: strings.newEntry,
            icon: Icons.add_rounded,
            size: PaperButtonSize.large,
            expand: true,
            onPressed: () => _open(null),
          ),
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.entries,
    required this.resurfaced,
    required this.today,
    required this.strings,
    required this.grouped,
    required this.onOpen,
  });

  final List<Entry> entries;
  final List<Entry> resurfaced;
  final Day today;
  final S strings;

  /// Month headers are dropped while searching: results that jump between
  /// months read better as one ranked list than as a sparse calendar.
  final bool grouped;

  final Future<void> Function(String? entryId) onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (resurfaced.isNotEmpty) {
      rows
        ..add(SectionHeader(title: strings.onThisDay))
        ..addAll([
          for (final entry in resurfaced)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: PaperCard(
                accent: true,
                onTap: () => onOpen(entry.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.yearsAgo(today.year - entry.day.year),
                      style: context.type.label.copyWith(
                        color: context.colors.accent,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      entry.titleOr(strings.untitled),
                      style: context.type.bodyStrong,
                    ),
                    if (entry.preview.isNotEmpty) ...[
                      const SizedBox(height: Gap.xxs),
                      Text(
                        entry.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ]);
    }

    Day? lastMonth;
    for (final entry in entries) {
      if (grouped) {
        final month = Day(entry.day.year, entry.day.month, 1);
        if (month != lastMonth) {
          lastMonth = month;
          rows.add(
            SectionHeader(
              title: DateFormat.yMMMM().format(month.startOfDay),
            ),
          );
        }
      }
      rows.add(
        _EntryRow(
          entry: entry,
          today: today,
          strings: strings,
          onTap: () => onOpen(entry.id),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.today,
    required this.strings,
    required this.onTap,
  });

  final Entry entry;
  final Day today;
  final S strings;
  final VoidCallback onTap;

  String get _dateLabel {
    if (entry.day == today) return strings.today;
    if (entry.day == today.previous) return strings.yesterday;
    return DateFormat.MMMd().format(entry.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mood = entry.mood;
    return Semantics(
      button: true,
      label: <String>[
        entry.titleOr(strings.untitled),
        _dateLabel,
        if (mood != null) strings.moodName(mood),
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  _dateLabel,
                  style: context.type.caption.copyWith(
                    color: entry.day == today ? colors.accent : colors.inkMuted,
                    fontWeight: entry.day == today ? FontWeight.w600 : null,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (mood != null) ...[
                          MoodDot(mood: mood),
                          const SizedBox(width: Gap.sm),
                        ],
                        Expanded(
                          child: Text(
                            entry.titleOr(strings.untitled),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                    if (entry.preview.isNotEmpty) ...[
                      const SizedBox(height: Gap.xxs),
                      Text(
                        entry.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption,
                      ),
                    ],
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      Text(
                        entry.tags.map((t) => '#$t').join('  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption.copyWith(
                          color: colors.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
