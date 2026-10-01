import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grove/data/garden_repository.dart';
import 'package:grove/domain/active_session.dart';
import 'package:grove/domain/day.dart';
import 'package:grove/domain/session.dart';
import 'package:grove/domain/settings.dart';
import 'package:grove/domain/species.dart';
import 'package:grove/domain/stats.dart';
import 'package:grove/state/garden_store.dart';
import 'package:grove/state/session_controller.dart';
import 'package:paper/paper.dart';

const _key = 'grove.garden.v1';

class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
  void advance(Duration by) => now = now.add(by);
}

({GardenStore store, FakeClock clock, MemoryStore raw}) build({
  Map<String, String>? seed,
}) {
  final clock = FakeClock();
  final raw = MemoryStore(seed);
  var id = 0;
  final store = GardenStore(
    repository: GardenRepository(raw),
    controller: SessionController(
      clock: () => clock.now,
      idFactory: () => 'id-${id++}',
    ),
    clock: () => clock.now,
  );
  return (store: store, clock: clock, raw: raw);
}

String persisted({
  List<FocusSession> sessions = const <FocusSession>[],
  ActiveSession? active,
  GroveSettings settings = const GroveSettings(),
}) => jsonEncode(<String, Object?>{
  'version': 1,
  'sessions': [for (final s in sessions) s.toJson()],
  'settings': settings.toJson(),
  if (active != null) 'active': active.toJson(),
});

