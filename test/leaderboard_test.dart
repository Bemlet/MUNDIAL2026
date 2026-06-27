/// Pick'em/leaderboard: el servicio de Supabase es seguro sin inicializar y la
/// pantalla rinde con la pestaña Ranking.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/models.dart';
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

  test('leaderboard desempata por exactos y nickname', () {
    final entries = [
      const LeaderEntry(
        userId: 'b',
        nickname: 'Zulu',
        points: 12,
        exactCount: 1,
      ),
      const LeaderEntry(
        userId: 'c',
        nickname: 'Ana',
        points: 12,
        exactCount: 2,
      ),
      const LeaderEntry(
        userId: 'd',
        nickname: 'Beto',
        points: 12,
        exactCount: 2,
      ),
      const LeaderEntry(
        userId: 'a',
        nickname: 'Max',
        points: 15,
        exactCount: 0,
      ),
    ];

    final sorted = SupabaseService.sortLeaderboardForDisplay(entries);

    expect(sorted.map((e) => e.nickname), ['Max', 'Ana', 'Beto', 'Zulu']);
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

    // Pin clock to before knockout so finalPhaseActive is deterministically false.
    state.clockOverride = DateTime.utc(2026, 6, 1);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(theme: buildTheme(), home: const PredictionScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tu puntaje · Grupos'), findsOneWidget); // header de puntaje (fase grupos activa)
    expect(find.text('Pronósticos'), findsOneWidget);
    expect(find.text('Ranking'), findsWidgets);
    expect(find.text('Mejores terceros'), findsNothing);
    expect(find.text('Bracket'), findsNothing);
  });

  testWidgets('PredictionScreen muestra filtros de pickem en español', (
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

    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('Próximos'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Mis picks'), findsOneWidget);
    expect(find.text('Cerrados'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
  });

  testWidgets('PredictionScreen filtra pendientes, todos y mis picks', (
    tester,
  ) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      await state.load(initialSync: false);
    });

    final now = DateTime.now().toUtc();
    final first = state.matches[0];
    final second = state.matches[1];
    final pending = _matchCopy(
      first,
      no: 1,
      date: now.add(const Duration(days: 2)),
    );
    final picked = _matchCopy(
      second,
      no: 2,
      date: now.add(const Duration(days: 3)),
    );
    state.matches
      ..clear()
      ..addAll([pending, picked]);
    state.byNo
      ..clear()
      ..addEntries(state.matches.map((m) => MapEntry(m.no, m)));
    state.preds
      ..clear()
      ..[picked.no] = Pred(2, 1);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(theme: buildTheme(), home: const PredictionScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final pendingChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Pendientes'),
    );
    expect(pendingChip.selected, isTrue);
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('P2'), findsNothing);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();

    expect(find.text('P1'), findsOneWidget);
    expect(find.text('P2'), findsOneWidget);

    await tester.tap(find.text('Mis picks'));
    await tester.pumpAndSettle();

    expect(find.text('P1'), findsNothing);
    expect(find.text('P2'), findsOneWidget);
  });

  testWidgets(
    'PredictionScreen acomoda el editor de marcador en móviles angostos',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late AppState state;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        state = AppState();
        await state.load(initialSync: false);
      });

      final original = state.matches.first;
      final visibleEditable = WcMatch.fromJson({
        'no': original.no,
        'stage': 'group',
        'group': original.group,
        'home': original.homeSlot,
        'away': original.awaySlot,
        'date': DateTime.now()
            .toUtc()
            .add(const Duration(days: 2))
            .toIso8601String(),
        'venue': original.venue,
        'espnId': original.espnId,
      });
      state.matches[0] = visibleEditable;
      state.byNo[visibleEditable.no] = visibleEditable;
      state.preds[visibleEditable.no] = Pred(10, 11);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: buildTheme(),
            home: const PredictionScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    },
  );
}

WcMatch _matchCopy(WcMatch source, {required int no, required DateTime date}) {
  return WcMatch.fromJson({
    'no': no,
    'stage': 'group',
    'group': source.group,
    'home': source.homeSlot,
    'away': source.awaySlot,
    'date': date.toIso8601String(),
    'venue': source.venue,
    'espnId': source.espnId,
  });
}
