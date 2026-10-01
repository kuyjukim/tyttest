import 'package:flutter/foundation.dart';

import '../domain/active_session.dart';
import '../domain/session.dart';
import '../domain/settings.dart';
import '../domain/species.dart';

enum SessionPhase {
  /// Nothing running. The dial is live.
  idle,

  /// A session is counting down.
  running,

  /// Just finished successfully; the reward screen is showing.
  succeeded,

  /// Just ended early; the withered screen is showing.
  failed,
}

/// Why a session ended early.
enum FailureReason {
  /// The user pressed the give-up button.
  gaveUp,

  /// The app went to the background for longer than the allowance while
  /// strict mode was on.
  leftApp,

  /// The app was not running when the session should have been.
  appClosed,
}

/// The focus session state machine.
///
/// Two decisions shape this class.
///
/// **Elapsed time comes from the wall clock, never from counting ticks.** A
/// tick-counting timer drifts, stops when the OS throttles timers, and can be
/// starved by a busy frame; a 25-minute session would quietly become 27. Here
/// a tick only triggers a repaint, and [elapsed] is always
/// `now - startedAt`, so a missed tick costs a frame rather than a minute.
///
/// **There is no pause.** Pausing is the feature that makes a commitment
/// device pointless, so the only ways out are finishing and giving up.
class SessionController extends ChangeNotifier {
  SessionController({
    required DateTime Function() clock,
    required String Function() idFactory,
  }) : _clock = clock,
       _idFactory = idFactory;

  /// How long the app may be in the background before strict mode calls it.
  ///
  /// Not zero, because iOS foregrounds other things without being asked - an
  /// incoming call, a system alert - and a 50-minute session should survive
  /// glancing at one.
  static const Duration backgroundAllowance = Duration(seconds: 20);

  final DateTime Function() _clock;
  final String Function() _idFactory;

  SessionPhase _phase = SessionPhase.idle;
  SessionPhase get phase => _phase;

  ActiveSession? _active;

  /// The running session, or null when idle.
  ActiveSession? get active => _active;

  FocusSession? _result;

  /// The session that just ended, while [phase] is succeeded or failed.
  FocusSession? get result => _result;

  FailureReason? _failureReason;
  FailureReason? get failureReason => _failureReason;

  DateTime? _backgroundedAt;

  bool get isRunning => _phase == SessionPhase.running;

  /// Time spent in the current session so far, clamped to what was planned.
  Duration get elapsed {
    final active = _active;
    if (active == null) return Duration.zero;
    final raw = _clock().difference(active.startedAt);
    if (raw.isNegative) return Duration.zero;
    return raw > active.planned ? active.planned : raw;
  }

  Duration get remaining {
    final active = _active;
    if (active == null) return Duration.zero;
    return active.planned - elapsed;
  }

  /// 0 to 1. Drives how grown the tree is.
  double get progress {
    final active = _active;
    if (active == null || active.planned.inSeconds <= 0) return 0;
    return (elapsed.inSeconds / active.planned.inSeconds).clamp(0.0, 1.0);
  }

  /// Begins a session. Ignored when one is already running.
  ActiveSession? start({
    required Species species,
    required Duration planned,
    String? tag,
  }) {
    if (_phase == SessionPhase.running) return null;
    final clamped = planned < GroveSettings.minDuration
        ? GroveSettings.minDuration
        : (planned > GroveSettings.maxDuration
              ? GroveSettings.maxDuration
              : planned);
    final session = ActiveSession(
      id: _idFactory(),
      species: species,
      planned: clamped,
      startedAt: _clock(),
      tag: (tag == null || tag.trim().isEmpty) ? null : tag.trim(),
    );
    _active = session;
    _phase = SessionPhase.running;
    _result = null;
    _failureReason = null;
    _backgroundedAt = null;
    notifyListeners();
    return session;
  }

  /// Recomputes state against the clock. Call once a second while running.
  ///
  /// Returns the finished session when this tick ended it, so the caller can
  /// persist it; null otherwise.
  FocusSession? tick() {
    if (_phase != SessionPhase.running) return null;
    final active = _active!;
    if (elapsed < active.planned) {
      notifyListeners();
      return null;
    }
    return _finish(
      FocusSession(
        id: active.id,
        species: active.species,
        planned: active.planned,
        startedAt: active.startedAt,
        elapsed: active.planned,
        outcome: SessionOutcome.completed,
        tag: active.tag,
      ),
      phase: SessionPhase.succeeded,
    );
  }

  /// Ends the session early at the user's request.
  FocusSession? giveUp() => _abandon(FailureReason.gaveUp);

  /// Call from `didChangeAppLifecycleState` when the app leaves the foreground.
  void onBackgrounded() {
    if (_phase != SessionPhase.running) return;
    _backgroundedAt ??= _clock();
  }

  /// Call when the app returns to the foreground.
  ///
  /// Returns a finished session when the absence ended the run - either
  /// because strict mode's allowance was exceeded, or because the planned
  /// time elapsed while the app was away.
  FocusSession? onForegrounded({required bool strict}) {
    if (_phase != SessionPhase.running) return null;
    final leftAt = _backgroundedAt;
    _backgroundedAt = null;

    if (strict && leftAt != null) {
      final away = _clock().difference(leftAt);
      if (away > backgroundAllowance) return _abandon(FailureReason.leftApp);
    }
    // Not away long enough to matter, or lenient mode: the normal tick path
    // credits the time that passed while we were gone.
    return tick();
  }

  /// Records a session that was interrupted by the app not running at all.
  ///
  /// The caller resolves the persisted [ActiveSession] and hands the outcome
  /// in, so this only has to surface it.
  void adoptRecovered(FocusSession recovered) {
    _active = null;
    _result = recovered;
    _phase = recovered.isCompleted
        ? SessionPhase.succeeded
        : SessionPhase.failed;
    _failureReason = recovered.isCompleted ? null : FailureReason.appClosed;
    notifyListeners();
  }

  /// Dismisses the result screen and returns to idle.
  void acknowledge() {
    if (_phase == SessionPhase.idle || _phase == SessionPhase.running) return;
    _result = null;
    _failureReason = null;
    _phase = SessionPhase.idle;
    notifyListeners();
  }

  FocusSession? _abandon(FailureReason reason) {
    if (_phase != SessionPhase.running) return null;
    final active = _active!;
    _failureReason = reason;
    return _finish(
      FocusSession(
        id: active.id,
        species: active.species,
        planned: active.planned,
        startedAt: active.startedAt,
        elapsed: elapsed,
        outcome: SessionOutcome.abandoned,
        tag: active.tag,
      ),
      phase: SessionPhase.failed,
    );
  }

  FocusSession _finish(FocusSession session, {required SessionPhase phase}) {
    _active = null;
    _result = session;
    _phase = phase;
    _backgroundedAt = null;
    notifyListeners();
    return session;
  }
}
