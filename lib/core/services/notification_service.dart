import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

class NotificationService {
  static const _morningId = 1001;
  static const _eveningId = 1002;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzData.initializeTimeZones();
    // Set the local timezone to the device's actual timezone so that
    // scheduled notifications fire at the correct wall-clock time.
    final deviceTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTz));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Schedule 8 AM morning summary notification (daily recurring).
  Future<void> scheduleMorningSummary() async {
    await _plugin.zonedSchedule(
      _morningId,
      '☀️ Good morning! Your financial day starts now.',
      'Check your budget and track today\'s spending in The Ledger.',
      _nextInstanceOf(8, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'echelon_morning',
          'Morning Recap',
          channelDescription: 'Daily 8 AM financial summary',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule 9 PM evening nudge notification (daily recurring).
  Future<void> scheduleEveningNudge() async {
    await _plugin.zonedSchedule(
      _eveningId,
      '🌙 Did you log today\'s expenses?',
      'A quick 30-second review keeps your finances on track. Open The Ledger.',
      _nextInstanceOf(21, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'echelon_evening',
          'Evening Nudge',
          channelDescription: 'Daily 9 PM spending review reminder',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<void> cancelMorning() async => _plugin.cancel(_morningId);
  Future<void> cancelEvening() async => _plugin.cancel(_eveningId);

  /// Returns the next occurrence of [hour]:[minute] in local time.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
