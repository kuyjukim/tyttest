import 'package:flutter/material.dart' show ThemeMode;

/// Preferences kept *outside* the vault, in plaintext.
///
/// This split is deliberate. The theme has to be known before the passphrase
/// is entered - otherwise the lock screen flashes the wrong colours on every
/// launch - and the auto-lock delay has to be readable while the vault is
/// locked, which is precisely when it matters. Neither is sensitive.
///
/// Everything a reader would actually care about - titles, bodies, moods,
/// tags, even the entry count - stays inside the sealed blob.
class Prefs {
  const Prefs({
    this.themeMode = ThemeMode.system,
    this.autoLock = const Duration(minutes: 1),
  });

  factory Prefs.fromJson(Map<String, Object?> json) => Prefs(
    themeMode: switch (json['themeMode']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    autoLock: _readAutoLock(json['autoLockSeconds']),
  );

  /// `Duration.zero` means lock the moment the app leaves the foreground.
  static const List<Duration> autoLockChoices = <Duration>[
    Duration.zero,
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    never,
  ];

  /// Sentinel for "do not auto-lock".
  ///
  /// A real duration rather than a nullable field, so every comparison is
  /// just a comparison; nothing is going to be in the background for a year.
  static const Duration never = Duration(days: 365);

  final ThemeMode themeMode;
  final Duration autoLock;

  bool get locksImmediately => autoLock == Duration.zero;
  bool get neverLocks => autoLock >= never;

  Prefs copyWith({ThemeMode? themeMode, Duration? autoLock}) => Prefs(
    themeMode: themeMode ?? this.themeMode,
    autoLock: autoLock ?? this.autoLock,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'autoLockSeconds': autoLock.inSeconds,
  };

  static Duration _readAutoLock(Object? raw) {
    final seconds = switch (raw) {
      final int v => v,
      final double v => v.round(),
      final String v => int.tryParse(v) ?? 60,
      _ => 60,
    };
    if (seconds <= 0) return Duration.zero;
    final clamped = Duration(seconds: seconds);
    return clamped > never ? never : clamped;
  }
}

/// The record of failed unlock attempts, kept in plaintext beside the vault.
///
/// This slows down someone who has picked up an unlocked phone and is
/// guessing. It does *not* slow down an attacker who has copied the vault
/// file off the device - they can brute-force offline, where nothing this app
/// does can reach them. That is what the Argon2 cost is for; this is for the
/// other, far more common threat.
class AttemptRecord {
  const AttemptRecord({this.failures = 0, this.lockedUntil});

  factory AttemptRecord.fromJson(Map<String, Object?> json) {
    final raw = json['lockedUntil'];
    return AttemptRecord(
      failures: switch (json['failures']) {
        final int v => v < 0 ? 0 : v,
        _ => 0,
      },
      lockedUntil: raw is String ? DateTime.tryParse(raw)?.toLocal() : null,
    );
  }

  static const AttemptRecord clean = AttemptRecord();

  /// Guesses before any delay is imposed. Fat-fingering a long passphrase a
  /// few times is normal and should not be punished.
  static const int freeAttempts = 4;

  final int failures;
  final DateTime? lockedUntil;

  /// How long the next failure will lock the user out for.
  static Duration penaltyFor(int failures) {
    if (failures <= freeAttempts) return Duration.zero;
    return switch (failures - freeAttempts) {
      1 => const Duration(seconds: 30),
      2 => const Duration(minutes: 1),
      3 => const Duration(minutes: 2),
      4 => const Duration(minutes: 5),
      _ => const Duration(minutes: 15),
    };
  }

  AttemptRecord afterFailure(DateTime now) {
    final next = failures + 1;
    final penalty = penaltyFor(next);
    return AttemptRecord(
      failures: next,
      lockedUntil: penalty == Duration.zero ? null : now.add(penalty),
    );
  }

  /// Remaining lockout at [now], or zero when the user may try again.
  Duration remainingAt(DateTime now) {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isLockedAt(DateTime now) => remainingAt(now) > Duration.zero;

  Map<String, Object?> toJson() => <String, Object?>{
    'failures': failures,
    if (lockedUntil != null) 'lockedUntil': lockedUntil!.toIso8601String(),
  };
}
