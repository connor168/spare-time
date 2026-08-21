import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/domain/planner_task.dart';
import 'package:focus_flow/services/focus_flow_api_client.dart';
import 'package:focus_flow/services/supabase_rest_client.dart';

void main() {
  test('exchanges WeChat code with the Focus Flow API', () async {
    final requests = <String>[];
    final client = FocusFlowApiClient(
      baseUrl: Uri.parse('https://api.focusflow.test'),
      request: (method, uri, headers, body) async {
        requests.add('$method ${uri.path} $body');
        return SupabaseResponse(200, jsonEncode({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 900,
          'user': {'id': 'user-1'},
        }));
      },
    );

    final session = await client.signInWithWeChatCode(' code-1 ');

    expect(session.userId, 'user-1');
    expect(requests.single, contains('POST /api/auth/wechat'));
    expect(requests.single, contains('"code":"code-1"'));
  });

  test('refresh uses the current refresh token and rotates the session',
      () async {
    final client = FocusFlowApiClient(
      baseUrl: Uri.parse('https://api.focusflow.test'),
      request: (method, uri, headers, body) async => const SupabaseResponse(
        200,
        '{"access_token":"next","refresh_token":"next-refresh","user":{"id":"user-1"}}',
      ),
    )..setSession(const SupabaseSession(
        accessToken: 'access', refreshToken: 'refresh', userId: 'user-1'));

    final session = await client.refreshSession();

    expect(session.accessToken, 'next');
    expect(client.session?.refreshToken, 'next-refresh');
  });

  test('pushes task CAS rows and pulls paged tasks', () async {
    final requests = <String>[];
    final client = FocusFlowApiClient(
      baseUrl: Uri.parse('https://api.focusflow.test'),
      request: (method, uri, headers, body) async {
        requests.add('$method ${uri.path}${uri.query.isEmpty ? '' : '?${uri.query}'} $body');
        if (uri.path == '/api/sync/push') {
          return const SupabaseResponse(
              200, '{"tasks":{"accepted":1,"conflicts":0}}');
        }
        return const SupabaseResponse(
            200, '{"items":[],"next_cursor":null}');
      },
    )..setSession(const SupabaseSession(
        accessToken: 'access', refreshToken: 'refresh', userId: 'user-1'));
    final now = DateTime.utc(2026, 8, 8, 9);

    final result = await client.syncTasks([
      PlannerTask(
        id: 'task-1',
        title: 'Task',
        startAt: now,
        endAt: now.add(const Duration(hours: 1)),
        timeZoneId: 'UTC',
        version: 3,
      ),
    ], baseVersions: const {'task-1': 2});
    final pulled = await client.fetchTasks();

    expect(result.accepted, 1);
    expect(pulled, isEmpty);
    expect(requests[0], contains('POST /api/sync/push'));
    expect(requests[0], contains('"base_version":2'));
    expect(requests[1], 'GET /api/sync/pull?entity=tasks null');
  });

  test('registers and revokes a device token through the API', () async {
    final requests = <String>[];
    final client = FocusFlowApiClient(
      baseUrl: Uri.parse('https://api.focusflow.test'),
      request: (method, uri, headers, body) async {
        requests.add('$method ${uri.path}${uri.query.isEmpty ? '' : '?${uri.query}'}');
        return const SupabaseResponse(204, '');
      },
    )..setSession(const SupabaseSession(
        accessToken: 'access', refreshToken: 'refresh', userId: 'user-1'));

    await client.registerDeviceToken(
        platform: 'android', provider: 'fcm', token: 'token-1');
    await client.revokeDeviceToken('token-1');

    expect(requests, [
      'POST /api/device-tokens',
      'DELETE /api/device-tokens?token=token-1',
    ]);
  });
}
