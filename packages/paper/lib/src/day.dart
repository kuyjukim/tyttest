/// A local calendar date, with no time and no zone.
///
/// Streaks, "today's total" and the garden's day grouping are all calendar
/// questions, and answering them with [DateTime] arithmetic is how streak
/// bugs happen: `subtract(const Duration(days: 1))` is 23 or 25 hours on a
/// DST boundary, so "yesterday" can land on the wrong date or on the same one
/// twice. Every step here goes through [DateTime]'s own field normalisation
/// instead, which is calendar-correct by construction.
class Day implements Comparable<Day> {
  const Day(this.year, this.month, this.dayOfMonth);

  /// The calendar date [moment] falls on, in the device's current zone.
  factory Day.fromDateTime(DateTime moment) {
    final local = moment.isUtc ? moment.toLocal() : moment;
    return Day(local.year, local.month, local.day);
  }

  /// Parses the `YYYY-MM-DD` form written by [toString].
  factory Day.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected YYYY-MM-DD', value);
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      throw FormatException('Expected YYYY-MM-DD', value);
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      throw FormatException('Not a calendar date', value);
    }
    return Day(year, month, day);
  }

  final int year;
  final int month;
  final int dayOfMonth;

  /// Local midnight at the start of this day.
  ///
  /// On the rare dates where local midnight does not exist (a DST jump at
  /// 00:00, as in parts of Latin America), [DateTime] shifts forward into the
  /// first valid instant; that is the right answer for "the start of this
  /// day" and keeps the result on this date.
  DateTime get startOfDay => DateTime(year, month, dayOfMonth);

  /// The instant this day ends, i.e. the start of the next one.
  DateTime get endOfDay => next.startOfDay;

  /// Monday is 1, Sunday is 7, matching [DateTime.weekday].
  int get weekday => startOfDay.weekday;

  Day get next => _shift(1);
  Day get previous => _shift(-1);

  /// This day moved by [days], which may be negative.
  Day _shift(int days) {
    // Passing an out-of-range day-of-month to the DateTime constructor is
    // defined to roll over into the next or previous month, including across
    // year ends and leap days, which is exactly the arithmetic wanted here.
    final shifted = DateTime(year, month, dayOfMonth + days);
    return Day(shifted.year, shifted.month, shifted.day);
  }

  Day addDays(int days) => days == 0 ? this : _shift(days);

  /// Whole days from this day to [other]; negative when [other] is earlier.
  int daysUntil(Day other) {
    // Compared at midday rather than midnight so that a DST shift of an hour
    // either way cannot round the division to the wrong integer.
    final a = DateTime.utc(year, month, dayOfMonth, 12);
    final b = DateTime.utc(other.year, other.month, other.dayOfMonth, 12);
    return b.difference(a).inDays;
  }

  bool isBefore(Day other) => compareTo(other) < 0;
  bool isAfter(Day other) => compareTo(other) > 0;

  /// Inclusive range from this day to [end]. Empty when [end] is earlier.
  Iterable<Day> through(Day end) sync* {
    var cursor = this;
    while (!cursor.isAfter(end)) {
      yield cursor;
      cursor = cursor.next;
    }
  }

  @override
  int compareTo(Day other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return dayOfMonth.compareTo(other.dayOfMonth);
  }

  @override
  bool operator ==(Object other) =>
      other is Day &&
      other.year == year &&
      other.month == month &&
      other.dayOfMonth == dayOfMonth;

  @override
  int get hashCode => Object.hash(year, month, dayOfMonth);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${dayOfMonth.toString().padLeft(2, '0')}';
}
