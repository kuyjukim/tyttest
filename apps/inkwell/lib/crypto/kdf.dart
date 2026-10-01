import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'secret_key.dart';

/// Parameters for turning a passphrase into a key.
///
/// Stored in the vault header rather than hard-coded, so that raising the
/// cost later can re-wrap an existing vault instead of locking its owner out.
@immutable
class KdfParams {
  const KdfParams({
    required this.salt,
    required this.iterations,
    required this.memoryKib,
    required this.lanes,
  });

  /// What a new vault is created with.
  ///
  /// These are OWASP's lower Argon2id configuration (m=19 MiB, t=2, p=1),
  /// chosen over the 64 MiB sets for a concrete reason: pointycastle is pure
  /// Dart, where 64 MiB with t=3 measures about 1.4 s on a desktop and
  /// several seconds on a phone. A journal is opened daily, and an unlock
  /// that takes five seconds trains its owner to pick a shorter passphrase -
  /// which costs more entropy than the extra memory cost buys.
  factory KdfParams.fresh({Random? random}) => KdfParams(
    salt: randomBytes(16, random: random),
    iterations: 2,
    memoryKib: 19456,
    lanes: 1,
  );

  factory KdfParams.fromJson(Map<String, Object?> json) {
    final algorithm = json['algorithm'];
    if (algorithm != algorithmName) {
      throw FormatException('Unsupported KDF: $algorithm');
    }
    final salt = _requireBase64(json['salt'], 'salt');
    if (salt.length < 8) {
      throw const FormatException('KDF salt is too short to be real');
    }
    return KdfParams(
      salt: salt,
      iterations: _requirePositiveInt(json['iterations'], 'iterations'),
      memoryKib: _requirePositiveInt(json['memoryKib'], 'memoryKib'),
      lanes: _requirePositiveInt(json['lanes'], 'lanes'),
    );
  }

  static const String algorithmName = 'argon2id';

  /// Length of the derived key, in bytes. AES-256 wants 32.
  static const int keyLength = 32;

  final Uint8List salt;
  final int iterations;
  final int memoryKib;
  final int lanes;

  Map<String, Object?> toJson() => <String, Object?>{
    'algorithm': algorithmName,
    'salt': base64.encode(salt),
    'iterations': iterations,
    'memoryKib': memoryKib,
    'lanes': lanes,
  };

  /// Cryptographically strong random bytes.
  ///
  /// [Random.secure] is the platform CSPRNG; the optional [random] exists so
  /// tests can pin a salt and nonce and assert on exact ciphertext.
  static Uint8List randomBytes(int count, {Random? random}) {
    final source = random ?? Random.secure();
    final bytes = Uint8List(count);
    for (var i = 0; i < count; i++) {
      bytes[i] = source.nextInt(256);
    }
    return bytes;
  }

  static Uint8List _requireBase64(Object? value, String field) {
    if (value is! String) throw FormatException('Missing KDF $field');
    try {
      return base64.decode(value);
    } on FormatException {
      throw FormatException('KDF $field is not base64');
    }
  }

  static int _requirePositiveInt(Object? value, String field) {
    if (value is! int || value <= 0) {
      throw FormatException('KDF $field must be a positive integer');
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is KdfParams &&
      other.iterations == iterations &&
      other.memoryKib == memoryKib &&
      other.lanes == lanes &&
      _sameBytes(other.salt, salt);

  @override
  int get hashCode =>
      Object.hash(iterations, memoryKib, lanes, Object.hashAll(salt));

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Derives the vault key from a passphrase.
abstract final class Kdf {
  /// Derives on the calling isolate. Blocks for as long as the cost says.
  static SecretKey deriveSync(String passphrase, KdfParams params) {
    final generator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          params.salt,
          desiredKeyLength: KdfParams.keyLength,
          iterations: params.iterations,
          memory: params.memoryKib,
          lanes: params.lanes,
        ),
      );
    // NFC-normalising would be better still, but Dart has no normaliser in
    // the core libraries; UTF-8 of the raw string at least makes the
    // encoding explicit rather than platform-dependent.
    final bytes = generator.process(
      Uint8List.fromList(utf8.encode(passphrase)),
    );
    return SecretKey(bytes);
  }

  /// Derives on a background isolate, so unlocking does not drop frames.
  ///
  /// The passphrase is copied into the isolate, which is unavoidable; it is
  /// also the only secret that crosses, and the isolate dies immediately
  /// afterwards.
  static Future<SecretKey> derive(String passphrase, KdfParams params) async {
    final bytes = await compute<_DeriveRequest, Uint8List>(
      _deriveInIsolate,
      _DeriveRequest(passphrase, params),
      debugLabel: 'inkwell.kdf',
    );
    return SecretKey(bytes);
  }
}

@immutable
class _DeriveRequest {
  const _DeriveRequest(this.passphrase, this.params);

  final String passphrase;
  final KdfParams params;
}

/// Top-level so it can be sent to an isolate.
Uint8List _deriveInIsolate(_DeriveRequest request) {
  final key = Kdf.deriveSync(request.passphrase, request.params);
  // Copied out before the isolate's own object goes away.
  return Uint8List.fromList(key.bytes);
}
