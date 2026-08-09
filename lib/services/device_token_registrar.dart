import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:huawei_push/huawei_push.dart';

import 'supabase_rest_client.dart';

enum PushProvider { fcm, apns, hms }

abstract interface class DeviceTokenSource {
  PushProvider get provider;
  Future<String?> requestToken();
  Stream<String> get onTokenRefresh;
}

class FirebaseDeviceTokenSource implements DeviceTokenSource {
  FirebaseDeviceTokenSource({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;
  final FirebaseMessaging _messaging;

  @override
  PushProvider get provider => PushProvider.fcm;

  @override
  Future<String?> requestToken() async {
    await _messaging.requestPermission(
        alert: true, badge: true, sound: true, provisional: false);
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}

class HuaweiDeviceTokenSource implements DeviceTokenSource {
  @override
  PushProvider get provider => PushProvider.hms;

  @override
  Future<String?> requestToken() async {
    final tokenFuture = Push.getTokenStream.first;
    Push.getToken('HCM');
    return tokenFuture;
  }

  @override
  Stream<String> get onTokenRefresh => Push.getTokenStream;
}

class DeviceTokenRegistrar {
  DeviceTokenRegistrar(
      {required this.supabase,
      required this.source,
      this.platform = 'android'});

  final SupabaseRestClient supabase;
  final DeviceTokenSource source;
  final String platform;
  StreamSubscription<String>? _subscription;
  String? _currentToken;
  Future<void> _refreshQueue = Future<void>.value();

  Future<void> start() async {
    final token = await source.requestToken();
    await _register(token);
    _currentToken = token;
    await _subscription?.cancel();
    _subscription = source.onTokenRefresh.listen((token) {
      _refreshQueue = _refreshQueue
          .then((_) => _replaceToken(token))
          .catchError((Object _) {});
    });
  }

  Future<void> dispose() => _subscription?.cancel() ?? Future<void>.value();

  Future<void> revoke() async {
    await dispose();
    final token = _currentToken;
    _currentToken = null;
    if (token == null || token.isEmpty || supabase.session == null) return;
    await supabase.revokeDeviceToken(token);
  }

  Future<void> _register(String? token) async {
    if (token == null || token.isEmpty || supabase.session == null) return;
    await supabase.registerDeviceToken(
        platform: platform, provider: source.provider.name, token: token);
  }

  Future<void> _replaceToken(String token) async {
    final previous = _currentToken;
    await _register(token);
    _currentToken = token;
    if (previous != null && previous.isNotEmpty && previous != token) {
      await supabase.revokeDeviceToken(previous);
    }
  }
}
