import '../data/knowledge_note_repository.dart';
import '../data/task_repository.dart';
import '../domain/knowledge_note.dart';
import '../domain/planner_task.dart';
import 'supabase_rest_client.dart';

class SyncReport {
  const SyncReport(
      {required this.pulled, required this.pushed, required this.conflicts});
  final int pulled;
  final int pushed;
  final int conflicts;
}

class SyncEngine {
  SyncEngine({required this.client, required this.tasks, required this.notes});

  final SupabaseRestClient client;
  final TaskRepository tasks;
  final NoteRepository notes;

  Future<SyncReport> sync() async {
    final session = client.session;
    if (session == null) throw StateError('Sign in before syncing.');
    _assertContext(session);
    var pulled = 0;
    var pushed = 0;
    var conflicts = 0;

    final localNotes =
        await _guard(session, () => notes.loadNotes(includeDeleted: true));
    final localById = {for (final note in localNotes) note.id: note};
    final remoteNotes = await _guard(session, client.fetchNotes);
    final uploadNotes = <KnowledgeNote>[];
    final noteBaseVersions = <String, int>{};
    for (final row in remoteNotes) {
      final remote = _noteFromRow(row);
      final local = localById[remote.id];
      if (local == null) {
        await _guard(session, () => notes.applyRemoteNote(remote));
        pulled += 1;
      } else if (remote.version > local.version) {
        await _guard(session, () => notes.applyRemoteNote(remote));
        pulled += 1;
      } else if (local.version > remote.version) {
        uploadNotes.add(local);
        noteBaseVersions[local.id] = remote.version;
      } else if (!_sameNote(local, remote)) {
        conflicts += 1;
      }
    }
    final remoteNoteIds =
        remoteNotes.map((row) => row['id']).whereType<String>().toSet();
    for (final note
        in localNotes.where((note) => !remoteNoteIds.contains(note.id))) {
      uploadNotes.add(note);
      noteBaseVersions[note.id] = 0;
    }
    if (uploadNotes.isNotEmpty) {
      final result = await _guard(
        session,
        () => client.syncNotes(uploadNotes, baseVersions: noteBaseVersions),
      );
      pushed += result.accepted;
      conflicts += result.conflicts;
    }

    final localTasks =
        await _guard(session, () => tasks.loadTasks(includeDeleted: true));
    final remoteTasks = await _guard(session, client.fetchTasks);
    final uploadTasks = <PlannerTask>[];
    final taskBaseVersions = <String, int>{};
    final localTasksById = {for (final task in localTasks) task.id: task};
    for (final row in remoteTasks) {
      final remote = _taskFromRow(row);
      final local = localTasksById[remote.id];
      if (local == null) {
        await _guard(session, () => tasks.applyRemoteTask(remote));
        pulled += 1;
      } else if (remote.version > local.version) {
        await _guard(session, () => tasks.applyRemoteTask(remote));
        pulled += 1;
      } else if (local.version > remote.version) {
        uploadTasks.add(local);
        taskBaseVersions[local.id] = remote.version;
      } else if (!_sameTask(local, remote)) {
        conflicts += 1;
      }
    }
    final remoteTaskIds =
        remoteTasks.map((row) => row['id']).whereType<String>().toSet();
    for (final task
        in localTasks.where((task) => !remoteTaskIds.contains(task.id))) {
      uploadTasks.add(task);
      taskBaseVersions[task.id] = 0;
    }
    if (uploadTasks.isNotEmpty) {
      final result = await _guard(
        session,
        () => client.syncTasks(uploadTasks, baseVersions: taskBaseVersions),
      );
      pushed += result.accepted;
      conflicts += result.conflicts;
    }
    return SyncReport(pulled: pulled, pushed: pushed, conflicts: conflicts);
  }

  Future<T> _guard<T>(
    SupabaseSession session,
    Future<T> Function() operation,
  ) async {
    _assertContext(session);
    final result = await operation();
    _assertContext(session);
    return result;
  }

  void _assertContext(SupabaseSession expected) {
    final current = client.session;
    final unchanged = current?.userId == expected.userId &&
        current?.accessToken == expected.accessToken &&
        tasks.ownerUserId == expected.userId &&
        notes.ownerUserId == expected.userId;
    if (!unchanged) {
      throw StateError('The signed-in account changed; sync was cancelled.');
    }
  }

  KnowledgeNote _noteFromRow(Map<String, dynamic> row) => KnowledgeNote(
        id: row['id'] as String,
        title: row['title'] as String,
        bodyMarkdown: row['body_markdown'] as String? ?? '',
        tags: (row['tags'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        isFavorite: row['is_favorite'] as bool? ?? false,
        version: (row['version'] as num? ?? 1).toInt(),
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
        deletedAt: row['deleted_at'] == null ? null : _date(row['deleted_at']),
      );

  PlannerTask _taskFromRow(Map<String, dynamic> row) {
    final repeat = row['repeat_rule'];
    final type = repeat is Map<String, dynamic> ? repeat['type'] : 'none';
    return PlannerTask(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      startAt: _date(row['start_at']),
      endAt: _date(row['end_at']),
      timeZoneId: row['timezone_id'] as String? ?? 'UTC',
      reminderMinutes: (row['reminder_minutes'] as num? ?? 0).toInt(),
      priority: (row['priority'] as num? ?? 2).toInt(),
      recurrence: TaskRecurrence.values.firstWhere(
          (value) => value.name == type,
          orElse: () => TaskRecurrence.none),
      isCompleted: row['status'] == 'completed',
      version: (row['version'] as num? ?? 1).toInt(),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      deletedAt: row['deleted_at'] == null ? null : _date(row['deleted_at']),
    );
  }

  DateTime _date(Object? value) {
    if (value is! String) {
      throw FormatException('Remote timestamp must be a string: $value');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Remote timestamp is invalid: $value');
    }
    return parsed.toUtc();
  }

  bool _sameNote(KnowledgeNote left, KnowledgeNote right) =>
      left.title == right.title &&
      left.bodyMarkdown == right.bodyMarkdown &&
      left.isFavorite == right.isFavorite &&
      left.deletedAt == right.deletedAt &&
      _sameTags(left.tags, right.tags);

  bool _sameTags(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    return left.toSet().containsAll(right);
  }

  bool _sameTask(PlannerTask left, PlannerTask right) =>
      left.title == right.title &&
      left.description == right.description &&
      left.startAt == right.startAt &&
      left.endAt == right.endAt &&
      left.timeZoneId == right.timeZoneId &&
      left.reminderMinutes == right.reminderMinutes &&
      left.recurrence == right.recurrence &&
      left.isCompleted == right.isCompleted &&
      left.priority == right.priority &&
      left.deletedAt == right.deletedAt;
}
