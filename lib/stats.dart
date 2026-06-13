/// Motor de estadísticas del torneo.
///
/// Capa pura y testeable: parsea la respuesta del scoreboard de ESPN (goles,
/// tarjetas y stats por equipo — sin red extra, ya se descarga) y, cuando está
/// disponible, el `summary` por partido (asistencias, atajadas y arqueros por
/// jugador). `TournamentStats.aggregate` combina todos los partidos en los
/// rankings que consume la pantalla de estadísticas.
///
/// No depende de Flutter ni de `AppState`: los equipos se guardan por su
/// `displayName` de ESPN y la UI los resuelve contra `teamsByEspn`.
library;

/// Referencia mínima a un jugador (clave estable = id de atleta de ESPN).
class PlayerRef {
  final String id;
  final String name;
  final String teamEspn; // displayName ESPN del equipo (se resuelve en la UI)

  const PlayerRef({required this.id, required this.name, required this.teamEspn});
}

/// Gol parseado de los `details` del scoreboard (excluye goles en contra y de
/// tanda de penales: no cuentan para la Bota de Oro).
class GoalEvent {
  final PlayerRef scorer;
  final bool penalty;
  final int? minute;

  const GoalEvent(this.scorer, {this.penalty = false, this.minute});
}

/// Tarjeta parseada de los `details` del scoreboard.
class CardEvent {
  final PlayerRef player;
  final bool red;

  const CardEvent(this.player, {required this.red});
}

/// Línea por jugador tomada del `summary` (rosters): asistencias, atajadas y
/// arqueros. Solo existe cuando se bajó el detalle del partido (Nivel 2).
class PlayerLine {
  final PlayerRef player;
  final bool goalkeeper;
  final bool starter;
  final int goals;
  final int assists;
  final int saves;
  final int conceded;
  final int yellow;
  final int red;

  const PlayerLine({
    required this.player,
    required this.goalkeeper,
    required this.starter,
    this.goals = 0,
    this.assists = 0,
    this.saves = 0,
    this.conceded = 0,
    this.yellow = 0,
    this.red = 0,
  });
}

/// Línea por equipo de un partido (stats del scoreboard + marcador).
class TeamLine {
  final String teamEspn;
  final int goalsFor;
  final int goalsAgainst;
  final double possessionPct;
  final int shots;
  final int shotsOnTarget;
  final int corners;
  final int fouls;

  const TeamLine({
    required this.teamEspn,
    required this.goalsFor,
    required this.goalsAgainst,
    this.possessionPct = 0,
    this.shots = 0,
    this.shotsOnTarget = 0,
    this.corners = 0,
    this.fouls = 0,
  });
}

/// Todo lo estadístico de un partido. Se construye con `fromScoreboardEvent`
/// (Nivel 1) y se enriquece con `mergeSummary` (Nivel 2).
class MatchStats {
  final String espnId;
  final bool started;
  final bool finished;
  final int? attendance;
  final List<GoalEvent> goals;
  final List<CardEvent> cards;
  final List<TeamLine> teamLines;
  final List<PlayerLine> playerLines;

  const MatchStats({
    required this.espnId,
    required this.started,
    required this.finished,
    this.attendance,
    this.goals = const [],
    this.cards = const [],
    this.teamLines = const [],
    this.playerLines = const [],
  });

  MatchStats copyWith({List<PlayerLine>? playerLines}) => MatchStats(
    espnId: espnId,
    started: started,
    finished: finished,
    attendance: attendance,
    goals: goals,
    cards: cards,
    teamLines: teamLines,
    playerLines: playerLines ?? this.playerLines,
  );

