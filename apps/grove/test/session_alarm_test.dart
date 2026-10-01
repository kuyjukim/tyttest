// What the end-of-session notification does, decided here rather than on a
// phone.
//
// The plugin itself cannot be tested without a device, so the seam is drawn
// at [SessionAlarm]: everything worth getting right - whether an alarm is
// armed at all, for which instant, and when it is dropped again - is a
// decision [GardenStore] makes, and all of it is checked below. What is left
// unverified is only the delivery, and that is one thin wrapper away in
// `lib/platform/notification_alarm.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:grove/data/garden_repository.dart';
import 'package:grove/domain/active_session.dart';
import 'package:grove/domain/settings.dart';
import 'package:grove/domain/species.dart';
import 'package:grove/platform/session_alarm.dart';
import 'package:grove/state/garden_store.dart';
import 'package:grove/state/session_controller.dart';
import 'package:paper/paper.dart';

const AlarmCopy _copy = AlarmCopy(title: 'Time is up', body: 'Come back.');

/// Records what the store asked for, so the assertions can be about intent
/// rather than about a platform channel.
class RecordingAlarm implements SessionAlarm {
  final List<DateTime> armed = <DateTime>[];
  final List<AlarmCopy> copies = <AlarmCopy>[];
  int disarms = 0;
  int permissionRequests = 0;

  /// What the OS would answer. False is the interesting case: a refused
  /// permission must not change anything else the store does.
  bool granted = true;

  /// True while an alarm would be pending on the device.
  bool get isArmed => _pending;
  bool _pending = false;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> arm({required DateTime moment, required AlarmCopy copy}) async {
    armed.add(moment);
    copies.add(copy);
    _pending = true;
  }

  @override
  Future<void> disarm() async {
    disarms++;
    _pending = false;
  }
}

class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
  void advance(Duration by) => now = now.add(by);
}

({GardenStore store, FakeClock clock, RecordingAlarm alarm}) build({
  Map<String, String>? seed,
}) {
  final clock = FakeClock();
  final alarm = RecordingAlarm();
  var id = 0;
  final store = GardenStore(
    repository: GardenRepository(MemoryStore(seed)),
    controller: SessionController(
      clock: () => clock.now,
      idFactory: () => 'id-${id++}',
    ),
    clock: () => clock.now,
    alarm: alarm,
  );
  return (store: store, clock: clock, alarm: alarm);
}

Future<GardenStore> started(
  ({GardenStore store, FakeClock clock, RecordingAlarm alarm}) harness, {
  Duration planned = const Duration(minutes: 25),
}) async {
  await harness.store.initialize();
  await harness.store.startSession(species: Species.sprout, planned: planned);
  return harness.store;
}

