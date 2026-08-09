import 'dart:convert';
import 'dart:io';

import '../domain/knowledge_note.dart';
import '../domain/planner_task.dart';

typedef SupabaseRequest = Future<SupabaseResponse> Function(
    String method, Uri uri, Map<String, String> headers, String? body);

class SupabaseResponse {
  const SupabaseResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

class SyncWriteResult {
  const SyncWriteResult({required this.accepted, required this.conflicts});

  final int accepted;
  final int conflicts;
}

class EmailConfirmationRequired implements Exception {
  const EmailConfirmationRequired();
}

class SupabaseApiException implements Exception {
  const SupabaseApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'Supabase request failed ($statusCode).';
}

class SupabaseSession {
  const SupabaseSession(
      {required this.accessToken,
      required this.refreshToken,
      required this.userId,
      this.expiresAt});

  factory SupabaseSession.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored Supabase session.');
    }
    return SupabaseSession(
      accessToken: value['access_token'] as String,
      refreshToken: value['refresh_token'] as String,
      userId: value['user_id'] as String,
      expiresAt: value['expires_at'] == null
          ? null
          : DateTime.parse(value['expires_at'] as String).toUtc(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String userId;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user_id': userId,
        'expires_at': expiresAt?.toIso8601String(),
      };
}

class SupabaseRestClient {
  SupabaseRestClient(
      {required this.url, required this.anonKey, SupabaseRequest? request})
      : _request = request ?? _defaultRequest;

  final Uri url;
  final String anonKey;
  final SupabaseRequest _request;
  SupabaseSession? _session;

  SupabaseSession? get session => _session;

  void setSession(SupabaseSession session) => _session = session;

  void clearSession() => _session = null;

  Future<SupabaseSession> signIn(
      {required String email, required String password}) async {
    final response = await _send('POST', '/auth/v1/token?grant_type=password',
        {'email': email, 'password': password},
        authorized: false);
    final json = _decode(response);
    return _session = _sessionFromResponse(json);
  }

  Future<SupabaseSession> signUp(
      {required String email, required String password}) async {
    final response = await _send(
        'POST', '/auth/v1/signup', {'email': email, 'password': password},
        authorized: false);
    final json = _decode(response);
    final user = (json['user'] as Map<String, dynamic>?);
    if (user == null || json['access_token'] == null) {
      throw const EmailConfirmationRequired();
    }
    return _session = _sessionFromResponse(json);
  }

  Future<SupabaseSession> refreshSession() async {
    final current = _session;
    if (current == null || current.refreshToken.isEmpty) {
      throw StateError('No refresh token is available.');
    }
    final response = await _send(
      'POST',
      '/auth/v1/token?grant_type=refresh_token',
      {'refresh_token': current.refreshToken},
      authorized: false,
    );
    return _session = _sessionFromResponse(
      _decode(response),
      fallbackUserId: current.userId,
      fallbackRefreshToken: current.refreshToken,
    );
  }

  Future<void> signOut() async {
    if (_session != null) {
      await _send('POST', '/auth/v1/logout', null);
    }
    _session = null;
  }

  Future<SyncWriteResult> syncNotes(
    Iterable<KnowledgeNote> notes, {
    Map<String, int> baseVersions = const {},
  }) async {
    if (_session == null) {
      throw StateError('Sign in before syncing notes.');
    }
    return _syncWithCas(
      notes.map((note) => {
            'id': note.id,
            'title': note.title,
            'body_markdown': note.bodyMarkdown,
            'tags': note.tags,
            'is_favorite': note.isFavorite,
            'version': note.version,
            'base_version':
                baseVersions[note.id] ?? _defaultBaseVersion(note.version),
            'created_at': note.createdAt.toUtc().toIso8601String(),
            'updated_at': note.updatedAt.toUtc().toIso8601String(),
            'deleted_at': note.deletedAt?.toUtc().toIso8601String(),
          }),
      '/rest/v1/rpc/sync_note_cas',
      'p_note',
    );
  }

