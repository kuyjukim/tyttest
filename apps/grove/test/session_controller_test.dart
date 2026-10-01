import 'package:flutter_test/flutter_test.dart';
import 'package:grove/domain/session.dart';
import 'package:grove/domain/settings.dart';
import 'package:grove/domain/species.dart';
import 'package:grove/state/session_controller.dart';

/// A clock the test moves by hand, so a 25-minute session takes no time.
class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
  void advance(Duration by) => now = now.add(by);
}

void main() {
  late FakeClock clock;
  late SessionController controller;
  var nextId = 0;

  setUp(() {
    clock = FakeClock();
    nextId = 0;
    controller = SessionController(
      clock: () => clock.now,
      idFactory: () => 'id-${nextId++}',
    );
  });

  tearDown(() => controller.dispose());

  void start({Duration planned = const Duration(minutes: 25)}) {
    controller.start(species: Species.sprout, planned: planned);
  }

  group('start', () {
    test('moves to running and reports an untouched session', () {
      start();
      expect(controller.phase, SessionPhase.running);
      expect(controller.isRunning, isTrue);
      expect(controller.elapsed, Duration.zero);
      expect(controller.remaining, const Duration(minutes: 25));
      expect(controller.progress, 0);
      expect(controller.active!.id, 'id-0');
    });

    test('is ignored while a session is already running', () {
      start();
      final second = controller.start(
        species: Species.pine,
        planned: const Duration(minutes: 5),
      );
      expect(second, isNull);
      expect(controller.active!.species, Species.sprout);
    });

    test('clamps a duration outside the supported range', () {
      start(planned: const Duration(seconds: 30));
      expect(controller.active!.planned, GroveSettings.minDuration);

      controller.giveUp();
      controller.acknowledge();

      start(planned: const Duration(hours: 9));
      expect(controller.active!.planned, GroveSettings.maxDuration);
    });

    test('blank tags are dropped rather than stored as empty strings', () {
      controller.start(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
        tag: '   ',
      );
      expect(controller.active!.tag, isNull);

      controller.giveUp();
      controller.acknowledge();
      controller.start(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
        tag: '  thesis  ',
      );
      expect(controller.active!.tag, 'thesis');
    });
  });

  group('elapsed time', () {
    test('comes from the wall clock, not from how often tick is called', () {
      start();
      clock.advance(const Duration(minutes: 10));

      // One tick after ten minutes of silence - a throttled timer, a busy
      // frame, a sleeping device. The session must know it is 10 minutes in.
      expect(controller.tick(), isNull);
      expect(controller.elapsed, const Duration(minutes: 10));
      expect(controller.progress, closeTo(0.4, 1e-9));
      expect(controller.remaining, const Duration(minutes: 15));
    });

    test('does not run past the planned duration', () {
      start();
      clock.advance(const Duration(minutes: 40));
      expect(controller.elapsed, const Duration(minutes: 25));
      expect(controller.remaining, Duration.zero);
      expect(controller.progress, 1.0);
    });

    test('treats a backwards clock as no progress rather than negative', () {
      start();
      clock.advance(const Duration(minutes: -5));
      expect(controller.elapsed, Duration.zero);
      expect(controller.progress, 0);
    });

    test('is zero when idle', () {
      expect(controller.elapsed, Duration.zero);
      expect(controller.progress, 0);
      expect(controller.remaining, Duration.zero);
    });
  });

  group('completion', () {
    test('tick finishes the session once the planned time has passed', () {
      start();
      clock.advance(const Duration(minutes: 24, seconds: 59));
      expect(controller.tick(), isNull, reason: 'one second short');

      clock.advance(const Duration(seconds: 1));
      final finished = controller.tick();

      expect(finished, isNotNull);
      expect(finished!.outcome, SessionOutcome.completed);
      expect(finished.elapsed, const Duration(minutes: 25));
      expect(controller.phase, SessionPhase.succeeded);
      expect(controller.active, isNull);
      expect(controller.result, same(finished));
    });

    test('credits exactly the planned time even when the tick is late', () {
      start();
      clock.advance(const Duration(minutes: 31));
      final finished = controller.tick()!;
      expect(
        finished.elapsed,
        const Duration(minutes: 25),
        reason: 'a late tick must not inflate the session',
      );
    });

    test('a further tick after finishing does nothing', () {
      start();
      clock.advance(const Duration(minutes: 25));
      controller.tick();
      expect(controller.tick(), isNull);
      expect(controller.phase, SessionPhase.succeeded);
    });
  });

  group('giving up', () {
    test('records the partial time and fails the session', () {
      start();
      clock.advance(const Duration(minutes: 7));
      final result = controller.giveUp()!;

      expect(result.outcome, SessionOutcome.abandoned);
      expect(result.elapsed, const Duration(minutes: 7));
      expect(result.completion, closeTo(7 / 25, 1e-9));
      expect(controller.phase, SessionPhase.failed);
      expect(controller.failureReason, FailureReason.gaveUp);
    });

    test('is a no-op when nothing is running', () {
      expect(controller.giveUp(), isNull);
      expect(controller.phase, SessionPhase.idle);
    });

    test('there is no pause - the only exits are finishing and giving up', () {
      final api = controller.runtimeType.toString();
      expect(api, 'SessionController');
      // Guard against a future "pause" sneaking in: the public surface is
      // asserted by the absence of state between running and ended.
      expect(SessionPhase.values, [
        SessionPhase.idle,
        SessionPhase.running,
        SessionPhase.succeeded,
        SessionPhase.failed,
      ]);
    });
  });

  group('backgrounding', () {
    test('strict mode kills a session left for longer than the allowance', () {
      start();
      clock.advance(const Duration(minutes: 5));
      controller.onBackgrounded();
      clock.advance(SessionController.backgroundAllowance + const Duration(seconds: 1));

      final result = controller.onForegrounded(strict: true)!;

      expect(result.outcome, SessionOutcome.abandoned);
      expect(controller.failureReason, FailureReason.leftApp);
    });

    test('strict mode forgives a glance shorter than the allowance', () {
      start();
      clock.advance(const Duration(minutes: 5));
      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 10));

      expect(controller.onForegrounded(strict: true), isNull);
      expect(controller.phase, SessionPhase.running);
      expect(controller.elapsed, const Duration(minutes: 5, seconds: 10));
    });

    test('lenient mode credits time spent away', () {
      start();
      controller.onBackgrounded();
      clock.advance(const Duration(minutes: 26));

      final result = controller.onForegrounded(strict: false)!;

      expect(result.outcome, SessionOutcome.completed);
      expect(result.elapsed, const Duration(minutes: 25));
    });

    test('repeated background events keep the first departure time', () {
      start();
      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 15));
      controller.onBackgrounded();
      clock.advance(const Duration(seconds: 10));

      expect(
        controller.onForegrounded(strict: true),
        isNotNull,
        reason: '25s away in total exceeds the 20s allowance',
      );
    });

    test('a foreground event with no prior background is harmless', () {
      start();
      clock.advance(const Duration(minutes: 1));
      expect(controller.onForegrounded(strict: true), isNull);
      expect(controller.phase, SessionPhase.running);
    });

    test('lifecycle events while idle are ignored', () {
      controller.onBackgrounded();
      expect(controller.onForegrounded(strict: true), isNull);
      expect(controller.phase, SessionPhase.idle);
    });

    test('a new session starts with a clean background record', () {
      start();
      controller.onBackgrounded();
      controller.giveUp();
      controller.acknowledge();

      start();
      clock.advance(const Duration(minutes: 1));
      expect(
        controller.onForegrounded(strict: true),
        isNull,
        reason: 'the previous session\'s departure must not carry over',
      );
      expect(controller.phase, SessionPhase.running);
    });
  });

  group('acknowledge', () {
    test('returns to idle and clears the result', () {
      start();
      clock.advance(const Duration(minutes: 25));
      controller.tick();

      controller.acknowledge();

      expect(controller.phase, SessionPhase.idle);
      expect(controller.result, isNull);
      expect(controller.failureReason, isNull);
    });

    test('cannot be used to escape a running session', () {
      start();
      controller.acknowledge();
      expect(controller.phase, SessionPhase.running);
    });
  });

  group('notifications', () {
    test('fire on every state change the UI must redraw for', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      start();
      expect(notifications, 1);

      clock.advance(const Duration(minutes: 1));
      controller.tick();
      expect(notifications, 2, reason: 'a tick repaints the countdown');

      controller.giveUp();
      expect(notifications, 3);

      controller.acknowledge();
      expect(notifications, 4);
    });
  });
}
