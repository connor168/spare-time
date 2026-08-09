import 'package:flutter_test/flutter_test.dart';

import 'package:focus_flow/services/auth_controller.dart';
import 'package:focus_flow/services/auth_session_store.dart';
import 'package:focus_flow/services/supabase_rest_client.dart';

void main() {
  test('sign in persists the session', () async {
    final store = InMemoryAuthSessionStore();
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async => const SupabaseResponse(
        200,
        '{"access_token":"a","refresh_token":"r","expires_in":3600,"user":{"id":"u1"}}',
      ),
    );
    final controller = AuthController(client: client, store: store);

    await controller.signIn(email: ' a@b.test ', password: 'password');

    expect(controller.status, AuthStatus.signedIn);
    expect((await store.read())?.userId, 'u1');
  });

  test('restore refreshes an expired session and persists rotated tokens',
      () async {
    final store = InMemoryAuthSessionStore();
    await store.write(SupabaseSession(
        accessToken: 'old',
        refreshToken: 'old-r',
        userId: 'u1',
        expiresAt: DateTime(2020).toUtc()));
    var refreshCalled = false;
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async {
        refreshCalled = true;
        return const SupabaseResponse(200,
            '{"access_token":"new","refresh_token":"new-r","expires_in":3600}');
      },
    );
    final controller = AuthController(client: client, store: store);

    await controller.restore();

    expect(refreshCalled, isTrue);
    expect(controller.session?.accessToken, 'new');
    expect((await store.read())?.refreshToken, 'new-r');
  });

  test('email confirmation is a distinct non-error state', () async {
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async =>
          const SupabaseResponse(200, '{"user":{"id":"u1"}}'),
    );
    final controller =
        AuthController(client: client, store: InMemoryAuthSessionStore());

    await controller.signUp(email: 'a@b.test', password: 'password');

    expect(controller.status, AuthStatus.needsEmailConfirmation);
    expect(controller.errorMessage, isNull);
  });

  test('sign out clears local state even when the network fails', () async {
    final store = InMemoryAuthSessionStore();
    await store.write(const SupabaseSession(
        accessToken: 'a', refreshToken: 'r', userId: 'u1'));
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'public-key',
      request: (method, uri, headers, body) async =>
          const SupabaseResponse(503, ''),
    );
    client.setSession(const SupabaseSession(
        accessToken: 'a', refreshToken: 'r', userId: 'u1'));
    final controller = AuthController(client: client, store: store);
    controller.status = AuthStatus.signedIn;
    controller.session = client.session;

    await controller.signOut();

    expect(controller.status, AuthStatus.signedOut);
    expect(await store.read(), isNull);
    expect(client.session, isNull);
  });
}
