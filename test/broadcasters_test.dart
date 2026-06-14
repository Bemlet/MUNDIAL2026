/// Canales de transmisión: dataset por país, EE.UU. en vivo desde ESPN y UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/models.dart';
import 'package:mundial2026/screens/match_detail.dart';
import 'package:mundial2026/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('AppState canales', () {
    test('carga el dataset (US, MX, AR, CO)', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      expect(s.broadcasters.keys.toSet(), {'US', 'MX', 'AR', 'CO'});
      expect(s.broadcasters['MX']!.all, contains('ViX'));
      expect(s.broadcasters['MX']!.select, contains('Canal 5'));
    });

    test('MX: partido de México suma los abiertos; otro grupo solo ViX', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      s.setCountry('MX');

      // Partido de la selección mexicana (o inauguración): abiertos + ViX.
      final mex = s.matches.firstWhere(
        (m) => m.stage == Stage.group &&
            (m.homeSlot == 'MEX' || m.awaySlot == 'MEX'),
      );
      expect(s.channelsFor(mex), containsAll(['ViX', 'Canal 5', 'Azteca 7']));

      // Partido de grupos sin México (ni inauguración): solo el de todo el torneo.
      final other = s.matches.firstWhere(
        (m) => m.stage == Stage.group &&
            m.no != 1 &&
            m.homeSlot != 'MEX' &&
            m.awaySlot != 'MEX',
      );
      expect(s.channelsFor(other), ['ViX']);
      expect(s.channelsFor(other), isNot(contains('Canal 5')));
    });

    test('los abiertos aparecen en eliminatorias', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      s.setCountry('AR');
      final ko = s.matches.firstWhere((m) => m.isKnockout);
      expect(s.channelsFor(ko), containsAll(['DSports', 'Telefe']));
    });

    test('EE.UU. prioriza el feed en vivo de ESPN cuando existe', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      s.setCountry('US');
      final m = s.byNo[1]!;
      // Sin datos en vivo → cae a la lista de todo el torneo.
      expect(s.channelsFor(m), contains('FOX'));
      // Con datos en vivo → usa esos (por partido).
      s.liveBroadcasts[m.espnId] = ['FS1', 'Telemundo'];
      expect(s.channelsFor(m), ['FS1', 'Telemundo']);
    });

    test('país no soportado no muestra canales', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      s.setCountry('CL');
      expect(s.channelsFor(s.byNo[1]!), isEmpty);
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
    expect(find.text('ViX'), findsWidgets); // partido 1 = inauguración (México)
  });
}
