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
  final Map<String, int> _pendingRevocations = {};
  Timer? _retryTimer;
  static const _retryDelay = Duration(minutes: 5);
  static const _maxRetries = 12;

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

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    if (_pendingRevocations.isEmpty) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _processRetryQueue);
  }

  Future<void> _processRetryQueue() async {
    if (_pendingRevocations.isEmpty || supabase.session == null) return;
    final batch = Map<String, int>.from(_pendingRevocations);
    _pendingRevocations.clear();
    for (final entry in batch.entries) {
      try {
        await supabase.revokeDeviceToken(entry.key);
      } on Object {
        final attempts = entry.value + 1;
        if (attempts < _maxRetries) {
          _pendingRevocations[entry.key] = attempts;
        }
      }
    }
    if (_pendingRevocations.isNotEmpty) {
      _scheduleRetry();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _retryTimer?.cancel();
  }

  Future<void> revoke() async {
    await dispose();
    final token = _currentToken;
    _currentToken = null;
    if (token == null || token.isEmpty || supabase.session == null) return;
    try {
      await supabase.revokeDeviceToken(token);
    } on Object {
      _pendingRevocations[token] = 1;
      _scheduleRetry();
    }
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
      try {
        await supabase.revokeDeviceToken(previous);
      } on Object {
        _pendingRevocations[previous] = 1;
        _scheduleRetry();
      }
    }
  }
}
