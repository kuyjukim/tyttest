import 'package:paper/paper.dart';

import '../domain/active_session.dart';
import '../domain/session.dart';
import '../domain/settings.dart';

/// Everything Grove persists: the sessions and the settings.
class GardenData {
  const GardenData({
    required this.sessions,
    required this.settings,
    this.active,
  });

  static const GardenData empty = GardenData(
    sessions: <FocusSession>[],
    settings: GroveSettings(),
  );

  final List<FocusSession> sessions;
  final GroveSettings settings;

  /// Set while a session is running, so an interrupted run can be resolved on
  /// the next launch instead of vanishing.
  final ActiveSession? active;

  GardenData copyWith({
    List<FocusSession>? sessions,
    GroveSettings? settings,
    ActiveSession? active,
    bool clearActive = false,
  }) => GardenData(
    sessions: sessions ?? this.sessions,
    settings: settings ?? this.settings,
    active: clearActive ? null : (active ?? this.active),
  );
}

/// Reads and writes [GardenData] as one JSON document.
///
/// Sessions are append-only in practice, so there is no per-record store and
/// no migration machinery: the file is small (a year of heavy use is a few
/// hundred kilobytes) and rewriting it whole is both simpler and atomic.
class GardenRepository {
  GardenRepository(KeyValueStore store)
    : _document = JsonDocument<GardenData>(
        store: store,
        key: 'grove.garden.v1',
        empty: () => GardenData.empty,
        decode: _decode,
        encode: _encode,
      );

  final JsonDocument<GardenData> _document;

  Future<GardenData> load({void Function(Object error)? onCorrupt}) =>
      _document.load(onCorrupt: onCorrupt);

  Future<void> save(GardenData data) => _document.save(data);

  static GardenData _decode(Map<String, Object?> json) {
    final rawSessions = json['sessions'];
    final sessions = <FocusSession>[];
    if (rawSessions is List) {
      for (final entry in rawSessions) {
        if (entry is! Map<String, Object?>) continue;
        try {
          sessions.add(FocusSession.fromJson(entry));
        } on Object {
          // One unreadable record must not cost the user the other 400.
          continue;
        }
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final rawSettings = json['settings'];
    final rawActive = json['active'];
    ActiveSession? active;
    if (rawActive is Map<String, Object?>) {
      try {
        active = ActiveSession.fromJson(rawActive);
      } on Object {
        active = null;
      }
    }

    return GardenData(
      sessions: sessions,
      settings: rawSettings is Map<String, Object?>
          ? GroveSettings.fromJson(rawSettings)
          : const GroveSettings(),
      active: active,
    );
  }

  static Map<String, Object?> _encode(GardenData data) => <String, Object?>{
    'version': 1,
    'sessions': <Object?>[for (final s in data.sessions) s.toJson()],
    'settings': data.settings.toJson(),
    if (data.active != null) 'active': data.active!.toJson(),
  };
}
