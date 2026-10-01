import 'package:flutter/foundation.dart';
import 'package:paper/paper.dart';

import '../crypto/kdf.dart';
import '../crypto/secret_key.dart';
import '../crypto/vault_cipher.dart';
import '../data/vault_repository.dart';
import '../domain/entry.dart';
import '../domain/journal.dart';
import '../domain/prefs.dart';

enum VaultStatus {
  /// Still reading from disk.
  checking,

  /// No vault on this device: the user has to choose a passphrase.
  absent,

  /// A vault exists and the passphrase has not been given.
  locked,

  /// Decrypted and in memory.
  unlocked,
}

/// Application state for Inkwell.
///
/// The invariant everything else leans on: the decrypted [Journal] and the
/// [SecretKey] exist only while [status] is [VaultStatus.unlocked], and
/// [lock] destroys both. No screen can reach plaintext through this object at
/// any other time.
class VaultStore extends ChangeNotifier {
  VaultStore({
    required VaultRepository repository,
    required DateTime Function() clock,
    required String Function() idFactory,
    KdfParams Function()? kdfFactory,
    Future<SecretKey> Function(String passphrase, KdfParams params)? deriveKey,
  }) : _repository = repository,
       _clock = clock,
       _idFactory = idFactory,
       _kdfFactory = kdfFactory ?? KdfParams.fresh,
       _deriveKey = deriveKey ?? Kdf.derive;

  final VaultRepository _repository;
  final DateTime Function() _clock;
  final String Function() _idFactory;

  /// Produces the parameters for a *new* vault or a re-wrap.
  ///
  /// Injectable because the right cost is not a universal constant: a slower
  /// device deserves a cheaper setting than a current flagship, and the tests
  /// here would otherwise spend most of their runtime in Argon2. Opening an
  /// existing vault always uses the parameters stored in its own header, so
  /// this cannot weaken a vault that already exists.
  final KdfParams Function() _kdfFactory;

  /// How a passphrase becomes a key.
  ///
  /// Defaults to the isolate-backed derivation, so a one-second Argon2 run
  /// does not drop frames on the unlock screen. Injectable because a widget
  /// test runs inside a fake-async zone where an isolate's reply is never
  /// delivered, and a test that hangs forever is worse than one that uses the
  /// synchronous path - which `crypto_test` covers directly, including the
  /// isolate agreeing with it byte for byte.
  final Future<SecretKey> Function(String passphrase, KdfParams params)
  _deriveKey;

  VaultStatus _status = VaultStatus.checking;
  Prefs _prefs = const Prefs();
  AttemptRecord _attempts = AttemptRecord.clean;

  Journal? _journal;
  SecretKey? _key;
  KdfParams? _kdf;

  /// When the app last went to the background, for auto-lock.
  DateTime? _leftForegroundAt;

  VaultStatus get status => _status;
  Prefs get prefs => _prefs;
  bool get isUnlocked => _status == VaultStatus.unlocked;

  /// The decrypted journal. Null unless unlocked.
  Journal? get journal => _journal;

  /// Entries, or an empty list when locked - so list screens need no
  /// null-handling of their own.
  List<Entry> get entries => _journal?.entries ?? const <Entry>[];

  Day get today => Day.fromDateTime(_clock());

  int get failedAttempts => _attempts.failures;

  /// Time left before another unlock attempt is allowed.
  Duration get lockoutRemaining => _attempts.remainingAt(_clock());

  bool get isLockedOut => lockoutRemaining > Duration.zero;

  /// Reads the plaintext side of the world and decides which screen to show.
  Future<void> initialize() async {
    _prefs = await _repository.readPrefs();
    _attempts = await _repository.readAttempts();
    _status = await _repository.vaultExists()
        ? VaultStatus.locked
        : VaultStatus.absent;
    notifyListeners();
  }

  /// Creates a vault and leaves it unlocked.
  ///
  /// Throws [StateError] if one already exists, rather than overwriting:
  /// there is no recovery from silently replacing someone's journal.
  Future<void> create(String passphrase) async {
    if (_status != VaultStatus.absent) {
      throw StateError('A vault already exists on this device.');
    }
    final kdf = _kdfFactory();
    final key = await _deriveKey(passphrase, kdf);
    final journal = Journal.empty();

    _kdf = kdf;
    _key = key;
    _journal = journal;
    _status = VaultStatus.unlocked;
    await _seal();
    await _resetAttempts();
    notifyListeners();
  }

  /// Decrypts the vault, or throws a [VaultError].
  ///
  /// Throws [StateError] while locked out, so the UI cannot be coaxed into
  /// burning through guesses by calling this in a loop.
  Future<void> unlock(String passphrase) async {
    if (_status == VaultStatus.unlocked) return;
    if (isLockedOut) {
      throw StateError('Locked out for another ${lockoutRemaining.inSeconds}s');
    }

    final raw = await _repository.readVault();
    if (raw == null || raw.isEmpty) {
      _status = VaultStatus.absent;
      notifyListeners();
      throw const VaultCorrupt('There is no vault to open.');
    }

    final envelope = VaultEnvelope.parse(raw);
    final key = await _deriveKey(passphrase, envelope.kdf);

    final String plaintext;
    try {
      plaintext = VaultCipher.open(envelope: envelope, key: key);
    } on VaultError {
      // The derived key is useless now; do not leave it in the heap.
      key.destroy();
      await _recordFailure();
      rethrow;
    }

    final Journal journal;
    try {
      journal = Journal.decode(plaintext);
    } on FormatException catch (error) {
      key.destroy();
      throw VaultCorrupt('Vault contents could not be read: ${error.message}');
    }

    _kdf = envelope.kdf;
    _key = key;
    _journal = journal;
    _status = VaultStatus.unlocked;
    await _resetAttempts();
    notifyListeners();
  }