void main() {
  group('arming', () {
    test('nothing is armed while the app is on screen', () async {
      final harness = build();
      await started(harness);

      expect(
        harness.alarm.armed,
        isEmpty,
        reason:
            'the countdown and the finish haptic already say the time is up, '
            'and Android cannot suppress a notification in the foreground',
      );
    });

    test('backgrounding a session arms it for the moment it ends', () async {
      final harness = build();
      await started(harness, planned: const Duration(minutes: 50));

      harness.clock.advance(const Duration(minutes: 3));
      await harness.store.onBackgrounded(alarm: _copy);

      expect(
        harness.alarm.armed.single,
        DateTime(2026, 10, 1, 9, 50),
        reason: 'the end of the session, not three minutes from now',
      );
      expect(harness.alarm.copies.single, _copy);
    });

    test('backgrounding with nothing running arms nothing', () async {
      final harness = build();
      await harness.store.initialize();

      await harness.store.onBackgrounded(alarm: _copy);

      expect(harness.alarm.armed, isEmpty);
    });

    test('an alarm needs copy, so a caller with no locale arms nothing',
        () async {
      final harness = build();
      await started(harness);

      await harness.store.onBackgrounded();

      expect(
        harness.alarm.armed,
        isEmpty,
        reason: 'this is what keeps every other test free of a plugin',
      );
    });

    test('the setting turns it off', () async {
      final harness = build();
      await started(harness);
      await harness.store.setNotify(false);

      await harness.store.onBackgrounded(alarm: _copy);

      expect(harness.alarm.armed, isEmpty);
    });

    test('leaving and returning twice replaces rather than stacks', () async {
      final harness = build();
      await started(harness, planned: const Duration(minutes: 50));

      await harness.store.onBackgrounded(alarm: _copy);
      await harness.store.onForegrounded();
      harness.clock.advance(const Duration(minutes: 1));
      await harness.store.onBackgrounded(alarm: _copy);

      expect(harness.alarm.armed, hasLength(2));
      expect(
        harness.alarm.armed.toSet(),
        hasLength(1),
        reason: 'both point at the same end, which never moved',
      );
      expect(harness.alarm.isArmed, isTrue);
    });
  });

  group('disarming', () {
    test('coming back drops the alarm', () async {
      final harness = build();
      await started(harness, planned: const Duration(minutes: 50));
      await harness.store.onBackgrounded(alarm: _copy);

      harness.clock.advance(const Duration(minutes: 5));
      await harness.store.onForegrounded();

      expect(harness.alarm.isArmed, isFalse);
    });

    test('a session killed by coming back cannot leave one behind', () async {
      // Strict mode: a long absence ends the session on return. The alarm
      // must go with it, or the phone announces a finish for a tree that is
      // already a stump.
      final harness = build();
      await started(harness, planned: const Duration(minutes: 50));
      await harness.store.onBackgrounded(alarm: _copy);

      harness.clock.advance(const Duration(minutes: 5));
      await harness.store.onForegrounded();

      expect(harness.store.sessions.single.isCompleted, isFalse);
      expect(harness.alarm.isArmed, isFalse);
    });

    test('a tick while away leaves the notification it already posted alone',
        () async {
      final harness = build();
      await started(harness, planned: const Duration(minutes: 25));
      await harness.store.onBackgrounded(alarm: _copy);

      // Android keeps Dart timers running while the activity is stopped, so
      // the tick that completes the session can land a second after the
      // notification was posted.
      harness.clock.advance(const Duration(minutes: 25));
      await harness.store.tick();

      expect(harness.store.controller.phase, SessionPhase.succeeded);
      expect(
        harness.alarm.disarms,
        0,
        reason: 'cancelling now would pull the banner back out of the shade '
            'before the user had a chance to see it',
      );
    });

    test('returning after it fired clears the stale banner', () async {
      final harness = build();
      await started(harness, planned: const Duration(minutes: 25));
      await harness.store.onBackgrounded(alarm: _copy);
      harness.clock.advance(const Duration(minutes: 25));
      await harness.store.tick();

      await harness.store.onForegrounded();

      expect(harness.alarm.isArmed, isFalse);
      expect(harness.alarm.disarms, 1);
    });

    test('nothing is armed to drop when a session ends on screen', () async {
      final harness = build();
      await started(harness, planned: const Duration(minutes: 50));

      await harness.store.giveUp();

      expect(harness.alarm.isArmed, isFalse);
      expect(harness.alarm.disarms, 0, reason: 'there was never anything to '
          'cancel, and a pointless platform call on every session is still a '
          'platform call');
    });

    test('switching the setting off drops a pending alarm', () async {
      final harness = build();
      await started(harness, planned: const Duration(minutes: 50));
      await harness.store.onBackgrounded(alarm: _copy);

      await harness.store.setNotify(false);

      expect(harness.alarm.isArmed, isFalse);
    });

    test('a session recovered at launch drops the alarm it left armed',
        () async {
      // The app went away mid-session with an alarm pending. Whatever that
      // session turned out to be, it is over by the time this resolves it.
      final harness = build(
        seed: <String, String>{
          'grove.garden.v1':
              '{"version":1,"sessions":[],"settings":{},'
              '"active":{"id":"gone","species":"sprout","plannedSeconds":3000,'
              '"startedAt":"2026-10-01T08:00:00.000"}}',
        },
      );
      await harness.store.initialize();

      expect(harness.store.recovered, isNotNull);
      expect(harness.alarm.disarms, greaterThan(0));
    });
  });

  group('permission', () {
    test('is asked for at the first session start, not at launch', () async {
      final harness = build();
      await harness.store.initialize();
      expect(harness.alarm.permissionRequests, 0);

      await harness.store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
      );
      // Requested without being awaited, so let the microtask run.
      await Future<void>.delayed(Duration.zero);

      expect(harness.alarm.permissionRequests, 1);
    });

    test('is not asked for when the setting is off', () async {
      final harness = build();
      await harness.store.initialize();
      await harness.store.setNotify(false);

      await harness.store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
      );
      await Future<void>.delayed(Duration.zero);

      expect(harness.alarm.permissionRequests, 0);
    });

    test('is asked for when the user switches the setting on', () async {
      final harness = build();
      await harness.store.initialize();
      await harness.store.setNotify(false);

      await harness.store.setNotify(true);

      expect(harness.alarm.permissionRequests, 1);
    });

    test('a refusal still leaves a working timer', () async {
      final harness = build();
      harness.alarm.granted = false;
      await started(harness, planned: const Duration(minutes: 25));

      harness.clock.advance(const Duration(minutes: 25));
      await harness.store.tick();

      expect(
        harness.store.sessions.single.isCompleted,
        isTrue,
        reason: 'a notification is a courtesy; the tree is the product',
      );
    });
  });

  group('the setting', () {
    test('defaults on, because the phone is meant to be face down', () {
      expect(const GroveSettings().notify, isTrue);
    });

    test('survives a round trip', () {
      final json = const GroveSettings(notify: false).toJson();
      expect(GroveSettings.fromJson(json).notify, isFalse);
    });

    test('reads as on in a file written before it existed', () {
      expect(
        GroveSettings.fromJson(<String, Object?>{'haptics': true}).notify,
        isTrue,
      );
    });
  });

  group('SilentAlarm', () {
    test('does nothing and promises nothing', () async {
      const alarm = SilentAlarm();
      expect(await alarm.requestPermission(), isFalse);
      await alarm.arm(moment: DateTime(2026), copy: _copy);
      await alarm.disarm();
    });
  });

  test('ActiveSession carries enough to know when to fire', () {
    // The alarm instant is derived rather than stored, so this is the one
    // place that pins the derivation down.
    final session = ActiveSession(
      id: 'a',
      species: Species.sprout,
      planned: const Duration(minutes: 50),
      startedAt: DateTime(2026, 10, 1, 9),
    );
    expect(
      session.startedAt.add(session.planned),
      DateTime(2026, 10, 1, 9, 50),
    );
  });
}
