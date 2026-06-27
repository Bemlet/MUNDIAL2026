/// Lógica del torneo: tablas de grupos (criterios FIFA), ranking de mejores
/// terceros, asignación de terceros a llaves y resolución del bracket.
library;

import 'models.dart';

/// Multiplicador de puntos por ronda en la fase final (el 6/3 base se duplica
/// cada ronda). Grupos y 3er puesto = ×1.
int roundMultiplier(Stage stage) => switch (stage) {
  Stage.r16 => 2,
  Stage.qf => 4,
  Stage.sf => 8,
  Stage.finalMatch => 16,
  _ => 1, // group, r32, third
};

/// Puntaje del pick'em comparando un pronóstico contra el resultado real:
/// 6 si el marcador es exacto, 3 si acierta el resultado (gana/empata/pierde),
/// 0 si no.
int scorePick(Pred pred, Pred real) {
  if (pred.home == real.home && pred.away == real.away) return 6;
  int sign(int a, int b) => a == b ? 0 : (a > b ? 1 : -1);
  if (sign(pred.home, pred.away) == sign(real.home, real.away)) return 3;
  return 0;
}

/// Resultado simple usado por la lógica (real o pronosticado).
class ScoreEntry {
  final String homeId;
  final String awayId;
  final int home;
  final int away;
  ScoreEntry(this.homeId, this.awayId, this.home, this.away);
}

/// Calcula la tabla de un grupo. `teamIds` son los 4 equipos; `results` los
/// partidos con marcador disponibles. `rankOf` desempata en última instancia
/// (determinista, sustituye al sorteo de FIFA).
List<TableRow> computeTable(
  List<String> teamIds,
  List<ScoreEntry> results,
  int Function(String) rankOf,
) {
  final rows = {for (final id in teamIds) id: TableRow(id)};
  for (final r in results) {
    final h = rows[r.homeId], a = rows[r.awayId];
    if (h == null || a == null) continue;
    h.played++;
    a.played++;
    h.gf += r.home;
    h.ga += r.away;
    a.gf += r.away;
    a.ga += r.home;
    if (r.home > r.away) {
      h.won++;
      a.lost++;
    } else if (r.home < r.away) {
      a.won++;
      h.lost++;
    } else {
      h.drawn++;
      a.drawn++;
    }
  }

  final list = rows.values.toList();
  // Orden principal: puntos, diferencia, goles a favor.
  int baseCmp(TableRow x, TableRow y) {
    if (x.points != y.points) return y.points - x.points;
    if (x.gd != y.gd) return y.gd - x.gd;
    if (x.gf != y.gf) return y.gf - x.gf;
    return 0;
  }

  list.sort(baseCmp);

  // Desempate entre empatados: resultados entre sí, luego ranking.
  for (var i = 0; i < list.length;) {
    var j = i + 1;
    while (j < list.length && baseCmp(list[i], list[j]) == 0) {
      j++;
    }
    if (j - i > 1) {
      final tiedIds = list.sublist(i, j).map((r) => r.teamId).toSet();
      final h2h = computeMiniTable(
        tiedIds,
        results.where(
          (r) => tiedIds.contains(r.homeId) && tiedIds.contains(r.awayId),
        ),
      );
      final segment = list.sublist(i, j)
        ..sort((x, y) {
          final hx = h2h[x.teamId]!, hy = h2h[y.teamId]!;
          if (hx.points != hy.points) return hy.points - hx.points;
          if (hx.gd != hy.gd) return hy.gd - hx.gd;
          if (hx.gf != hy.gf) return hy.gf - hx.gf;
          return rankOf(x.teamId) - rankOf(y.teamId);
        });
      list.replaceRange(i, j, segment);
    }
    i = j;
  }
  return list;
}

Map<String, TableRow> computeMiniTable(
  Set<String> ids,
  Iterable<ScoreEntry> results,
) {
  final rows = {for (final id in ids) id: TableRow(id)};
  for (final r in results) {
    final h = rows[r.homeId]!, a = rows[r.awayId]!;
    h.played++;
    a.played++;
    h.gf += r.home;
    h.ga += r.away;
    a.gf += r.away;
    a.ga += r.home;
    if (r.home > r.away) {
      h.won++;
      a.lost++;
    } else if (r.home < r.away) {
      a.won++;
      h.lost++;
    } else {
      h.drawn++;
      a.drawn++;
    }
  }
  return rows;
}

/// Ordena los 12 terceros y devuelve los 8 clasificados.
List<TableRow> rankThirds(List<TableRow> thirds, int Function(String) rankOf) {
  final sorted = [...thirds]
    ..sort((x, y) {
      if (x.points != y.points) return y.points - x.points;
      if (x.gd != y.gd) return y.gd - x.gd;
      if (x.gf != y.gf) return y.gf - x.gf;
      return rankOf(x.teamId) - rankOf(y.teamId);
    });
  return sorted;
}

/// Asigna los 8 mejores terceros a las llaves de 16avos.
/// `slotAllowed`: nº de partido -> grupos admitidos en esa llave.
/// `qualified`: grupo -> teamId del tercero clasificado.
/// Devuelve nº de partido -> teamId, o {} si no hay asignación válida.
Map<int, String> allocateThirds(
  Map<int, String> slotAllowed,
  Map<String, String> qualified,
) {
  final slots = slotAllowed.keys.toList();
  final assigned = <int, String>{}; // matchNo -> grupo
  final used = <String>{};

  bool solve(int idx) {
    if (idx == slots.length) return true;
    final slot = slots[idx];
    for (final g in slotAllowed[slot]!.split('')) {
      if (!used.contains(g) && qualified.containsKey(g)) {
        used.add(g);
        assigned[slot] = g;
        if (solve(idx + 1)) return true;
        used.remove(g);
        assigned.remove(slot);
      }
    }
    return false;
  }

  if (!solve(0)) return {};
  return assigned.map((slot, g) => MapEntry(slot, qualified[g]!));
}

/// Etiqueta en español para un slot sin resolver ('WA', 'RB', 'TABCDF', 'M89', 'L101').
String slotLabel(String slot) {
  if (slot.length == 2 && slot.startsWith('W')) return '1.º Grupo ${slot[1]}';
  if (slot.length == 2 && slot.startsWith('R')) return '2.º Grupo ${slot[1]}';
  if (slot.startsWith('T')) {
    return '3.º ${slot.substring(1).split('').join('/')}';
  }
  if (slot.startsWith('M')) return 'Ganador P${slot.substring(1)}';
  if (slot.startsWith('L')) return 'Perdedor P${slot.substring(1)}';
  return slot;
}
