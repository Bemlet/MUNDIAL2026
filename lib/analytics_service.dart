import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';

import 'supabase_service.dart';

/// Analítica de uso. Métodos estáticos, fire-and-forget: nunca bloquea la UI
/// ni propaga excepciones. Encola en memoria y envía por lotes a Supabase.
class AnalyticsService {
  static bool _enabled = true;
  static String? _sessionId;
  static String? _appVersion;
  static String? _platform;
  static final List<Map<String, dynamic>> _queue = [];
  static Timer? _flushTimer;
  static bool _flushing = false;

  static const Duration _flushInterval = Duration(seconds: 30);
  static const int _maxQueue = 200; // tope duro; al pasarse, se descarta lo más viejo
  static const int _flushAt = 20; // flush proactivo al acumular esta cantidad

  static bool get enabled => _enabled;
  static int get queueLength => _queue.length;

  // Solo para tests.
  static Map<String, dynamic>? get lastEventForTest =>
      _queue.isEmpty ? null : Map.of(_queue.last);

  static Future<void> initialize({required bool enabled}) async {
    _enabled = enabled;
    if (!enabled) _queue.clear();
    _sessionId ??= _uuidV4();
    _platform ??= _detectPlatform();
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {
      // En tests o plataformas sin plugin: queda null.
    }
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flush());
  }

  static void setEnabled(bool value) {
    _enabled = value;
    if (!value) _queue.clear();
  }

  static void logEvent(String name, {Map<String, dynamic>? props}) {
    if (!_enabled) return;
    _queue.add({
      'session_id': _sessionId ?? _uuidV4(),
      'event_name': name,
      'props': props ?? const <String, dynamic>{},
      'app_version': _appVersion,
      'platform': _platform,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
    if (_queue.length >= _flushAt) unawaited(flush());
  }

  static void logScreen(String screen) =>
      logEvent('screen_view', props: {'screen': screen});

  static void logError(String context, String message) {
    final m = message.length > 200 ? message.substring(0, 200) : message;
    logEvent('app_error', props: {'context': context, 'message': m});
  }

  static Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    final uid = SupabaseService.userId;
    if (uid == null) return; // sin sesión: se conservan para el próximo flush
    _flushing = true;
    try {
      final batch = List<Map<String, dynamic>>.from(_queue);
      final rows = batch.map((e) => {...e, 'user_id': uid}).toList(growable: false);
      await SupabaseService.insertEvents(rows);
      final sent = Set<Map<String, dynamic>>.identity()..addAll(batch);
      _queue.removeWhere(sent.contains);
    } catch (_) {
      // Falla silenciosa: se reintenta en el próximo flush.
    } finally {
      _flushing = false;
    }
  }

  static String _detectPlatform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // versión 4
    b[8] = (b[8] & 0x3f) | 0x80; // variante
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).toList();
    return '${h[0]}${h[1]}${h[2]}${h[3]}-${h[4]}${h[5]}-${h[6]}${h[7]}-'
        '${h[8]}${h[9]}-${h[10]}${h[11]}${h[12]}${h[13]}${h[14]}${h[15]}';
  }

  /// Limpia el estado estático entre tests.
  static void resetForTest() {
    _enabled = true;
    _sessionId = null;
    _appVersion = null;
    _platform = null;
    _queue.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushing = false;
  }
}
