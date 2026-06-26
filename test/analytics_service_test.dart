import 'package:flutter_test/flutter_test.dart';
import 'package:mundial2026/analytics_service.dart';

void main() {
  setUp(() => AnalyticsService.resetForTest());

  test('opt-out por defecto encola; deshabilitado descarta', () async {
    await AnalyticsService.initialize(enabled: true);
    expect(AnalyticsService.enabled, isTrue);

    AnalyticsService.logScreen('groups');
    AnalyticsService.logEvent('app_open');
    expect(AnalyticsService.queueLength, 2);

    AnalyticsService.setEnabled(false);
    expect(AnalyticsService.enabled, isFalse);
    expect(AnalyticsService.queueLength, 0); // al deshabilitar se vacía la cola

    AnalyticsService.logScreen('matches'); // ignorado mientras está off
    expect(AnalyticsService.queueLength, 0);
  });

  test('logScreen arma el evento screen_view con props.screen', () async {
    await AnalyticsService.initialize(enabled: true);
    AnalyticsService.logScreen('bracket');
    expect(AnalyticsService.lastEventForTest?['event_name'], 'screen_view');
    expect(AnalyticsService.lastEventForTest?['props'], {'screen': 'bracket'});
  });

  test('session_id es un UUID v4 válido', () async {
    await AnalyticsService.initialize(enabled: true);
    AnalyticsService.logEvent('app_open');
    final sid = AnalyticsService.lastEventForTest?['session_id'] as String?;
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(sid ?? ''),
      isTrue,
    );
  });

  test('flush sin sesión (userId null) NO descarta los eventos', () async {
    await AnalyticsService.initialize(enabled: true);
    AnalyticsService.logEvent('app_open');
    await AnalyticsService.flush(); // SupabaseService no está ready → userId null
    expect(AnalyticsService.queueLength, 1); // se conservan para reintentar
  });
}
