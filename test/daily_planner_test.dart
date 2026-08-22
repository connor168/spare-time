import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/domain/planner_task.dart';
import 'package:focus_flow/services/daily_planner.dart';

void main() {
  test('fills available gaps without moving existing tasks', () {
    final day = DateTime(2026, 8, 24);
    final existing = PlannerTask(
      id: 'course', title: '课程', kind: ScheduleItemKind.course,
      startAt: DateTime.utc(2026, 8, 24, 3), endAt: DateTime.utc(2026, 8, 24, 5),
      timeZoneId: 'Asia/Shanghai');
    final blocks = const DailyPlanner().generate(day: day, existing: [existing], targetMinutes: 50);
    expect(blocks, hasLength(1));
    expect(blocks.single.kind, ScheduleItemKind.timeBlock);
    expect(blocks.single.startAt, DateTime.utc(2026, 8, 24, 1));
  });

  test('does not create a block when the target is shorter than a session', () {
    final blocks = const DailyPlanner().generate(
      day: DateTime(2026, 8, 24),
      existing: const [],
      targetMinutes: 25,
    );

    expect(blocks, isEmpty);
  });

  test('fills multiple sessions only when each fits with its break', () {
    final blocks = const DailyPlanner().generate(
      day: DateTime(2026, 8, 24),
      existing: const [],
      workStartMinute: 9 * 60,
      workEndMinute: 12 * 60,
      targetMinutes: 120,
    );

    expect(blocks, hasLength(2));
    expect(blocks[0].startAt, DateTime.utc(2026, 8, 24, 1));
    expect(blocks[1].startAt, DateTime.utc(2026, 8, 24, 2));
  });

  test('rejects an invalid work window', () {
    expect(
      () => const DailyPlanner().generate(
        day: DateTime(2026, 8, 24),
        existing: const [],
        workStartMinute: 21 * 60,
        workEndMinute: 9 * 60,
      ),
      throwsArgumentError,
    );
  });
}
