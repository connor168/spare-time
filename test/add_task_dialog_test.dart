import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flow/domain/planner_task.dart';
import 'package:focus_flow/ui/add_task_dialog.dart';

void main() {
  testWidgets('new arrangement defaults to a study task with five-minute alert',
      (tester) async {
    PlannerTask? saved;
    await tester.pumpWidget(
      _DialogHarness(onResult: (result) => saved = result),
    );

    await _openDialog(tester);

    expect(find.text('添加安排'), findsOneWidget);
    expect(find.text('学习任务'), findsOneWidget);
    expect(find.text('提前 5 分钟'), findsOneWidget);
    expect(find.byKey(const Key('task-location-field')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      '复习高等数学',
    );
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, '复习高等数学');
    expect(saved!.kind, ScheduleItemKind.task);
    expect(saved!.status, TaskStatus.planned);
    expect(saved!.location, isEmpty);
    expect(saved!.reminderEnabled, isTrue);
    expect(saved!.reminderMinutes, 5);
  });

  testWidgets('course input accepts a location and can disable its alert',
      (tester) async {
    PlannerTask? saved;
    await tester.pumpWidget(
      _DialogHarness(onResult: (result) => saved = result),
    );

    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('task-kind-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-location-field')), findsOneWidget);
    expect(find.text('课程名称'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      '操作系统',
    );
    await tester.enterText(
      find.byKey(const Key('task-location-field')),
      '教学楼 A201',
    );

    await tester.ensureVisible(find.byKey(const Key('task-reminder-field')));
    await tester.tap(find.byKey(const Key('task-reminder-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭提醒').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.kind, ScheduleItemKind.course);
    expect(saved!.location, '教学楼 A201');
    expect(saved!.reminderEnabled, isFalse);
  });

  testWidgets('editing prefills values and preserves sync metadata',
      (tester) async {
    final createdAt = DateTime.utc(2026, 1, 2, 3, 4);
    final updatedAt = DateTime.utc(2026, 2, 3, 4, 5);
    final original = PlannerTask(
      id: 'existing-course',
      title: '大学英语',
      description: '第三单元',
      startAt: DateTime.utc(2026, 8, 17, 1),
      endAt: DateTime.utc(2026, 8, 17, 2, 30),
      timeZoneId: 'Asia/Shanghai',
      kind: ScheduleItemKind.course,
      location: '综合楼 301',
      reminderEnabled: false,
      reminderMinutes: 15,
      priority: 3,
      recurrence: TaskRecurrence.weekly,
      status: TaskStatus.todayIncomplete,
      createdAt: createdAt,
      updatedAt: updatedAt,
      version: 7,
    );
    PlannerTask? saved;
    await tester.pumpWidget(
      _DialogHarness(
        original: original,
        onResult: (result) => saved = result,
      ),
    );

    await _openDialog(tester);

    expect(find.text('编辑安排'), findsOneWidget);
    expect(find.text('关闭提醒'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('task-title-field')))
          .controller!
          .text,
      '大学英语',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('task-location-field')))
          .controller!
          .text,
      '综合楼 301',
    );

    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      '大学英语精读',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, '大学英语精读');
    expect(saved!.id, original.id);
    expect(saved!.createdAt, createdAt);
    expect(saved!.updatedAt, updatedAt);
    expect(saved!.version, 7);
    expect(saved!.recurrence, TaskRecurrence.weekly);
    expect(saved!.status, TaskStatus.todayIncomplete);
    expect(saved!.kind, ScheduleItemKind.course);
    expect(saved!.location, '综合楼 301');
    expect(saved!.reminderEnabled, isFalse);
    expect(saved!.reminderMinutes, 15);
  });
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-dialog')));
  await tester.pumpAndSettle();
}

class _DialogHarness extends StatelessWidget {
  const _DialogHarness({this.original, required this.onResult});

  final PlannerTask? original;
  final ValueChanged<PlannerTask?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key('open-dialog'),
              onPressed: () async {
                final result = await showDialog<PlannerTask>(
                  context: context,
                  builder: (context) => AddTaskDialog(original: original),
                );
                onResult(result);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
  }
}
