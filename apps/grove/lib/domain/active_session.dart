import 'session.dart';
import 'species.dart';

/// A session that was in flight when the app last stopped running.
///
/// This is persisted the moment a session starts, which is what makes
/// force-quitting the app a failure rather than a loophole. Without it, the
/// cheapest way to avoid a withered tree would be to swipe the app away -
/// and a commitment device with an escape hatch is not a commitment device.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.species,
    required this.planned,
    required this.startedAt,
    this.tag,
  });

  factory ActiveSession.fromJson(Map<String, Object?> json) => ActiveSession(
    id: json['id']! as String,
    species:
        Species.byName(json['species'] as String? ?? '') ?? Species.sprout,
    planned: Duration(seconds: json['plannedSeconds']! as int),
    startedAt: DateTime.parse(json['startedAt']! as String).toLocal(),
    tag: json['tag'] as String?,
  );

  final String id;
  final Species species;
  final Duration planned;
  final DateTime startedAt;
  final String? tag;

  /// Turns an interrupted session into a recorded one, given the time now.
  ///
  /// In lenient mode a session whose full duration had already passed before
  /// the app died is credited: the user did put the time in, and the app
  /// being killed by the OS is not their fault. In strict mode they left, and
  /// leaving is what strict mode exists to punish.
  FocusSession resolve({required DateTime now, required bool strict}) {
    final away = now.difference(startedAt);
    final elapsed = away.isNegative
        // A clock moved backwards while the app was closed. Credit nothing
        // rather than inventing a negative session.
        ? Duration.zero
        : (away > planned ? planned : away);
    final finished = !strict && elapsed >= planned;
    return FocusSession(
      id: id,
      species: species,
      planned: planned,
      startedAt: startedAt,
      elapsed: elapsed,
      outcome: finished ? SessionOutcome.completed : SessionOutcome.abandoned,
      tag: tag,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'species': species.name,
    'plannedSeconds': planned.inSeconds,
    'startedAt': startedAt.toIso8601String(),
    if (tag != null && tag!.isNotEmpty) 'tag': tag,
  };
}
