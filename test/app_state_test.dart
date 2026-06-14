import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mundial2026/app_state.dart';
import 'package:mundial2026/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dataset embebido: 48 equipos, 104 partidos, llaves válidas', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();

    expect(s.teams.length, 48);
    expect(s.matches.length, 104);
    expect(s.matches.every((m) => m.dateUtc.isUtc), isTrue);
    expect(s.groupMatches.length, 12);
    for (final g in s.groupMatches.values) {
      expect(g.length, 6);
    }
    // Cada slot de eliminatorias debe ser interpretable.
    for (final m in s.matches.where((m) => m.isKnockout)) {
      for (final slot in [m.homeSlot, m.awaySlot]) {
        expect(
          slot.startsWith('W') ||
              slot.startsWith('R') ||
              slot.startsWith('T') ||
              slot.startsWith('M') ||
              slot.startsWith('L'),
          isTrue,
          reason: 'slot inválido $slot en partido ${m.no}',
        );
      }
    }
    // Las sedes de todos los partidos existen.
    for (final m in s.matches) {
      expect(
        s.venues.containsKey(m.venue),
        isTrue,
        reason: 'sede desconocida ${m.venue}',
      );
    }
  });

  test('simulación completa: produce campeón y 104 pronósticos', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();

    s.simulateRemaining();

    expect(s.preds.length, 104);
    expect(s.allGroupsPredicted, isTrue);
    expect(s.predThirdsRanked().length, 12);
    expect(s.predChampion, isNotNull);

    // Todas las llaves de 16avos en adelante deben resolverse.
    for (final m in s.matches.where((m) => m.isKnockout)) {
      final (h, a) = s.predTeams(m);
      expect(h, isNotNull, reason: 'P${m.no} local sin resolver');
      expect(a, isNotNull, reason: 'P${m.no} visitante sin resolver');
      expect(s.predWinner(m), isNotNull, reason: 'P${m.no} sin ganador');
    }

    // El campeón debe ser el ganador pronosticado de la final.
    final finalMatch = s.byNo[104]!;
    expect(s.predChampion!.id, s.predWinner(finalMatch)!.id);
  });

  test('simulateRemaining usa resultados reales de partidos jugados', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load(initialSync: false);

    final m = s.groupMatches['A']!.first;
    // Resultado real finalizado 3-1.
    s.live[m.espnId] = LiveInfo(
      espnId: m.espnId,
      status: 'STATUS_FULL_TIME',
      detail: 'FT',
      homeScore: 3,
      awayScore: 1,
      homeEspn: s.teams[m.homeSlot]!.espn,
      awayEspn: s.teams[m.awaySlot]!.espn,
    );
    // El usuario había puesto otra cosa: debe pisarse con el real.
    s.preds[m.no] = Pred(0, 0);

    s.simulateRemaining();

    expect(s.preds[m.no]!.home, 3);
    expect(s.preds[m.no]!.away, 1);
    // Un partido aún no jugado igual queda simulado.
    final unplayed = s.groupMatches['A']!.firstWhere((x) => x.no != m.no);
    expect(s.preds.containsKey(unplayed.no), isTrue);
  });

  test('cambiar la fase de grupos invalida penales huérfanos', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load();
    s.simulateRemaining();

    // Forzar un cambio drástico en el grupo A y verificar consistencia.
    for (final m in s.groupMatches['A']!) {
      s.setPred(m.no, Pred(0, 5)); // gana siempre el visitante
    }
    for (final m in s.matches.where((m) => m.isKnockout)) {
      final p = s.preds[m.no];
      if (p?.penWinner != null) {
        final (h, a) = s.predTeams(m);
        expect(
          p!.penWinner == h?.id || p.penWinner == a?.id,
          isTrue,
          reason: 'P${m.no} con penWinner huérfano',
        );
      }
    }
  });
}
