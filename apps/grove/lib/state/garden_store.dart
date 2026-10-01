import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:paper/paper.dart';

import '../data/garden_repository.dart';
import '../domain/session.dart';
import '../domain/settings.dart';
import '../domain/species.dart';
import '../domain/stats.dart';
import '../platform/session_alarm.dart';
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
    SessionAlarm alarm = const SilentAlarm(),
  }) : _repository = repository,
       _controller = controller,
       _clock = clock,
       _alarm = alarm {
    _controller.addListener(notifyListeners);
  }

  final GardenRepository _repository;
  final SessionController _controller;
  final DateTime Function() _clock;
  final SessionAlarm _alarm;

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
      // The previous run may have gone away with an alarm armed. That
      // session is over now, however it ended, so the notification would
      // only announce a tree that is already in the garden or already dead.
      await _alarm.disarm();
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
    // Asked for here and not at launch, because this is the first moment the
    // user has said they want a timer, and not awaited, because the OS
    // prompt must not hold up the session they just started. The answer is
    // only needed later, when the app leaves the foreground.
    if (settings.notify) unawaited(_alarm.requestPermission());
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

  /// Hands the lifecycle change to the controller and arms the end-of-session
  /// notification.
  ///
  /// Arming happens here rather than at [startSession] on purpose. While
  /// Grove is on screen the countdown and the finish haptic already say the
  /// time is up, so a notification would be noise - and on Android there is
  /// no way to post one that the shade will not show. Arming on the way out
  /// and dropping it on the way back in means the alarm exists exactly while
  /// it is the only thing that can speak.
  ///
  /// [alarm] carries the localised copy; without it nothing is scheduled,
  /// which is what keeps every test free of a notification plugin.
  Future<void> onBackgrounded({AlarmCopy? alarm}) async {
    _controller.onBackgrounded();
    final active = _controller.active;
    if (alarm == null || active == null || !settings.notify) return;
    await _alarm.arm(
      moment: active.startedAt.add(active.planned),
      copy: alarm,
    );
  }

  Future<void> onForegrounded() async {
    // Before resolving, so that a session the return has just killed cannot
    // leave a notification behind to go off afterwards.
    await _alarm.disarm();
    final finished = _controller.onForegrounded(strict: settings.strict);
    if (finished != null) await _record(finished);
  }

  void acknowledge() {
    _recovered = null;
    _controller.acknowledge();
  }

  /// Records whether the user wants the end-of-session notification, asking
  /// the OS for permission the first time they say yes.
  ///
  /// The setting and the permission are deliberately two things. This stores
  /// the intent; the OS decides whether anything is delivered, and the only
  /// honest moment to ask it is the one where the user has just said they
  /// want it.
  Future<void> setNotify(bool value) async {
    await updateSettings(settings.copyWith(notify: value));
    if (value) await _alarm.requestPermission();
  }

  Future<void> updateSettings(GroveSettings next) async {
    final wasNotifying = settings.notify;
    _data = _data.copyWith(settings: next);
    if (wasNotifying && !next.notify) await _alarm.disarm();
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

  // Deliberately does not disarm. It looks like the one place that should,
  // since every session ends here, but an alarm is only ever armed while the
  // app is away - and on Android a Dart timer keeps running while the
  // activity is stopped, so the tick that lands here can be the one a second
  // after the notification was posted. Cancelling then would pull the banner
  // back out of the shade before the user ever saw it, which is precisely the
  // thing this feature exists to prevent. The alarm is dropped on the way
  // back in instead, by [onForegrounded].
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
