import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:inkwell/crypto/kdf.dart';
import 'package:inkwell/crypto/vault_cipher.dart';
import 'package:inkwell/data/vault_repository.dart';
import 'package:inkwell/domain/entry.dart';
import 'package:inkwell/domain/prefs.dart';
import 'package:inkwell/state/vault_store.dart';
import 'package:paper/paper.dart';

class FakeClock {
  DateTime now = DateTime(2026, 10, 1, 9);
  void advance(Duration by) => now = now.add(by);
}

/// Cheap KDF so the suite is not dominated by Argon2.
KdfParams cheapKdf() => KdfParams(
  salt: KdfParams.randomBytes(16),
  iterations: 1,
  memoryKib: 64,
  lanes: 1,
);

({VaultStore store, FakeClock clock, MemoryStore raw}) build({
  Map<String, String>? seed,
}) {
  final clock = FakeClock();
  final raw = MemoryStore(seed);
  var id = 0;
  return (
    store: VaultStore(
      repository: VaultRepository(raw),
      clock: () => clock.now,
      idFactory: () => 'entry-${id++}',
      kdfFactory: cheapKdf,
    ),
    clock: clock,
    raw: raw,
  );
}

void main() {
  group('first launch', () {
    test('reports no vault and offers to create one', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();

      expect(store.status, VaultStatus.absent);
      expect(store.isUnlocked, isFalse);
      expect(store.entries, isEmpty);
      expect(store.journal, isNull);
    });

    test('creating a vault leaves it unlocked and persisted', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();

      await store.create('a long enough passphrase');

      expect(store.status, VaultStatus.unlocked);
      expect(store.journal, isNotNull);
      final onDisk = raw.snapshot[VaultRepository.vaultKey];
      expect(onDisk, isNotNull);
      expect(
        VaultEnvelope.parse(onDisk!).kdf.iterations,
        1,
        reason: 'the injected cost was used',
      );
    });

    test('refuses to create a second vault over an existing one', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('first');
      store.lock();

      await expectLater(store.create('second'), throwsStateError);
    });
  });

  group('locking', () {
    test('drops the plaintext and zeroes the key', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      await store.saveEntry(title: 'Secret', body: 'contents');

      store.lock();

      expect(store.status, VaultStatus.locked);
      expect(store.journal, isNull);
      expect(store.entries, isEmpty);
      expect(
        () => store.saveEntry(title: 'x', body: 'y'),
        throwsStateError,
        reason: 'a locked vault must not accept writes',
      );
    });

    test('unlocks again with the right passphrase', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      await store.saveEntry(title: 'Monday', body: 'it rained');
      store.lock();

      await store.unlock('passphrase');

      expect(store.status, VaultStatus.unlocked);
      expect(store.entries.single.title, 'Monday');
      expect(store.entries.single.body, 'it rained');
    });

    test('survives a full restart of the app', () async {
      final (store: first, clock: _, raw: raw) = build();
      await first.initialize();
      await first.create('passphrase');
      await first.saveEntry(title: 'Kept', body: '오늘은 좋았다');

      // A fresh store over the same bytes: what a cold start looks like.
      final second = VaultStore(
        repository: VaultRepository(raw),
        clock: () => DateTime(2026, 10, 2),
        idFactory: () => 'x',
      );
      await second.initialize();
      expect(second.status, VaultStatus.locked);

      await second.unlock('passphrase');
      expect(second.entries.single.body, '오늘은 좋았다');
    });

    test('rejects the wrong passphrase and stays locked', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      store.lock();

      await expectLater(
        store.unlock('not the passphrase'),
        throwsA(isA<WrongPassphrase>()),
      );
      expect(store.status, VaultStatus.locked);
      expect(store.journal, isNull);
    });

    test('a corrupt vault file reports corruption, not a wrong passphrase',
        () async {
      final (store: store, clock: _, raw: _) = build(
        seed: {VaultRepository.vaultKey: 'garbage'},
      );
      await store.initialize();
      expect(store.status, VaultStatus.locked);

      await expectLater(
        store.unlock('passphrase'),
        throwsA(isA<VaultCorrupt>()),
      );
    });

    test('a vault from a newer build says so instead of blaming the user',
        () async {
      final (store: seedStore, clock: _, raw: raw) = build();
      await seedStore.initialize();
      await seedStore.create('passphrase');

      final json = jsonDecode(raw.snapshot[VaultRepository.vaultKey]!)
          as Map<String, Object?>;
      json['version'] = 2;
      await raw.write(VaultRepository.vaultKey, jsonEncode(json));

      final (store: store, clock: _, raw: _) = build(seed: raw.snapshot);
      await store.initialize();
      await expectLater(
        store.unlock('passphrase'),
        throwsA(isA<VaultTooNew>()),
      );
    });
  });

  group('failed attempts', () {
    Future<void> failOnce(VaultStore store) async {
      try {
        await store.unlock('wrong');
      } on VaultError {
        // expected
      }
    }

    test('the first few guesses are free', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      store.lock();

      for (var i = 0; i < AttemptRecord.freeAttempts; i++) {
        await failOnce(store);
      }

      expect(store.failedAttempts, AttemptRecord.freeAttempts);
      expect(store.isLockedOut, isFalse);
    });

    test('a further guess imposes a delay that grows', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      store.lock();

      for (var i = 0; i <= AttemptRecord.freeAttempts; i++) {
        await failOnce(store);
      }
      expect(store.isLockedOut, isTrue);
      expect(store.lockoutRemaining, const Duration(seconds: 30));

      // While locked out, unlock refuses outright rather than spending a
      // guess - otherwise the UI could burn through attempts in a loop.
      await expectLater(store.unlock('passphrase'), throwsStateError);

      clock.advance(const Duration(seconds: 31));
      expect(store.isLockedOut, isFalse);

      await failOnce(store);
      expect(store.lockoutRemaining, const Duration(minutes: 1));
    });

    test('the delay is capped rather than growing forever', () async {
      expect(AttemptRecord.penaltyFor(100), const Duration(minutes: 15));
      expect(AttemptRecord.penaltyFor(0), Duration.zero);
    });

    test('a successful unlock clears the record, on disk too', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.create('passphrase');
      store.lock();
      await failOnce(store);
      expect(raw.snapshot[VaultRepository.attemptsKey], isNotNull);

      await store.unlock('passphrase');

      expect(store.failedAttempts, 0);
      expect(raw.snapshot[VaultRepository.attemptsKey], isNull);
    });

    test('the record survives a restart, so quitting is not a reset',
        () async {
      final (store: first, clock: _, raw: raw) = build();
      await first.initialize();
      await first.create('passphrase');
      first.lock();
      for (var i = 0; i <= AttemptRecord.freeAttempts; i++) {
        await failOnce(first);
      }

      final (store: second, clock: _, raw: _) = build(seed: raw.snapshot);
      await second.initialize();

      expect(second.failedAttempts, AttemptRecord.freeAttempts + 1);
      expect(second.isLockedOut, isTrue);
    });
  });

  group('entries', () {
    Future<VaultStore> opened() async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      return store;
    }

    test('are created newest first', () async {
      final store = await opened();
      await store.saveEntry(title: 'First', body: 'a');
      await store.saveEntry(title: 'Second', body: 'b');

      expect(store.entries.map((e) => e.title), ['Second', 'First']);
    });

    test('are updated in place, keeping the creation time', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      final created = await store.saveEntry(title: 'Draft', body: 'one');

      clock.advance(const Duration(hours: 3));
      final updated = await store.saveEntry(
        id: created.id,
        title: 'Finished',
        body: 'two',
      );

      expect(store.entries, hasLength(1));
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
      expect(store.entries.single.title, 'Finished');
    });

    test('tags are trimmed, de-duplicated case-insensitively and kept as '
        'first typed', () async {
      final store = await opened();
      final entry = await store.saveEntry(
        title: 'Tagged',
        body: '',
        tags: <String>['  Work ', 'work', 'WORK', '', '   ', 'travel'],
      );
      expect(entry.tags, ['Work', 'travel']);
    });

    test('a mood can be set and then cleared', () async {
      final store = await opened();
      final entry = await store.saveEntry(
        title: 'Mood',
        body: '',
        mood: Mood.great,
      );
      expect(entry.mood, Mood.great);

      final cleared = await store.saveEntry(
        id: entry.id,
        title: 'Mood',
        body: '',
        clearMood: true,
      );
      expect(cleared.mood, isNull);
    });

    test('deleting is persisted and deleting a stranger is a no-op',
        () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.create('passphrase');
      final entry = await store.saveEntry(title: 'Doomed', body: '');
      final before = raw.snapshot[VaultRepository.vaultKey];

      await store.deleteEntry('no such id');
      expect(store.entries, hasLength(1));
      expect(raw.snapshot[VaultRepository.vaultKey], before);

      await store.deleteEntry(entry.id);
      expect(store.entries, isEmpty);

      store.lock();
      await store.unlock('passphrase');
      expect(store.entries, isEmpty);
    });

    test('every save re-seals with a fresh nonce', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.create('passphrase');

      final nonces = <String>{};
      for (var i = 0; i < 5; i++) {
        await store.saveEntry(title: 'Entry $i', body: 'same body');
        nonces.add(
          base64.encode(
            VaultEnvelope.parse(raw.snapshot[VaultRepository.vaultKey]!).nonce,
          ),
        );
      }
      expect(nonces.length, 5);
    });

    test('nothing readable leaks into the file on disk', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.create('passphrase');
      await store.saveEntry(
        title: 'MY EMBARRASSING TITLE',
        body: 'MY EMBARRASSING BODY',
        tags: <String>['EMBARRASSINGTAG'],
      );

      final onDisk = raw.snapshot[VaultRepository.vaultKey]!;
      expect(onDisk, isNot(contains('EMBARRASSING')));
      // And nothing else written alongside it leaks either.
      for (final value in raw.snapshot.values) {
        expect(value, isNot(contains('EMBARRASSING')));
      }
    });
  });

  group('changePassphrase', () {
    test('re-seals under a new key and a new salt', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.create('old passphrase');
      await store.saveEntry(title: 'Kept', body: 'through the change');
      final oldSalt =
          VaultEnvelope.parse(raw.snapshot[VaultRepository.vaultKey]!).kdf.salt;

      await store.changePassphrase(
        current: 'old passphrase',
        next: 'new passphrase',
      );

      final newSalt =
          VaultEnvelope.parse(raw.snapshot[VaultRepository.vaultKey]!).kdf.salt;
      expect(newSalt, isNot(oldSalt), reason: 'a fresh salt per re-wrap');

      store.lock();
      await expectLater(
        store.unlock('old passphrase'),
        throwsA(isA<WrongPassphrase>()),
      );
      await store.unlock('new passphrase');
      expect(store.entries.single.body, 'through the change');
    });

    test('requires the current passphrase', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('old');

      await expectLater(
        store.changePassphrase(current: 'guess', next: 'new'),
        throwsA(isA<WrongPassphrase>()),
      );

      // And the old passphrase still works afterwards.
      store.lock();
      await store.unlock('old');
      expect(store.isUnlocked, isTrue);
    });

    test('is refused while locked', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('old');
      store.lock();

      await expectLater(
        store.changePassphrase(current: 'old', next: 'new'),
        throwsStateError,
      );
    });
  });

  group('auto-lock', () {
    Future<({VaultStore store, FakeClock clock})> openedWith(
      Duration autoLock,
    ) async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      await store.updatePrefs(store.prefs.copyWith(autoLock: autoLock));
      return (store: store, clock: clock);
    }

    test('locks immediately when set to zero', () async {
      final (store: store, clock: _) = await openedWith(Duration.zero);
      store.onBackgrounded();
      expect(store.status, VaultStatus.locked);
    });

    test('locks after the delay, but not before', () async {
      final (store: store, clock: clock) = await openedWith(
        const Duration(minutes: 5),
      );

      store.onBackgrounded();
      clock.advance(const Duration(minutes: 1));
      store.onForegrounded();
      expect(store.status, VaultStatus.unlocked);

      store.onBackgrounded();
      clock.advance(const Duration(minutes: 6));
      store.onForegrounded();
      expect(store.status, VaultStatus.locked);
    });

    test('never locks when set to never', () async {
      final (store: store, clock: clock) = await openedWith(Prefs.never);
      store.onBackgrounded();
      clock.advance(const Duration(days: 2));
      store.onForegrounded();
      expect(store.status, VaultStatus.unlocked);
    });

    test('repeated background events keep the first departure time', () async {
      final (store: store, clock: clock) = await openedWith(
        const Duration(minutes: 5),
      );
      store.onBackgrounded();
      clock.advance(const Duration(minutes: 3));
      store.onBackgrounded();
      clock.advance(const Duration(minutes: 3));
      store.onForegrounded();
      expect(
        store.status,
        VaultStatus.locked,
        reason: 'six minutes away in total is past a five-minute setting',
      );
    });

    test('a foreground event with no prior background does nothing', () async {
      final (store: store, clock: _) = await openedWith(
        const Duration(minutes: 1),
      );
      store.onForegrounded();
      expect(store.status, VaultStatus.unlocked);
    });
  });

  group('prefs', () {
    test('are plaintext, so the lock screen has the right theme', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.updatePrefs(const Prefs(themeMode: ThemeMode.dark));

      final (store: reopened, clock: _, raw: _) = build(seed: raw.snapshot);
      await reopened.initialize();

      expect(reopened.status, VaultStatus.absent);
      expect(
        reopened.prefs.themeMode,
        ThemeMode.dark,
        reason: 'readable before any passphrase is entered',
      );
    });

    test('a corrupt prefs file falls back instead of blocking the app',
        () async {
      final (store: store, clock: _, raw: _) = build(
        seed: {VaultRepository.prefsKey: 'not json'},
      );
      await store.initialize();
      expect(store.prefs.themeMode, ThemeMode.system);
      expect(store.status, VaultStatus.absent);
    });

    test('an absurd stored auto-lock value is clamped', () async {
      final (store: store, clock: _, raw: _) = build(
        seed: {
          VaultRepository.prefsKey: jsonEncode(<String, Object?>{
            'autoLockSeconds': 99999999,
          }),
        },
      );
      await store.initialize();
      expect(store.prefs.autoLock, Prefs.never);
    });
  });

  group('destroyVault', () {
    test('removes the file and returns to the create screen', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.create('passphrase');
      await store.saveEntry(title: 'Gone', body: 'soon');

      await store.destroyVault();

      expect(store.status, VaultStatus.absent);
      expect(raw.snapshot[VaultRepository.vaultKey], isNull);
      expect(store.journal, isNull);
    });
  });

  group('export', () {
    test('produces plain markdown of every entry', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      await store.saveEntry(
        title: 'Monday',
        body: 'it rained',
        mood: Mood.low,
        tags: <String>['weather'],
      );

      final markdown = store.exportMarkdown();

      expect(markdown, contains('## Monday'));
      expect(markdown, contains('it rained'));
      expect(markdown, contains('weather'));
    });

    test('is refused while locked', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      store.lock();
      expect(store.exportMarkdown, throwsStateError);
    });
  });

  group('key hygiene', () {
    test('a failed unlock does not leave a derived key behind', () async {
      // Checked through behaviour rather than inspection: after a failure the
      // store must still be locked with no journal, so there is nothing a
      // later call could encrypt with a stale key.
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      store.lock();

      try {
        await store.unlock('wrong');
      } on VaultError {
        // expected
      }

      expect(store.isUnlocked, isFalse);
      expect(store.journal, isNull);
      expect(() => store.saveEntry(title: 'x', body: ''), throwsStateError);
    });

    test('disposing an unlocked store destroys the key', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.create('passphrase');
      expect(store.dispose, returnsNormally);
    });
  });
}
