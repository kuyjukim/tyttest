import 'package:paper/paper.dart';

/// A calendar month.
///
/// Budgets are month-shaped, and month arithmetic is the other place after
/// day arithmetic where `Duration` gets it wrong: months are 28 to 31 days
/// long, so "a month later" is not a fixed number of hours. Every step here
/// goes through [DateTime] field normalisation.
class Month implements Comparable<Month> {
  const Month(this.year, this.month);

  factory Month.fromDay(Day day) => Month(day.year, day.month);

  factory Month.fromDateTime(DateTime moment) =>
      Month.fromDay(Day.fromDateTime(moment));

  /// Parses the `YYYY-MM` form written by [toString].
  factory Month.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 2) throw FormatException('Expected YYYY-MM', value);
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      throw FormatException('Expected YYYY-MM', value);
    }
    return Month(year, month);
  }

  final int year;
  final int month;

  Day get firstDay => Day(year, month, 1);

  /// The last day of this month: day zero of the next one, which [DateTime]
  /// normalises for us and which is correct for February in any year.
  Day get lastDay {
    final rolled = DateTime(year, month + 1, 0);
    return Day(rolled.year, rolled.month, rolled.day);
  }

  int get dayCount => lastDay.dayOfMonth;

  Month get next => _shift(1);
  Month get previous => _shift(-1);

  Month addMonths(int months) => months == 0 ? this : _shift(months);

  Month _shift(int months) {
    final shifted = DateTime(year, month + months);
    return Month(shifted.year, shifted.month);
  }

  int monthsUntil(Month other) =>
      (other.year - year) * 12 + (other.month - month);

  bool contains(Day day) => day.year == year && day.month == month;

  /// Inclusive range. Empty when [end] is earlier.
  Iterable<Month> through(Month end) sync* {
    var cursor = this;
    while (cursor.compareTo(end) <= 0) {
      yield cursor;
      cursor = cursor.next;
    }
  }

  /// Days from [today] to the end of this month, counting today.
  ///
  /// The whole month when [today] is earlier, and zero once it has passed -
  /// which is what stops a "safe to spend per day" figure from dividing by a
  /// negative number of days in a month the user is only looking back at.
  int daysRemainingFrom(Day today) {
    if (contains(today)) return dayCount - today.dayOfMonth + 1;
    return today.isBefore(firstDay) ? dayCount : 0;
  }

  @override
  int compareTo(Month other) {
    if (year != other.year) return year.compareTo(other.year);
    return month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) =>
      other is Month && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
