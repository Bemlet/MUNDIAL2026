/// Modelos de datos del Mundial 2026.
library;

class Team {
  final String id; // p. ej. 'ARG'
  final String name; // nombre en español
  final String espn; // displayName en la API de ESPN
  final String flag; // código de bandera (asset assets/flags/{flag}.png)
  final String group; // 'A'..'L'
  final String conf; // UEFA, CONMEBOL...
  final String confRegion;
  final int rank; // ranking FIFA (nov. 2025)
  final int apps; // participaciones en Mundiales (incluida 2026)
  final int titles;
  final String best; // mejor resultado histórico
  final List<String> stars;
  final String note;

  Team.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      espn = j['espn'],
      flag = j['flag'],
      group = j['group'],
      conf = j['conf'],
      confRegion = j['confRegion'],
      rank = j['rank'],
      apps = j['apps'],
      titles = j['titles'],
      best = j['best'],
      stars = List<String>.from(j['stars']),
      note = j['note'];
}

class Venue {
  final String name;
  final String city;
  final String country;
  final int capacity;

  Venue.fromJson(this.name, Map<String, dynamic> j)
    : city = j['city'],
      country = j['country'],
      capacity = j['cap'];
}

enum Stage { group, r32, r16, qf, sf, third, finalMatch }

Stage stageFrom(String s) => switch (s) {
  'group' => Stage.group,
  'r32' => Stage.r32,
  'r16' => Stage.r16,
  'qf' => Stage.qf,
  'sf' => Stage.sf,
  'third' => Stage.third,
  _ => Stage.finalMatch,
};

extension StageX on Stage {
  String get label => switch (this) {
    Stage.group => 'Fase de grupos',
    Stage.r32 => 'Dieciseisavos de final',
    Stage.r16 => 'Octavos de final',
    Stage.qf => 'Cuartos de final',
    Stage.sf => 'Semifinales',
    Stage.third => 'Tercer puesto',
    Stage.finalMatch => 'Final',
  };

  String get shortLabel => switch (this) {
    Stage.group => 'Grupos',
    Stage.r32 => '16avos',
    Stage.r16 => 'Octavos',
    Stage.qf => 'Cuartos',
    Stage.sf => 'Semis',
    Stage.third => '3.er puesto',
    Stage.finalMatch => 'Final',
  };
}

/// Un partido del fixture. `homeSlot`/`awaySlot` son IDs de equipo en fase de
/// grupos, o códigos de llave en eliminatorias:
///   W{G} ganador del grupo, R{G} segundo, T{GG...} mejor tercero de esos
///   grupos, M{n} ganador del partido n, L{n} perdedor del partido n.
class WcMatch {
  final int no;
  final Stage stage;
  final String? group;
  final String homeSlot;
  final String awaySlot;
  final DateTime dateUtc;
  final String venue;
  final String espnId;

  WcMatch.fromJson(Map<String, dynamic> j)
    : no = j['no'],
      stage = stageFrom(j['stage']),
      group = j['group'],
      homeSlot = j['home'],
      awaySlot = j['away'],
      dateUtc = DateTime.parse(j['date']).toUtc(),
      venue = j['venue'],
      espnId = j['espnId'];

  bool get isKnockout => stage != Stage.group;
}

/// Estado en vivo de un partido según ESPN.
class LiveInfo {
  final String espnId;
  final String
  status; // STATUS_SCHEDULED | STATUS_IN_PROGRESS... | STATUS_FULL_TIME / STATUS_FINAL...
  final String detail; // texto legible ("FT", "45'+2", "Sáb, 13 jun")
  final int? homeScore;
  final int? awayScore;
  final String homeEspn; // displayName: puede ser placeholder en eliminatorias
  final String awayEspn;

  LiveInfo({
    required this.espnId,
    required this.status,
    required this.detail,
    required this.homeScore,
    required this.awayScore,
    required this.homeEspn,
    required this.awayEspn,
  });

  bool get isFinished =>
      status.contains('FINAL') ||
      status.contains('FULL_TIME') ||
      status == 'STATUS_FT';
  bool get isLive =>
      status.contains('IN_PROGRESS') ||
      status.contains('HALFTIME') ||
      status.contains('FIRST_HALF') ||
      status.contains('SECOND_HALF') ||
      status.contains('EXTRA_TIME') ||
      status.contains('SHOOTOUT');

  Map<String, dynamic> toJson() => {
    'id': espnId,
    'st': status,
    'dt': detail,
    'hs': homeScore,
    'as': awayScore,
    'he': homeEspn,
    'ae': awayEspn,
  };

  factory LiveInfo.fromJson(Map<String, dynamic> j) => LiveInfo(
    espnId: j['id'],
    status: j['st'] ?? '',
    detail: j['dt'] ?? '',
    homeScore: j['hs'],
    awayScore: j['as'],
    homeEspn: j['he'] ?? '',
    awayEspn: j['ae'] ?? '',
  );
}

/// Pronóstico del usuario para un partido.
class Pred {
  int home;
  int away;

  /// En eliminatorias, si hay empate: id del equipo que avanza por penales.
  String? penWinner;

  Pred(this.home, this.away, [this.penWinner]);

  Map<String, dynamic> toJson() => {
    'h': home,
    'a': away,
    if (penWinner != null) 'p': penWinner,
  };

  factory Pred.fromJson(Map<String, dynamic> j) => Pred(j['h'], j['a'], j['p']);
}

/// Fila de una tabla de posiciones.
class TableRow {
  final String teamId;
  int played = 0, won = 0, drawn = 0, lost = 0, gf = 0, ga = 0;

  TableRow(this.teamId);

  int get points => won * 3 + drawn;
  int get gd => gf - ga;
}
