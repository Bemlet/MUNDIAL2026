/// Capturas de las pantallas reales (goldens) para revisión visual.
/// Ejecutar: flutter test --update-goldens test/screens_golden_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/models.dart';
import 'package:mundial2026/screens/match_detail.dart';
import 'package:mundial2026/screens/onboarding_screen.dart';
import 'package:mundial2026/screens/team_detail.dart';
import 'package:mundial2026/stats.dart';
import 'package:mundial2026/theme.dart';

late AppState state;

Widget app(Widget home) => AppScope(
  state: state,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: home,
  ),
);

/// Inserta resultados realistas: partidos 1-2 finalizados y 3 en vivo.
void seedLive() {
  void put(int no, String st, String dt, int hs, int as) {
    final m = state.byNo[no]!;
    state.live[m.espnId] = LiveInfo(
      espnId: m.espnId,
      status: st,
      detail: dt,
      homeScore: hs,
      awayScore: as,
      homeEspn: state.teams[m.homeSlot]!.espn,
      awayEspn: state.teams[m.awaySlot]!.espn,
    );
  }

  put(1, 'STATUS_FULL_TIME', 'FT', 2, 0); // México 2-0 Sudáfrica
  put(2, 'STATUS_FULL_TIME', 'FT', 2, 1); // Corea del Sur 2-1 Chequia
  put(3, 'STATUS_IN_PROGRESS', "57'", 1, 0); // Canadá 1-0 Bosnia (en vivo)
}

/// Siembra estadísticas de torneo realistas para la captura de la pantalla.
void seedStats() {
  Map<String, dynamic> goal(String id, String name, String teamId) => {
    'scoringPlay': true,
    'penaltyKick': false,
    'ownGoal': false,
    'shootout': false,
    'athletesInvolved': [
      {
        'id': id,
        'displayName': name,
        'team': {'id': teamId},
      },
    ],
  };

  Map<String, dynamic> event(
    int no,
    int hs,
    int as,
    List<Map<String, dynamic>> details,
  ) {
    final m = state.byNo[no]!;
    final home = state.teams[m.homeSlot]!, away = state.teams[m.awaySlot]!;
    return {
      'id': m.espnId,
      'status': {
        'type': {'state': 'post', 'completed': true},
      },
      'competitions': [
        {
          'attendance': 78000,
          'competitors': [
            {
              'homeAway': 'home',
              'score': '$hs',
              'team': {'id': 'h$no', 'displayName': home.espn},
              'statistics': [
                {'name': 'possessionPct', 'value': 56.0},
                {'name': 'totalShots', 'value': 14.0},
              ],
            },
            {
              'homeAway': 'away',
              'score': '$as',
              'team': {'id': 'a$no', 'displayName': away.espn},
              'statistics': const [],
            },
          ],
          'details': details,
        },
      ],
    };
  }

  final m1 = state.byNo[1]!, m2 = state.byNo[2]!;
  state.matchStats[m1.espnId] = MatchStats.fromScoreboardEvent(
    event(1, 2, 0, [
      goal('s1', 'Raúl Jiménez', 'h1'),
      goal('s1', 'Raúl Jiménez', 'h1'),
    ]),
  );
  state.matchStats[m2.espnId] = MatchStats.fromScoreboardEvent(
    event(2, 2, 1, [
      goal('s2', 'Son Heung-min', 'h2'),
      goal('s3', 'Lee Kang-in', 'h2'),
      goal('s4', 'Patrik Schick', 'a2'),
    ]),
  );
}

Future<void> snap(
  WidgetTester tester,
  Widget home,
  String name, {
  Future<void> Function(WidgetTester)? interact,
}) async {
  // Key única: evita que se reutilice el estado de la captura anterior.
  await tester.pumpWidget(app(KeyedSubtree(key: UniqueKey(), child: home)));
  // Decodificar todas las banderas para que salgan en la captura.
  final ctx = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final t in state.teams.values) {
      await precacheImage(AssetImage('assets/flags/${t.flag}.png'), ctx);
    }
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  if (interact != null) {
    await interact(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit-Variable.ttf'));
    await loader.load();
    await initializeDateFormatting('es');
    Intl.defaultLocale = 'es';

    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    state = AppState();
    await state.load(initialSync: false);
    seedLive();
    seedStats();
  });

  // Solo se ejecuta con --update-goldens: la simulación es aleatoria, por lo
  // que las capturas son una herramienta de revisión, no un test de regresión.
  testWidgets('capturas de pantallas', skip: !autoUpdateGoldenFiles, (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    // 1. Partidos (inicio)
    await snap(tester, const Shell(), 'partidos');

    // 2. Grupos
    await snap(
      tester,
      const Shell(),
      'grupos',
      interact: (t) async {
        await t.tap(find.text('Grupos').last);
      },
    );

    // 3. Bracket real (con llaves por definir)
    await snap(
      tester,
      const Shell(),
      'bracket',
      interact: (t) async {
        await t.tap(find.text('Bracket').last);
      },
    );

    // 4. Equipos
    await snap(
      tester,
      const Shell(),
      'equipos',
      interact: (t) async {
        await t.tap(find.text('Equipos').last);
      },
    );

    // 4b. Estadísticas (goleadores)
    await snap(
      tester,
      const Shell(),
      'estadisticas',
      interact: (t) async {
        await t.tap(find.text('Stats').last);
      },
    );

    // 4c. Onboarding de primera apertura (slide de bienvenida)
    await snap(tester, const OnboardingScreen(), 'onboarding');

    // 5. Detalle de selección (Argentina)
    await snap(tester, const TeamDetailScreen(teamId: 'ARG'), 'equipo_arg');

    // 6. Detalle de partido finalizado (México 2-0 Sudáfrica)
    await snap(tester, const MatchDetailScreen(matchNo: 1), 'partido_final');

    // 7. Detalle de partido futuro (Argentina vs Argelia, previa)
    await snap(tester, const MatchDetailScreen(matchNo: 19), 'partido_previa');

    // 8-9. Simulador con simulación completa
    state.simulateRemaining();
    await snap(
      tester,
      const Shell(),
      'polla_grupos',
      interact: (t) async {
        await t.tap(find.text('Simulador').last);
      },
    );
    await snap(
      tester,
      const Shell(),
      'polla_bracket',
      interact: (t) async {
        await t.tap(find.text('Simulador').last);
        for (var i = 0; i < 4; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.tap(
          find.descendant(
            of: find.byType(TabBar),
            matching: find.text('Bracket'),
          ),
        );
      },
    );

    // 10-12. Modo claro
    state.toggleTheme();
    await snap(tester, const Shell(), 'claro_partidos');
    await snap(
      tester,
      const Shell(),
      'claro_grupos',
      interact: (t) async {
        await t.tap(find.text('Grupos').last);
      },
    );
    await snap(
      tester,
      const Shell(),
      'claro_simulador',
      interact: (t) async {
        await t.tap(find.text('Simulador').last);
      },
    );
    await snap(tester, const MatchDetailScreen(matchNo: 1), 'claro_partido');
    state.toggleTheme(); // restaurar
  });
}
