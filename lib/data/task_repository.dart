import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/planner_task.dart';
import 'app_database.dart';

abstract interface class TaskRepository {
  String? get ownerUserId;

  void setOwner(String? ownerUserId);

  Future<List<PlannerTask>> loadTasks({bool includeDeleted = false});

  Future<void> saveTask(PlannerTask task);

  Future<void> applyRemoteTask(PlannerTask task);

  Future<void> deleteTask(String taskId);
}

class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this.database, {String? ownerUserId})
      : _ownerUserId = ownerUserId;

  final AppDatabase database;
  String? _ownerUserId;

  @override
  String? get ownerUserId => _ownerUserId;

  @override
  void setOwner(String? ownerUserId) => _ownerUserId = ownerUserId;

  @override
  Future<List<PlannerTask>> loadTasks({bool includeDeleted = false}) async {
    final query = database.select(database.taskRows)
      ..orderBy([(row) => OrderingTerm(expression: row.startAt)]);
    if (_ownerUserId == null) {
      query.where((row) => row.ownerUserId.isNull());
    } else {
      query.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    if (!includeDeleted) query.where((row) => row.deletedAt.isNull());
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> saveTask(PlannerTask task) async {
    final now = DateTime.now().toUtc();
    final existingQuery = database.select(database.taskRows)
      ..where((row) => row.id.equals(task.id));
    if (_ownerUserId == null) {
      existingQuery.where((row) => row.ownerUserId.isNull());
    } else {
      existingQuery.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    final existing = await existingQuery.getSingleOrNull();
    await database.into(database.taskRows).insertOnConflictUpdate(
          TaskRowsCompanion.insert(
            id: task.id,
            ownerUserId: Value(_ownerUserId),
            title: task.title,
            description: Value(task.description),
            startAt: task.startAt.toUtc(),
            endAt: task.endAt.toUtc(),
            timezoneId: task.timeZoneId,
            repeatRuleJson: Value(jsonEncode({'type': task.recurrence.name})),
            reminderMinutes: Value(task.reminderMinutes),
            priority: Value(task.priority),
            status: Value(task.isCompleted ? 'completed' : 'planned'),
            version: Value((existing?.version ?? 0) + 1),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            deletedAt: const Value(null),
          ),
        );
  }

  @override
  Future<void> applyRemoteTask(PlannerTask task) {
    return database.into(database.taskRows).insertOnConflictUpdate(
          TaskRowsCompanion.insert(
            id: task.id,
            ownerUserId: Value(_ownerUserId),
            title: task.title,
            description: Value(task.description),
            startAt: task.startAt.toUtc(),
            endAt: task.endAt.toUtc(),
            timezoneId: task.timeZoneId,
            repeatRuleJson: Value(jsonEncode({'type': task.recurrence.name})),
            reminderMinutes: Value(task.reminderMinutes),
            priority: Value(task.priority),
            status: Value(task.isCompleted ? 'completed' : 'planned'),
            version: Value(task.version),
            createdAt: task.createdAt.toUtc(),
            updatedAt: task.updatedAt.toUtc(),
            deletedAt: Value(task.deletedAt?.toUtc()),
          ),
        );
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final existingQuery = database.select(database.taskRows)
      ..where((row) => row.id.equals(taskId));
    if (_ownerUserId == null) {
      existingQuery.where((row) => row.ownerUserId.isNull());
    } else {
      existingQuery.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    final existing = await existingQuery.getSingleOrNull();
    if (existing == null || existing.deletedAt != null) return;

    final now = DateTime.now().toUtc();
    final update = database.update(database.taskRows)
      ..where((row) => row.id.equals(taskId));
    if (_ownerUserId == null) {
      update.where((row) => row.ownerUserId.isNull());
    } else {
      update.where((row) => row.ownerUserId.equals(_ownerUserId!));
    }
    await update.write(
      TaskRowsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        version: Value(existing.version + 1),
      ),
    );
  }

  PlannerTask _toDomain(TaskRow row) {
    return PlannerTask(
      id: row.id,
      title: row.title,
      description: row.description,
      startAt: row.startAt.toUtc(),
      endAt: row.endAt.toUtc(),
      timeZoneId: row.timezoneId,
      reminderMinutes: row.reminderMinutes,
      priority: row.priority,
      recurrence: _recurrenceFromJson(row.repeatRuleJson),
      isCompleted: row.status == 'completed',
      version: row.version,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      deletedAt: row.deletedAt?.toUtc(),
    );
  }

  TaskRecurrence _recurrenceFromJson(String value) {
    try {
      final type = (jsonDecode(value) as Map<String, dynamic>)['type'];
      return TaskRecurrence.values.firstWhere(
        (candidate) => candidate.name == type,
        orElse: () => TaskRecurrence.none,
      );
    } on Object {
      // Older rows can contain malformed/default data; treat them as one-off tasks.
    }
    return TaskRecurrence.none;
  }
}

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository(
      {Iterable<PlannerTask> seed = const [], String? ownerUserId})
      : _tasks = [...seed],
        _ownerUserId = ownerUserId {
    for (final task in _tasks) {
      _owners[task.id] = ownerUserId;
    }
  }

  final List<PlannerTask> _tasks;
  final Map<String, String?> _owners = {};
  String? _ownerUserId;

  @override
  String? get ownerUserId => _ownerUserId;

  @override
  void setOwner(String? ownerUserId) => _ownerUserId = ownerUserId;

  @override
  Future<List<PlannerTask>> loadTasks({bool includeDeleted = false}) async =>
      (includeDeleted ? _tasks : _tasks.where((task) => task.deletedAt == null))
          .where((task) => _owners[task.id] == _ownerUserId)
          .toList();

  @override
  Future<void> saveTask(PlannerTask task) async {
    final index = _tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index == -1) {
      _tasks.add(task);
    } else {
      _tasks[index] = task;
    }
    _owners[task.id] = _ownerUserId;
  }

  @override
  Future<void> applyRemoteTask(PlannerTask task) async {
    final index = _tasks.indexWhere((candidate) => candidate.id == task.id);
    if (index == -1) {
      _tasks.add(task);
    } else {
      _tasks[index] = task;
    }
    _owners[task.id] = _ownerUserId;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0 || _tasks[index].deletedAt != null) return;
    final existing = _tasks[index];
    final now = DateTime.now().toUtc();
    _tasks[index] = existing.copyWith(
      updatedAt: now,
      version: existing.version + 1,
      deletedAt: now,
    );
  }
}
