import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'session_alarm.dart';

/// The real [SessionAlarm], backed by `flutter_local_notifications`.
///
/// Nothing here can be exercised without a phone, so it is kept as thin as a
/// plugin wrapper can be: one notification, one id, no payload, no actions,
/// no taps to route. Everything that could be decided in Dart - when to arm,
/// what to say - is decided above this class, where it is tested.
class NotificationAlarm implements SessionAlarm {
  NotificationAlarm({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Only one alarm is ever pending, so the id is a constant.
  static const int _id = 1;

  /// Shown to the user in the Android notification settings, so it is worth
  /// naming after what it is rather than after the code that posts it.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'session_end',
    'Session finished',
    description: 'Tells you when a focus session is over.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  /// Android 14 stopped granting `SCHEDULE_EXACT_ALARM` on install, and the
  /// plugin throws rather than silently firing late. Checked once and cached,
  /// so a session start never waits on a platform round trip twice.
  bool? _exact;

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // All three false: the prompt belongs at the first session start,
        // where the user has just asked for a timer, not at the first launch,
        // where they have not yet seen what the app does.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    await _android?.createNotificationChannel(_channel);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => Platform.isAndroid
      ? _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
      : null;

  IOSFlutterLocalNotificationsPlugin? get _ios => Platform.isIOS
      ? _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
      : null;

  @override
  Future<bool> requestPermission() async => _guard(() async {
    await _initialize();
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    if (Platform.isAndroid) {
      final android = _android;
      final granted = await android?.requestNotificationsPermission() ?? false;
      // Never `requestExactAlarmsPermission`: that opens a system settings
      // screen, which backgrounds Grove - and in strict mode backgrounding
      // Grove is what kills the tree. Asking the user to choose between an
      // accurate alarm and the session they just started is not a choice
      // worth offering, so read the permission instead and live with it.
      _exact = await android?.canScheduleExactNotifications() ?? false;
      return granted;
    }
    return false;
  }, orElse: false);

  @override
  Future<void> arm({
    required DateTime moment,
    required AlarmCopy copy,
  }) async => _guard(() async {
    await _initialize();
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: copy.title,
      body: copy.body,
      // UTC on purpose. The alarm is a fixed instant a few minutes away, not
      // a wall-clock time, and naming the zone UTC is the one way to say that
      // which no DST transition, no travel and no tzdata download can bend.
      // It is also why this file needs no `initializeTimeZones` and no
      // platform zone lookup: `tz.UTC` exists without the database.
      scheduledDate: tz.TZDateTime.from(moment.toUtc(), tz.UTC),
      androidScheduleMode: await _scheduleMode(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: _channel.importance,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }, orElse: null);

  @override
  Future<void> disarm() async =>
      _guard(() => _plugin.cancel(id: _id), orElse: null);

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    _exact ??= await _android?.canScheduleExactNotifications() ?? false;
    // The fallback fires within a doze window of the right time rather than
    // at it. That is a worse timer, but a notification a few minutes late
    // beats the PlatformException the exact path throws without the
    // permission, which would be no notification at all.
    return _exact!
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Runs [body], turning any platform failure into [orElse].
  ///
  /// A notification is a courtesy. The session, the tree and the garden are
  /// the product, and none of them should ever be lost because an OS refused
  /// to post a banner.
  Future<T> _guard<T>(Future<T> Function() body, {required T orElse}) async {
    try {
      return await body();
    } on PlatformException catch (error) {
      debugPrint('grove: notification failed (${error.code})');
      return orElse;
    } on MissingPluginException {
      // No plugin registered: a unit test, or a platform Grove does not ship
      // on. Silence is the correct behaviour.
      return orElse;
    }
  }
}
