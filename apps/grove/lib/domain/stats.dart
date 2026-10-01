import 'package:paper/paper.dart';

import 'session.dart';

/// A current/longest streak pair.
class Streak {
  const Streak({required this.current, required this.longest});

  static const Streak none = Streak(current: 0, longest: 0);

  /// Length of the run of qualifying days ending today - or ending yesterday,
  /// when today has not qualified yet. See [Stats.streak] for why.
  final int current;

  final int longest;

  @override
  bool operator ==(Object other) =>
      other is Streak && other.current == current && other.longest == longest;

  @override
  int get hashCode => Object.hash(current, longest);

  @override
  String toString() => 'Streak(current: $current, longest: $longest)';
}

/// A single day's totals.
class DayTotal {
  const DayTotal({
    required this.day,
    required this.focused,
    required this.completedCount,
    required this.abandonedCount,
  });

  final Day day;

  /// Sum of completed sessions only.
  final Duration focused;

  final int completedCount;
  final int abandonedCount;

  bool get isEmpty => completedCount == 0 && abandonedCount == 0;
}

/// Read-only projections over a session list.
///
/// All of it is static and pure: the store holds the sessions, and every
/// number on screen is derived here. That keeps the persisted file small -
/// just the sessions - and means no cached total can ever drift from the
/// sessions it was supposed to summarise.
abstract final class Stats {
  /// Lifetime completed focus time. Drives species unlocks.
  static Duration totalFocused(Iterable<FocusSession> sessions) {
    var seconds = 0;
    for (final session in sessions) {
      if (session.isCompleted) seconds += session.elapsed.inSeconds;
    }
    return Duration(seconds: seconds);
  }

  static int totalFocusedMinutes(Iterable<FocusSession> sessions) =>
      totalFocused(sessions).inMinutes;

  /// Sessions grouped by the day they started, newest day first.
  static Map<Day, List<FocusSession>> byDay(Iterable<FocusSession> sessions) {
    final grouped = <Day, List<FocusSession>>{};
    for (final session in sessions) {
      grouped.putIfAbsent(session.day, () => <FocusSession>[]).add(session);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return <Day, List<FocusSession>>{
      for (final key in keys)
        key: grouped[key]!..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
    };
  }

  static DayTotal totalFor(Iterable<FocusSession> sessions, Day day) {
    var seconds = 0;
    var completed = 0;
    var abandoned = 0;
    for (final session in sessions) {
      if (session.day != day) continue;
      if (session.isCompleted) {
        completed++;
        seconds += session.elapsed.inSeconds;
      } else {
        abandoned++;
      }
    }
    return DayTotal(
      day: day,
      focused: Duration(seconds: seconds),
      completedCount: completed,
      abandonedCount: abandoned,
    );
  }

  /// Totals for the [days] calendar days ending on [endingOn], oldest first.
  ///
  /// Days with nothing in them are included as zeroes so a chart always has a
  /// full week of columns rather than a ragged few.
  static List<DayTotal> window(
    Iterable<FocusSession> sessions, {
    required Day endingOn,
    required int days,
  }) {
    assert(days > 0, 'a window needs at least one day');
    final start = endingOn.addDays(-(days - 1));
    final list = sessions.toList(growable: false);
    return <DayTotal>[
      for (final day in start.through(endingOn)) totalFor(list, day),
    ];
  }

  /// The set of days with at least one completed session.
  static Set<Day> qualifyingDays(Iterable<FocusSession> sessions) => <Day>{
    for (final session in sessions)
      if (session.isCompleted) session.day,
  };

  /// Current and longest streaks as of [today].
  ///
  /// A day qualifies when it holds at least one *completed* session.
  ///
  /// The current streak is the run ending today if today qualifies, and
  /// otherwise the run ending yesterday. Without that grace the number a user
  /// sees reads 0 every morning until they focus again, which punishes them
  /// for the clock rather than for their behaviour. The streak only truly
  /// breaks once a whole day has passed with nothing in it.
  static Streak streak(Iterable<FocusSession> sessions, {required Day today}) {
    final qualifying = qualifyingDays(sessions);
    if (qualifying.isEmpty) return Streak.none;

    int runEndingAt(Day end) {
      var length = 0;
      var cursor = end;
      while (qualifying.contains(cursor)) {
        length++;
        cursor = cursor.previous;
      }
      return length;
    }

    final current = qualifying.contains(today)
        ? runEndingAt(today)
        : runEndingAt(today.previous);

    // Longest: walk the sorted days once, counting consecutive runs. Future
    // days (a session recorded while the device clock was ahead) are included
    // rather than silently dropped - the data is the user's.
    final sorted = qualifying.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i - 1].daysUntil(sorted[i]) == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    return Streak(
      current: current,
      longest: longest > current ? longest : current,
    );
  }

  /// Completed-session count by species, for the collection screen.
  static Map<String, int> plantedBySpecies(Iterable<FocusSession> sessions) {
    final counts = <String, int>{};
    for (final session in sessions) {
      if (!session.isCompleted) continue;
      counts.update(session.species.name, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// The day with the most completed focus time, or null when there is none.
  static DayTotal? bestDay(Iterable<FocusSession> sessions) {
    DayTotal? best;
    for (final day in qualifyingDays(sessions)) {
      final total = totalFor(sessions, day);
      if (best == null || total.focused > best.focused) best = total;
    }
    return best;
  }
}