  /// Parsea un evento del scoreboard de ESPN. Tolerante a campos ausentes.
  static MatchStats fromScoreboardEvent(Map<String, dynamic> event) {
    final comp = (event['competitions'] as List?)?.firstOrNull as Map?;
    final status = (event['status']?['type'] ?? const {}) as Map;
    final state = '${status['state'] ?? ''}';
    final started = state == 'in' || state == 'post';
    final finished = status['completed'] == true || state == 'post';
    final espnId = '${event['id'] ?? ''}';

    if (comp == null) {
      return MatchStats(espnId: espnId, started: started, finished: finished);
    }

    // Mapa id de equipo ESPN -> displayName, y marcador por equipo.
    final idToName = <String, String>{};
    final goalsFor = <String, int>{};
    final competitors = (comp['competitors'] as List?) ?? const [];
    final teamLines = <TeamLine>[];
    for (final c in competitors) {
      final team = (c['team'] ?? const {}) as Map;
      final id = '${team['id'] ?? ''}';
      final name = '${team['displayName'] ?? ''}';
      idToName[id] = name;
      goalsFor[id] = int.tryParse('${c['score'] ?? ''}') ?? 0;
    }
    for (final c in competitors) {
      final team = (c['team'] ?? const {}) as Map;
      final id = '${team['id'] ?? ''}';
      final against = goalsFor.entries
          .where((e) => e.key != id)
          .fold(0, (a, e) => a + e.value);
      final stat = _statMap((c['statistics'] as List?) ?? const []);
      teamLines.add(
        TeamLine(
          teamEspn: idToName[id] ?? '',
          goalsFor: goalsFor[id] ?? 0,
          goalsAgainst: against,
          possessionPct: stat['possessionPct'] ?? 0,
          shots: (stat['totalShots'] ?? 0).round(),
          shotsOnTarget: (stat['shotsOnTarget'] ?? 0).round(),
          corners: (stat['wonCorners'] ?? 0).round(),
          fouls: (stat['foulsCommitted'] ?? 0).round(),
        ),
      );
    }

    final goals = <GoalEvent>[];
    final cards = <CardEvent>[];
    for (final raw in (comp['details'] as List?) ?? const []) {
      final d = raw as Map;
      final athletes = (d['athletesInvolved'] as List?) ?? const [];
      if (athletes.isEmpty) continue;
      final a = athletes.first as Map;
      final teamId = '${(a['team'] ?? const {})['id'] ?? d['team']?['id'] ?? ''}';
      final ref = PlayerRef(
        id: '${a['id'] ?? a['displayName'] ?? ''}',
        name: '${a['displayName'] ?? ''}',
        teamEspn: idToName[teamId] ?? '',
      );
      final minute = _minuteOf('${d['clock']?['displayValue'] ?? ''}');
      if (d['scoringPlay'] == true &&
          d['ownGoal'] != true &&
          d['shootout'] != true) {
        goals.add(GoalEvent(ref, penalty: d['penaltyKick'] == true, minute: minute));
      }
      if (d['yellowCard'] == true || d['redCard'] == true) {
        cards.add(CardEvent(ref, red: d['redCard'] == true));
      }
    }

    return MatchStats(
      espnId: espnId,
      started: started,
      finished: finished,
      attendance: comp['attendance'] is int ? comp['attendance'] as int : null,
      goals: goals,
      cards: cards,
      teamLines: teamLines,
    );
  }

  /// Enriquece con datos por jugador del `summary` (rosters): asistencias,
  /// atajadas, arqueros. Devuelve una copia; no muta.
  MatchStats mergeSummary(Map<String, dynamic> summary) {
    final lines = <PlayerLine>[];
    for (final r in (summary['rosters'] as List?) ?? const []) {
      final roster = r as Map;
      final teamName = '${(roster['team'] ?? const {})['displayName'] ?? ''}';
      for (final raw in (roster['roster'] as List?) ?? const []) {
        final p = raw as Map;
        final ath = (p['athlete'] ?? const {}) as Map;
        final pos = '${(p['position'] ?? const {})['abbreviation'] ?? ''}';
        final stat = _statMap((p['stats'] as List?) ?? const []);
        lines.add(
          PlayerLine(
            player: PlayerRef(
              id: '${ath['id'] ?? ath['displayName'] ?? ''}',
              name: '${ath['displayName'] ?? ''}',
              teamEspn: teamName,
            ),
            goalkeeper: pos == 'G',
            starter: p['starter'] == true,
            goals: (stat['totalGoals'] ?? 0).round(),
            assists: (stat['goalAssists'] ?? 0).round(),
            saves: (stat['saves'] ?? 0).round(),
            conceded: (stat['goalsConceded'] ?? 0).round(),
            yellow: (stat['yellowCards'] ?? 0).round(),
            red: (stat['redCards'] ?? 0).round(),
          ),
        );
      }
    }
    return copyWith(playerLines: lines);
  }
}

