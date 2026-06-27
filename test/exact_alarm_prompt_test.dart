/// Prompt de permiso de alarma exacta: lógica de cuándo mostrarlo y el diálogo
/// en el Shell.
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

  test('shouldPromptExactAlarm: solo si falta permiso, hay onboarding y no se pidió', () async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true, 'tourDone': true, 'whatsNewV11Shown': true, 'pickemNudgeShown': true});
    final s = AppState();
    await s.load(initialSync: false);

    expect(s.shouldPromptExactAlarm, isFalse); // exactAlarmGranted = true por defecto

    s.exactAlarmGranted = false;
    expect(s.shouldPromptExactAlarm, isTrue);

    s.markExactAlarmAsked();
    expect(s.shouldPromptExactAlarm, isFalse);

    // El flag persiste entre instancias.
    final s2 = AppState();
    await s2.load(initialSync: false);
    expect(s2.exactAlarmAsked, isTrue);
  });

  test('no se pide si el onboarding no está completo', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load(initialSync: false);
    s.exactAlarmGranted = false;
    expect(s.shouldPromptExactAlarm, isFalse); // falta onboarding
  });

  testWidgets('el Shell muestra el prompt y "Ahora no" lo descarta', (tester) async {
    late AppState state;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'onboardingDone': true, 'tourDone': true, 'whatsNewV11Shown': true, 'pickemNudgeShown': true});
      state = AppState();
      await state.load(initialSync: false);
    });
    state.exactAlarmGranted = false; // simulamos permiso faltante

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(theme: buildTheme(), home: const Shell()),
      ),
    );
    await tester.pump(); // ejecuta el post-frame callback
    await tester.pump(const Duration(milliseconds: 300)); // anima el diálogo

    expect(find.text(_es.exactAlarmTitle), findsOneWidget);

    await tester.tap(find.text(_es.exactAlarmNotNow));
    await tester.pump(); // inicia el cierre
    await tester.pump(const Duration(seconds: 1)); // anima la salida

    expect(state.exactAlarmAsked, isTrue);
    expect(find.text(_es.exactAlarmTitle), findsNothing);
  });
}
