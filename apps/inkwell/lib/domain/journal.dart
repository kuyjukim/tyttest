import 'dart:convert';

import 'package:paper/paper.dart';

import 'entry.dart';

/// The decrypted contents of a vault.
///
/// This object only ever exists while the vault is unlocked. It is the
/// plaintext, so nothing here is persisted directly - it is serialised,
/// sealed and written as one blob.
class Journal {
  Journal({required this.entries});

  factory Journal.empty() => Journal(entries: <Entry>[]);

  /// Parses the decrypted JSON body.
  ///
  /// An entry that fails to parse is skipped rather than failing the whole
  /// journal: having decrypted successfully, the key was right, and dropping
  /// one damaged record beats refusing to show the other nine hundred.
  factory Journal.decode(String plaintext) {
    if (plaintext.trim().isEmpty) return Journal.empty();
    final decoded = jsonDecode(plaintext);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Journal body is not an object');
    }
    final rawEntries = decoded['entries'];
    final entries = <Entry>[];
    if (rawEntries is List) {
      for (final raw in rawEntries) {
        if (raw is! Map<String, Object?>) continue;
        try {
          entries.add(Entry.fromJson(raw));
        } on Object {
          continue;
        }
      }
    }
    return Journal(entries: entries)..sort();
  }

  static const int formatVersion = 1;

  final List<Entry> entries;

  /// Newest first, which is the order every screen wants.
  ///
  /// The id is the tiebreaker, not decoration: two entries written in the
  /// same clock tick - easy to do, and certain in a test with a fixed clock -
  /// would otherwise come back in whatever order the last operation happened
  /// to leave them in, so the list would reshuffle on reload. Ids are
  /// allocated in time order and fixed width, so comparing them descending
  /// continues "newest first" rather than inventing a second rule.
  void sort() => entries.sort((a, b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });

  Entry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Inserts or replaces [entry], keeping the list sorted.
  void upsert(Entry entry) {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    sort();
  }

  bool remove(String id) {
    final before = entries.length;
    entries.removeWhere((e) => e.id == id);
    return entries.length != before;
  }

  List<Entry> search(String query) =>
      <Entry>[for (final entry in entries) if (entry.matches(query)) entry];

  /// Entries grouped by calendar month, newest month first.
  Map<Day, List<Entry>> byMonth() {
    final grouped = <Day, List<Entry>>{};
    for (final entry in entries) {
      final month = Day(entry.day.year, entry.day.month, 1);
      grouped.putIfAbsent(month, () => <Entry>[]).add(entry);
    }
    final months = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return <Day, List<Entry>>{for (final month in months) month: grouped[month]!};
  }

  /// Entries written on the same month and day in an earlier year.
  ///
  /// The feature that makes a journal worth keeping for years rather than
  /// weeks: it gives the archive a reason to be read.
  List<Entry> onThisDay(Day today) => <Entry>[
    for (final entry in entries)
      if (entry.day.year < today.year &&
          entry.day.month == today.month &&
          entry.day.dayOfMonth == today.dayOfMonth)
        entry,
  ];

  /// The set of tags in use, alphabetically.
  List<String> allTags() {
    final tags = <String>{};
    for (final entry in entries) {
      tags.addAll(entry.tags);
    }
    return tags.toList()..sort();
  }

  /// Consecutive days with at least one entry, ending today or yesterday.
  ///
  /// Same grace as the rest of the suite: a streak that reads zero every
  /// morning punishes the user for the clock.
  int writingStreak(Day today) {
    final days = <Day>{for (final entry in entries) entry.day};
    if (days.isEmpty) return 0;

    int runEndingAt(Day end) {
      var length = 0;
      var cursor = end;
      while (days.contains(cursor)) {
        length++;
        cursor = cursor.previous;
      }
      return length;
    }

    return days.contains(today) ? runEndingAt(today) : runEndingAt(today.previous);
  }

  String encode() => jsonEncode(<String, Object?>{
    'version': formatVersion,
    'entries': <Object?>[for (final entry in entries) entry.toJson()],
  });

  /// A plain-text export, for someone leaving or keeping a paper copy.
  ///
  /// Offered because a journal that can only be read by the app that wrote it
  /// is a journal held hostage.
  String toMarkdown() {
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer
        ..writeln('## ${entry.titleOr(entry.day.toString())}')
        ..writeln()
        ..writeln('*${entry.createdAt.toIso8601String()}*');
      if (entry.mood != null) buffer.writeln('*Mood: ${entry.mood!.name}*');
      if (entry.tags.isNotEmpty) {
        buffer.writeln('*Tags: ${entry.tags.join(', ')}*');
      }
      buffer
        ..writeln()
        ..writeln(entry.body.trim())
        ..writeln()
        ..writeln('---')
        ..writeln();
    }
    return buffer.toString();
  }
}
