import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/domain/knowledge_note.dart';
import 'package:focus_flow/domain/planner_task.dart';
import 'package:focus_flow/services/supabase_rest_client.dart';

void main() {
  test('sign in stores session and sync sends authenticated note payload',
      () async {
    final requests = <String>[];
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        requests.add('$method ${uri.path} ${headers['authorization'] ?? ''}');
        if (uri.path == '/auth/v1/token') {
          return const SupabaseResponse(200,
              '{"access_token":"a","refresh_token":"r","user":{"id":"u1"}}');
        }
        return const SupabaseResponse(200, '{"status":"accepted"}');
      },
    );
    final session = await client.signIn(email: 'a@b.test', password: 'secret');
    expect(session.userId, 'u1');
    expect(client.session?.accessToken, 'a');
    final now = DateTime.utc(2026, 8, 8);
    final result = await client.syncNotes([
      KnowledgeNote(
        id: '00000000-0000-0000-0000-000000000001',
        title: 'Note',
        bodyMarkdown: '',
        createdAt: now,
        updatedAt: now,
      )
    ]);
    expect(result.accepted, 1);
    expect(requests.last, contains('Bearer a'));
  });

  test('task CAS payload preserves description and priority', () async {
    Object? sent;
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        sent = jsonDecode(body!);
        return const SupabaseResponse(200, '{"status":"conflict"}');
      },
    )..setSession(const SupabaseSession(
        accessToken: 'a', refreshToken: 'r', userId: 'u1'));
    final now = DateTime.utc(2026, 8, 8, 9);

    final result = await client.syncTasks([
      PlannerTask(
        id: '00000000-0000-0000-0000-000000000001',
        title: 'Task',
        description: 'Keep this text',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        timeZoneId: 'UTC',
        priority: 3,
      )
    ]);

    final task =
        (sent as Map<String, dynamic>)['p_task'] as Map<String, dynamic>;
    expect(task['description'], 'Keep this text');
    expect(task['priority'], 3);
    expect(task['base_version'], 0);
    expect(task, isNot(contains('user_id')));
    expect(result.conflicts, 1);
  });

  test('fetches every PostgREST page', () async {
    var requests = 0;
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        requests += 1;
        final offset = int.parse(uri.queryParameters['offset']!);
        final count = offset == 0 ? 500 : 1;
        return SupabaseResponse(
          200,
          jsonEncode(List.generate(count, (index) => {'id': '$offset-$index'})),
        );
      },
    )..setSession(const SupabaseSession(
        accessToken: 'a', refreshToken: 'r', userId: 'u1'));

    final rows = await client.fetchTasks();

    expect(rows, hasLength(501));
    expect(requests, 2);
  });
}
