import 'package:flutter_test/flutter_test.dart';
import 'package:grove/domain/day.dart';

void main() {
  group('Day', () {
    test('is derived from the local calendar date', () {
      final day = Day.fromDateTime(DateTime(2026, 3, 8, 23, 59, 59));
      expect(day, const Day(2026, 3, 8));
    });

    test('converts a UTC instant to the local day before reading fields', () {
      final utc = DateTime.utc(2026, 3, 8, 12);
      expect(Day.fromDateTime(utc), Day.fromDateTime(utc.toLocal()));
    });

    test('steps across month, year and leap-day boundaries', () {
      expect(const Day(2026, 1, 31).next, const Day(2026, 2, 1));
      expect(const Day(2026, 12, 31).next, const Day(2027, 1, 1));
      expect(const Day(2026, 3, 1).previous, const Day(2026, 2, 28));
      // 2028 is a leap year; 2026 is not.
      expect(const Day(2028, 3, 1).previous, const Day(2028, 2, 29));
      expect(const Day(2028, 2, 29).next, const Day(2028, 3, 1));
    });

    test('next and previous are inverses for every day across four years', () {
      // Four years covers two DST transitions per year in the host zone plus
      // a leap day. Any arithmetic that leans on a 24-hour Duration fails
      // somewhere in here; calendar-field arithmetic does not.
      var cursor = const Day(2025, 1, 1);
      const end = Day(2029, 1, 1);
      var checked = 0;
      while (cursor.isBefore(end)) {
        expect(cursor.next.previous, cursor, reason: 'round trip at $cursor');
        expect(cursor.daysUntil(cursor.next), 1, reason: 'step at $cursor');
        cursor = cursor.next;
        checked++;
      }
      expect(checked, greaterThan(1460));
    });

    test('daysUntil is signed and zero for the same day', () {
      const a = Day(2026, 3, 8);
      expect(a.daysUntil(const Day(2026, 3, 15)), 7);
      expect(const Day(2026, 3, 15).daysUntil(a), -7);
      expect(a.daysUntil(a), 0);
    });

    test('daysUntil survives a spring-forward week in a DST zone', () {
      // US DST begins 2026-03-08. If this arithmetic used the local wall
      // clock, the week containing it would measure 6 days and 23 hours and
      // truncate to 6.
      expect(const Day(2026, 3, 5).daysUntil(const Day(2026, 3, 12)), 7);
      // And the autumn transition, 2026-11-01, which is 25 hours long.
      expect(const Day(2026, 10, 29).daysUntil(const Day(2026, 11, 5)), 7);
    });

    test('through yields an inclusive range, and nothing when inverted', () {
      final week = const Day(2026, 3, 2).through(const Day(2026, 3, 8));
      expect(week.length, 7);
      expect(week.first, const Day(2026, 3, 2));
      expect(week.last, const Day(2026, 3, 8));
      expect(const Day(2026, 3, 8).through(const Day(2026, 3, 2)), isEmpty);
      expect(const Day(2026, 3, 8).through(const Day(2026, 3, 8)).length, 1);
    });

    test('addDays matches repeated stepping', () {
      const start = Day(2026, 1, 20);
      var stepped = start;
      for (var i = 0; i < 45; i++) {
        stepped = stepped.next;
      }
      expect(start.addDays(45), stepped);
      expect(start.addDays(0), start);
      expect(start.addDays(-45).addDays(45), start);
    });

    test('startOfDay stays on this date and endOfDay is the next midnight', () {
      const day = Day(2026, 11, 1);
      expect(Day.fromDateTime(day.startOfDay), day);
      expect(Day.fromDateTime(day.endOfDay), day.next);
    });

    test('sorts and compares chronologically', () {
      final days = <Day>[
        const Day(2026, 1, 2),
        const Day(2025, 12, 31),
        const Day(2026, 1, 1),
      ]..sort();
      expect(days.map((d) => d.toString()), [
        '2025-12-31',
        '2026-01-01',
        '2026-01-02',
      ]);
      expect(const Day(2026, 1, 1).isBefore(const Day(2026, 1, 2)), isTrue);
      expect(const Day(2026, 2, 1).isAfter(const Day(2026, 1, 31)), isTrue);
    });

    test('round-trips through its string form, padded', () {
      const day = Day(2026, 3, 8);
      expect(day.toString(), '2026-03-08');
      expect(Day.parse('2026-03-08'), day);
      expect(Day.parse(const Day(876, 1, 2).toString()), const Day(876, 1, 2));
    });

    test('rejects malformed date strings', () {
      for (final bad in <String>['', '2026-03', 'x-03-08', '2026-13-01',
          '2026-00-10', '2026-03-32', '2026/03/08']) {
        expect(
          () => Day.parse(bad),
          throwsFormatException,
          reason: 'should reject "$bad"',
        );
      }
    });

    test('equality and hashing are by value', () {
      expect(const Day(2026, 3, 8), const Day(2026, 3, 8));
      final duplicates = <Day>[const Day(2026, 3, 8), Day.parse('2026-03-08')];
      expect(duplicates.toSet().length, 1);
    });
  });
}
