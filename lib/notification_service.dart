import 'package:flutter/services.dart';

class NotificationService {
  static const _channel = MethodChannel('mundial2026/notifications');
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _channel.invokeMethod<void>('initialize');
      await _channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // Tests and non-Android targets do not provide the native channel.
    } catch (_) {}
  }

  static Future<void> setLanguage(String code) async {
    await initialize();
    try {
      await _channel.invokeMethod<void>('setLanguage', {'code': code});
    } on MissingPluginException {
      // Tests and non-Android targets do not provide the native channel.
    } catch (_) {}
  }

  static Future<bool> show({
    required String key,
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    try {
      return await _channel.invokeMethod<bool>('show', {
            'key': key,
            'id': id,
            'title': title,
            'body': body,
          }) ??
          false;
    } on MissingPluginException {
      // Tests and non-Android targets do not provide the native channel.
    } catch (_) {}
    return false;
  }
}
