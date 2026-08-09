import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/planner_task.dart';
import 'notification_scheduler.dart';

class FlutterNotificationScheduler implements NotificationScheduler {
  FlutterNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin
        .initialize(const InitializationSettings(android: android, iOS: ios));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  @override
  Future<void> schedule(PlannerTask task) async {
    final scheduledAt = task.notificationAt;
    await _plugin.cancel(_notificationId(task.id));
    if (scheduledAt.isBefore(DateTime.now())) return;
    final location = tz.getLocation(task.timeZoneId);
    final date = tz.TZDateTime.from(scheduledAt.toUtc(), location);
    final localStart = tz.TZDateTime.from(task.startAt.toUtc(), location);
    await _plugin.zonedSchedule(
      _notificationId(task.id),
      task.title,
      '任务将在 ${_clock(localStart)} 开始',
      date,
      const NotificationDetails(
        android: AndroidNotificationDetails('tasks', '任务提醒',
            channelDescription: 'Focus Flow 的任务提醒'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:${task.id}',
    );
  }

  @override
  Future<void> cancel(String taskId) => _plugin.cancel(_notificationId(taskId));

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> rescheduleAll(Iterable<PlannerTask> tasks) async {
    await cancelAll();
    for (final task in tasks) {
      if (task.isCompleted) continue;
      await schedule(task);
    }
  }

  int _notificationId(String id) =>
      id.codeUnits.fold(0, (value, code) => (value * 31 + code) & 0x7fffffff);

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
