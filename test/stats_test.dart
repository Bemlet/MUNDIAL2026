import 'package:flutter_test/flutter_test.dart';

import 'package:mundial2026/stats.dart';

/// Construye un evento de scoreboard con la forma real de ESPN.
Map<String, dynamic> scoreboardEvent({
  required String id,
  required String homeId,
  required String homeName,
  required int homeScore,
  required String awayId,
  required String awayName,
  required int awayScore,
  String state = 'post',
  bool completed = true,
  int? attendance,
  List<Map<String, dynamic>> details = const [],
  Map<String, double> homeStats = const {},
  Map<String, double> awayStats = const {},
}) {
  List<Map<String, dynamic>> stat(Map<String, double> s) =>
      [for (final e in s.entries) {'name': e.key, 'value': e.value}];
  return {
    'id': id,
    'status': {
      'type': {'state': state, 'completed': completed},
    },
    'competitions': [
      {
        'attendance': attendance,
        'competitors': [
          {
            'homeAway': 'home',
            'score': '$homeScore',
            'team': {'id': homeId, 'displayName': homeName},
            'statistics': stat(homeStats),
          },
          {
            'homeAway': 'away',
            'score': '$awayScore',
            'team': {'id': awayId, 'displayName': awayName},
            'statistics': stat(awayStats),
          },
        ],
        'details': details,
      },
    ],
  };
}

Map<String, dynamic> goalDetail(
  String athId,
  String name,
  String teamId, {
  bool penalty = false,
  bool ownGoal = false,
  bool shootout = false,
  String clock = "23'",
}) => {
  'scoringPlay': true,
  'penaltyKick': penalty,
  'ownGoal': ownGoal,
  'shootout': shootout,
  'redCard': false,
  'yellowCard': false,
  'clock': {'displayValue': clock},
  'team': {'id': teamId},
  'athletesInvolved': [
    {
      'id': athId,
      'displayName': name,
      'team': {'id': teamId},
    },
  ],
};

Map<String, dynamic> cardDetail(
  String athId,
  String name,
  String teamId, {
  required bool red,
}) => {
  'scoringPlay': false,
  'redCard': red,
  'yellowCard': !red,
  'team': {'id': teamId},
  'athletesInvolved': [
    {
      'id': athId,
      'displayName': name,
      'team': {'id': teamId},
    },
  ],
};

/// Construye un summary con rosters (Nivel 2).
Map<String, dynamic> summary(List<Map<String, dynamic>> rosters) => {
  'rosters': [
    for (final r in rosters)
      {
        'team': {'displayName': r['team']},
        'roster': [
          for (final p in (r['players'] as List))
            {
              'starter': p['starter'] ?? true,
              'position': {'abbreviation': p['pos'] ?? 'M'},
              'athlete': {'id': p['id'], 'displayName': p['name']},
              'stats': [
                {'name': 'goalAssists', 'value': (p['assists'] ?? 0).toDouble()},
                {'name': 'saves', 'value': (p['saves'] ?? 0).toDouble()},
                {'name': 'goalsConceded', 'value': (p['conceded'] ?? 0).toDouble()},
                {'name': 'totalGoals', 'value': (p['goals'] ?? 0).toDouble()},
              ],
            },
        ],
      },
  ],
};