/// Ranking de goleadores (orden Bota de Oro: goles, luego asistencias).
class ScorerStat {
  final PlayerRef player;
  int goals = 0;
  int penalties = 0;
  int assists = 0;
  ScorerStat(this.player);
}

/// Ranking de asistencias.
class AssistStat {
  final PlayerRef player;
  int assists = 0;
  int goals = 0;
  AssistStat(this.player);
}

/// Ranking de arqueros (vallas invictas, atajadas).
class KeeperStat {
  final PlayerRef player;
  int cleanSheets = 0;
  int saves = 0;
  int conceded = 0;
  int matches = 0;
  KeeperStat(this.player);
}

/// Ranking disciplinario por jugador.
class DisciplineStat {
  final PlayerRef player;
  int yellow = 0;
  int red = 0;
  DisciplineStat(this.player);

  /// Puntos de juego limpio (amarilla 1, roja 3) para ordenar.
  int get points => yellow + red * 3;
}

/// Jugador destacado: índice de impacto derivado (no es un rating oficial).
class StandoutPlayer {
  final PlayerRef player;
  final int goals;
  final int assists;
  final int saves;
  final int cleanSheets;
  StandoutPlayer(this.player, {
    required this.goals,
    required this.assists,
    required this.saves,
    required this.cleanSheets,
  });

  /// Impacto = goles·5 + asistencias·3 + vallas·2 + atajadas·0.5.
  double get impact => goals * 5 + assists * 3 + cleanSheets * 2 + saves * 0.5;
}

/// Acumulado por equipo a lo largo del torneo.
class TeamStat {
  final String teamEspn;
  int played = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int cleanSheets = 0;
  int yellow = 0;
  int red = 0;
  int shots = 0;
  int shotsOnTarget = 0;
  int corners = 0;
  int fouls = 0;
  double _possessionSum = 0;
  int _possessionN = 0;
  TeamStat(this.teamEspn);

  int get goalDiff => goalsFor - goalsAgainst;
  int get disciplinePoints => yellow + red * 3;
  double get possessionAvg =>
      _possessionN == 0 ? 0 : _possessionSum / _possessionN;
}

/// Marcador más abultado del torneo.
class BiggestWin {
  final String winnerEspn;
  final String loserEspn;
  final int winnerGoals;
  final int loserGoals;
  const BiggestWin(this.winnerEspn, this.loserEspn, this.winnerGoals, this.loserGoals);
  int get margin => winnerGoals - loserGoals;
}

/// Totales agregados del torneo.
class TournamentTotals {
  int matchesPlayed = 0;
  int totalGoals = 0;
  int penalties = 0;
  int hatTricks = 0;
  int yellow = 0;
  int red = 0;
  int attendance = 0;
  BiggestWin? biggestWin;

  double get avgGoals => matchesPlayed == 0 ? 0 : totalGoals / matchesPlayed;
}

/// Resultado agregado: todos los rankings que consume la pantalla.
class TournamentStats {
  final List<ScorerStat> scorers;
  final List<AssistStat> assists;
  final List<KeeperStat> keepers;
  final List<StandoutPlayer> standouts;
  final List<DisciplineStat> discipline;
  final List<TeamStat> teams;
  final TournamentTotals totals;