  /// Drops the plaintext and zeroes the key.
  void lock() {
    if (_status != VaultStatus.unlocked) return;
    _key?.destroy();
    _key = null;
    _journal = null;
    _kdf = null;
    _leftForegroundAt = null;
    _status = VaultStatus.locked;
    notifyListeners();
  }

  /// Re-derives the key from [next] and re-seals the journal.
  ///
  /// Requires the current passphrase even though the vault is already open.
  /// The journal is readable at this point, so checking adds no
  /// cryptographic strength - it is there so that someone who walks up to an
  /// unlocked phone cannot lock the owner out of their own journal.
  Future<void> changePassphrase({
    required String current,
    required String next,
  }) async {
    final journal = _journal;
    final kdf = _kdf;
    if (journal == null || kdf == null) {
      throw StateError('The vault must be unlocked to change its passphrase.');
    }

    final check = await _deriveKey(current, kdf);
    final matches = _sameKey(check, _key!);
    check.destroy();
    if (!matches) throw const WrongPassphrase();

    // A new salt as well as a new key: reusing the salt would let anyone with
    // both files confirm they belong to the same person.
    final freshKdf = _kdfFactory();
    final freshKey = await _deriveKey(next, freshKdf);
    _key?.destroy();
    _key = freshKey;
    _kdf = freshKdf;
    await _seal();
    notifyListeners();
  }

  /// Creates or replaces an entry and saves.
  Future<Entry> saveEntry({
    String? id,
    required String title,
    required String body,
    Mood? mood,
    List<String> tags = const <String>[],
    bool clearMood = false,
  }) async {
    final journal = _requireJournal();
    final now = _clock();
    final cleanTags = _normaliseTags(tags);

    final existing = id == null ? null : journal.byId(id);
    final entry = existing == null
        ? Entry(
            id: id ?? _idFactory(),
            createdAt: now,
            updatedAt: now,
            title: title.trim(),
            body: body,
            mood: mood,
            tags: cleanTags,
          )
        : existing.copyWith(
            title: title.trim(),
            body: body,
            mood: mood,
            clearMood: clearMood,
            tags: cleanTags,
            updatedAt: now,
          );

    journal.upsert(entry);
    await _seal();
    notifyListeners();
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final journal = _requireJournal();
    if (!journal.remove(id)) return;
    await _seal();
    notifyListeners();
  }

  Future<void> updatePrefs(Prefs next) async {
    _prefs = next;
    await _repository.writePrefs(next);
    notifyListeners();
  }

  /// Deletes the vault and everything in it.
  Future<void> destroyVault() async {
    _key?.destroy();
    _key = null;
    _journal = null;
    _kdf = null;
    await _repository.deleteVault();
    await _repository.clearAttempts();
    _attempts = AttemptRecord.clean;
    _status = VaultStatus.absent;
    notifyListeners();
  }

  /// A plaintext export of everything. The caller is responsible for warning
  /// the user that what they get back is no longer encrypted.
  String exportMarkdown() => _requireJournal().toMarkdown();

  /// Call when the app leaves the foreground.
  void onBackgrounded() {
    if (_status != VaultStatus.unlocked) return;
    if (_prefs.locksImmediately) {
      lock();
      return;
    }
    _leftForegroundAt ??= _clock();
  }

  /// Call when the app returns. Locks if it was away longer than the setting.
  void onForegrounded() {
    if (_status != VaultStatus.unlocked) return;
    final left = _leftForegroundAt;
    _leftForegroundAt = null;
    if (left == null || _prefs.neverLocks) return;
    if (_clock().difference(left) >= _prefs.autoLock) lock();
  }

  Journal _requireJournal() {
    final journal = _journal;
    if (journal == null) {
      throw StateError('The vault is locked; there is nothing to write to.');
    }
    return journal;
  }

  /// Trims, drops blanks, and removes duplicates case-insensitively while
  /// keeping the spelling the user typed first.
  static List<String> _normaliseTags(List<String> tags) {
    final seen = <String>{};
    final result = <String>[];
    for (final tag in tags) {
      final clean = tag.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean.toLowerCase())) result.add(clean);
    }
    return result;
  }

  Future<void> _seal() async {
    final journal = _requireJournal();
    final envelope = VaultCipher.seal(
      plaintext: journal.encode(),
      key: _key!,
      kdf: _kdf!,
    );
    await _repository.writeVault(envelope.serialise());
  }

  Future<void> _recordFailure() async {
    _attempts = _attempts.afterFailure(_clock());
    await _repository.writeAttempts(_attempts);
    notifyListeners();
  }

  Future<void> _resetAttempts() async {
    if (_attempts.failures == 0 && _attempts.lockedUntil == null) return;
    _attempts = AttemptRecord.clean;
    await _repository.clearAttempts();
  }

  /// Constant-time-ish comparison of two keys.
  ///
  /// Both are local and the attacker here has the device unlocked already, so
  /// timing is not a realistic channel - but a short-circuiting `==` in key
  /// comparison is the kind of thing that gets copied somewhere it matters.
  static bool _sameKey(SecretKey a, SecretKey b) {
    final left = a.bytes;
    final right = b.bytes;
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }

  @override
  void dispose() {
    _key?.destroy();
    super.dispose();
  }
}
