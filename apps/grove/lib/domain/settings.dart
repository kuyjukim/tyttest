import 'package:flutter/material.dart' show ThemeMode;

import 'species.dart';

/// User preferences. Small, flat, and persisted alongside the sessions.
class GroveSettings {
  const GroveSettings({
    this.themeMode = ThemeMode.system,
    this.strict = true,
    this.defaultDuration = const Duration(minutes: 25),
    this.dailyGoal = const Duration(minutes: 90),
    this.preferredSpecies = Species.sprout,
    this.haptics = true,
  });

  factory GroveSettings.fromJson(Map<String, Object?> json) => GroveSettings(
    themeMode: switch (json['themeMode']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    strict: json['strict'] as bool? ?? true,
    defaultDuration: Duration(
      minutes: _clampMinutes(json['defaultMinutes'], fallback: 25),
    ),
    dailyGoal: Duration(
      minutes: _clampMinutes(json['dailyGoalMinutes'], fallback: 90, max: 960),
    ),
    preferredSpecies:
        Species.byName(json['species'] as String? ?? '') ?? Species.sprout,
    haptics: json['haptics'] as bool? ?? true,
  );

  /// Shortest and longest session the dial offers.
  static const Duration minDuration = Duration(minutes: 5);
  static const Duration maxDuration = Duration(minutes: 120);

  /// The dial moves in whole increments of this.
  static const Duration durationStep = Duration(minutes: 5);

  final ThemeMode themeMode;

  /// When true, leaving the app during a session kills the tree.
  ///
  /// Defaults on: the commitment is the product. It is a setting rather than a
  /// rule because iOS can foreground another app without the user asking - a
  /// call, an alarm - and losing a 50-minute session to that would be unjust.
  final bool strict;

  final Duration defaultDuration;
  final Duration dailyGoal;
  final Species preferredSpecies;
  final bool haptics;

  GroveSettings copyWith({
    ThemeMode? themeMode,
    bool? strict,
    Duration? defaultDuration,
    Duration? dailyGoal,
    Species? preferredSpecies,
    bool? haptics,
  }) => GroveSettings(
    themeMode: themeMode ?? this.themeMode,
    strict: strict ?? this.strict,
    defaultDuration: defaultDuration ?? this.defaultDuration,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    preferredSpecies: preferredSpecies ?? this.preferredSpecies,
    haptics: haptics ?? this.haptics,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'strict': strict,
    'defaultMinutes': defaultDuration.inMinutes,
    'dailyGoalMinutes': dailyGoal.inMinutes,
    'species': preferredSpecies.name,
    'haptics': haptics,
  };

  /// Reads a persisted minute count, defending against a hand-edited or
  /// newer-version file that holds a string, a double or something absurd.
  static int _clampMinutes(Object? raw, {required int fallback, int max = 120}) {
    final value = switch (raw) {
      final int v => v,
      final double v => v.round(),
      final String v => int.tryParse(v) ?? fallback,
      _ => fallback,
    };
    return value.clamp(1, max);
  }
}