void main() {
  group('initialize', () {
    test('starts empty on a fresh install', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();

      expect(store.ready, isTrue);
      expect(store.sessions, isEmpty);
      expect(store.streak, Streak.none);
      expect(store.unlockedSpecies, [Species.sprout]);
      expect(store.recovered, isNull);
    });

    test('opens anyway when the stored file is corrupt', () async {
      final (store: store, clock: _, raw: _) = build(
        seed: {_key: 'this is not json'},
      );
      await store.initialize();

      expect(store.ready, isTrue, reason: 'a bad file must not lock the user out');
      expect(store.sessions, isEmpty);
    });

    test('keeps the readable records when one is unreadable', () async {
      final good = FocusSession(
        id: 'good',
        species: Species.pine,
        planned: const Duration(minutes: 25),
        startedAt: DateTime(2026, 9, 30, 10),
        elapsed: const Duration(minutes: 25),
        outcome: SessionOutcome.completed,
      );
      final payload = jsonEncode(<String, Object?>{
        'version': 1,
        'sessions': <Object?>[
          good.toJson(),
          <String, Object?>{'id': 'broken'}, // missing required fields
          'not even a map',
        ],
        'settings': const GroveSettings().toJson(),
      });

      final (store: store, clock: _, raw: _) = build(seed: {_key: payload});
      await store.initialize();

      expect(store.sessions.map((s) => s.id), ['good']);
    });
  });

  group('recovery of an interrupted session', () {
    test('strict mode records a force-quit as abandoned', () async {
      final active = ActiveSession(
        id: 'interrupted',
        species: Species.pine,
        planned: const Duration(minutes: 50),
        startedAt: DateTime(2026, 10, 1, 8, 30),
      );
      final (store: store, clock: clock, raw: raw) = build(
        seed: {_key: persisted(active: active)},
      );
      // The clock says 9:00, so 30 of the 50 minutes had passed.
      await store.initialize();

      expect(store.sessions, hasLength(1));
      final recovered = store.sessions.single;
      expect(recovered.outcome, SessionOutcome.abandoned);
      expect(recovered.elapsed, const Duration(minutes: 30));
      expect(store.recovered, isNotNull);
      expect(store.controller.phase, SessionPhase.failed);
      expect(store.controller.failureReason, FailureReason.appClosed);
      expect(clock.now.hour, 9);

      // And the in-flight marker is gone, so it cannot resolve twice.
      final reread = await GardenRepository(raw).load();
      expect(reread.active, isNull);
      expect(reread.sessions, hasLength(1));
    });

    test('lenient mode credits a session whose time fully elapsed', () async {
      final active = ActiveSession(
        id: 'interrupted',
        species: Species.pine,
        planned: const Duration(minutes: 25),
        startedAt: DateTime(2026, 10, 1, 8),
      );
      final (store: store, clock: _, raw: _) = build(
        seed: {
          _key: persisted(
            active: active,
            settings: const GroveSettings(strict: false),
          ),
        },
      );
      await store.initialize();

      expect(store.sessions.single.outcome, SessionOutcome.completed);
      expect(store.controller.phase, SessionPhase.succeeded);
    });

    test('lenient mode still fails a session cut short', () async {
      final active = ActiveSession(
        id: 'interrupted',
        species: Species.pine,
        planned: const Duration(minutes: 50),
        startedAt: DateTime(2026, 10, 1, 8, 50),
      );
      final (store: store, clock: _, raw: _) = build(
        seed: {
          _key: persisted(
            active: active,
            settings: const GroveSettings(strict: false),
          ),
        },
      );
      await store.initialize();

      expect(store.sessions.single.outcome, SessionOutcome.abandoned);
      expect(store.sessions.single.elapsed, const Duration(minutes: 10));
    });

    test('a clock that moved backwards credits nothing, not negative time',
        () async {
      final active = ActiveSession(
        id: 'interrupted',
        species: Species.pine,
        planned: const Duration(minutes: 25),
        startedAt: DateTime(2026, 10, 1, 10),
      );
      final (store: store, clock: _, raw: _) = build(
        seed: {_key: persisted(active: active)},
      );
      await store.initialize();

      expect(store.sessions.single.elapsed, Duration.zero);
      expect(store.sessions.single.outcome, SessionOutcome.abandoned);
    });
  });

  group('running a session end to end', () {
    test('marks the session in flight as soon as it starts', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();

      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
        tag: 'thesis',
      );

      final onDisk = await GardenRepository(raw).load();
      expect(
        onDisk.active,
        isNotNull,
        reason: 'force-quitting must not be a way to dodge a withered tree',
      );
      expect(onDisk.active!.tag, 'thesis');
      expect(onDisk.sessions, isEmpty);
    });

    test('completing persists the tree and clears the in-flight marker',
        () async {
      final (store: store, clock: clock, raw: raw) = build();
      await store.initialize();
      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
      );

      clock.advance(const Duration(minutes: 25));
      await store.tick();

      expect(store.controller.phase, SessionPhase.succeeded);
      final onDisk = await GardenRepository(raw).load();
      expect(onDisk.active, isNull);
      expect(onDisk.sessions.single.outcome, SessionOutcome.completed);
      expect(store.totalFocusedMinutes, 25);
      expect(store.streak.current, 1);
      expect(store.todayTotal.focused, const Duration(minutes: 25));
    });

    test('giving up persists the failure too', () async {
      final (store: store, clock: clock, raw: raw) = build();
      await store.initialize();
      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
      );

      clock.advance(const Duration(minutes: 4));
      await store.giveUp();

      final onDisk = await GardenRepository(raw).load();
      expect(onDisk.sessions.single.outcome, SessionOutcome.abandoned);
      expect(store.totalFocusedMinutes, 0, reason: 'failures earn nothing');
      expect(store.streak.current, 0);
    });

    test('remembers the duration and species chosen last time', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();

      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 45),
      );
      clock.advance(const Duration(minutes: 45));
      await store.tick();

      expect(store.settings.defaultDuration, const Duration(minutes: 45));
      expect(store.settings.preferredSpecies, Species.sprout);
    });

    test('recording the same id twice does not duplicate the tree', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
      );
      clock.advance(const Duration(minutes: 25));

      await store.tick();
      await store.tick();

      expect(store.sessions, hasLength(1));
    });

    test('backgrounding in strict mode kills the run and persists it',
        () async {
      final (store: store, clock: clock, raw: raw) = build();
      await store.initialize();
      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
      );

      store.onBackgrounded();
      clock.advance(const Duration(minutes: 3));
      await store.onForegrounded();

      expect(store.controller.failureReason, FailureReason.leftApp);
      final onDisk = await GardenRepository(raw).load();
      expect(onDisk.sessions.single.outcome, SessionOutcome.abandoned);
      expect(onDisk.active, isNull);
    });
  });

  group('derived state', () {
    test('goal progress saturates at the goal and never divides by zero',
        () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      await store.updateSettings(
        store.settings.copyWith(dailyGoal: const Duration(minutes: 30)),
      );

      expect(store.goalProgress, 0);

      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 60),
      );
      clock.advance(const Duration(minutes: 60));
      await store.tick();

      expect(store.goalProgress, 1.0);

      await store.updateSettings(
        store.settings.copyWith(dailyGoal: Duration.zero),
      );
      expect(store.goalProgress, 1.0);
    });

    test('unlocks advance with lifetime completed minutes', () async {
      final sessions = <FocusSession>[
        for (var i = 0; i < 5; i++)
          FocusSession(
            id: 's$i',
            species: Species.sprout,
            planned: const Duration(minutes: 25),
            startedAt: DateTime(2026, 9, 20 + i, 10),
            elapsed: const Duration(minutes: 25),
            outcome: SessionOutcome.completed,
          ),
      ];
      final (store: store, clock: _, raw: _) = build(
        seed: {_key: persisted(sessions: sessions)},
      );
      await store.initialize();

      expect(store.totalFocusedMinutes, 125);
      expect(store.unlockedSpecies, [Species.sprout, Species.pine]);
      expect(store.nextUnlock, Species.maple);
    });

    test('today is read from the injected clock', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      expect(store.today, const Day(2026, 10, 1));

      clock.advance(const Duration(days: 1));
      expect(store.today, const Day(2026, 10, 2));
    });
  });

  group('clearGarden', () {
    test('removes every session but keeps settings', () async {
      final (store: store, clock: clock, raw: raw) = build();
      await store.initialize();
      await store.updateSettings(store.settings.copyWith(strict: false));
      await store.startSession(
        species: Species.sprout,
        planned: const Duration(minutes: 25),
      );
      clock.advance(const Duration(minutes: 25));
      await store.tick();
      expect(store.sessions, hasLength(1));

      await store.clearGarden();

      expect(store.sessions, isEmpty);
      expect(store.settings.strict, isFalse);
      final onDisk = await GardenRepository(raw).load();
      expect(onDisk.sessions, isEmpty);
      expect(onDisk.settings.strict, isFalse);
    });
  });

  group('settings persistence', () {
    test('survives a reload, including out-of-range stored values', () async {
      final raw = MemoryStore({
        _key: jsonEncode(<String, Object?>{
          'version': 1,
          'sessions': <Object?>[],
          'settings': <String, Object?>{
            'themeMode': 'dark',
            'strict': false,
            'defaultMinutes': '45',
            'dailyGoalMinutes': 99999,
            'species': 'nonexistent',
            'haptics': false,
          },
        }),
      });
      final data = await GardenRepository(raw).load();

      expect(data.settings.defaultDuration, const Duration(minutes: 45));
      expect(
        data.settings.dailyGoal.inMinutes,
        lessThanOrEqualTo(960),
        reason: 'a hand-edited file must not produce an absurd goal',
      );
      expect(data.settings.preferredSpecies, Species.sprout);
      expect(data.settings.strict, isFalse);
    });
  });
}
