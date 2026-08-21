import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/data/knowledge_note_repository.dart';
import 'package:focus_flow/data/task_repository.dart';
import 'package:focus_flow/domain/knowledge_note.dart';
import 'package:focus_flow/domain/planner_task.dart';
import 'package:focus_flow/services/supabase_rest_client.dart';
import 'package:focus_flow/services/sync_engine.dart';

void main() {
  const session = SupabaseSession(
    accessToken: 'access',
    refreshToken: 'refresh',
    userId: 'user-1',
  );

  test('uploads local task and note tombstones', () async {
    final now = DateTime.utc(2026, 8, 8, 9);
    final tasks = InMemoryTaskRepository(ownerUserId: session.userId, seed: [
      PlannerTask(
        id: 'task-1',
        title: 'Deleted task',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        timeZoneId: 'UTC',
      ),
    ]);
    final notes = InMemoryNoteRepository(ownerUserId: session.userId, seed: [
      KnowledgeNote(
        id: 'note-1',
        title: 'Deleted note',
        bodyMarkdown: '',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await tasks.deleteTask('task-1');
    await notes.deleteNote('note-1');

    final uploads = <String, Object?>{};
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        if (method == 'GET') return const SupabaseResponse(200, '[]');
        uploads[uri.path] = jsonDecode(body!);
        return const SupabaseResponse(200, '{"status":"accepted"}');
      },
    )..setSession(session);

    final report = await SyncEngine(
      client: client,
      tasks: tasks,
      notes: notes,
    ).sync();

    expect(report.pushed, 2);
    expect(
        (uploads['/rest/v1/rpc/sync_note_cas'] as Map)['p_note']['deleted_at'],
        isNotNull);
    expect(
        (uploads['/rest/v1/rpc/sync_task_cas'] as Map)['p_task']['deleted_at'],
        isNotNull);
  });

  test('counts a server-side CAS rejection without overwriting local data',
      () async {
    final now = DateTime.utc(2026, 8, 8, 9);
    final tasks = InMemoryTaskRepository(ownerUserId: session.userId, seed: [
      PlannerTask(
        id: 'task-1',
        title: 'Local edit',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        timeZoneId: 'UTC',
        version: 2,
        updatedAt: now,
      ),
    ]);
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        if (method == 'GET') return const SupabaseResponse(200, '[]');
        return const SupabaseResponse(200, '{"status":"conflict"}');
      },
    )..setSession(session);

    final report = await SyncEngine(
      client: client,
      tasks: tasks,
      notes: InMemoryNoteRepository(ownerUserId: session.userId),
    ).sync();

    expect(report.pushed, 0);
    expect(report.conflicts, 1);
    expect((await tasks.loadTasks()).single.title, 'Local edit');
  });

  test('preserves remote metadata and does not echo it on the next sync',
      () async {
    final createdAt = DateTime.utc(2026, 8, 1);
    final remoteUpdatedAt = DateTime.utc(2026, 8, 8, 10);
    final notes = InMemoryNoteRepository(ownerUserId: session.userId, seed: [
      KnowledgeNote(
        id: 'note-1',
        title: 'Local title',
        bodyMarkdown: 'Local body',
        createdAt: createdAt,
        updatedAt: DateTime.utc(2026, 8, 7),
      ),
    ]);
    var writes = 0;
    final remoteNotes = jsonEncode([
      {
        'id': 'note-1',
        'title': 'Remote title',
        'body_markdown': 'Remote body',
        'tags': ['synced'],
        'is_favorite': true,
        'version': 7,
        'created_at': createdAt.toIso8601String(),
        'updated_at': remoteUpdatedAt.toIso8601String(),
        'deleted_at': null,
      }
    ]);
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        if (method == 'GET' && uri.path.endsWith('/notes')) {
          return SupabaseResponse(200, remoteNotes);
        }
        if (method == 'GET') return const SupabaseResponse(200, '[]');
        writes += 1;
        return const SupabaseResponse(201, '');
      },
    )..setSession(session);
    final engine = SyncEngine(
      client: client,
      tasks: InMemoryTaskRepository(ownerUserId: session.userId),
      notes: notes,
    );

    expect((await engine.sync()).pulled, 1);
    final applied = (await notes.loadNotes()).single;
    expect(applied.title, 'Remote title');
    expect(applied.version, 7);
    expect(applied.updatedAt, remoteUpdatedAt);

    final second = await engine.sync();
    expect(second.pushed, 0);
    expect(writes, 0);
  });

  test('cancels a sync when the signed-in account changes', () async {
    final tasks = InMemoryTaskRepository(ownerUserId: session.userId);
    final notes = InMemoryNoteRepository(ownerUserId: session.userId);
    late SupabaseRestClient client;
    client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        client.setSession(const SupabaseSession(
          accessToken: 'other-access',
          refreshToken: 'other-refresh',
          userId: 'user-2',
        ));
        tasks.setOwner('user-2');
        notes.setOwner('user-2');
        return const SupabaseResponse(200, '[]');
      },
    )..setSession(session);

    final engine = SyncEngine(client: client, tasks: tasks, notes: notes);

    await expectLater(engine.sync(), throwsStateError);
  });

  test('uploads multiple offline edits against the fetched base version',
      () async {
    final createdAt = DateTime.utc(2026, 8, 1);
    final now = DateTime.utc(2026, 8, 8, 9);
    final tasks = InMemoryTaskRepository(ownerUserId: session.userId, seed: [
      PlannerTask(
        id: 'task-1',
        title: 'Several offline edits',
        description: 'Newest local content',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        timeZoneId: 'UTC',
        createdAt: createdAt,
        updatedAt: now,
        version: 5,
      ),
    ]);
    Map<String, dynamic>? uploadedTask;
    final remoteTasks = jsonEncode([
      {
        'id': 'task-1',
        'title': 'Old remote content',
        'description': '',
        'start_at': now.toIso8601String(),
        'end_at': now.add(const Duration(hours: 1)).toIso8601String(),
        'timezone_id': 'UTC',
        'repeat_rule': {'type': 'none'},
        'reminder_minutes': 0,
        'status': 'planned',
        'priority': 2,
        'version': 2,
        'created_at': createdAt.toIso8601String(),
        'updated_at': now.add(const Duration(days: 1)).toIso8601String(),
        'deleted_at': null,
      }
    ]);
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        if (method == 'GET' && uri.path.endsWith('/tasks')) {
          return SupabaseResponse(200, remoteTasks);
        }
        if (method == 'GET') return const SupabaseResponse(200, '[]');
        uploadedTask = (jsonDecode(body!) as Map<String, dynamic>)['p_task']
            as Map<String, dynamic>;
        return const SupabaseResponse(200, '{"status":"accepted"}');
      },
    )..setSession(session);

    final report = await SyncEngine(
      client: client,
      tasks: tasks,
      notes: InMemoryNoteRepository(ownerUserId: session.userId),
    ).sync();

    expect(report.pushed, 1);
    expect(uploadedTask?['version'], 5);
    expect(uploadedTask?['base_version'], 2);
    expect(uploadedTask?['description'], 'Newest local content');
  });

  test('preserves local content when equal versions conflict', () async {
    final now = DateTime.utc(2026, 8, 8, 9);
    final notes = InMemoryNoteRepository(ownerUserId: session.userId, seed: [
      KnowledgeNote(
        id: 'note-1',
        title: 'Local version',
        bodyMarkdown: 'Local body',
        createdAt: now,
        updatedAt: now,
        version: 3,
      ),
    ]);
    final remoteNotes = jsonEncode([
      {
        'id': 'note-1',
        'title': 'Remote version',
        'body_markdown': 'Remote body',
        'tags': <String>[],
        'is_favorite': false,
        'version': 3,
        'created_at': now.toIso8601String(),
        'updated_at': now.add(const Duration(days: 1)).toIso8601String(),
        'deleted_at': null,
      }
    ]);
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async =>
          method == 'GET' && uri.path.endsWith('/notes')
              ? SupabaseResponse(200, remoteNotes)
              : const SupabaseResponse(200, '[]'),
    )..setSession(session);

    final report = await SyncEngine(
      client: client,
      tasks: InMemoryTaskRepository(ownerUserId: session.userId),
      notes: notes,
    ).sync();

    expect(report.conflicts, 1);
    expect((await notes.loadNotes()).single.title, 'Local version');
  });

  test('pulls schedule metadata and today-incomplete status', () async {
    final now = DateTime.utc(2026, 8, 8, 9);
    final remoteTasks = jsonEncode([
      {
        'id': 'task-1',
        'title': 'Linear algebra',
        'description': '',
        'kind': 'course',
        'location': 'Teaching Building A-201',
        'start_at': now.toIso8601String(),
        'end_at': now.add(const Duration(hours: 1)).toIso8601String(),
        'timezone_id': 'UTC',
        'repeat_rule': {'type': 'weekly'},
        'reminder_minutes': 5,
        'reminder_enabled': false,
        'status': 'today_incomplete',
        'priority': 2,
        'version': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'deleted_at': null,
      }
    ]);
    final tasks = InMemoryTaskRepository(ownerUserId: session.userId);
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async =>
          method == 'GET' && uri.path.endsWith('/tasks')
              ? SupabaseResponse(200, remoteTasks)
              : const SupabaseResponse(200, '[]'),
    )..setSession(session);

    final report = await SyncEngine(
      client: client,
      tasks: tasks,
      notes: InMemoryNoteRepository(ownerUserId: session.userId),
    ).sync();
    final pulled = (await tasks.loadTasks()).single;

    expect(report.pulled, 1);
    expect(pulled.kind, ScheduleItemKind.course);
    expect(pulled.location, 'Teaching Building A-201');
    expect(pulled.reminderEnabled, isFalse);
    expect(pulled.status, TaskStatus.todayIncomplete);
  });
}
