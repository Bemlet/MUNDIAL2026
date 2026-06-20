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

  test("pick'em: cutoff 17/jun y puntaje 6/3/0", () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load(initialSync: false);

    expect(AppState.pickemStart, DateTime.utc(2026, 6, 17));

    LiveInfo ft(WcMatch m, int h, int a) => LiveInfo(
      espnId: m.espnId,
      status: 'STATUS_FULL_TIME',
      detail: 'FT',
      homeScore: h,
      awayScore: a,
      homeEspn: s.teams[m.homeSlot]!.espn,
      awayEspn: s.teams[m.awaySlot]!.espn,
    );

    // Partido anterior al 17/jun: aunque acierte exacto, NO puntúa.
    final pre = s.matches.firstWhere(
      (m) => m.stage == Stage.group && m.dateUtc.isBefore(AppState.pickemStart),
    );
    s.live[pre.espnId] = ft(pre, 2, 1);
    s.preds[pre.no] = Pred(2, 1);
    expect(s.pickemPoints(pre), 0);

    // Partido del 17/jun en adelante: exacto = 6, resultado = 3, erró = 0.
    final post = s.matches.firstWhere(
      (m) =>
          m.stage == Stage.group && !m.dateUtc.isBefore(AppState.pickemStart),
    );
    s.live[post.espnId] = ft(post, 2, 1);
    s.preds[post.no] = Pred(2, 1);
    expect(s.pickemPoints(post), 6);
    s.preds[post.no] = Pred(3, 0);
    expect(s.pickemPoints(post), 3);
    s.preds[post.no] = Pred(0, 2);
    expect(s.pickemPoints(post), 0);
  });

  test("pick'em: la edición se bloquea en el kickoff exacto", () {
    final s = AppState();
    final m = WcMatch.fromJson({
      'no': 999,
      'stage': 'group',
      'group': 'A',
      'home': 'MEX',
      'away': 'RSA',
      'date': '2026-06-17T00:00:00Z',
      'venue': 'Test',
      'espnId': 'test',
    });

    expect(s.pickemLocked(m, DateTime.utc(2026, 6, 16, 23, 59, 59)), isFalse);
    expect(s.pickemLocked(m, DateTime.utc(2026, 6, 17)), isTrue);
    expect(s.pickemLocked(m, DateTime.utc(2026, 6, 17, 0, 0, 1)), isTrue);
  });

  test(
    "pick'em: canEditPickem requiere equipos resueltos, puntaje y kickoff futuro",
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load(initialSync: false);

      final editable = s.byNo[20]!;
      expect(
        s.canEditPickem(
          editable,
          editable.dateUtc.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(s.canEditPickem(editable, editable.dateUtc), isFalse);

      final beforeCutoff = s.byNo[18]!;
      expect(
        s.canEditPickem(
          beforeCutoff,
          beforeCutoff.dateUtc.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );

      final unresolvedKnockout = s.byNo[73]!;
      expect(
        s.canEditPickem(
          unresolvedKnockout,
          unresolvedKnockout.dateUtc.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    },
  );

  test("pick'em: setPred no muta picks bloqueados y permite futuros", () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load(initialSync: false);

    final m = s.byNo[20]!;
    final beforeKickoff = m.dateUtc.subtract(const Duration(seconds: 1));
    final atKickoff = m.dateUtc;

    s.setPred(m.no, Pred(1, 0), now: beforeKickoff);
    expect(s.preds[m.no]!.home, 1);

    s.setPred(m.no, Pred(2, 0), now: atKickoff);
    expect(s.preds[m.no]!.home, 1);

    s.setPred(m.no, null, now: atKickoff);
    expect(s.preds[m.no], isNotNull);

    s.setPred(m.no, null, now: beforeKickoff);
    expect(s.preds.containsKey(m.no), isFalse);
  });

  test("pick'em: clearPreds borra solo pronósticos editables", () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.load(initialSync: false);

    final locked = s.byNo[19]!;
    final editable = s.byNo[20]!;
    final now = DateTime.utc(2026, 6, 17, 2);
    s.preds[locked.no] = Pred(1, 1);
    s.preds[editable.no] = Pred(2, 0);

    s.clearPreds(now: now);

    expect(s.preds[locked.no], isNotNull);
    expect(s.preds.containsKey(editable.no), isFalse);
  });

  test(
    'carga: poda pronósticos legacy de eliminatorias sin equipos reales',
    () async {
      SharedPreferences.setMockInitialValues({
        'preds': '{"73":{"h":1,"a":0},"20":{"h":2,"a":1}}',
      });
      final s = AppState();
      await s.load(initialSync: false);

      expect(s.preds.containsKey(73), isFalse);
      expect(s.preds[20], isNotNull);
    },
  );

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
