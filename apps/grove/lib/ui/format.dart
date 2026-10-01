/// Duration formatting shared by the timer, the garden and the stats screen.
abstract final class Fmt {
  /// A countdown: `25:00`, or `1:05:00` once an hour is involved.
  ///
  /// Seconds are always two digits and minutes are only padded when hours are
  /// present, which is how a stopwatch reads. Negative input clamps to zero -
  /// a countdown should never show `-0:01` because a tick arrived late.
  static String clock(Duration duration) {
    final total = duration.isNegative ? 0 : duration.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final ss = seconds.toString().padLeft(2, '0');
    if (hours == 0) return '$minutes:$ss';
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  }

  /// A total: `0m`, `45m`, `2h`, `2h 30m`.
  ///
  /// Used for sums rather than countdowns, so it drops seconds entirely; a
  /// weekly total of "7h 32m 09s" is noise.
  static String span(
    Duration duration, {
    String hourSuffix = 'h',
    String minuteSuffix = 'm',
  }) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    if (hours == 0) return '$minutes$minuteSuffix';
    if (minutes == 0) return '$hours$hourSuffix';
    return '$hours$hourSuffix $minutes$minuteSuffix';
  }

  /// Whole minutes, for the dial: `25m`, `1h 30m`.
  static String minutes(
    Duration duration, {
    String hourSuffix = 'h',
    String minuteSuffix = 'm',
  }) => span(duration, hourSuffix: hourSuffix, minuteSuffix: minuteSuffix);
}
