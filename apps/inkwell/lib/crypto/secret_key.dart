import 'dart:typed_data';

/// A symmetric key, with an explicit end of life.
///
/// Dart gives no way to guarantee a secret is gone from memory - the garbage
/// collector may have copied the bytes, and `String` is immutable so a
/// passphrase cannot be scrubbed at all. What [destroy] does buy is that the
/// *one* long-lived copy, the key the app holds for as long as the vault is
/// unlocked, is zeroed the moment the vault locks rather than sitting in the
/// heap until something happens to overwrite it.
///
/// Treating that as a complete defence would be wrong; treating it as not
/// worth doing would also be wrong.
class SecretKey {
  SecretKey(Uint8List bytes) : _bytes = bytes;

  final Uint8List _bytes;
  bool _destroyed = false;

  bool get isDestroyed => _destroyed;

  int get length => _bytes.length;

  /// The raw key. Throws once [destroy] has been called, so a use-after-lock
  /// is a loud failure rather than an encryption with a key of zeroes.
  Uint8List get bytes {
    if (_destroyed) {
      throw StateError(
        'This key was destroyed when the vault locked. Derive a new one from '
        'the passphrase instead of holding on to the old object.',
      );
    }
    return _bytes;
  }

  /// Overwrites the key material with zeroes.
  void destroy() {
    if (_destroyed) return;
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }

  @override
  String toString() => 'SecretKey(${_bytes.length} bytes, '
      '${_destroyed ? 'destroyed' : 'live'})';
}
