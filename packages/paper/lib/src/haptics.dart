import 'dart:async';

import 'package:flutter/services.dart';

/// Fire-and-forget haptics.
///
/// Haptics are garnish: a tap that produced no vibration is a disappointment,
/// but a tap that *did nothing* because the vibration failed is a bug. The
/// platform channel behind `HapticFeedback` throws `MissingPluginException`
/// wherever it is not implemented - the web, desktop, some Android builds,
/// and any widget test that has not mocked it - so every call here is both
/// unawaited and error-swallowing.
///
/// The rule that follows: never `await` a haptic before doing the real work.
abstract final class Buzz {
  /// A value changed under the finger: a dial step, a segment switch.
  static void select({bool enabled = true}) =>
      _fire(enabled, HapticFeedback.selectionClick);

  /// A deliberate action landed: a button that commits to something.
  static void tap({bool enabled = true}) =>
      _fire(enabled, HapticFeedback.mediumImpact);

  /// Something the user was waiting for completed.
  static void success({bool enabled = true}) =>
      _fire(enabled, HapticFeedback.heavyImpact);

  /// A refusal: an invalid entry, a locked control.
  static void reject({bool enabled = true}) =>
      _fire(enabled, HapticFeedback.vibrate);

  static void _fire(bool enabled, Future<void> Function() effect) {
    if (!enabled) return;
    unawaited(effect().catchError((Object _) {}));
  }
}
