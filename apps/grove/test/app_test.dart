import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grove/app.dart';
import 'package:grove/data/garden_repository.dart';
import 'package:grove/domain/active_session.dart';
import 'package:grove/domain/session.dart';
import 'package:grove/domain/settings.dart';
import 'package:grove/domain/species.dart';
import 'package:grove/state/garden_store.dart';
import 'package:grove/state/session_controller.dart';
import 'package:grove/ui/widgets/duration_dial.dart';
import 'package:grove/ui/widgets/tree_view.dart';
import 'package:paper/paper.dart';

const _key = 'grove.garden.v1';

class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
}

class Harness {
  Harness({Map<String, String>? seed})
    : clock = FakeClock(),
      raw = MemoryStore(seed) {
    var id = 0;
    store = GardenStore(
      repository: GardenRepository(raw),
      controller: SessionController(
        clock: () => clock.now,
        idFactory: () => 'id-${id++}',
      ),
      clock: () => clock.now,
    );
  }

  final FakeClock clock;
  final MemoryStore raw;
  late final GardenStore store;

  /// Moves the injected clock and the test's own timers together, so the
  /// per-second ticker sees the same passage of time the session does.
  ///
  /// Deliberately `pump`, never `pumpAndSettle`: while a session runs the
  /// tree is swaying on a repeating animation, so there is nothing to settle
  /// to and `pumpAndSettle` would spin until it timed out.
  Future<void> advance(WidgetTester tester, Duration by) async {
    clock.now = clock.now.add(by);
    await tester.pump(by);
    await frames(tester);
  }
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  Map<String, String>? seed,
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
}) async {
  if (reduceMotion) {
    // The reduced-motion signal has to come from the platform dispatcher, not
    // from a MediaQuery wrapped around the app: MaterialApp builds its own
    // MediaQuery from the view, so an outer one would be discarded.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  // A real phone, not the 800x600 default: the focus screen is designed to
  // fit a session's controls without scrolling, and a test that has to scroll
  // to reach the Start button is not testing the screen users see.
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = Harness(seed: seed);
  await harness.store.initialize();
  await tester.pumpWidget(GroveApp(store: harness.store, locale: locale));
  await tester.pumpAndSettle();
  return harness;
}

/// Pumps a few frames without waiting for quiescence.
Future<void> frames(WidgetTester tester, [int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
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
  group('first run', () {
    testWidgets('opens on the dial with the default duration', (tester) async {
      await pumpApp(tester);

      expect(find.byType(DurationDial), findsOneWidget);
      expect(find.text('25m'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(
        find.text('Leaving the app will kill the tree.'),
        findsOneWidget,
        reason: 'strict mode is on by default and should say so',
      );
    });

    testWidgets('the garden tab shows its empty state and routes back',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Garden'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planted yet'), findsOneWidget);

      await tester.tap(find.text('Start focusing'));
      await tester.pumpAndSettle();
      expect(find.byType(DurationDial), findsOneWidget);
    });

    testWidgets('only the starter species is offered', (tester) async {
      await pumpApp(tester);
      expect(find.text('Sprout'), findsWidgets);
      expect(find.text('Pine'), findsNothing);
      expect(
        find.bySemanticsLabel('Unlocks at 2h of focus'),
        findsOneWidget,
        reason: 'the locked chip shows only the threshold, but says why',
      );
    });
  });

  group('running a session', () {
    testWidgets('counts down, grows a tree, then plants it', (tester) async {
      final harness = await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'thesis');
      await tester.tap(find.text('Start'));
      await frames(tester);

      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('thesis'), findsOneWidget);
      expect(find.text('Give up'), findsOneWidget);
      expect(find.byType(TreeView), findsOneWidget);

      await harness.advance(tester, const Duration(minutes: 10));
      expect(find.text('15:00'), findsOneWidget);
      expect(harness.store.controller.progress, closeTo(0.4, 1e-9));

      await harness.advance(tester, const Duration(minutes: 15));

      expect(find.text('Planted'), findsOneWidget);
      expect(find.text('Your tree is in the garden for good.'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(DurationDial), findsOneWidget);
    });

    testWidgets('the planted tree appears in the garden', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await frames(tester);
      await harness.advance(tester, const Duration(minutes: 25));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Garden'));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('1 planted'), findsOneWidget);
    });

    testWidgets('giving up asks first and leaves a withered tree',
        (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await frames(tester);
      await harness.advance(tester, const Duration(minutes: 5));

      await tester.tap(find.text('Give up'));
      await frames(tester, 20);
      expect(find.text('Let this tree die?'), findsOneWidget);

      // Backing out of the dialog must not end the session.
      await tester.tap(find.text('Cancel'));
      await frames(tester, 20);
      expect(harness.store.controller.isRunning, isTrue);

      await tester.tap(find.text('Give up'));
      await frames(tester, 20);
      await tester.tap(find.widgetWithText(PaperButton, 'Give up').last);
      await tester.pumpAndSettle();

      expect(find.text('It withered'), findsOneWidget);
      expect(find.text('You ended the session early.'), findsOneWidget);
      expect(find.text('Got 20% of the way · 5m'), findsOneWidget);
    });

    testWidgets('the dial is read-only while a session runs', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('Start'));
      await frames(tester);

      final dial = tester.widget<DurationDial>(find.byType(DurationDial));
      expect(dial.onChanged, isNull);
      expect(dial.progress, isNotNull);

      await harness.store.giveUp();
      await tester.pumpAndSettle();
    });
  });

  group('recovering an interrupted session', () {
    testWidgets('explains the tree the user did not watch die', (tester) async {
      final active = ActiveSession(
        id: 'interrupted',
        species: Species.sprout,
        planned: const Duration(minutes: 50),
        startedAt: DateTime(2026, 10, 1, 8, 30),
      );
      await pumpApp(tester, seed: {_key: persisted(active: active)});

      expect(find.text('It withered'), findsOneWidget);
      expect(
        find.text('The app stopped running before the timer ended.'),
        findsOneWidget,
      );
    });
  });

  group('stats', () {
    testWidgets('are empty until a session exists, then show the numbers',
        (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(
        find.text('Finish a session to see your numbers here.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Focus'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'reading');
      await tester.tap(find.text('Start'));
      await frames(tester);
      await harness.advance(tester, const Duration(minutes: 25));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      // Only the peak column is labelled, and today is the only non-zero day.
      expect(find.text('25m'), findsWidgets);
      // The tag breakdown ranks what was focused on, directly labelled.
      expect(find.text('reading'), findsOneWidget);

      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('settings', () {
    testWidgets('strict mode can be switched off and persists', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Strict mode'));
      await tester.pumpAndSettle();

      expect(harness.store.settings.strict, isFalse);
      final onDisk = await GardenRepository(harness.raw).load();
      expect(onDisk.settings.strict, isFalse);

      await tester.tap(find.text('Focus'));
      await tester.pumpAndSettle();
      expect(
        find.text('You can leave the app; the timer keeps going.'),
        findsOneWidget,
      );
    });

    testWidgets('switching to dark mode repaints on the dark surface',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Dark'));
      expect(context.colors.isDark, isTrue);
    });

    testWidgets('clearing the garden requires confirmation', (tester) async {
      final session = FocusSession(
        id: 'old',
        species: Species.sprout,
        planned: const Duration(minutes: 25),
        startedAt: DateTime(2026, 9, 30, 10),
        elapsed: const Duration(minutes: 25),
        outcome: SessionOutcome.completed,
      );
      final harness = await pumpApp(
        tester,
        seed: {_key: persisted(sessions: <FocusSession>[session])},
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      // The danger zone is at the bottom of a long settings list, which is
      // where it belongs.
      await tester.scrollUntilVisible(
        find.text('Delete every tree'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete every tree'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(harness.store.sessions, hasLength(1));

      await tester.tap(find.text('Delete every tree'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();

      expect(harness.store.sessions, isEmpty);
      expect(find.text('Garden cleared'), findsOneWidget);
    });
  });

  group('accessibility and localisation', () {
    testWidgets('runs in Korean end to end', (tester) async {
      final harness = await pumpApp(tester, locale: const Locale('ko'));

      expect(find.text('집중'), findsWidgets);
      expect(find.text('시작'), findsOneWidget);
      expect(find.text('25분'), findsOneWidget);

      await tester.tap(find.text('시작'));
      await frames(tester);
      await harness.advance(tester, const Duration(minutes: 25));

      expect(find.text('심었습니다'), findsOneWidget);
    });

    testWidgets('the tree is drawn perfectly still under reduced motion',
        (tester) async {
      final harness = await pumpApp(tester, reduceMotion: true);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // With the breeze suppressed there is no repeating animation left, so
      // pumpAndSettle terminates instead of timing out.
      expect(find.byType(TreeView), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);

      await harness.store.giveUp();
      await tester.pumpAndSettle();
    });

    testWidgets('the dial is a semantic slider with adjust actions',
        (tester) async {
      await pumpApp(tester);
      final node = tester.getSemantics(find.byType(DurationDial));
      expect(node.value, '25m');
      expect(node.increasedValue, '30m');
      expect(node.decreasedValue, '20m');
    });
  });
}
