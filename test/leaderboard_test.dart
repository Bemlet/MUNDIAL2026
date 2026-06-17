/// Pick'em/leaderboard: el servicio de Supabase es seguro sin inicializar y la
/// pantalla rinde con la pestaña Ranking.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/screens/prediction_screen.dart';
import 'package:mundial2026/supabase_service.dart';
import 'package:mundial2026/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  test('SupabaseService no crashea sin inicializar (no-op)', () async {
    expect(SupabaseService.ready, isFalse);
    expect(SupabaseService.userId, isNull);
    expect(await SupabaseService.fetchLeaderboard(), isEmpty);
    expect(await SupabaseService.fetchNickname(), isNull);
    await SupabaseService.signInAnonymously();
    await SupabaseService.upsertPrediction(1, 2, 1);
    await SupabaseService.deletePrediction(1);
  });

  testWidgets("PredictionScreen rinde el pick'em con pestaña Ranking", (
    tester,
  ) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      await state.load(initialSync: false);
    });

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(theme: buildTheme(), home: const PredictionScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tu puntaje'), findsOneWidget); // header de puntaje
    expect(find.text('Ranking'), findsWidgets); // pestaña nueva
  });
}
