import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkwell/app.dart';
import 'package:inkwell/crypto/kdf.dart';
import 'package:inkwell/data/vault_repository.dart';
import 'package:inkwell/domain/prefs.dart';
import 'package:inkwell/state/vault_store.dart';
import 'package:paper/paper.dart';

class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
}

/// Cheap KDF: the real cost would add a second to every unlock here.
KdfParams cheapKdf() => KdfParams(
  salt: KdfParams.randomBytes(16),
  iterations: 1,
  memoryKib: 64,
  lanes: 1,
);

class Harness {
  Harness({Map<String, String>? seed})
    : clock = FakeClock(),
      raw = MemoryStore(seed) {
    var id = 0;
    store = VaultStore(
      repository: VaultRepository(raw),
      clock: () => clock.now,
      idFactory: () => 'entry-${(id++).toString().padLeft(4, '0')}',
      kdfFactory: cheapKdf,
      // Synchronous: a widget test's fake-async zone never delivers an
      // isolate's reply, so the offloaded path would hang here.
      deriveKey: (passphrase, params) async =>
          Kdf.deriveSync(passphrase, params),
    );
  }

  final FakeClock clock;
  final MemoryStore raw;
  late final VaultStore store;
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  Map<String, String>? seed,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = Harness(seed: seed);
  await harness.store.initialize();
  await tester.pumpWidget(InkwellApp(store: harness.store, locale: locale));
  await tester.pumpAndSettle();
  return harness;
}

/// Pumps frames until [done] or the budget runs out.
///
/// Needed wherever a button is in its busy state: the spinner is an
/// indefinite animation, so `pumpAndSettle` has nothing to settle to and
/// times out instead.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  int maxFrames = 400,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (done()) break;
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

/// Creates a vault through the UI, leaving the app unlocked.
Future<void> createVault(
  WidgetTester tester,
  Harness harness, {
  String passphrase = 'tuesday afternoon rain',
}) async {
  await tester.enterText(find.byType(TextField).first, passphrase);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, passphrase);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Create journal'));
  await pumpUntil(tester, () => harness.store.isUnlocked);
}

/// Types a passphrase on the unlock screen and waits for the attempt to land.
Future<void> attemptUnlock(
  WidgetTester tester,
  Harness harness,
  String passphrase, {
  String action = 'Unlock',
}) async {
  final failuresBefore = harness.store.failedAttempts;
  await tester.enterText(find.byType(TextField).first, passphrase);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await pumpUntil(
    tester,
    () =>
        harness.store.isUnlocked ||
        harness.store.failedAttempts != failuresBefore,
  );
}

