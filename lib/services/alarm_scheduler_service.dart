import 'package:flutter/services.dart';

/// Bridges Dart ↔ native AlarmManager.
///
/// Flow when app is killed:
///   AlarmManager fires → AlarmReceiver → startActivity(MainActivity)
///   → screen wakes → Flutter starts → getLaunchReminderId() → AlarmScreen
///
/// Flow when app is backgrounded:
///   AlarmManager fires → AlarmReceiver → onNewIntent(MainActivity)
///   → alarmChannel.invokeMethod("onAlarm") → setAlarmHandler callback → AlarmScreen
///
/// Flow when app is in foreground:
///   Dart Timer fires → directly pushes AlarmScreen → cancelAlarm() called
class AlarmSchedulerService {
  static const _alarmCh = MethodChannel('com.task_reminder/alarm');
  static const _permCh  = MethodChannel('com.task_reminder/permissions');

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Call once from main(). Requests required permissions and returns the
  /// reminder ID if the app was cold-launched by an alarm (killed-app case).
  static Future<String?> init() async {
    // POST_NOTIFICATIONS (Android 13+)
    try {
      await _permCh.invokeMethod('requestNotificationsPermission');
    } catch (_) {}

    // Battery optimisation exemption – critical for Samsung/Xiaomi/OnePlus
    await _requestBatteryOptimization();

    // USE_FULL_SCREEN_INTENT – Android 14+ requires explicit user grant
    await _requestFullScreenIntentIfNeeded();

    // SYSTEM_ALERT_WINDOW ("Display over other apps") – required on Android 10+
    // and strict OEMs (Samsung/Xiaomi/OnePlus) for AlarmScreen to open
    // automatically from background without the user tapping the notification.
    await _requestOverlayPermissionIfNeeded();

    // If app was killed and launched by AlarmReceiver, this is non-null.
    return _alarmCh.invokeMethod<String>('getLaunchReminderId');
  }

  /// Returns the reminder ID if an alarm fired while the app was backgrounded
  /// (notification tapped → onNewIntent set the ID). Same underlying call as
  /// getLaunchReminderId — reads once then clears.
  static Future<String?> checkPendingAlarm() =>
      _alarmCh.invokeMethod<String>('getLaunchReminderId');

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Schedule a native AlarmManager.setAlarmClock() alarm.
  /// Fires even in Doze mode. No SCHEDULE_EXACT_ALARM permission required.
  static Future<void> schedule({
    required int id,
    required DateTime scheduledTime,
    required String reminderId,
  }) async {
    await _alarmCh.invokeMethod('scheduleAlarm', {
      'id': id,
      'timeMillis': scheduledTime.millisecondsSinceEpoch,
      'reminderId': reminderId,
    });
  }

  static Future<void> cancel(int id) async {
    try {
      await _alarmCh.invokeMethod('cancelAlarm', {'id': id});
    } catch (_) {}
  }

  static Future<void> startAlarmRingtone() async {
    try {
      await _alarmCh.invokeMethod('startAlarmRingtone');
    } catch (_) {}
  }

  static Future<void> stopAlarmRingtone() async {
    try {
      await _alarmCh.invokeMethod('stopAlarmRingtone');
    } catch (_) {}
  }

  // ── Internal permission helpers ───────────────────────────────────────────

  static Future<void> _requestBatteryOptimization() async {
    try {
      final isIgnoring =
          await _permCh.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
              false;
      if (!isIgnoring) {
        await _permCh.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (_) {}
  }

  static Future<void> _requestFullScreenIntentIfNeeded() async {
    try {
      final canUse =
          await _permCh.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
      if (!canUse) {
        await _permCh.invokeMethod('requestFullScreenIntentPermission');
      }
    } catch (_) {}
  }

  static Future<void> _requestOverlayPermissionIfNeeded() async {
    try {
      final canDraw =
          await _permCh.invokeMethod<bool>('canDrawOverlays') ?? false;
      if (!canDraw) {
        await _permCh.invokeMethod('requestOverlayPermission');
      }
    } catch (_) {}
  }
}
