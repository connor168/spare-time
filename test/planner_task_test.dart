import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/domain/planner_task.dart';

void main() {
  final start = DateTime.utc(2026, 8, 7, 9);
  final end = DateTime.utc(2026, 8, 7, 10);

  PlannerTask buildTask({int reminderMinutes = 15}) {
    return PlannerTask(
      id: 'task-1',
      title: 'Deep work',
      startAt: start,
      endAt: end,
      timeZoneId: 'Asia/Tokyo',
      reminderMinutes: reminderMinutes,
    );
  }

  test('calculates the local notification time from reminder lead time', () {
    expect(buildTask().notificationAt,
        start.subtract(const Duration(minutes: 15)));
  });

  test('rejects an end time before the start time', () {
    expect(
      () => PlannerTask(
          id: 'bad',
          title: 'Invalid',
          startAt: end,
          endAt: start,
          timeZoneId: 'UTC'),
      throwsArgumentError,
    );
  });

  test('rejects a non-IANA local time zone placeholder', () {
    expect(
      () => PlannerTask(
          id: 'bad-zone',
          title: 'Invalid zone',
          startAt: start,
          endAt: end,
          timeZoneId: 'local'),
      throwsArgumentError,
    );
  });

  test('rejects non-UTC instants at the domain boundary', () {
    expect(
      () => PlannerTask(
          id: 'local-time',
          title: 'Local',
          startAt: DateTime(2026, 8, 7, 9),
          endAt: DateTime(2026, 8, 7, 10),
          timeZoneId: 'Asia/Tokyo'),
      throwsArgumentError,
    );
  });

  test('rejects a priority outside the supported range', () {
    expect(() => buildTask().copyWith(priority: 4), throwsArgumentError);
  });

  test('copyWith preserves immutable fields and changes completion', () {
    final completed = buildTask().copyWith(isCompleted: true);
    expect(completed.id, 'task-1');
    expect(completed.isCompleted, isTrue);
    expect(completed.isOverdueAt(end.add(const Duration(minutes: 1))), isFalse);
  });

  test('uses schedule defaults and preserves legacy completion calls', () {
    final task = buildTask(reminderMinutes: 5);

    expect(task.kind, ScheduleItemKind.task);
    expect(task.location, isEmpty);
    expect(task.status, TaskStatus.planned);
    expect(task.reminderEnabled, isTrue);

    final incomplete = task.copyWith(status: TaskStatus.todayIncomplete);
    expect(incomplete.status, TaskStatus.todayIncomplete);
    expect(incomplete.isCompleted, isFalse);
    expect(incomplete.copyWith(isCompleted: true).status, TaskStatus.completed);
    expect(incomplete.copyWith(isCompleted: false).status,
        TaskStatus.todayIncomplete);
  });

  test('serializes enum values for local and cloud storage', () {
    expect(ScheduleItemKind.timeBlock.storageValue, 'time_block');
    expect(
        scheduleItemKindFromStorage('time_block'), ScheduleItemKind.timeBlock);
    expect(TaskStatus.todayIncomplete.storageValue, 'today_incomplete');
    expect(
        taskStatusFromStorage('today_incomplete'), TaskStatus.todayIncomplete);
  });
}
