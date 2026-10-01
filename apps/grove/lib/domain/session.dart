import 'package:paper/paper.dart';

import 'species.dart';

/// How a focus session ended.
enum SessionOutcome {
  /// Ran to the planned duration. Plants a tree and counts toward unlocks.
  completed,

  /// The user gave up, or left the app in strict mode. Recorded on purpose:
  /// a withered stump in the garden is the whole point of the mechanic, and
  /// hiding failures would make the garden a flattering lie.
  abandoned,
}

/// One attempt at focusing.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.species,
    required this.planned,
    required this.startedAt,
    required this.elapsed,
    required this.outcome,
    this.tag,
  });

  factory FocusSession.fromJson(Map<String, Object?> json) {
    final startedAt = DateTime.parse(json['startedAt']! as String);
    return FocusSession(
      id: json['id']! as String,
      // An unknown species name means the file was written by a newer build.
      // Falling back to the starter species keeps the garden openable instead
      // of throwing the user out of their own data.
      species: Species.byName(json['species'] as String? ?? '') ?? Species.sprout,
      planned: Duration(seconds: json['plannedSeconds']! as int),
      startedAt: startedAt.toLocal(),
      elapsed: Duration(seconds: json['elapsedSeconds']! as int),
      outcome: json['outcome'] == SessionOutcome.completed.name
          ? SessionOutcome.completed
          : SessionOutcome.abandoned,
      tag: json['tag'] as String?,
    );
  }

  final String id;
  final Species species;

  /// What the user signed up for.
  final Duration planned;

  final DateTime startedAt;

  /// Time actually spent before the session ended. Equal to [planned] on a
  /// completed session, shorter on an abandoned one.
  final Duration elapsed;

  final SessionOutcome outcome;

  /// Optional note: what the session was for.
  final String? tag;

  bool get isCompleted => outcome == SessionOutcome.completed;

  /// The calendar day this session is filed under - where it *started*.
  ///
  /// A session begun at 23:50 and finished at 00:15 belongs to the day the
  /// user sat down, which is both how they remember it and what keeps a
  /// late-night session from silently starting tomorrow's streak.
  Day get day => Day.fromDateTime(startedAt);

  /// How far the attempt got, 0 to 1.
  double get completion {
    if (planned.inSeconds <= 0) return 1;
    return (elapsed.inSeconds / planned.inSeconds).clamp(0.0, 1.0);
  }

  /// A stable per-session number used to vary the procedural tree, so the
  /// same session always draws the same tree.
  int get seed => id.hashCode & 0x7fffffff;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'species': species.name,
    'plannedSeconds': planned.inSeconds,
    'startedAt': startedAt.toIso8601String(),
    'elapsedSeconds': elapsed.inSeconds,
    'outcome': outcome.name,
    if (tag != null && tag!.isNotEmpty) 'tag': tag,
  };

  @override
  bool operator ==(Object other) => other is FocusSession && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FocusSession($id, ${species.name}, ${outcome.name}, $day)';
}
