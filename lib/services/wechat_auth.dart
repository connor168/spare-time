import 'package:flutter/services.dart';

class WeChatAuthException implements Exception {
  const WeChatAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class WeChatAuth {
  Future<bool> isInstalled();

  Future<String> requestCode();
}

class MethodChannelWeChatAuth implements WeChatAuth {
  MethodChannelWeChatAuth({required this.appId})
      : _channel = const MethodChannel('focusflow/wechat');

  final String appId;
  final MethodChannel _channel;

  @override
  Future<bool> isInstalled() async {
    final result = await _channel.invokeMethod<bool>('isInstalled');
    return result ?? false;
  }

  @override
  Future<String> requestCode() async {
    final installed = await isInstalled();
    if (!installed) {
      throw const WeChatAuthException(
          'WeChat is not installed on this device.');
    }
    final code = await _channel.invokeMethod<String>('login');
    if (code == null || code.isEmpty) {
      throw const WeChatAuthException(
          'WeChat did not return an authorization code.');
    }
    return code;
  }
}
