import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/data/app_database.dart';
import 'package:focus_flow/data/task_repository.dart';
import 'package:focus_flow/domain/planner_task.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
  });

  tearDown(() => database.close());

  test('persists tasks and round-trips recurrence', () async {
    final task = PlannerTask(
      id: 'task-1',
      title: 'Daily review',
      description: 'Review the complete backlog.',
      kind: ScheduleItemKind.course,
      location: 'Room 301',
      startAt: DateTime.utc(2026, 8, 8, 9),
      endAt: DateTime.utc(2026, 8, 8, 10),
      timeZoneId: 'Asia/Tokyo',
      recurrence: TaskRecurrence.daily,
      reminderMinutes: 15,
      reminderEnabled: false,
      priority: 3,
      status: TaskStatus.todayIncomplete,
    );

    await repository.saveTask(task);

    final loaded = await repository.loadTasks();
    expect(loaded, hasLength(1));
    expect(loaded.single.recurrence, TaskRecurrence.daily);
    expect(loaded.single.description, 'Review the complete backlog.');
    expect(loaded.single.kind, ScheduleItemKind.course);
    expect(loaded.single.location, 'Room 301');
    expect(loaded.single.status, TaskStatus.todayIncomplete);
    expect(loaded.single.reminderEnabled, isFalse);
    expect(loaded.single.priority, 3);
    expect(loaded.single.notificationAt, DateTime.utc(2026, 8, 8, 8, 45));
  });

  test('increments version and preserves creation time on update', () async {
    final original = PlannerTask(
      id: 'task-1',
      title: 'Draft',
      startAt: DateTime.utc(2026, 8, 8, 9),
      endAt: DateTime.utc(2026, 8, 8, 10),
      timeZoneId: 'Asia/Tokyo',
    );
    await repository.saveTask(original);
    final firstRow = await (database.select(database.taskRows)
          ..where((row) => row.id.equals(original.id)))
        .getSingle();

    await repository.saveTask(original.copyWith(title: 'Published'));

    final secondRow = await (database.select(database.taskRows)
          ..where((row) => row.id.equals(original.id)))
        .getSingle();
    expect(secondRow.createdAt, firstRow.createdAt);
    expect(secondRow.version, firstRow.version + 1);
    expect((await repository.loadTasks()).single.title, 'Published');
  });

  test('soft-deleted tasks stay hidden until restored', () async {
    final task = PlannerTask(
      id: 'task-1',
      title: 'Temporary',
      startAt: DateTime.utc(2026, 8, 8, 9),
      endAt: DateTime.utc(2026, 8, 8, 10),
      timeZoneId: 'Asia/Tokyo',
    );
    await repository.saveTask(task);
    await repository.deleteTask(task.id);
    expect(await repository.loadTasks(), isEmpty);
    final tombstone = (await repository.loadTasks(includeDeleted: true)).single;
    expect(tombstone.deletedAt, isNotNull);
    expect(tombstone.version, 2);

    await repository.saveTask(task.copyWith(title: 'Restored'));
    expect((await repository.loadTasks()).single.title, 'Restored');
  });

  test('owner scopes isolate local rows between accounts', () async {
    final task = PlannerTask(
      id: 'task-owner',
      title: 'Private task',
      startAt: DateTime.utc(2026, 8, 8, 9),
      endAt: DateTime.utc(2026, 8, 8, 10),
      timeZoneId: 'UTC',
    );
    repository.setOwner('user-a');
    await repository.saveTask(task);
    repository.setOwner('user-b');
    expect(await repository.loadTasks(), isEmpty);
    repository.setOwner('user-a');
    expect((await repository.loadTasks()).single.title, 'Private task');
  });
}
