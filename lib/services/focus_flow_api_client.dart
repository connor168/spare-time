import 'dart:convert';
import 'dart:io';

import '../domain/knowledge_note.dart';
import '../domain/planner_task.dart';
import 'supabase_rest_client.dart';

/// Client for the Focus Flow API hosted outside the Flutter application.
class FocusFlowApiClient extends SupabaseRestClient {
  FocusFlowApiClient({required Uri baseUrl, FocusFlowRequest? request})
      : _apiRequest = request ?? _defaultRequest,
        super(url: baseUrl, anonKey: 'focus-flow-api');

  final FocusFlowRequest _apiRequest;

  @override
  Future<SupabaseSession> signIn(
      {required String email, required String password}) async {
    return _setSessionFromApi(await _sendApi('POST', '/api/auth/email', {
      'email': email,
      'password': password,
    }));
  }

  @override
  Future<SupabaseSession> signUp(
      {required String email, required String password}) async {
    return _setSessionFromApi(await _sendApi('POST', '/api/auth/email', {
      'mode': 'signup',
      'email': email,
      'password': password,
    }));
  }

  @override
  Future<SupabaseSession> signInWithWeChatCode(String code) async {
    if (code.trim().isEmpty) {
      throw const FormatException('WeChat authorization code is empty.');
    }
    return _setSessionFromApi(
        await _sendApi('POST', '/api/auth/wechat', {'code': code.trim()}));
  }

  @override
  Future<SupabaseSession> refreshSession() async {
    final current = session;
    if (current == null || current.refreshToken.isEmpty) {
      throw StateError('No refresh token is available.');
    }
    return _setSessionFromApi(await _sendApi('POST', '/api/auth/refresh', {
      'refresh_token': current.refreshToken,
    }));
  }

  @override
  Future<void> signOut() async {
    if (session != null) {
      await _sendApi('POST', '/api/auth/logout', null, authorized: true);
    }
    clearSession();
  }

  @override
  Future<SyncWriteResult> syncNotes(Iterable<KnowledgeNote> notes,
      {Map<String, int> baseVersions = const {}}) {
    return _push(
      'notes',
      notes.map((note) => {
        'id': note.id,
        'title': note.title,
        'body_markdown': note.bodyMarkdown,
        'tags': note.tags,
        'is_favorite': note.isFavorite,
        'version': note.version,
        'base_version': baseVersions[note.id] ?? (note.version > 1 ? note.version - 1 : 0),
        'created_at': note.createdAt.toUtc().toIso8601String(),
        'updated_at': note.updatedAt.toUtc().toIso8601String(),
        'deleted_at': note.deletedAt?.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<SyncWriteResult> syncTasks(Iterable<PlannerTask> tasks,
      {Map<String, int> baseVersions = const {}}) {
    return _push(
      'tasks',
      tasks.map((task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'kind': task.kind.storageValue,
        'location': task.location,
        'start_at': task.startAt.toUtc().toIso8601String(),
        'end_at': task.endAt.toUtc().toIso8601String(),
        'timezone_id': task.timeZoneId,
        'repeat_rule': {'type': task.recurrence.name},
        'reminder_minutes': task.reminderMinutes,
        'reminder_enabled': task.reminderEnabled,
        'status': task.status.storageValue,
        'priority': task.priority,
        'version': task.version,
        'base_version': baseVersions[task.id] ?? (task.version > 1 ? task.version - 1 : 0),
        'created_at': task.createdAt.toUtc().toIso8601String(),
        'updated_at': task.updatedAt.toUtc().toIso8601String(),
        'deleted_at': task.deletedAt?.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNotes() {
    return _pull('notes');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTasks() {
    return _pull('tasks');
  }

  @override
  Future<void> registerDeviceToken(
      {required String platform,
      required String provider,
      required String token}) {
    return _sendApi('POST', '/api/device-tokens', {
      'platform': platform,
      'provider': provider,
      'token': token,
    }, authorized: true).then((_) {});
  }

  @override
  Future<void> revokeDeviceToken(String token) {
    final encoded = Uri.encodeQueryComponent(token);
    return _sendApi('DELETE', '/api/device-tokens?token=$encoded', null,
        authorized: true).then((_) {});
  }

  @override
  Future<Map<String, dynamic>> exportMyData() async {
    return _sendApi('POST', '/api/account/export', null, authorized: true);
  }

  @override
  Future<void> deleteMyAccount() async {
    await _sendApi('POST', '/api/account/delete', null, authorized: true);
    clearSession();
  }

  SupabaseSession _setSessionFromApi(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    final user = json['user'];
    final userId = user is Map<String, dynamic> ? user['id'] : json['user_id'];
    if (accessToken is! String || refreshToken is! String || userId is! String) {
      throw const FormatException(
          'Focus Flow API response is missing session fields.');
    }
    final expiresIn = json['expires_in'];
    final value = SupabaseSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: expiresIn is num
          ? DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()))
          : null,
    );
    setSession(value);
    return value;
  }

  Future<SyncWriteResult> _push(
      String entity, Iterable<Map<String, Object?>> rows) async {
    final result = await _sendApi('POST', '/api/sync/push', {entity: rows.toList()},
        authorized: true);
    final value = result[entity];
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Focus Flow sync response is invalid.');
    }
    return SyncWriteResult(
      accepted: (value['accepted'] as num? ?? 0).toInt(),
      conflicts: (value['conflicts'] as num? ?? 0).toInt(),
    );
  }

  Future<List<Map<String, dynamic>>> _pull(String entity) async {
    final all = <Map<String, dynamic>>[];
    String? cursor;
    while (true) {
      final query = cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}';
      final response = await _sendApi(
          'GET', '/api/sync/pull?entity=$entity$query', null,
          authorized: true);
      final items = response['items'];
      if (items is! List) throw const FormatException('Focus Flow pull response is invalid.');
      all.addAll(items.whereType<Map<String, dynamic>>());
      final next = response['next_cursor'];
      if (items.isEmpty || next is! String || next.isEmpty || next == cursor) return all;
      cursor = next;
      if (items.length < 500) return all;
    }
  }

  Future<Map<String, dynamic>> _sendApi(
      String method, String path, Object? payload,
      {bool authorized = false}) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (authorized && session != null) {
      headers['authorization'] = 'Bearer ${session!.accessToken}';
    }
    final response = await _apiRequest(method, url.resolve(path), headers,
        payload == null ? null : jsonEncode(payload));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseApiException(response.statusCode, response.body);
    }
    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Focus Flow API response must be an object.');
    }
    return value;
  }

  static Future<SupabaseResponse> _defaultRequest(
      String method, Uri uri, Map<String, String> headers, String? body) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close();
      return SupabaseResponse(
          response.statusCode, await response.transform(utf8.decoder).join());
    } finally {
      client.close(force: true);
    }
  }
}

typedef FocusFlowRequest = Future<SupabaseResponse> Function(
    String method, Uri uri, Map<String, String> headers, String? body);
