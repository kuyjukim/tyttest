import 'package:flutter_test/flutter_test.dart';
import 'package:grove/domain/day.dart';
import 'package:grove/domain/session.dart';
import 'package:grove/domain/species.dart';
import 'package:grove/domain/stats.dart';

FocusSession session({
  required Day day,
  int minutes = 25,
  SessionOutcome outcome = SessionOutcome.completed,
  int hour = 10,
  String? id,
  Species species = Species.sprout,
}) => FocusSession(
  id: id ?? '${day}_${hour}_${outcome.name}_$minutes',
  species: species,
  planned: Duration(minutes: minutes),
  startedAt: DateTime(day.year, day.month, day.dayOfMonth, hour),
  elapsed: Duration(minutes: minutes),
  outcome: outcome,
);

void main() {
  const today = Day(2026, 10, 1);

  group('totals', () {
    test('count completed time only', () {
      final sessions = <FocusSession>[
        session(day: today, minutes: 25),
        session(day: today, minutes: 50, hour: 12),
        session(
          day: today,
          minutes: 40,
          hour: 14,
          outcome: SessionOutcome.abandoned,
        ),
      ];
      expect(Stats.totalFocused(sessions), const Duration(minutes: 75));
      expect(Stats.totalFocusedMinutes(sessions), 75);

      final day = Stats.totalFor(sessions, today);
      expect(day.completedCount, 2);
      expect(day.abandonedCount, 1);
      expect(day.focused, const Duration(minutes: 75));
    });

    test('an empty day reports zero rather than throwing', () {
      final total = Stats.totalFor(const <FocusSession>[], today);
      expect(total.focused, Duration.zero);
      expect(total.isEmpty, isTrue);
    });

    test('a session is filed under the day it started, not the day it ended',
        () {
      // Begun 23:50, ran 25 minutes, so it finished after midnight.
      final late = FocusSession(
        id: 'late',
        species: Species.sprout,
        planned: const Duration(minutes: 25),
        startedAt: DateTime(2026, 9, 30, 23, 50),
        elapsed: const Duration(minutes: 25),
        outcome: SessionOutcome.completed,
      );
      expect(late.day, const Day(2026, 9, 30));
      expect(Stats.totalFor(<FocusSession>[late], today).isEmpty, isTrue);
    });
  });

  group('byDay', () {
    test('groups newest day first, newest session first inside a day', () {
      final sessions = <FocusSession>[
        session(day: const Day(2026, 9, 29), hour: 9),
        session(day: today, hour: 8),
        session(day: today, hour: 17),
        session(day: const Day(2026, 9, 30), hour: 11),
      ];
      final grouped = Stats.byDay(sessions);
      expect(grouped.keys.toList(), [
        today,
        const Day(2026, 9, 30),
        const Day(2026, 9, 29),
      ]);
      expect(grouped[today]!.first.startedAt.hour, 17);
      expect(grouped[today]!.last.startedAt.hour, 8);
    });
  });

  group('window', () {
    test('zero-fills gaps so a chart always has a full span', () {
      final sessions = <FocusSession>[
        session(day: today, minutes: 30),
        session(day: const Day(2026, 9, 28), minutes: 60),
      ];
      final week = Stats.window(sessions, endingOn: today, days: 7);

      expect(week.length, 7);
      expect(week.first.day, const Day(2026, 9, 25));
      expect(week.last.day, today);
      expect(week.last.focused, const Duration(minutes: 30));
      expect(
        week.firstWhere((d) => d.day == const Day(2026, 9, 28)).focused,
        const Duration(minutes: 60),
      );
      expect(week.where((d) => d.isEmpty).length, 5);
    });

    test('spans a month boundary correctly', () {
      final week = Stats.window(
        const <FocusSession>[],
        endingOn: const Day(2026, 3, 2),
        days: 7,
      );
      expect(week.first.day, const Day(2026, 2, 24));
      expect(week.length, 7);
    });

    test('a one-day window is just today', () {
      final window = Stats.window(
        const <FocusSession>[],
        endingOn: today,
        days: 1,
      );
      expect(window.single.day, today);
    });
  });

  group('streak', () {
    test('is zero with no completed sessions at all', () {
      expect(Stats.streak(const <FocusSession>[], today: today), Streak.none);
      expect(
        Stats.streak(
          <FocusSession>[
            session(day: today, outcome: SessionOutcome.abandoned),
          ],
          today: today,
        ),
        Streak.none,
        reason: 'giving up must not keep a streak alive',
      );
    });

    test('counts a run ending today', () {
      final sessions = <FocusSession>[
        for (var i = 0; i < 4; i++) session(day: today.addDays(-i)),
      ];
      expect(Stats.streak(sessions, today: today).current, 4);
    });

    test('keeps yesterday\'s run alive before today\'s first session', () {
      // The grace that matters: at 9am, before the user has focused, the
      // streak they built must not read as zero.
      final sessions = <FocusSession>[
        for (var i = 1; i <= 3; i++) session(day: today.addDays(-i)),
      ];
      expect(Stats.streak(sessions, today: today).current, 3);
    });

    test('breaks once a whole empty day has passed', () {
      final sessions = <FocusSession>[
        for (var i = 2; i <= 5; i++) session(day: today.addDays(-i)),
      ];
      expect(
        Stats.streak(sessions, today: today).current,
        0,
        reason: 'nothing yesterday and nothing today is a broken streak',
      );
      expect(Stats.streak(sessions, today: today).longest, 4);
    });

    test('longest survives after the current run breaks', () {
      final sessions = <FocusSession>[
        for (var i = 0; i < 6; i++) session(day: const Day(2026, 1, 1).addDays(i)),
        session(day: today),
      ];
      final streak = Stats.streak(sessions, today: today);
      expect(streak.current, 1);
      expect(streak.longest, 6);
    });

    test('longest is never reported below current', () {
      final sessions = <FocusSession>[
        for (var i = 0; i < 3; i++) session(day: today.addDays(-i)),
      ];
      final streak = Stats.streak(sessions, today: today);
      expect(streak.longest, greaterThanOrEqualTo(streak.current));
    });

    test('several sessions on one day count once', () {
      final sessions = <FocusSession>[
        session(day: today, hour: 9),
        session(day: today, hour: 13),
        session(day: today, hour: 20),
      ];
      expect(Stats.streak(sessions, today: today).current, 1);
    });

    test('a streak that crosses a DST change still counts every day', () {
      // US spring-forward is 2026-03-08; a run through it is still 5 days.
      const sunday = Day(2026, 3, 8);
      final sessions = <FocusSession>[
        for (var i = 0; i < 5; i++) session(day: sunday.addDays(-i)),
      ];
      expect(Stats.streak(sessions, today: sunday).current, 5);
    });
  });

  group('bestDay and plantedBySpecies', () {
    test('report the heaviest day and the species tally', () {
      final sessions = <FocusSession>[
        session(day: today, minutes: 30, species: Species.pine),
        session(day: const Day(2026, 9, 20), minutes: 120, species: Species.pine),
        session(
          day: const Day(2026, 9, 21),
          minutes: 90,
          outcome: SessionOutcome.abandoned,
          species: Species.maple,
        ),
      ];
      expect(Stats.bestDay(sessions)!.day, const Day(2026, 9, 20));
      expect(Stats.plantedBySpecies(sessions), {'pine': 2});
      expect(Stats.bestDay(const <FocusSession>[]), isNull);
    });
  });

  group('Species unlocks', () {
    test('only the starter is available at zero minutes', () {
      expect(Species.unlockedAt(0), [Species.sprout]);
      expect(Species.nextLockedAfter(0), Species.pine);
    });

    test('thresholds are strictly increasing so the ladder never stalls', () {
      for (var i = 1; i < Species.values.length; i++) {
        expect(
          Species.values[i].unlockMinutes,
          greaterThan(Species.values[i - 1].unlockMinutes),
          reason: '${Species.values[i].name} does not advance the ladder',
        );
      }
    });

    test('everything is unlocked at the top threshold', () {
      final top = Species.values.last.unlockMinutes;
      expect(Species.unlockedAt(top).length, Species.values.length);
      expect(Species.nextLockedAfter(top), isNull);
    });

    test('byName is total over the enum and null for junk', () {
      for (final s in Species.values) {
        expect(Species.byName(s.name), s);
      }
      expect(Species.byName('eucalyptus'), isNull);
    });
  });
}
