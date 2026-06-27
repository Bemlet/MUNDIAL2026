import 'package:flutter/services.dart';

class NotificationService {
  static const _channel = MethodChannel('mundial2026/notifications');
  static bool _initialized = false;

  /// Callback invocado cuando se toca una notificación con `route` (app abierta).
  static void Function(String route)? _onNavigate;

  static void setNavigateHandler(void Function(String route) handler) {
    _onNavigate = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'navigate') {
        final route = call.arguments as String?;
        if (route != null && route.isNotEmpty) _onNavigate?.call(route);
      }
      return null;
    });
  }

  /// Ruta pendiente si la app se abrió tocando una notificación (cold start).
  static Future<String?> consumeLaunchRoute() async {
    try {
      return await _channel.invokeMethod<String>('consumeRoute');
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

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

  /// ¿La app puede programar alarmas exactas? (true en plataformas sin el canal).
  static Future<bool> canScheduleExactAlarms() async {
    await initialize();
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? true;
    } on MissingPluginException {
      // Tests and non-Android targets do not provide the native channel.
    } catch (_) {}
    return true;
  }

  /// Abre los ajustes del sistema para conceder la alarma exacta (Android 12+).
  static Future<void> requestExactAlarm() async {
    await initialize();
    try {
      await _channel.invokeMethod<void>('requestExactAlarm');
    } on MissingPluginException {
      // Tests and non-Android targets do not provide the native channel.
    } catch (_) {}
  }

  static Future<bool> show({
    required String key,
    required int id,
    required String title,
    required String body,
    String? route,
  }) async {
    await initialize();
    try {
      return await _channel.invokeMethod<bool>('show', {
            'key': key,
            'id': id,
            'title': title,
            'body': body,
            'route': route,
          }) ??
          false;
    } on MissingPluginException {
      // Tests and non-Android targets do not provide the native channel.
    } catch (_) {}
    return false;
  }
}
