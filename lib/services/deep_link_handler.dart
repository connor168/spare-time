import 'dart:async';

import 'package:flutter/services.dart';

enum DeepLinkRoute { newsDaily, unknown }

class DeepLinkEvent {
  const DeepLinkEvent(this.route, this.uri);
  final DeepLinkRoute route;
  final Uri uri;
}

class DeepLinkHandler {
  DeepLinkHandler() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const _channel = MethodChannel('focusflow/deep_link');
  final _controller = StreamController<DeepLinkEvent>.broadcast();

  Stream<DeepLinkEvent> get events => _controller.stream;
  DeepLinkEvent? _pending;

  static DeepLinkRoute parse(String uriString) {
    Uri uri;
    try {
      uri = Uri.parse(uriString);
    } on FormatException {
      return DeepLinkRoute.unknown;
    }
    if (uri.scheme == 'focusflow' &&
        uri.host == 'news' &&
        uri.path.startsWith('/daily')) {
      return DeepLinkRoute.newsDaily;
    }
    return DeepLinkRoute.unknown;
  }

  void handleUri(String uriString) {
    final event = DeepLinkEvent(parse(uriString), Uri.tryParse(uriString) ?? Uri());
    if (_controller.hasListener) {
      _controller.add(event);
    } else {
      _pending = event;
    }
  }

  DeepLinkEvent? consumePending() {
    final event = _pending;
    _pending = null;
    return event;
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final uri = call.arguments as String?;
      if (uri != null && uri.isNotEmpty) handleUri(uri);
    }
  }

  void dispose() => _controller.close();
}