  const TournamentStats({
    required this.scorers,
    required this.assists,
    required this.keepers,
    required this.standouts,
    required this.discipline,
    required this.teams,
    required this.totals,
  });

  bool get isEmpty =>
      scorers.isEmpty &&
      discipline.isEmpty &&
      teams.isEmpty &&
      totals.matchesPlayed == 0;

  /// Combina todos los partidos en los rankings ordenados.
  static TournamentStats aggregate(Iterable<MatchStats> matches) {
    final scorers = <String, ScorerStat>{};
    final assists = <String, AssistStat>{};
    final keepers = <String, KeeperStat>{};
    final discipline = <String, DisciplineStat>{};
    final teams = <String, TeamStat>{};
    final impactGoals = <String, int>{};
    final impactAssists = <String, int>{};
    final impactSaves = <String, int>{};
    final impactClean = <String, int>{};
    final impactRef = <String, PlayerRef>{};
    final totals = TournamentTotals();

    for (final m in matches) {
      if (!m.started) continue;
      totals.matchesPlayed += 1;
      if (m.attendance != null) totals.attendance += m.attendance!;

      // Goles -> goleadores + totales + hat-tricks.
      final perPlayerGoalsThisMatch = <String, int>{};
      for (final g in m.goals) {
        totals.totalGoals += 1;
        if (g.penalty) totals.penalties += 1;
        final s = scorers.putIfAbsent(g.scorer.id, () => ScorerStat(g.scorer));
        s.goals += 1;
        if (g.penalty) s.penalties += 1;
        perPlayerGoalsThisMatch.update(g.scorer.id, (v) => v + 1, ifAbsent: () => 1);
        impactGoals.update(g.scorer.id, (v) => v + 1, ifAbsent: () => 1);
        impactRef[g.scorer.id] = g.scorer;
      }
      for (final n in perPlayerGoalsThisMatch.values) {
        if (n >= 3) totals.hatTricks += 1;
      }

      // Tarjetas -> disciplina + totales.
      for (final c in m.cards) {
        if (c.red) {
          totals.red += 1;
        } else {
          totals.yellow += 1;
        }
        final d = discipline.putIfAbsent(
          c.player.id,
          () => DisciplineStat(c.player),
        );
        if (c.red) {
          d.red += 1;
        } else {
          d.yellow += 1;
        }
      }

      // Stats por equipo + marcador más abultado.
      for (final t in m.teamLines) {
        if (t.teamEspn.isEmpty) continue;
        final ts = teams.putIfAbsent(t.teamEspn, () => TeamStat(t.teamEspn));
        ts.played += 1;
        ts.goalsFor += t.goalsFor;
        ts.goalsAgainst += t.goalsAgainst;
        ts.shots += t.shots;
        ts.shotsOnTarget += t.shotsOnTarget;
        ts.corners += t.corners;
        ts.fouls += t.fouls;
        if (t.possessionPct > 0) {
          ts._possessionSum += t.possessionPct;
          ts._possessionN += 1;
        }
        if (m.finished && t.goalsAgainst == 0) ts.cleanSheets += 1;
      }
      if (m.finished && m.teamLines.length == 2) {
        final a = m.teamLines[0], b = m.teamLines[1];
        if (a.goalsFor != b.goalsFor) {
          final w = a.goalsFor > b.goalsFor ? a : b;
          final l = a.goalsFor > b.goalsFor ? b : a;
          final margin = w.goalsFor - l.goalsFor;
          if (totals.biggestWin == null || margin > totals.biggestWin!.margin) {
            totals.biggestWin =
                BiggestWin(w.teamEspn, l.teamEspn, w.goalsFor, l.goalsFor);
          }
        }
      }

      // Datos por jugador del summary (Nivel 2).
      for (final p in m.playerLines) {
        if (p.assists > 0) {
          final a = assists.putIfAbsent(
            p.player.id,
            () => AssistStat(p.player),
          );
          a.assists += p.assists;
          impactAssists.update(p.player.id, (v) => v + p.assists,
              ifAbsent: () => p.assists);
          impactRef[p.player.id] = p.player;
        }
        // Asistencias también desempatan la Bota de Oro.
        if (p.assists > 0 && scorers.containsKey(p.player.id)) {
          scorers[p.player.id]!.assists += p.assists;
        }
        if (p.goalkeeper && (p.starter || p.saves > 0)) {
          final k = keepers.putIfAbsent(
            p.player.id,
            () => KeeperStat(p.player),
          );
          k.saves += p.saves;
          k.conceded += p.conceded;
          k.matches += 1;
          if (m.finished && p.conceded == 0) k.cleanSheets += 1;
          impactSaves.update(p.player.id, (v) => v + p.saves,
              ifAbsent: () => p.saves);
          if (m.finished && p.conceded == 0) {
            impactClean.update(p.player.id, (v) => v + 1, ifAbsent: () => 1);
          }
          impactRef[p.player.id] = p.player;
        }
      }
    }

    // Resolver "goles" en AssistStat para mostrarlos juntos.
    for (final a in assists.values) {
      a.goals = scorers[a.player.id]?.goals ?? 0;
    }

    final scorerList = scorers.values.toList()
      ..sort((x, y) {
        final g = y.goals.compareTo(x.goals);
        if (g != 0) return g;
        final as = y.assists.compareTo(x.assists);
        if (as != 0) return as;
        return x.player.name.compareTo(y.player.name);
      });

    final assistList = assists.values.toList()
      ..sort((x, y) {
        final a = y.assists.compareTo(x.assists);
        if (a != 0) return a;
        final g = y.goals.compareTo(x.goals);
        if (g != 0) return g;
        return x.player.name.compareTo(y.player.name);
      });

    final keeperList = keepers.values.toList()
      ..sort((x, y) {
        final c = y.cleanSheets.compareTo(x.cleanSheets);
        if (c != 0) return c;
        final s = y.saves.compareTo(x.saves);
        if (s != 0) return s;
        return x.player.name.compareTo(y.player.name);
      });

    final disciplineList = discipline.values.toList()
      ..sort((x, y) {
        final p = y.points.compareTo(x.points);
        if (p != 0) return p;
        return x.player.name.compareTo(y.player.name);
      });

    final standoutList = impactRef.keys
        .map((id) => StandoutPlayer(
              impactRef[id]!,
              goals: impactGoals[id] ?? 0,
              assists: impactAssists[id] ?? 0,
              saves: impactSaves[id] ?? 0,
              cleanSheets: impactClean[id] ?? 0,
            ))
        .where((s) => s.impact > 0)
        .toList()
      ..sort((x, y) {
        final i = y.impact.compareTo(x.impact);
        if (i != 0) return i;
        return x.player.name.compareTo(y.player.name);
      });

    final teamList = teams.values.toList();

    return TournamentStats(
      scorers: scorerList,
      assists: assistList,
      keepers: keeperList,
      standouts: standoutList,
      discipline: disciplineList,
      teams: teamList,
      totals: totals,
    );
  }
}

// ---------------------------------------------------------------- utilidades

/// Convierte una lista de stats de ESPN (`[{name, value}]`) a un mapa nombre→valor.
Map<String, double> _statMap(List<dynamic> stats) {
  final out = <String, double>{};
  for (final raw in stats) {
    final s = raw as Map;
    final name = '${s['name'] ?? ''}';
    if (name.isEmpty) continue;
    final v = s['value'];
    if (v is num) {
      out[name] = v.toDouble();
    } else {
      final parsed = double.tryParse('${s['displayValue'] ?? ''}'.replaceAll('%', ''));
      if (parsed != null) out[name] = parsed;
    }
  }
  return out;
}

/// Extrae el minuto de un reloj tipo "23'" o "45'+2".
int? _minuteOf(String clock) {
  final m = RegExp(r'(\d+)').firstMatch(clock);
  return m == null ? null : int.tryParse(m.group(1)!);
}
