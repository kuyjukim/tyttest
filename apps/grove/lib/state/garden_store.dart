import 'package:flutter/foundation.dart';

import '../data/garden_repository.dart';
import '../domain/day.dart';
import '../domain/session.dart';
import '../domain/settings.dart';
import '../domain/species.dart';
import '../domain/stats.dart';
import 'session_controller.dart';

/// Application state for Grove.
///
/// Holds the loaded [GardenData], derives everything on screen through
/// [Stats], and owns persistence. The [SessionController] stays pure - it
/// knows about clocks and phases, not about files - and this class is the one
/// place that writes.
class GardenStore extends ChangeNotifier {
  GardenStore({
    required GardenRepository repository,
    required SessionController controller,
    required DateTime Function() clock,
  }) : _repository = repository,
       _controller = controller,
       _clock = clock {
    _controller.addListener(notifyListeners);
  }

  final GardenRepository _repository;
  final SessionController _controller;
  final DateTime Function() _clock;

  GardenData _data = GardenData.empty;
  bool _ready = false;

  /// Set when startup found an unfinished session from a previous launch, so
  /// the UI can explain the tree the user did not watch die.
  FocusSession? _recovered;

  SessionController get controller => _controller;

  /// False until [initialize] has finished; the UI shows a splash until then.
  bool get ready => _ready;

  List<FocusSession> get sessions => _data.sessions;
  GroveSettings get settings => _data.settings;
  FocusSession? get recovered => _recovered;

  Day get today => Day.fromDateTime(_clock());

  Duration get totalFocused => Stats.totalFocused(_data.sessions);
  int get totalFocusedMinutes => totalFocused.inMinutes;
  Streak get streak => Stats.streak(_data.sessions, today: today);
  DayTotal get todayTotal => Stats.totalFor(_data.sessions, today);

  List<Species> get unlockedSpecies => Species.unlockedAt(totalFocusedMinutes);
  Species? get nextUnlock => Species.nextLockedAfter(totalFocusedMinutes);

  /// Fraction of today's goal met, 0 to 1.
  double get goalProgress {
    final goal = settings.dailyGoal.inSeconds;
    if (goal <= 0) return 1;
    return (todayTotal.focused.inSeconds / goal).clamp(0.0, 1.0);
  }

  /// Loads persisted data and resolves any session left in flight.
  Future<void> initialize() async {
    _data = await _repository.load();

    final active = _data.active;
    if (active != null) {
      // The app stopped running mid-session. Resolve it against the clock and
      // record the outcome, so quitting can never be a way out.
      final resolved = active.resolve(
        now: _clock(),
        strict: _data.settings.strict,
      );
      _data = _data.copyWith(
        sessions: <FocusSession>[resolved, ..._data.sessions],
        clearActive: true,
      );
      _recovered = resolved;
      _controller.adoptRecovered(resolved);
      await _persist();
    }

    _ready = true;
    notifyListeners();
  }

  /// Starts a session and records it as in flight before returning.
  Future<void> startSession({
    required Species species,
    required Duration planned,
    String? tag,
  }) async {
    final started = _controller.start(
      species: species,
      planned: planned,
      tag: tag,
    );
    if (started == null) return;
    _recovered = null;
    _data = _data.copyWith(
      active: started,
      settings: settings.copyWith(
        defaultDuration: started.planned,
        preferredSpecies: species,
      ),
    );
    await _persist();
  }

  /// Drives the controller forward; persists if the tick ended the session.
  Future<void> tick() async {
    final finished = _controller.tick();
    if (finished != null) await _record(finished);
  }

  Future<void> giveUp() async {
    final finished = _controller.giveUp();
    if (finished != null) await _record(finished);
  }

  void onBackgrounded() => _controller.onBackgrounded();

  Future<void> onForegrounded() async {
    final finished = _controller.onForegrounded(strict: settings.strict);
    if (finished != null) await _record(finished);
  }

  void acknowledge() {
    _recovered = null;
    _controller.acknowledge();
  }

  Future<void> updateSettings(GroveSettings next) async {
    _data = _data.copyWith(settings: next);
    await _persist();
    notifyListeners();
  }

  /// Deletes every session, keeping settings. Irreversible by design - the
  /// confirm dialog is the safety, not a hidden undo.
  Future<void> clearGarden() async {
    _data = _data.copyWith(sessions: const <FocusSession>[], clearActive: true);
    await _persist();
    notifyListeners();
  }

  Future<void> _record(FocusSession session) async {
    _data = _data.copyWith(
      sessions: <FocusSession>[
        session,
        // A recovered session can already be in the list; replacing by id
        // keeps a double-resolve from duplicating a tree.
        ..._data.sessions.where((s) => s.id != session.id),
      ],
      clearActive: true,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() => _repository.save(_data);

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    super.dispose();
  }
}
