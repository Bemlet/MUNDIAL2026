/// Canales de transmisión: dataset por país, EE.UU. en vivo desde ESPN y UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/screens/match_detail.dart';
import 'package:mundial2026/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('AppState canales', () {
    test('carga el dataset de canales por país', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      expect(s.broadcasters.containsKey('MX'), isTrue);
      expect(s.broadcasters.containsKey('US'), isTrue);
      expect(s.broadcasters['MX']!.channels, contains('ViX'));
    });

    test('channelsFor usa la lista curada del país elegido', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      s.setCountry('MX');
      final m = s.byNo[1]!;
      expect(s.channelsFor(m), contains('Televisa'));
    });

    test('EE.UU. prioriza el feed en vivo de ESPN cuando existe', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      s.setCountry('US');
      final m = s.byNo[1]!;
      // Sin datos en vivo → cae a la lista curada.
      expect(s.channelsFor(m), contains('FOX'));
      // Con datos en vivo → usa esos (por partido).
      s.liveBroadcasts[m.espnId] = ['FS1', 'Telemundo'];
      expect(s.channelsFor(m), ['FS1', 'Telemundo']);
    });

    test('setCountry persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      s.setCountry('AR');
      final s2 = AppState();
      await s2.load(initialSync: false);
      expect(s2.country, 'AR');
    });
  });

  testWidgets('el detalle de partido muestra "Dónde verlo"', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      await state.load(initialSync: false);
    });
    state.setCountry('MX');

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: buildTheme(),
          home: const MatchDetailScreen(matchNo: 1),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Dónde verlo'), findsOneWidget);
    expect(find.text('Televisa'), findsWidgets);
  });
}
