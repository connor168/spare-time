import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/domain/planner_task.dart';
import 'package:focus_flow/services/flutter_notification_scheduler.dart';
import 'package:focus_flow/services/notification_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('FlutterNotificationScheduler', () {
    late FakeLocalNotificationBackend backend;
    late FlutterNotificationScheduler scheduler;

    setUp(() {
      backend = FakeLocalNotificationBackend();
      scheduler = FlutterNotificationScheduler(
        backend: backend,
        now: () => DateTime.utc(2026, 8, 15),
      );
    });

    test('initialize does not request permissions', () async {
      await scheduler.initialize();
      await scheduler.initialize();

      expect(backend.initializeCalls, 1);
      expect(backend.permissionCalls, 0);
    });

    test('requestPermissions returns the backend result', () async {
      backend.permissionResult = false;

      expect(await scheduler.requestPermissions(), isFalse);
      expect(backend.permissionCalls, 1);
    });

    test('disabled reminders are cancelled and not scheduled', () async {
      await scheduler.schedule(_task(reminderEnabled: false));

      expect(backend.cancelledIds, hasLength(1));
      expect(backend.scheduled, isEmpty);
    });

    for (final status in [TaskStatus.completed, TaskStatus.todayIncomplete]) {
      test('$status reminders are cancelled and not scheduled', () async {
        await scheduler.schedule(_task(status: status));

        expect(backend.cancelledIds, hasLength(1));
        expect(backend.scheduled, isEmpty);
      });
    }

    test('course body contains local start time and location', () async {
      await scheduler.schedule(
        _task(
          kind: ScheduleItemKind.course,
          location: '教学楼 A203',
        ),
      );

      expect(backend.scheduled, hasLength(1));
      expect(backend.scheduled.single.title, '高等数学');
      expect(backend.scheduled.single.body, '08:30 上课 · 教学楼 A203');
      expect(backend.scheduled.single.payload, 'task:task-1');
    });

    test('course body uses a clear fallback when location is empty', () async {
      await scheduler.schedule(_task(kind: ScheduleItemKind.course));

      expect(backend.scheduled.single.body, '08:30 上课 · 地点待定');
    });

    test('task body keeps the start time', () async {
      await scheduler.schedule(_task());

      expect(backend.scheduled.single.body, '任务将在 08:30 开始');
    });

    test('rescheduleAll clears old reminders and applies filtering', () async {
      await scheduler.rescheduleAll([
        _task(id: 'planned'),
        _task(id: 'disabled', reminderEnabled: false),
        _task(id: 'incomplete', status: TaskStatus.todayIncomplete),
      ]);

      expect(backend.cancelAllCalls, 1);
      expect(backend.cancelledIds, hasLength(3));
      expect(backend.scheduled.map((item) => item.payload), ['task:planned']);
    });

    test('forwards valid notification tap payloads as task IDs', () async {
      String? tappedTaskId;
      scheduler = FlutterNotificationScheduler(
        backend: backend,
        onNotificationTap: (taskId) => tappedTaskId = taskId,
      );
      await scheduler.initialize();

      backend.tap('unrelated');
      expect(tappedTaskId, isNull);
      backend.tap('task:course-42');
      expect(tappedTaskId, 'course-42');
    });
  });

  test('NoopNotificationScheduler grants its no-op permission request',
      () async {
    const scheduler = NoopNotificationScheduler();

    expect(await scheduler.requestPermissions(), isTrue);
  });
}

PlannerTask _task({
  String id = 'task-1',
  ScheduleItemKind kind = ScheduleItemKind.task,
  String location = '',
  bool reminderEnabled = true,
  TaskStatus status = TaskStatus.planned,
}) {
  return PlannerTask(
    id: id,
    title: '高等数学',
    kind: kind,
    location: location,
    startAt: DateTime.utc(2026, 8, 16, 0, 30),
    endAt: DateTime.utc(2026, 8, 16, 2),
    timeZoneId: 'Asia/Shanghai',
    reminderMinutes: 5,
    reminderEnabled: reminderEnabled,
    status: status,
  );
}

class ScheduledCall {
  const ScheduledCall({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final tz.TZDateTime scheduledAt;
  final String payload;
}

class FakeLocalNotificationBackend implements LocalNotificationBackend {
  int initializeCalls = 0;
  int permissionCalls = 0;
  int cancelAllCalls = 0;
  bool permissionResult = true;
  final List<int> cancelledIds = [];
  final List<ScheduledCall> scheduled = [];
  void Function(String? payload)? _onTap;

  @override
  Future<void> initialize(
    void Function(String? payload) onNotificationTap,
  ) async {
    initializeCalls += 1;
    _onTap = onNotificationTap;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionCalls += 1;
    return permissionResult;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledAt,
    required String payload,
  }) async {
    scheduled.add(
      ScheduledCall(
        id: id,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls += 1;
  }

  void tap(String? payload) => _onTap?.call(payload);
}
