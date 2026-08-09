import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'supabase_rest_client.dart';

abstract interface class AuthSessionStore {
  Future<SupabaseSession?> read();

  Future<void> write(SupabaseSession session);

  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'focus_flow.auth.session';
  final FlutterSecureStorage _storage;

  @override
  Future<SupabaseSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SupabaseSession.fromJson(jsonDecode(raw));
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(SupabaseSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}

class InMemoryAuthSessionStore implements AuthSessionStore {
  SupabaseSession? _session;

  @override
  Future<SupabaseSession?> read() async => _session;

  @override
  Future<void> write(SupabaseSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