void main() {
  group('MatchStats.fromScoreboardEvent', () {
    test('parsea goles, excluye en contra y de tanda', () {
      final m = MatchStats.fromScoreboardEvent(
        scoreboardEvent(
          id: '1',
          homeId: '203',
          homeName: 'Mexico',
          homeScore: 2,
          awayId: '467',
          awayName: 'South Africa',
          awayScore: 0,
          attendance: 80824,
          details: [
            goalDetail('a1', 'Quiñones', '203'),
            goalDetail('a1', 'Quiñones', '203', penalty: true),
            goalDetail('x', 'Defensa RSA', '467', ownGoal: true),
            goalDetail('y', 'Tanda', '203', shootout: true),
          ],
        ),
      );
      expect(m.goals.length, 2, reason: 'en contra y tanda no cuentan');
      expect(m.goals.where((g) => g.penalty).length, 1);
      expect(m.goals.first.scorer.teamEspn, 'Mexico');
      expect(m.attendance, 80824);
      expect(m.finished, isTrue);
    });

    test('parsea stats y marcador por equipo', () {
      final m = MatchStats.fromScoreboardEvent(
        scoreboardEvent(
          id: '1',
          homeId: '203',
          homeName: 'Mexico',
          homeScore: 3,
          awayId: '467',
          awayName: 'South Africa',
          awayScore: 1,
          homeStats: {'possessionPct': 62, 'totalShots': 15, 'shotsOnTarget': 7},
        ),
      );
      final mex = m.teamLines.firstWhere((t) => t.teamEspn == 'Mexico');
      expect(mex.goalsFor, 3);
      expect(mex.goalsAgainst, 1);
      expect(mex.possessionPct, 62);
      expect(mex.shots, 15);
    });

    test('partido no empezado no cuenta como started', () {
      final m = MatchStats.fromScoreboardEvent(
        scoreboardEvent(
          id: '1', homeId: 'a', homeName: 'A', homeScore: 0,
          awayId: 'b', awayName: 'B', awayScore: 0,
          state: 'pre', completed: false,
        ),
      );
      expect(m.started, isFalse);
    });
  });

  group('TournamentStats.aggregate', () {
    test('ranking de goleadores con desempate Bota de Oro', () {
      final m1 = MatchStats.fromScoreboardEvent(scoreboardEvent(
        id: '1', homeId: '1', homeName: 'A', homeScore: 2,
        awayId: '2', awayName: 'B', awayScore: 1,
        details: [
          goalDetail('p1', 'Messi', '1'),
          goalDetail('p1', 'Messi', '1'),
          goalDetail('p2', 'Mbappe', '2'),
        ],
      ));
      // Mbappe suma otro gol en otro partido -> empata 2-2 con Messi.
      final m2 = MatchStats.fromScoreboardEvent(scoreboardEvent(
        id: '2', homeId: '2', homeName: 'B', homeScore: 1,
        awayId: '3', awayName: 'C', awayScore: 0,
        details: [goalDetail('p2', 'Mbappe', '2')],
      ));
      // Messi tiene 1 asistencia (summary) -> debe quedar primero.
      final m1b = m1.mergeSummary(summary([
        {'team': 'A', 'players': [
          {'id': 'p1', 'name': 'Messi', 'goals': 2, 'assists': 1},
        ]},
      ]));

      final stats = TournamentStats.aggregate([m1b, m2]);
      expect(stats.scorers.first.player.name, 'Messi');
      expect(stats.scorers.first.goals, 2);
      expect(stats.scorers.first.assists, 1);
      expect(stats.scorers[1].player.name, 'Mbappe');
      expect(stats.scorers[1].goals, 2);
    });

    test('totales: promedio, penales, hat-trick y goleada', () {
      final m1 = MatchStats.fromScoreboardEvent(scoreboardEvent(
        id: '1', homeId: '1', homeName: 'A', homeScore: 4,
        awayId: '2', awayName: 'B', awayScore: 0,
        attendance: 50000,
        details: [
          goalDetail('p1', 'Tripletista', '1'),
          goalDetail('p1', 'Tripletista', '1'),
          goalDetail('p1', 'Tripletista', '1', penalty: true),
          goalDetail('p9', 'Otro', '1'),
        ],
      ));
      final m2 = MatchStats.fromScoreboardEvent(scoreboardEvent(
        id: '2', homeId: '3', homeName: 'C', homeScore: 1,
        awayId: '4', awayName: 'D', awayScore: 1,
        attendance: 30000,
        details: [goalDetail('p5', 'X', '3'), goalDetail('p6', 'Y', '4')],
      ));
      final t = TournamentStats.aggregate([m1, m2]).totals;
      expect(t.matchesPlayed, 2);
      expect(t.totalGoals, 6);
      expect(t.avgGoals, 3.0);
      expect(t.penalties, 1);
      expect(t.hatTricks, 1);
      expect(t.attendance, 80000);
      expect(t.biggestWin?.winnerEspn, 'A');
      expect(t.biggestWin?.margin, 4);
    });

    test('disciplina y fair play por jugador', () {
      final m = MatchStats.fromScoreboardEvent(scoreboardEvent(
        id: '1', homeId: '1', homeName: 'A', homeScore: 0,
        awayId: '2', awayName: 'B', awayScore: 0,
        details: [
          cardDetail('p1', 'Rudo', '1', red: false),
          cardDetail('p1', 'Rudo', '1', red: true),
          cardDetail('p2', 'Leve', '2', red: false),
        ],
      ));
      final stats = TournamentStats.aggregate([m]);
      expect(stats.discipline.first.player.name, 'Rudo');
      expect(stats.discipline.first.yellow, 1);
      expect(stats.discipline.first.red, 1);
      expect(stats.discipline.first.points, 4);
      expect(stats.totals.red, 1);
      expect(stats.totals.yellow, 2);
    });

    test('asistencias, arqueros y vallas invictas (Nivel 2)', () {
      final m = MatchStats.fromScoreboardEvent(scoreboardEvent(
        id: '1', homeId: '1', homeName: 'A', homeScore: 2,
        awayId: '2', awayName: 'B', awayScore: 0,
      )).mergeSummary(summary([
        {'team': 'A', 'players': [
          {'id': 'a1', 'name': 'Asistidor', 'pos': 'M', 'assists': 2},
          {'id': 'gk1', 'name': 'Arquero A', 'pos': 'G', 'saves': 4, 'conceded': 0},
        ]},
        {'team': 'B', 'players': [
          {'id': 'gk2', 'name': 'Arquero B', 'pos': 'G', 'saves': 6, 'conceded': 2},
        ]},
      ]));
      final stats = TournamentStats.aggregate([m]);
      expect(stats.assists.first.player.name, 'Asistidor');
      expect(stats.assists.first.assists, 2);

      final cleanKeeper =
          stats.keepers.firstWhere((k) => k.player.name == 'Arquero A');
      expect(cleanKeeper.cleanSheets, 1);
      expect(cleanKeeper.saves, 4);
      final beaten = stats.keepers.firstWhere((k) => k.player.name == 'Arquero B');
      expect(beaten.cleanSheets, 0);
      // Arquero A debe rankear primero (más vallas invictas).
      expect(stats.keepers.first.player.name, 'Arquero A');
    });

    test('rankings por equipo: ataque, defensa, posesión', () {
      final m1 = MatchStats.fromScoreboardEvent(scoreboardEvent(
        id: '1', homeId: '1', homeName: 'A', homeScore: 3,
        awayId: '2', awayName: 'B', awayScore: 0,
        homeStats: {'possessionPct': 60},
        awayStats: {'possessionPct': 40},
      ));
      final stats = TournamentStats.aggregate([m1]);
      final a = stats.teams.firstWhere((t) => t.teamEspn == 'A');
      expect(a.goalsFor, 3);
      expect(a.goalsAgainst, 0);
      expect(a.cleanSheets, 1);
      expect(a.possessionAvg, 60);
      expect(a.goalDiff, 3);
    });

    test('lista vacía sin partidos jugados', () {
      final stats = TournamentStats.aggregate([]);
      expect(stats.isEmpty, isTrue);
      expect(stats.totals.avgGoals, 0);
    });
  });
}
