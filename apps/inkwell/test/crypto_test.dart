import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkwell/crypto/kdf.dart';
import 'package:inkwell/crypto/secret_key.dart';
import 'package:inkwell/crypto/vault_cipher.dart';

/// Deliberately weak parameters, so the suite runs in milliseconds.
///
/// One test below uses the real shipped cost to prove it works and to keep
/// its runtime visible.
KdfParams cheap({int saltByte = 7}) => KdfParams(
  salt: Uint8List.fromList(List<int>.filled(16, saltByte)),
  iterations: 1,
  memoryKib: 64,
  lanes: 1,
);

SecretKey keyFor(String passphrase, [KdfParams? params]) =>
    Kdf.deriveSync(passphrase, params ?? cheap());

void main() {
  group('Kdf', () {
    test('is deterministic for the same passphrase and salt', () {
      final a = keyFor('correct horse battery staple');
      final b = keyFor('correct horse battery staple');
      expect(a.bytes, b.bytes);
      expect(a.length, KdfParams.keyLength);
    });

    test('a different salt gives a different key for the same passphrase', () {
      final a = keyFor('correct horse battery staple', cheap());
      final b = keyFor('correct horse battery staple', cheap(saltByte: 9));
      expect(a.bytes, isNot(b.bytes));
    });

    test('a one-character change gives an unrelated key', () {
      final a = keyFor('passphrase');
      final b = keyFor('passphrasf');
      var shared = 0;
      for (var i = 0; i < a.length; i++) {
        if (a.bytes[i] == b.bytes[i]) shared++;
      }
      expect(shared, lessThan(8), reason: 'the KDF should not be structured');
    });

    test('handles a passphrase of any script or length', () {
      for (final passphrase in <String>[
        '',
        ' ',
        '열려라 참깨',
        '🔐🔐🔐',
        'a' * 4096,
      ]) {
        expect(keyFor(passphrase).length, KdfParams.keyLength);
      }
    });

    test('derives on a background isolate with the same result', () async {
      final params = cheap();
      final sync = Kdf.deriveSync('offloaded', params);
      final async = await Kdf.derive('offloaded', params);
      expect(async.bytes, sync.bytes);
    });

    test('the shipped parameters are what the app actually uses', () {
      final fresh = KdfParams.fresh();
      expect(fresh.salt.length, 16);
      expect(fresh.iterations, 2);
      expect(fresh.memoryKib, 19456, reason: 'OWASP Argon2id m=19MiB, t=2');
      expect(fresh.lanes, 1);
    });

    test('a fresh salt is different every time', () {
      final salts = <String>{
        for (var i = 0; i < 20; i++) base64.encode(KdfParams.fresh().salt),
      };
      expect(salts.length, 20);
    });

    test('deriving at the shipped cost works end to end', () {
      // Slow on purpose: if this ever becomes intolerable, the parameters
      // need revisiting rather than the test deleting.
      final params = KdfParams.fresh();
      final key = Kdf.deriveSync('a real passphrase', params);
      expect(key.length, KdfParams.keyLength);
    }, timeout: const Timeout(Duration(seconds: 60)));

    group('params serialisation', () {
      test('round-trips', () {
        final params = KdfParams.fresh();
        final restored = KdfParams.fromJson(params.toJson());
        expect(restored, params);
      });

      test('rejects an unknown algorithm', () {
        final json = cheap().toJson()..['algorithm'] = 'md5';
        expect(() => KdfParams.fromJson(json), throwsFormatException);
      });

      test('rejects a salt that is too short to be real', () {
        final json = cheap().toJson()
          ..['salt'] = base64.encode(Uint8List(4));
        expect(() => KdfParams.fromJson(json), throwsFormatException);
      });

      test('rejects non-positive or non-integer costs', () {
        for (final bad in <Object?>[0, -1, '2', 2.5, null]) {
          final json = cheap().toJson()..['iterations'] = bad;
          expect(
            () => KdfParams.fromJson(json),
            throwsFormatException,
            reason: 'iterations: $bad',
          );
        }
      });
    });
  });

  group('SecretKey', () {
    test('zeroes its bytes on destroy and refuses further use', () {
      final key = keyFor('passphrase');
      final view = key.bytes;
      expect(view.any((b) => b != 0), isTrue);

      key.destroy();

      expect(view.every((b) => b == 0), isTrue);
      expect(key.isDestroyed, isTrue);
      expect(() => key.bytes, throwsStateError);
    });

    test('destroy is idempotent', () {
      final key = keyFor('passphrase')..destroy();
      expect(key.destroy, returnsNormally);
    });
  });

  group('seal and open', () {
    test('round-trips text through a vault', () {
      final params = cheap();
      final key = keyFor('passphrase', params);
      final envelope = VaultCipher.seal(
        plaintext: '{"entries":[]}',
        key: key,
        kdf: params,
      );
      expect(
        VaultCipher.open(envelope: envelope, key: key),
        '{"entries":[]}',
      );
    });

    test('round-trips every script, and an empty body', () {
      final params = cheap();
      final key = keyFor('passphrase', params);
      for (final text in <String>[
        '',
        '오늘은 비가 왔다. 🌧️',
        'line one\nline two\ttabbed',
        '{"nested":{"json":true}}',
        'x' * 200000,
      ]) {
        final envelope = VaultCipher.seal(
          plaintext: text,
          key: key,
          kdf: params,
        );
        expect(VaultCipher.open(envelope: envelope, key: key), text);
      }
    });

    test('a fresh nonce is used for every seal', () {
      final params = cheap();
      final key = keyFor('passphrase', params);
      final nonces = <String>{};
      final bodies = <String>{};
      for (var i = 0; i < 25; i++) {
        final envelope = VaultCipher.seal(
          plaintext: 'the same plaintext every time',
          key: key,
          kdf: params,
        );
        nonces.add(base64.encode(envelope.nonce));
        bodies.add(base64.encode(envelope.ciphertext));
      }
      expect(nonces.length, 25, reason: 'nonce reuse breaks GCM completely');
      expect(bodies.length, 25, reason: 'so identical plaintext must differ');
    });

    test('the wrong passphrase is rejected', () {
      final params = cheap();
      final envelope = VaultCipher.seal(
        plaintext: 'secret',
        key: keyFor('right', params),
        kdf: params,
      );
      expect(
        () => VaultCipher.open(
          envelope: envelope,
          key: keyFor('wrong', params),
        ),
        throwsA(isA<WrongPassphrase>()),
      );
    });

    test('a flipped ciphertext byte is detected', () {
      final params = cheap();
      final key = keyFor('passphrase', params);
      final sealed = VaultCipher.seal(
        plaintext: 'a diary entry worth protecting',
        key: key,
        kdf: params,
      );

      for (final index in <int>[0, sealed.ciphertext.length ~/ 2,
          sealed.ciphertext.length - 1]) {
        final body = Uint8List.fromList(sealed.ciphertext);
        body[index] ^= 0x01;
        final tampered = VaultEnvelope(
          version: sealed.version,
          kdf: sealed.kdf,
          nonce: sealed.nonce,
          ciphertext: body,
        );
        expect(
          () => VaultCipher.open(envelope: tampered, key: key),
          throwsA(isA<WrongPassphrase>()),
          reason: 'byte $index',
        );
      }
    });

    test('a changed nonce is detected', () {
      final params = cheap();
      final key = keyFor('passphrase', params);
      final sealed = VaultCipher.seal(
        plaintext: 'secret',
        key: key,
        kdf: params,
      );
      final nonce = Uint8List.fromList(sealed.nonce)..[0] ^= 0xFF;

      expect(
        () => VaultCipher.open(
          envelope: VaultEnvelope(
            version: sealed.version,
            kdf: sealed.kdf,
            nonce: nonce,
            ciphertext: sealed.ciphertext,
          ),
          key: key,
        ),
        throwsA(isA<WrongPassphrase>()),
      );
    });

    test('weakening the KDF cost in the header is detected', () {
      // The attack this defends against: the header must be plaintext
      // because it holds the salt and cost needed to derive the key, so an
      // attacker can see it. If they could rewrite iterations to 1 and have
      // the app accept it, a strong passphrase would become brute-forceable.
      // Binding the header as GCM associated data makes that edit fail.
      final params = cheap();
      final key = keyFor('passphrase', params);
      final sealed = VaultCipher.seal(
        plaintext: 'secret',
        key: key,
        kdf: params,
      );

      final weakened = VaultEnvelope(
        version: sealed.version,
        kdf: KdfParams(
          salt: sealed.kdf.salt,
          iterations: 1,
          memoryKib: 8,
          lanes: 1,
        ),
        nonce: sealed.nonce,
        ciphertext: sealed.ciphertext,
      );

      expect(
        () => VaultCipher.open(envelope: weakened, key: key),
        throwsA(isA<WrongPassphrase>()),
      );
    });

    test('a truncated body is rejected rather than crashing', () {
      final params = cheap();
      final key = keyFor('passphrase', params);
      final sealed = VaultCipher.seal(
        plaintext: 'secret',
        key: key,
        kdf: params,
      );
      for (final keep in <int>[0, 1, 8, sealed.ciphertext.length - 1]) {
        final tampered = VaultEnvelope(
          version: sealed.version,
          kdf: sealed.kdf,
          nonce: sealed.nonce,
          ciphertext: Uint8List.sublistView(sealed.ciphertext, 0, keep),
        );
        expect(
          () => VaultCipher.open(envelope: tampered, key: key),
          throwsA(isA<WrongPassphrase>()),
          reason: 'kept $keep bytes',
        );
      }
    });

    test('the plaintext does not appear in the sealed bytes', () {
      final params = cheap();
      final envelope = VaultCipher.seal(
        plaintext: 'MY DIARY SAYS SOMETHING EMBARRASSING',
        key: keyFor('passphrase', params),
        kdf: params,
      );
      expect(envelope.serialise(), isNot(contains('EMBARRASSING')));
      expect(
        utf8.decode(envelope.ciphertext, allowMalformed: true),
        isNot(contains('EMBARRASSING')),
      );
    });

    test('a pinned RNG produces a reproducible envelope', () {
      // Not a security property - a check that nothing else is sneaking
      // entropy in, so the format stays a pure function of its inputs.
      final params = cheap();
      final key = keyFor('passphrase', params);
      String sealOnce() => VaultCipher.seal(
        plaintext: 'deterministic',
        key: key,
        kdf: params,
        random: Random(42),
      ).serialise();

      expect(sealOnce(), sealOnce());
    });
  });

  group('VaultEnvelope', () {
    VaultEnvelope sample() {
      final params = cheap();
      return VaultCipher.seal(
        plaintext: 'body',
        key: keyFor('passphrase', params),
        kdf: params,
      );
    }

    test('survives a trip through its serialised form', () {
      final original = sample();
      final restored = VaultEnvelope.parse(original.serialise());

      expect(restored.version, original.version);
      expect(restored.nonce, original.nonce);
      expect(restored.ciphertext, original.ciphertext);
      expect(restored.kdf, original.kdf);
      expect(
        VaultCipher.open(
          envelope: restored,
          key: keyFor('passphrase', original.kdf),
        ),
        'body',
      );
    });

    test('associated data is byte-identical across a round trip', () {
      // If key order in the header ever drifted, every existing vault would
      // stop opening. This is the test that would catch it.
      final original = sample();
      final restored = VaultEnvelope.parse(original.serialise());
      expect(restored.associatedData, original.associatedData);
    });

    test('rejects things that are not vaults', () {
      for (final raw in <String>[
        '',
        'not json at all',
        '[]',
        '{}',
        '{"format":"something.else","version":1}',
      ]) {
        expect(
          () => VaultEnvelope.parse(raw),
          throwsA(isA<VaultCorrupt>()),
          reason: 'input: "$raw"',
        );
      }
    });

    test('names the version when a file is from a newer build', () {
      final json = jsonDecode(sample().serialise()) as Map<String, Object?>;
      json['version'] = 99;
      expect(
        () => VaultEnvelope.parse(jsonEncode(json)),
        throwsA(
          isA<VaultTooNew>().having((e) => e.foundVersion, 'version', 99),
        ),
      );
    });

    test('rejects an unsupported cipher and a malformed nonce', () {
      final base = jsonDecode(sample().serialise()) as Map<String, Object?>;

      expect(
        () => VaultEnvelope.parse(
          jsonEncode(<String, Object?>{...base, 'cipher': 'rot13'}),
        ),
        throwsA(isA<VaultCorrupt>()),
      );
      expect(
        () => VaultEnvelope.parse(
          jsonEncode(<String, Object?>{
            ...base,
            'nonce': base64.encode(Uint8List(5)),
          }),
        ),
        throwsA(isA<VaultCorrupt>()),
      );
      expect(
        () => VaultEnvelope.parse(
          jsonEncode(<String, Object?>{...base, 'body': 'not base64 !!!'}),
        ),
        throwsA(isA<VaultCorrupt>()),
      );
    });

    test('reports a missing field as corrupt rather than throwing a TypeError',
        () {
      final base = jsonDecode(sample().serialise()) as Map<String, Object?>;
      for (final field in <String>['kdf', 'nonce', 'body']) {
        final json = <String, Object?>{...base}..remove(field);
        expect(
          () => VaultEnvelope.parse(jsonEncode(json)),
          throwsA(isA<VaultCorrupt>()),
          reason: 'missing $field',
        );
      }
    });
  });
}
