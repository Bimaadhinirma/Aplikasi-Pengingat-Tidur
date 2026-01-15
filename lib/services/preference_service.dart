import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart' show TimeOfDay;

class PreferenceService {
  static const String _keyAlarmEnabled = 'alarm_enabled';
  static const String _keyAlarmHour = 'alarm_hour';
  static const String _keyAlarmMinute = 'alarm_minute';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Alarm enabled status
  bool get isAlarmEnabled => _prefs.getBool(_keyAlarmEnabled) ?? false;

  Future<void> setAlarmEnabled(bool enabled) async {
    await _prefs.setBool(_keyAlarmEnabled, enabled);
  }

  // Alarm time - default to 22:00 (10 PM - ideal sleep time)
  int get alarmHour => _prefs.getInt(_keyAlarmHour) ?? 22;

  Future<void> setAlarmHour(int hour) async {
    await _prefs.setInt(_keyAlarmHour, hour);
  }

  int get alarmMinute => _prefs.getInt(_keyAlarmMinute) ?? 0;

  Future<void> setAlarmMinute(int minute) async {
    await _prefs.setInt(_keyAlarmMinute, minute);
  }

  // Helper to get/set time as TimeOfDay
  TimeOfDay get alarmTime => TimeOfDay(hour: alarmHour, minute: alarmMinute);

  Future<void> setAlarmTime(TimeOfDay time) async {
    await setAlarmHour(time.hour);
    await setAlarmMinute(time.minute);
  }
}
