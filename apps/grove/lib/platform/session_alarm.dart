/// What the end-of-session notification says.
///
/// Passed in by the caller rather than built where the alarm is armed: the
/// store has no locale, and a timer whose one notification arrives in the
/// wrong language is worse than a timer with none.
class AlarmCopy {
  const AlarmCopy({required this.title, required this.body});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is AlarmCopy && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);

  @override
  String toString() => 'AlarmCopy($title / $body)';
}

/// A single pending notification for the end of the running session.
///
/// An interface rather than a direct call into the plugin, for two reasons.
/// The obvious one is testing: the whole of Grove above this line is pure
/// Dart, and the 80-odd widget tests would need a mocked platform channel the
/// moment the store talked to a plugin. The less obvious one is that
/// notifications are the one part of this app that cannot be verified
/// anywhere but a real phone, so the seam is also where that uncertainty
/// stops.
///
/// There is only ever one alarm, because there is only ever one session.
/// [arm] replaces whatever was pending; [disarm] is safe to call when nothing
/// is.
abstract class SessionAlarm {
  /// Asks the OS for permission to post notifications, if it has not been
  /// asked already.
  ///
  /// Returns whether notifications will actually be delivered, so the caller
  /// can stop promising them. Idempotent: on both platforms a second call
  /// returns the stored decision without prompting again.
  Future<bool> requestPermission();

  /// Posts [copy] at [moment]. Replaces any pending alarm.
  Future<void> arm({required DateTime moment, required AlarmCopy copy});

  /// Drops the pending alarm, and removes it from the shade if it has already
  /// been delivered.
  Future<void> disarm();
}

/// A [SessionAlarm] that does nothing.
///
/// The default, so that a store built without one - every test, the
/// screenshot harness - needs no plugin and no platform channel.
class SilentAlarm implements SessionAlarm {
  const SilentAlarm();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> arm({required DateTime moment, required AlarmCopy copy}) async {}

  @override
  Future<void> disarm() async {}
}
