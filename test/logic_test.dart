import 'package:flutter_test/flutter_test.dart';

import 'package:mundial2026/logic.dart';
import 'package:mundial2026/models.dart';

void main() {
  test('scorePick: 6 exacto, 3 resultado, 0 erró', () {
    expect(scorePick(Pred(2, 1), Pred(2, 1)), 6); // exacto
    expect(scorePick(Pred(3, 0), Pred(2, 1)), 3); // ambos gana local
    expect(scorePick(Pred(1, 1), Pred(0, 0)), 3); // ambos empate
    expect(scorePick(Pred(0, 1), Pred(2, 1)), 0); // resultado opuesto
  });

  test('tabla de grupo con criterios de desempate', () {
    final rows = computeTable(
      ['MEX', 'RSA', 'KOR', 'CZE'],
      [ScoreEntry('MEX', 'RSA', 2, 0), ScoreEntry('KOR', 'CZE', 2, 1)],
      (id) => {'MEX': 14, 'RSA': 61, 'KOR': 22, 'CZE': 43}[id]!,
    );
    expect(rows.first.teamId, 'MEX'); // +2 de diferencia
    expect(rows[1].teamId, 'KOR'); // +1 de diferencia
    expect(rows.first.points, 3);
  });

  test('desempate por enfrentamiento directo', () {
    // A y B empatan en todo, pero B le ganó a A.
    final rows = computeTable(
      ['A', 'B', 'C', 'D'],
      [
        ScoreEntry('B', 'A', 1, 0),
        ScoreEntry('A', 'C', 1, 0),
        ScoreEntry('B', 'D', 0, 1),
        ScoreEntry('C', 'D', 0, 0),
      ],
      (id) => {'A': 1, 'B': 50, 'C': 60, 'D': 70}[id]!,
    );
    final posA = rows.indexWhere((r) => r.teamId == 'A');
    final posB = rows.indexWhere((r) => r.teamId == 'B');
    expect(
      posB < posA,
      isTrue,
      reason: 'B venció a A y debe quedar arriba pese al ranking',
    );
  });

  test('asignación de terceros por backtracking', () {
    final alloc = allocateThirds(
      {74: 'ABCDF', 77: 'CDFGH'},
      {'C': 'BRA', 'D': 'USA'},
    );
    expect(alloc.length, 2);
    expect(alloc.values.toSet(), {'BRA', 'USA'});
  });

  test('etiquetas de llaves', () {
    expect(slotLabel('WA'), '1.º Grupo A');
    expect(slotLabel('RB'), '2.º Grupo B');
    expect(slotLabel('TABCDF'), '3.º A/B/C/D/F');
    expect(slotLabel('M89'), 'Ganador P89');
    expect(slotLabel('L101'), 'Perdedor P101');
  });
}
