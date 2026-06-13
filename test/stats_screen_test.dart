/// Smoke test de la pantalla de estadísticas: verifica que renderiza los
/// rankings agregados sin lanzar y que navega entre pestañas.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/screens/stats_screen.dart';
import 'package:mundial2026/stats.dart';
import 'package:mundial2026/theme.dart';

Map<String, dynamic> _event({
  required String id,
  required String homeName,
  required int homeScore,
  required String awayName,
  required int awayScore,
  List<Map<String, dynamic>> details = const [],
}) => {
  'id': id,
  'status': {
    'type': {'state': 'post', 'completed': true},
  },
  'competitions': [
    {
      'attendance': 60000,
      'competitors': [
        {
          'homeAway': 'home',
          'score': '$homeScore',
          'team': {'id': 'h$id', 'displayName': homeName},
          'statistics': [
            {'name': 'possessionPct', 'value': 58.0},
          ],
        },
        {
          'homeAway': 'away',
          'score': '$awayScore',
          'team': {'id': 'a$id', 'displayName': awayName},
          'statistics': const [],
        },
      ],
      'details': details,
    },
  ],
};

Map<String, dynamic> _goal(String athId, String name, String teamId) => {
  'scoringPlay': true,
  'penaltyKick': false,
  'ownGoal': false,
  'shootout': false,
  'athletesInvolved': [
    {
      'id': athId,
      'displayName': name,
      'team': {'id': teamId},
    },
  ],
};

void main() {
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState();
    await state.load();
    // load() dispara sync() (sin red en test): inyectamos datos a mano.
    state.matchStats['1'] = MatchStats.fromScoreboardEvent(
      _event(
        id: '1',
        homeName: 'Argentina',
        homeScore: 3,
        awayName: 'Mexico',
        awayScore: 0,
        details: [
          _goal('p1', 'Lionel Messi', 'h1'),
          _goal('p1', 'Lionel Messi', 'h1'),
          _goal('p2', 'Julian Alvarez', 'h1'),
        ],
      ),
    );
  });

  Widget harness() => AppScope(
    state: state,
    child: MaterialApp(
      theme: buildTheme(),
      home: const Scaffold(body: SafeArea(child: StatsScreen())),
    ),
  );

  testWidgets('renderiza goleadores agregados', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bota de Oro'), findsOneWidget);
    // Messi aparece como goleador y como figura: basta con que esté presente.
    expect(find.text('Lionel Messi'), findsWidgets);
    expect(find.text('Julian Alvarez'), findsWidgets);
  });

  testWidgets('navega a la pestaña Resumen y muestra totales', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(Tab, 'Resumen'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    expect(find.text('El torneo en números'), findsOneWidget);
    expect(find.text('Goles totales'), findsOneWidget);
  });

  testWidgets('estado vacío sin partidos jugados', (tester) async {
    state.matchStats.clear();
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('estadísticas aparecerán'), findsOneWidget);
  });
}
