import 'dart:convert';

import 'package:paper/paper.dart';

import '../domain/prefs.dart';

/// Reads and writes the three things Inkwell keeps on disk: the sealed vault,
/// the plaintext preferences, and the failed-attempt record.
class VaultRepository {
  VaultRepository(this._store);

  final KeyValueStore _store;

  static const String vaultKey = 'inkwell.vault.v1';
  static const String prefsKey = 'inkwell.prefs.v1';
  static const String attemptsKey = 'inkwell.attempts.v1';

  /// The sealed envelope as written, or null when no vault exists yet.
  Future<String?> readVault() => _store.read(vaultKey);

  Future<void> writeVault(String serialisedEnvelope) =>
      _store.write(vaultKey, serialisedEnvelope);

  Future<void> deleteVault() => _store.delete(vaultKey);

  Future<bool> vaultExists() async {
    final raw = await _store.read(vaultKey);
    return raw != null && raw.isNotEmpty;
  }

  Future<Prefs> readPrefs() async =>
      _readJson(prefsKey, Prefs.fromJson, () => const Prefs());

  Future<void> writePrefs(Prefs prefs) =>
      _store.write(prefsKey, jsonEncode(prefs.toJson()));

  Future<AttemptRecord> readAttempts() async =>
      _readJson(attemptsKey, AttemptRecord.fromJson, () => AttemptRecord.clean);

  Future<void> writeAttempts(AttemptRecord record) =>
      _store.write(attemptsKey, jsonEncode(record.toJson()));

  Future<void> clearAttempts() => _store.delete(attemptsKey);

  /// Reads a small plaintext JSON document, falling back rather than throwing.
  ///
  /// A corrupt preferences file must not stop the app reaching the lock
  /// screen - that would turn a cosmetic problem into a lost journal.
  Future<T> _readJson<T>(
    String key,
    T Function(Map<String, Object?>) decode,
    T Function() fallback,
  ) async {
    final raw = await _store.read(key);
    if (raw == null || raw.isEmpty) return fallback();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return fallback();
      return decode(json);
    } on Object {
      return fallback();
    }
  }
}
