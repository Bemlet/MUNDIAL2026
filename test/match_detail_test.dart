/// Verifica que el detalle de partido muestra el timeline de goles y tarjetas
/// (autor, minuto) leído de AppState.matchStats.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/models.dart';
import 'package:mundial2026/screens/match_detail.dart';
import 'package:mundial2026/stats.dart';
import 'package:mundial2026/theme.dart';

Map<String, dynamic> _event(
  String espnId,
  String homeEspn,
  int hs,
  String awayEspn,
  int as,
  List<Map<String, dynamic>> details,
) => {
  'id': espnId,
  'status': {
    'type': {'state': 'post', 'completed': true},
  },
  'competitions': [
    {
      'competitors': [
        {
          'homeAway': 'home',
          'score': '$hs',
          'team': {'id': 'h', 'displayName': homeEspn},
          'statistics': const [],
        },
        {
          'homeAway': 'away',
          'score': '$as',
          'team': {'id': 'a', 'displayName': awayEspn},
          'statistics': const [],
        },
      ],
      'details': details,
    },
  ],
};

Map<String, dynamic> _goal(String name, String teamId, String clock) => {
  'scoringPlay': true,
  'penaltyKick': false,
  'ownGoal': false,
  'shootout': false,
  'clock': {'displayValue': clock},
  'athletesInvolved': [
    {
      'id': name,
      'displayName': name,
      'team': {'id': teamId},
    },
  ],
};

Map<String, dynamic> _card(String name, String teamId, String clock) => {
  'scoringPlay': false,
  'yellowCard': true,
  'redCard': false,
  'clock': {'displayValue': clock},
  'athletesInvolved': [
    {
      'id': name,
      'displayName': name,
      'team': {'id': teamId},
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  testWidgets('muestra goleadores y tarjetas del partido', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      await state.load(initialSync: false);
    });

    // Partido 1: México (local) vs Sudáfrica. Sembramos eventos.
    final m = state.byNo[1]!;
    final homeEspn = state.teams[m.homeSlot]!.espn; // 'Mexico'
    final awayEspn = state.teams[m.awaySlot]!.espn; // 'South Africa'
    state.matchStats[m.espnId] = MatchStats.fromScoreboardEvent(
      _event(m.espnId, homeEspn, 1, awayEspn, 0, [
        _goal('Raul Jimenez', 'h', "23'"),
        _card('Teboho Mokoena', 'a', "67'"),
      ]),
    );

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

    expect(find.text('Goles y tarjetas'), findsOneWidget);
    expect(find.textContaining('Raul Jimenez'), findsOneWidget);
    expect(find.textContaining('Teboho Mokoena'), findsOneWidget);
    expect(find.textContaining("23'"), findsOneWidget);
  });

  testWidgets('no muestra la sección si no hay eventos', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      await state.load(initialSync: false);
    });

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

    expect(find.text('Goles y tarjetas'), findsNothing);
  });

  testWidgets('detalle de grupo bloqueado no permite editar pronóstico', (
    tester,
  ) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      await state.load(initialSync: false);
    });

    final original = state.byNo[1]!;
    state.byNo[1] = WcMatch.fromJson({
      'no': original.no,
      'stage': 'group',
      'group': original.group,
      'home': original.homeSlot,
      'away': original.awaySlot,
      'date': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 1))
          .toIso8601String(),
      'venue': original.venue,
      'espnId': original.espnId,
    });

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

    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets(
    'detalle de eliminatoria permite editar si los equipos reales están resueltos',
    (tester) async {
      late AppState state;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        state = AppState();
        await state.load(initialSync: false);
      });

      final original = state.byNo[73]!;
      final match = WcMatch.fromJson({
        'no': original.no,
        'stage': 'r32',
        'group': null,
        'home': original.homeSlot,
        'away': original.awaySlot,
        'date': DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .toIso8601String(),
        'venue': original.venue,
        'espnId': original.espnId,
      });
      state.byNo[73] = match;
      final home = state.teams['MEX']!;
      final away = state.teams['RSA']!;
      state.live[match.espnId] = LiveInfo(
        espnId: match.espnId,
        status: 'STATUS_SCHEDULED',
        detail: '',
        homeScore: null,
        awayScore: null,
        homeEspn: home.espn,
        awayEspn: away.espn,
      );

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(),
            home: const MatchDetailScreen(matchNo: 73),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.keyboard_arrow_up), findsNWidgets(2));

      final firstStepper = find.byIcon(Icons.keyboard_arrow_up).first;
      await tester.ensureVisible(firstStepper);
      await tester.pump();
      await tester.tap(firstStepper);
      await tester.pump();

      expect(state.preds[73]!.home, 1);
      expect(state.preds[73]!.away, 0);
    },
  );
}
