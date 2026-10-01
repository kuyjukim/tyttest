import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'kdf.dart';
import 'secret_key.dart';

/// Something went wrong opening a vault.
sealed class VaultError implements Exception {
  const VaultError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The passphrase did not open the vault - or the file was tampered with.
///
/// These two cases are deliberately one error. The authentication tag cannot
/// distinguish "wrong key" from "modified ciphertext", and guessing which it
/// was for the user would mean guessing wrong sometimes.
class WrongPassphrase extends VaultError {
  const WrongPassphrase()
    : super('The passphrase did not open this vault, or the file has been '
          'modified.');
}

/// The file is not a vault, or is damaged beyond the header.
class VaultCorrupt extends VaultError {
  const VaultCorrupt(super.message);
}

/// The file was written by a newer version of the app.
class VaultTooNew extends VaultError {
  const VaultTooNew(this.foundVersion)
    : super('This vault was written by a newer version of Inkwell.');

  final int foundVersion;
}

/// The on-disk form of a vault: a plaintext header and a sealed body.
///
/// The header has to be readable without the key - it holds the KDF salt and
/// cost, which are needed *to derive* the key. It is therefore also the
/// obvious thing to attack: an attacker who could rewrite `iterations` to 1
/// would turn a strong passphrase into a weak one. So the canonical header
/// is fed to AES-GCM as associated data, which means any edit to it makes the
/// body fail to authenticate.
class VaultEnvelope {
  const VaultEnvelope({
    required this.version,
    required this.kdf,
    required this.nonce,
    required this.ciphertext,
  });

  factory VaultEnvelope.parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const VaultCorrupt('Not a vault file.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const VaultCorrupt('Not a vault file.');
    }
    if (decoded['format'] != formatTag) {
      throw const VaultCorrupt('Not a vault file.');
    }

    final version = decoded['version'];
    if (version is! int) throw const VaultCorrupt('Vault has no version.');
    if (version > currentVersion) throw VaultTooNew(version);

    if (decoded['cipher'] != cipherTag) {
      throw VaultCorrupt('Unsupported cipher: ${decoded['cipher']}');
    }

    try {
      final kdf = decoded['kdf'];
      if (kdf is! Map<String, Object?>) {
        throw const FormatException('Missing KDF block');
      }
      final nonce = base64.decode(decoded['nonce']! as String);
      if (nonce.length != nonceLength) {
        throw const FormatException('Nonce is the wrong length');
      }
      return VaultEnvelope(
        version: version,
        kdf: KdfParams.fromJson(kdf),
        nonce: nonce,
        ciphertext: base64.decode(decoded['body']! as String),
      );
    } on FormatException catch (error) {
      throw VaultCorrupt(error.message);
    } on TypeError {
      throw const VaultCorrupt('Vault header is missing fields.');
    }
  }

  static const String formatTag = 'inkwell.vault';
  static const String cipherTag = 'aes-256-gcm';
  static const int currentVersion = 1;

  /// 96 bits, the size AES-GCM is specified and fastest for.
  static const int nonceLength = 12;

  /// 128-bit authentication tag.
  static const int macBits = 128;

  final int version;
  final KdfParams kdf;
  final Uint8List nonce;

  /// Ciphertext with the GCM tag appended, as pointycastle produces it.
  final Uint8List ciphertext;

  /// The header fields, in a fixed key order.
  ///
  /// Fixed order matters: this exact byte string is the associated data, so
  /// sealing and opening have to produce it identically. A `Map` whose
  /// iteration order changed would make every vault unopenable.
  Uint8List get associatedData => Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'format': formatTag,
        'version': version,
        'cipher': cipherTag,
        'kdf': kdf.toJson(),
      }),
    ),
  );

  String serialise() => jsonEncode(<String, Object?>{
    'format': formatTag,
    'version': version,
    'cipher': cipherTag,
    'kdf': kdf.toJson(),
    'nonce': base64.encode(nonce),
    'body': base64.encode(ciphertext),
  });
}

/// Seals and opens vault bodies with AES-256-GCM.
abstract final class VaultCipher {
  /// Encrypts [plaintext] under [key], producing a complete envelope.
  ///
  /// A fresh nonce is generated on every call. That is not an optimisation:
  /// reusing a nonce with the same key breaks GCM catastrophically, leaking
  /// the keystream and the authentication key, so there is no API here that
  /// lets a caller supply one outside a test.
  static VaultEnvelope seal({
    required String plaintext,
    required SecretKey key,
    required KdfParams kdf,
    Random? random,
  }) {
    final nonce = KdfParams.randomBytes(
      VaultEnvelope.nonceLength,
      random: random,
    );
    final skeleton = VaultEnvelope(
      version: VaultEnvelope.currentVersion,
      kdf: kdf,
      nonce: nonce,
      ciphertext: Uint8List(0),
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key.bytes),
          VaultEnvelope.macBits,
          nonce,
          skeleton.associatedData,
        ),
      );
    final body = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    return VaultEnvelope(
      version: skeleton.version,
      kdf: kdf,
      nonce: nonce,
      ciphertext: body,
    );
  }

  /// Decrypts [envelope] with [key], or throws [WrongPassphrase].
  static String open({
    required VaultEnvelope envelope,
    required SecretKey key,
  }) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key.bytes),
          VaultEnvelope.macBits,
          envelope.nonce,
          envelope.associatedData,
        ),
      );
    final Uint8List plain;
    try {
      plain = cipher.process(envelope.ciphertext);
    } on InvalidCipherTextException {
      throw const WrongPassphrase();
    } on ArgumentError {
      // Ciphertext shorter than the tag, i.e. a truncated file.
      throw const WrongPassphrase();
    }
    try {
      return utf8.decode(plain);
    } on FormatException {
      // Authenticated, so the key was right, but the bytes are not text.
      throw const VaultCorrupt('Decrypted content is not valid UTF-8.');
    }
  }
}
