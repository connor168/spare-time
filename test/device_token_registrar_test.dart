import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_flow/services/device_token_registrar.dart';
import 'package:focus_flow/services/supabase_rest_client.dart';

class _FakeSource implements DeviceTokenSource {
  final controller = StreamController<String>.broadcast();
  @override
  PushProvider get provider => PushProvider.fcm;
  @override
  Stream<String> get onTokenRefresh => controller.stream;
  @override
  Future<String?> requestToken() async => 'token-1';
}

void main() {
  test('registers initial and refreshed token through Supabase', () async {
    final requests = <String>[];
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'key',
      request: (method, uri, headers, body) async {
        if (uri.path == '/auth/v1/token') {
          return const SupabaseResponse(200,
              '{"access_token":"a","refresh_token":"r","user":{"id":"u"}}');
        }
        requests.add('${uri.path} ${body ?? ''}');
        return const SupabaseResponse(201, '');
      },
    );
    await client.signIn(email: 'a@b.test', password: 'pw');
    final source = _FakeSource();
    final registrar = DeviceTokenRegistrar(supabase: client, source: source);
    await registrar.start();
    await Future<void>.delayed(Duration.zero);
    source.controller.add('token-2');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
        requests
            .where((request) =>
                request.contains('/rest/v1/rpc/claim_device_token'))
            .length,
        2);
    expect(requests, contains(contains('/rest/v1/rpc/revoke_device_token')));
    await registrar.revoke();
    expect(requests.last, contains('/rest/v1/rpc/revoke_device_token'));
    await source.controller.close();
  });

  test('keeps the last claimed token when a refresh claim fails', () async {
    final revokedBodies = <String>[];
    final client = SupabaseRestClient(
      url: Uri.parse('https://project.supabase.co'),
      anonKey: 'key',
      request: (method, uri, headers, body) async {
        if (uri.path.endsWith('/claim_device_token') &&
            (body ?? '').contains('token-2')) {
          return const SupabaseResponse(503, 'provider unavailable');
        }
        if (uri.path.endsWith('/revoke_device_token')) {
          revokedBodies.add(body!);
        }
        return const SupabaseResponse(200, '');
      },
    )..setSession(const SupabaseSession(
        accessToken: 'a', refreshToken: 'r', userId: 'u'));
    final source = _FakeSource();
    final registrar = DeviceTokenRegistrar(supabase: client, source: source);
    await registrar.start();

    source.controller.add('token-2');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await registrar.revoke();

    expect(revokedBodies.single, contains('token-1'));
    await source.controller.close();
  });
}
