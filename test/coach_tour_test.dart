/// Tour guiado: lógica del flag y comportamiento del overlay en el Shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/l10n.dart';
import 'package:mundial2026/main.dart';
import 'package:mundial2026/theme.dart';

const _es = AppStrings(AppLanguage.es);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  test('tourDone: default false, completeTour persiste, shouldRunTour', () async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    final s = AppState();
    await s.load(initialSync: false);

    expect(s.tourDone, isFalse);
    expect(s.shouldRunTour, isTrue);

    s.completeTour();
    expect(s.tourDone, isTrue);
    expect(s.shouldRunTour, isFalse);

    final s2 = AppState();
    await s2.load(initialSync: false);
    expect(s2.tourDone, isTrue);
  });

  Future<AppState> loaded(WidgetTester tester, Map<String, Object> prefs) async {
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

  testWidgets('el Shell corre el tour y "Saltar" lo termina', (tester) async {
    final state = await loaded(tester, {'onboardingDone': true}); // tourDone false

    await tester.pumpWidget(shellApp(state));
    await tester.pump(); // dispara el post-frame que inicia el tour
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_es.tourMatchesDesc), findsOneWidget); // primer paso
    expect(state.tourDone, isFalse);

    await tester.tap(find.text(_es.tourSkip));
    await tester.pump(const Duration(milliseconds: 100));

    expect(state.tourDone, isTrue);
    expect(find.text(_es.tourMatchesDesc), findsNothing);
  });

  testWidgets('"Siguiente" avanza al segundo paso', (tester) async {
    final state = await loaded(tester, {'onboardingDone': true});

    await tester.pumpWidget(shellApp(state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_es.tourMatchesDesc), findsOneWidget);

    await tester.tap(find.text(_es.tourNext));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_es.tourGroupsDesc), findsOneWidget); // segundo paso
    expect(state.tourDone, isFalse);
  });
}
