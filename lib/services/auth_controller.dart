import 'package:flutter/foundation.dart';

import 'auth_session_store.dart';
import 'supabase_rest_client.dart';

enum AuthStatus { signedOut, loading, signedIn, needsEmailConfirmation, error }

class AuthController extends ChangeNotifier {
  AuthController({required this.client, required this.store});

  final SupabaseRestClient client;
  final AuthSessionStore store;

  AuthStatus status = AuthStatus.signedOut;
  SupabaseSession? session;
  String? errorMessage;

  bool get isBusy => status == AuthStatus.loading;

  Future<void> restore() async {
    if (isBusy) return;
    _setLoading();
    try {
      final stored = await store.read();
      if (stored == null) {
        _setSignedOut();
        return;
      }
      client.setSession(stored);
      final expiresAt = stored.expiresAt;
      if (expiresAt == null ||
          expiresAt.isAfter(
              DateTime.now().toUtc().add(const Duration(minutes: 1)))) {
        _setSignedIn(stored);
        return;
      }
      try {
        final restored = await client.refreshSession();
        await _persist(restored);
        _setSignedIn(restored);
      } on SupabaseApiException catch (error) {
        if (error.statusCode == 400 || error.statusCode == 401) {
          await store.clear();
          client.clearSession();
          _setSignedOut();
        } else {
          _setSignedIn(stored);
        }
      } on Object {
        // Keep an offline session available; protected requests can retry later.
        _setSignedIn(stored);
      }
    } on Object catch (error) {
      await store.clear();
      client.clearSession();
      _setError(error);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _setLoading();
    try {
      final signedIn =
          await client.signIn(email: email.trim(), password: password);
      await _persist(signedIn);
      _setSignedIn(signedIn);
    } on Object catch (error) {
      _setError(error);
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    _setLoading();
    try {
      final registered =
          await client.signUp(email: email.trim(), password: password);
      await _persist(registered);
      _setSignedIn(registered);
    } on EmailConfirmationRequired {
      // Supabase returns no access token when email confirmation is enabled.
      session = null;
      status = AuthStatus.needsEmailConfirmation;
      errorMessage = null;
      notifyListeners();
    } on Object catch (error) {
      _setError(error);
    }
  }

  Future<void> signOut() async {
    _setLoading();
    try {
      await client.signOut();
    } on Object {
      // Local sign-out must not depend on network availability.
    } finally {
      await store.clear();
      client.clearSession();
      _setSignedOut();
    }
  }

  void dismissEmailConfirmation() {
    if (status == AuthStatus.needsEmailConfirmation) _setSignedOut();
  }

  Future<void> _persist(SupabaseSession value) => store.write(value);

  void _setLoading() {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();
  }

  void _setSignedIn(SupabaseSession value) {
    session = value;
    status = AuthStatus.signedIn;
    errorMessage = null;
    notifyListeners();
  }

  void _setSignedOut() {
    session = null;
    status = AuthStatus.signedOut;
    errorMessage = null;
    notifyListeners();
  }

  void _setError(Object error) {
    status = AuthStatus.error;
    errorMessage = error.toString();
    notifyListeners();
  }
}
