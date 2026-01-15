import 'package:alarm/alarm.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
void androidAlarmCallback() async {
  debugPrint(
    "🚀 AndroidAlarmManager triggered! Launching app via AndroidIntent...",
  );

  try {
    // Launch app explicitly
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: 'com.example.aplikasi_pengingat_tidur',
      componentName: 'com.example.aplikasi_pengingat_tidur.MainActivity',
      category: 'android.intent.category.LAUNCHER',
      flags: [
        Flag.FLAG_ACTIVITY_NEW_TASK,
        Flag.FLAG_ACTIVITY_CLEAR_TOP,
        Flag.FLAG_ACTIVITY_SINGLE_TOP,
        Flag.FLAG_ACTIVITY_REORDER_TO_FRONT,
        // Custom flags not in enum can be passed as int if needed, but these should suffice
      ],
      arguments: <String, dynamic>{
        'alarm_triggered': true,
        'show_alarm_overlay': true,
      },
    );

    await intent.launch();
    debugPrint("✅ App launch intent sent via AndroidIntent");
  } catch (e) {
    debugPrint("❌ Failed to launch app via AndroidIntent: $e");
  }
}

class AlarmService {
  static const int alarmId = 1;
  static const int androidAlarmId = 777;

  /// Initialize the alarm service
  static Future<void> init() async {
    await Alarm.init();
    await AndroidAlarmManager.initialize();
  }

  /// Schedule alarm for the given time
  /// If the time has already passed today, it will schedule for tomorrow
  static Future<bool> scheduleAlarm({
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return _setAlarm(scheduledDate);
  }

  /// Schedule alarm at a specific DateTime (for testing)
  static Future<bool> scheduleAlarmAt(DateTime dateTime) async {
    return _setAlarm(dateTime);
  }

  /// Internal method to set the alarm
  static Future<bool> _setAlarm(DateTime scheduledDate) async {
    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: scheduledDate,
      assetAudioPath: 'assets/audio/alarm_sound.mp3',
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      volumeEnforced: true,
      fadeDuration: 0.0,
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      notificationSettings: const NotificationSettings(
        title: '🌙 Waktunya Tidur!',
        body: 'Ketuk untuk membuka pengingat tidur',
        stopButton: 'Matikan',
        icon: 'notification_icon',
      ),
    );

    // Schedule primary alarm
    final result = await Alarm.set(alarmSettings: alarmSettings);

    // Schedule secondary "force wake" alarm
    // We schedule it 1 second after the main alarm to ensure notification is already there
    // or same time. Let's do same time.
    try {
      await AndroidAlarmManager.oneShotAt(
        scheduledDate,
        androidAlarmId,
        androidAlarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
      );
      debugPrint(
        "✅ Secondary AndroidAlarmManager force-wake scheduled for $scheduledDate",
      );
    } catch (e) {
      debugPrint("❌ Failed to schedule secondary alarm: $e");
    }

    debugPrint('Alarm scheduled for $scheduledDate: $result');
    return result;
  }

  /// Cancel the alarm
  static Future<bool> cancelAlarm() async {
    try {
      await AndroidAlarmManager.cancel(androidAlarmId);
    } catch (e) {
      debugPrint("Error cancelling AndroidAlarmManager: $e");
    }

    final result = await Alarm.stop(alarmId);
    debugPrint('Alarm cancelled: $result');
    return result;
  }

  /// Check if alarm is currently set
  static Future<bool> isAlarmSet() async {
    final alarm = await Alarm.getAlarm(alarmId);
    return alarm != null;
  }

  /// Get the scheduled alarm time
  static Future<DateTime?> getScheduledTime() async {
    final alarm = await Alarm.getAlarm(alarmId);
    return alarm?.dateTime;
  }

  /// Get time remaining async
  static Future<Duration?> getTimeRemainingAsync() async {
    final scheduledTime = await getScheduledTime();
    if (scheduledTime == null) return null;

    final now = DateTime.now();
    if (scheduledTime.isBefore(now)) return null;

    return scheduledTime.difference(now);
  }

  /// Format time remaining as readable string
  static String formatTimeRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours jam $minutes menit';
    } else {
      return '$minutes menit';
    }
  }

  /// Reschedule alarm for the next day (same time)
  static Future<bool> rescheduleForTomorrow() async {
    final alarm = await Alarm.getAlarm(alarmId);
    if (alarm == null) return false;

    final hour = alarm.dateTime.hour;
    final minute = alarm.dateTime.minute;

    await cancelAlarm();

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, hour, minute);

    return _setAlarm(tomorrow);
  }
}
