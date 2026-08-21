import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/planner_task.dart';
import 'notification_scheduler.dart';

typedef NotificationTapCallback = void Function(String taskId);

/// The small, testable boundary between scheduling policy and the platform
/// notifications plugin.
abstract interface class LocalNotificationBackend {
  Future<void> initialize(void Function(String? payload) onNotificationTap);

  Future<bool> requestPermissions();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledAt,
    required String payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

class FlutterNotificationScheduler implements NotificationScheduler {
  FlutterNotificationScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    LocalNotificationBackend? backend,
    NotificationTapCallback? onNotificationTap,
    DateTime Function()? now,
  })  : assert(plugin == null || backend == null),
        _backend = backend ??
            FlutterLocalNotificationBackend(
              plugin ?? FlutterLocalNotificationsPlugin(),
            ),
        _onNotificationTap = onNotificationTap,
        _now = now ?? DateTime.now;

  final LocalNotificationBackend _backend;
  final NotificationTapCallback? _onNotificationTap;
  final DateTime Function() _now;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    await _backend.initialize(_handleNotificationTap);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() => _backend.requestPermissions();

  @override
  Future<void> schedule(PlannerTask task) async {
    final id = _notificationId(task.id);
    await _backend.cancel(id);
    if (!task.reminderEnabled ||
        task.status != TaskStatus.planned ||
        task.deletedAt != null) {
      return;
    }

    final scheduledAt = task.notificationAt;
    if (!scheduledAt.isAfter(_now())) return;

    final location = tz.getLocation(task.timeZoneId);
    final date = tz.TZDateTime.from(scheduledAt.toUtc(), location);
    final localStart = tz.TZDateTime.from(task.startAt.toUtc(), location);
    await _backend.schedule(
      id: id,
      title: task.title,
      body: _notificationBody(task, localStart),
      scheduledAt: date,
      payload: 'task:${task.id}',
    );
  }

  @override
  Future<void> cancel(String taskId) =>
      _backend.cancel(_notificationId(taskId));

  @override
  Future<void> cancelAll() => _backend.cancelAll();

  @override
  Future<void> rescheduleAll(Iterable<PlannerTask> tasks) async {
    await cancelAll();
    for (final task in tasks) {
      await schedule(task);
    }
  }

  void _handleNotificationTap(String? payload) {
    const prefix = 'task:';
    if (payload == null || !payload.startsWith(prefix)) return;
    final taskId = payload.substring(prefix.length);
    if (taskId.isNotEmpty) _onNotificationTap?.call(taskId);
  }

  int _notificationId(String id) =>
      id.codeUnits.fold(0, (value, code) => (value * 31 + code) & 0x7fffffff);

  String _notificationBody(PlannerTask task, DateTime localStart) {
    final start = _clock(localStart);
    return switch (task.kind) {
      ScheduleItemKind.course =>
        '$start 上课 · ${task.location.trim().isEmpty ? '地点待定' : task.location.trim()}',
      ScheduleItemKind.task => '任务将在 $start 开始',
      ScheduleItemKind.timeBlock => '时间段将在 $start 开始',
    };
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class FlutterLocalNotificationBackend implements LocalNotificationBackend {
  FlutterLocalNotificationBackend(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize(
    void Function(String? payload) onNotificationTap,
  ) async {
    const android = AndroidInitializationSettings('ic_stat_focus_flow');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap(response.payload);
      },
    );
  }

  @override
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final notifications = await android.requestNotificationsPermission();
      final exactAlarms = await android.requestExactAlarmsPermission();
      return notifications != false && exactAlarms != false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledAt,
    required String payload,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_reminders_v2',
          '课程与任务提醒',
          channelDescription: 'Focus Flow 的课程和任务提醒',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.event,
          icon: 'ic_stat_focus_flow',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