Future<void> writeEntry(
  WidgetTester tester, {
  required String title,
  required String body,
}) async {
  // An empty journal shows its empty state's call to action; once there are
  // entries the compose button sits at the bottom of the list.
  final compose = find.text('New entry').evaluate().isEmpty
      ? find.text('Write something')
      : find.text('New entry').last;
  await tester.tap(compose);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, title);
  await tester.enterText(find.byType(TextField).at(1), body);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PaperButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  group('creating a vault', () {
    testWidgets('opens on the create screen with the no-recovery warning',
        (tester) async {
      await pumpApp(tester);

      expect(find.text('Choose a passphrase'), findsOneWidget);
      expect(find.textContaining('no reset and no recovery'), findsOneWidget);
      expect(find.text('Create journal'), findsOneWidget);
    });

    testWidgets('refuses a short passphrase', (tester) async {
      final harness = await pumpApp(tester);

      await tester.enterText(find.byType(TextField).first, 'short');
      await tester.pumpAndSettle();
      expect(find.text('Too short'), findsOneWidget);

      await tester.tap(find.text('Create journal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('At least 10 characters'), findsOneWidget);
      expect(harness.store.status, VaultStatus.absent);
    });

    testWidgets('refuses a mismatched confirmation', (tester) async {
      final harness = await pumpApp(tester);

      await tester.enterText(find.byType(TextField).first, 'a long passphrase');
      await tester.enterText(find.byType(TextField).last, 'a different one');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create journal'));
      await tester.pumpAndSettle();

      expect(find.text('The two entries do not match.'), findsOneWidget);
      expect(harness.store.status, VaultStatus.absent);
    });

    testWidgets('rates a strong passphrase and creates the journal',
        (tester) async {
      final harness = await pumpApp(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'tuesday afternoon rain',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Good'),
        findsOneWidget,
        reason: 'three common words rate as good, not strong - length is '
            'doing the work and the estimator says so honestly',
      );

      await tester.enterText(
        find.byType(TextField).last,
        'tuesday afternoon rain',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create journal'));
      await pumpUntil(tester, () => harness.store.isUnlocked);

      expect(harness.store.status, VaultStatus.unlocked);
      expect(find.text('Nothing written yet'), findsOneWidget);
    });
  });

  group('unlocking', () {
    testWidgets('a wrong passphrase shows an error and keeps the vault shut',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      harness.store.lock();
      await tester.pumpAndSettle();

      expect(find.text('Unlock your journal'), findsOneWidget);

      await attemptUnlock(tester, harness, 'wrong guess here');

      expect(find.textContaining('did not open the journal'), findsOneWidget);
      expect(find.text('1 failed attempt'), findsOneWidget);
      expect(harness.store.status, VaultStatus.locked);
    });

    testWidgets('the right passphrase gets the entries back', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await writeEntry(tester, title: 'Monday', body: 'it rained all day');
      harness.store.lock();
      await tester.pumpAndSettle();

      await attemptUnlock(tester, harness, 'tuesday afternoon rain');

      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('it rained all day'), findsOneWidget);
    });

    testWidgets('too many attempts lock the button and show a countdown',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      harness.store.lock();
      await tester.pumpAndSettle();

      for (var i = 0; i <= AttemptRecord.freeAttempts; i++) {
        await attemptUnlock(tester, harness, 'wrong guess $i');
      }

      expect(find.textContaining('Too many attempts'), findsOneWidget);
      final button = tester.widget<PaperButton>(
        find.widgetWithText(PaperButton, 'Unlock'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('writing', () {
    testWidgets('an entry appears in the timeline and on disk, encrypted',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);

      await writeEntry(
        tester,
        title: 'A private thought',
        body: 'something I would not want read',
      );

      expect(find.text('A private thought'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      final onDisk = harness.raw.snapshot[VaultRepository.vaultKey]!;
      expect(onDisk, isNot(contains('private thought')));
      expect(onDisk, isNot(contains('would not want read')));
    });

    testWidgets('the save button stays disabled for an empty entry',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Write something'));
      await tester.pumpAndSettle();

      final button = tester.widget<PaperButton>(
        find.widgetWithText(PaperButton, 'Save'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a mood can be picked and unpicked', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Write something'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'a day');
      await tester.tap(find.text('Great'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.store.entries.single.mood?.name, 'great');

      await tester.tap(find.text('a day'));
      await tester.pumpAndSettle();
      // Tapping the selected mood again clears it.
      await tester.tap(find.text('Great'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.store.entries.single.mood, isNull);
    });

    testWidgets('tags are added and shown on the row', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Write something'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'tagged entry');
      await tester.enterText(find.widgetWithText(TextField, 'Add a tag'), 'work');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.store.entries.single.tags, <String>['work']);
      expect(find.text('#work'), findsOneWidget);
    });

    testWidgets('leaving a dirty editor asks before discarding',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Write something'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'half a thought');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(harness.store.entries, isEmpty);
    });

    testWidgets('an entry can be edited and deleted', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await writeEntry(tester, title: 'Draft', body: 'first pass');

      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Finished');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Finished'), findsOneWidget);
      expect(harness.store.entries, hasLength(1));

      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(harness.store.entries, isEmpty);
      expect(find.text('Nothing written yet'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters the timeline and clears again', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await writeEntry(tester, title: 'Rainy day', body: 'puddles');
      await writeEntry(tester, title: 'Sunny day', body: 'warm');

      await tester.enterText(
        find.widgetWithText(TextField, 'Search entries'),
        'rain',
      );
      await tester.pumpAndSettle();

      expect(find.text('Rainy day'), findsOneWidget);
      expect(find.text('Sunny day'), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sunny day'), findsOneWidget);
    });
  });

  group('insights', () {
    testWidgets('show counts, the streak and the mood mix', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await writeEntry(tester, title: 'One', body: 'two three four five');

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Entries'), findsOneWidget);
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('4'), findsWidgets, reason: 'four words');
    });
  });

  group('settings', () {
    testWidgets('lock now returns to the lock screen', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);

      await tester.tap(find.byIcon(Icons.lock_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Unlock your journal'), findsOneWidget);
    });

    testWidgets('auto-lock can be changed and persists in plaintext',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Auto-lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('When I leave the app'));
      await tester.pumpAndSettle();

      expect(harness.store.prefs.autoLock, Duration.zero);
      expect(
        harness.raw.snapshot[VaultRepository.prefsKey],
        contains('autoLockSeconds'),
      );
    });

    testWidgets('changing the passphrase re-seals the journal',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await writeEntry(tester, title: 'Kept', body: 'through the change');

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change passphrase'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Current passphrase'),
        'tuesday afternoon rain',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'New passphrase'),
        'a completely different phrase',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Change'));
      await pumpUntil(tester, () => find.text('Change').evaluate().isEmpty);

      expect(find.text('Passphrase changed'), findsOneWidget);

      harness.store.lock();
      await tester.pumpAndSettle();
      await attemptUnlock(tester, harness, 'a completely different phrase');
      expect(find.text('Kept'), findsOneWidget);
    });

    testWidgets('a wrong current passphrase is refused', (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change passphrase'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Current passphrase'),
        'not the passphrase',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'New passphrase'),
        'a completely different phrase',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Change'));
      await pumpUntil(
        tester,
        () => find.textContaining('did not open the journal').evaluate().isNotEmpty,
      );

      expect(find.textContaining('did not open the journal'), findsOneWidget);
    });

    testWidgets('deleting the journal returns to the create screen',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await writeEntry(tester, title: 'Doomed', body: 'soon gone');

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete the journal'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete the journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything').last);
      await tester.pumpAndSettle();

      expect(find.text('Choose a passphrase'), findsOneWidget);
      expect(harness.raw.snapshot[VaultRepository.vaultKey], isNull);
    });

    testWidgets('the biometrics decision is explained rather than hidden',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('no Face ID unlock'),
        findsOneWidget,
        reason: 'a missing security feature should say why it is missing',
      );
    });
  });

  group('localisation', () {
    testWidgets('runs in Korean from the lock screen onwards', (tester) async {
      final harness = await pumpApp(tester, locale: const Locale('ko'));

      expect(find.text('암호문구를 정하세요'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '열려라 참깨 보물창고');
      await tester.enterText(find.byType(TextField).last, '열려라 참깨 보물창고');
      await tester.pumpAndSettle();
      await tester.tap(find.text('일기 만들기'));
      await pumpUntil(tester, () => harness.store.isUnlocked);

      expect(find.text('아직 쓴 글이 없습니다'), findsOneWidget);
    });
  });

  group('theme', () {
    testWidgets('the lock screen already uses the stored dark theme',
        (tester) async {
      final harness = await pumpApp(tester);
      await createVault(tester, harness);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      harness.store.lock();
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Unlock'));
      expect(
        context.colors.isDark,
        isTrue,
        reason: 'the theme is readable before the vault is open',
      );
    });
  });
}