  Future<SyncWriteResult> syncTasks(
    Iterable<PlannerTask> tasks, {
    Map<String, int> baseVersions = const {},
  }) async {
    if (_session == null) {
      throw StateError('Sign in before syncing tasks.');
    }
    return _syncWithCas(
      tasks.map((task) => {
            'id': task.id,
            'title': task.title,
            'description': task.description,
            'start_at': task.startAt.toUtc().toIso8601String(),
            'end_at': task.endAt.toUtc().toIso8601String(),
            'timezone_id': task.timeZoneId,
            'repeat_rule': {'type': task.recurrence.name},
            'reminder_minutes': task.reminderMinutes,
            'status': task.isCompleted ? 'completed' : 'planned',
            'priority': task.priority,
            'version': task.version,
            'base_version':
                baseVersions[task.id] ?? _defaultBaseVersion(task.version),
            'created_at': task.createdAt.toUtc().toIso8601String(),
            'updated_at': task.updatedAt.toUtc().toIso8601String(),
            'deleted_at': task.deletedAt?.toUtc().toIso8601String(),
          }),
      '/rest/v1/rpc/sync_task_cas',
      'p_task',
    );
  }

  Future<void> registerDeviceToken(
      {required String platform,
      required String provider,
      required String token}) async {
    if (_session == null) {
      throw StateError('Sign in before registering a device token.');
    }
    await _send('POST', '/rest/v1/rpc/claim_device_token', {
      'p_platform': platform,
      'p_provider': provider,
      'p_token': token,
    });
  }

  Future<void> revokeDeviceToken(String token) async {
    if (_session == null) {
      throw StateError('Sign in before revoking a device token.');
    }
    await _send('POST', '/rest/v1/rpc/revoke_device_token', {
      'p_token': token,
    });
  }

  Future<List<Map<String, dynamic>>> fetchNotes() async {
    return _fetchAll('notes');
  }

  Future<List<Map<String, dynamic>>> fetchTasks() async {
    return _fetchAll('tasks');
  }

  Future<SyncWriteResult> _syncWithCas(
    Iterable<Map<String, Object?>> rows,
    String path,
    String parameter,
  ) async {
    var accepted = 0;
    var conflicts = 0;
    for (final row in rows) {
      final response = await _send('POST', path, {parameter: row});
      final result = _decode(response);
      switch (result['status']) {
        case 'accepted':
          accepted += 1;
        case 'conflict':
          conflicts += 1;
        default:
          throw FormatException('Unexpected sync result: ${result['status']}');
      }
    }
    return SyncWriteResult(accepted: accepted, conflicts: conflicts);
  }

  Future<List<Map<String, dynamic>>> _fetchAll(String table) async {
    const pageSize = 500;
    var offset = 0;
    final allRows = <Map<String, dynamic>>[];
    while (true) {
      final response = await _send(
        'GET',
        '/rest/v1/$table?select=*&order=updated_at.asc,id.asc&limit=$pageSize&offset=$offset',
        null,
      );
      final rows = _decodeList(response);
      allRows.addAll(rows);
      if (rows.length < pageSize) return allRows;
      offset += rows.length;
    }
  }

  int _defaultBaseVersion(int version) => version > 1 ? version - 1 : 0;

  Future<SupabaseResponse> _send(String method, String path, Object? payload,
      {bool authorized = true,
      Map<String, String> extraHeaders = const {}}) async {
    final headers = {
      'apikey': anonKey,
      'content-type': 'application/json',
      ...extraHeaders
    };
    if (authorized && _session != null) {
      headers['authorization'] = 'Bearer ${_session!.accessToken}';
    }
    final response = await _request(method, url.resolve(path), headers,
        payload == null ? null : jsonEncode(payload));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseApiException(response.statusCode, response.body);
    }
    return response;
  }

  static Map<String, dynamic> _decode(SupabaseResponse response) {
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Supabase response must be an object.');
    }
    return value;
  }

  static List<Map<String, dynamic>> _decodeList(SupabaseResponse response) {
    final value = jsonDecode(response.body);
    if (value is! List) {
      throw const FormatException('Supabase response must be an array.');
    }
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static SupabaseSession _sessionFromResponse(Map<String, dynamic> json,
      {String? fallbackUserId, String? fallbackRefreshToken}) {
    final user = json['user'] as Map<String, dynamic>?;
    final userId = user?['id'] as String? ?? fallbackUserId;
    if (userId == null) {
      throw const FormatException('Supabase response is missing a user ID.');
    }
    final expiresAtSeconds = json['expires_at'];
    final expiresInSeconds = json['expires_in'];
    return SupabaseSession(
      accessToken: json['access_token'] as String,
      refreshToken:
          json['refresh_token'] as String? ?? fallbackRefreshToken ?? '',
      userId: userId,
      expiresAt: expiresAtSeconds is num
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds.toInt() * 1000,
              isUtc: true)
          : expiresInSeconds is num
              ? DateTime.now()
                  .toUtc()
                  .add(Duration(seconds: expiresInSeconds.toInt()))
              : null,
    );
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
