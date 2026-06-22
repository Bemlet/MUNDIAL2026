/// Tests del onboarding de primera apertura: estado persistente en AppState
/// y comportamiento de la pantalla (Saltar / Comenzar / navegación).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/l10n.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/screens/onboarding_screen.dart';
import 'package:mundial2026/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // MatchesScreen (rama app) usa DateFormat: necesita datos de locale.
    await initializeDateFormatting('es');
  });

  group('AppState.onboardingDone', () {
    test('arranca en false con prefs vacías', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      expect(s.onboardingDone, isFalse);
    });

    test('completeOnboarding lo marca y persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);

      s.completeOnboarding();
      expect(s.onboardingDone, isTrue);

      // Una nueva instancia debe leer el flag persistido.
      final s2 = AppState();
      await s2.load(initialSync: false);
      expect(s2.onboardingDone, isTrue);
    });

    test('respeta un flag previo en true', () async {
      SharedPreferences.setMockInitialValues({'onboardingDone': true, 'tourDone': true, 'pickemNudgeShown': true});
      final s = AppState();
      await s.load(initialSync: false);
      expect(s.onboardingDone, isTrue);
    });

    test("aviso del pick'em: nuevo no lo ve, existente sí", () async {
      // Nuevo: al completar onboarding ya vio el pick'em -> sin aviso.
      SharedPreferences.setMockInitialValues({});
      final nuevo = AppState();
      await nuevo.load(initialSync: false);
      nuevo.completeOnboarding();
      expect(nuevo.pickemNudgeShown, isTrue);
      expect(nuevo.shouldShowPickemNudge, isFalse);

      // Existente (onboarding+tour ya hechos, nunca vio el pick'em) -> aviso.
      SharedPreferences.setMockInitialValues({
        'onboardingDone': true,
        'tourDone': true,
      });
      final existente = AppState();
      await existente.load(initialSync: false);
      expect(existente.shouldShowPickemNudge, isTrue);
      existente.markPickemNudgeShown();
      expect(existente.shouldShowPickemNudge, isFalse);
    });
  });

  group('OnboardingScreen', () {
    late AppState state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      await state.load(initialSync: false);
    });

    Widget harness() => AppScope(
      state: state,
      child: MaterialApp(theme: buildTheme(), home: const OnboardingScreen()),
    );

    testWidgets('renderiza la primera slide y el botón Saltar', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(const AppStrings(AppLanguage.es).onbSkip), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Saltar completa el onboarding', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(const AppStrings(AppLanguage.es).onbSkip));
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.onboardingDone, isTrue);
    });

    testWidgets('el selector de idioma cambia el idioma de la app', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.language, AppLanguage.es);
      await tester.tap(find.text('English'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.language, AppLanguage.en);
    });
  });

  group('Shell con onboarding', () {
    // `load()` usa async real (SharedPreferences/NotificationService): debe
    // correr dentro de `tester.runAsync`, no en la zona FakeAsync de testWidgets.
    Future<AppState> loadState(WidgetTester tester, Map<String, Object> prefs) async {
      late AppState state;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues(prefs);
        state = AppState();
        await state.load(initialSync: false);
      });
      return state;
    }

    Widget shellApp(AppState state) => AppScope(
      state: state,
      child: MaterialApp(theme: buildTheme(), home: const Shell()),
    );

    testWidgets('muestra el onboarding cuando el flag es false', (tester) async {
      final state = await loadState(tester, {});

      await tester.pumpWidget(shellApp(state));
      await tester.pump();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('muestra la app cuando el flag es true', (tester) async {
      final state = await loadState(tester, {
        'onboardingDone': true,
        'tourDone': true,
        'pickemNudgeShown': true,
        'playerIntroShown': true,
        'lineupsIntroShown': true,
        'accountIntroShown': true,
      });

      await tester.pumpWidget(shellApp(state));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('avisa de las cartas de jugador a usuarios que ya tenían la app',
        (tester) async {
      final state = await loadState(tester, {
        'onboardingDone': true,
        'tourDone': true,
        'pickemNudgeShown': true,
        'lineupsIntroShown': true,
        'accountIntroShown': true,
        // playerIntroShown ausente -> debe mostrarse una vez
      });

      await tester.pumpWidget(shellApp(state));
      await tester.pump(); // dispara el post-frame callback
      await tester.pump(const Duration(milliseconds: 300));

      final l = const AppStrings(AppLanguage.es);
      expect(find.text(l.playerIntroTitle), findsOneWidget);

      await tester.tap(find.text(l.playerIntroLater));
      await tester.pump(); // procesa el tap (pop del diálogo)
      await tester.pump(const Duration(seconds: 1)); // anima el cierre

      expect(state.playerIntroShown, isTrue);
      expect(find.text(l.playerIntroTitle), findsNothing);
    });
  });

  group('AppState.playerIntroShown', () {
    test('completeOnboarding lo marca (los nuevos no reciben el aviso doble)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);
      expect(s.playerIntroShown, isFalse);
      s.completeOnboarding();
      expect(s.playerIntroShown, isTrue);
      expect(s.shouldShowPlayerIntro, isFalse);
    });
  });
}
