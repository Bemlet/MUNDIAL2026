/// Dataset curado de jugadores destacados.
///
/// Capa pura (sin Flutter): perfiles con puesto, club y seis habilidades
/// aproximadas (ritmo, tiro, pase, regate, defensa, físico) que alimentan la
/// carta de jugador. Los valores son curados/estimados, no oficiales. Se carga
/// de `assets/data/players.json` y se resuelve por nombre, tolerando acentos.
library;

/// Orden canónico de las habilidades en el radar.
const kSkillOrder = ['pac', 'sho', 'pas', 'dri', 'def', 'phy'];

/// Perfil de un jugador destacado.
class PlayerProfile {
  final String name;
  final String teamId;
  final String pos; // GK / DEF / MID / FWD
  final String club;
  final String? photo; // URL de foto curada (Wikimedia), si existe
  final String? bioEs; // reseña (Wikipedia ES)
  final String? bioEn; // reseña (Wikipedia EN)
  final Map<String, int> skills; // pac, sho, pas, dri, def, phy (0-99)

  const PlayerProfile({
    required this.name,
    required this.teamId,
    required this.pos,
    required this.club,
    required this.skills,
    this.photo,
    this.bioEs,
    this.bioEn,
  });

  factory PlayerProfile.fromJson(String name, Map<String, dynamic> j) {
    final raw = (j['skills'] as Map?) ?? const {};
    String? str(String k) {
      final v = '${j[k] ?? ''}';
      return v.isEmpty ? null : v;
    }

    return PlayerProfile(
      name: name,
      teamId: '${j['team'] ?? ''}',
      pos: '${j['pos'] ?? ''}',
      club: '${j['club'] ?? ''}',
      photo: str('photo'),
      bioEs: str('bio_es'),
      bioEn: str('bio_en'),
      skills: {
        for (final k in kSkillOrder) k: (raw[k] as num?)?.round() ?? 50,
      },
    );
  }

  /// Reseña en el idioma pedido, con respaldo en el otro si falta.
  String? bio({required bool isEn}) =>
      isEn ? (bioEn ?? bioEs) : (bioEs ?? bioEn);

  int _s(String k) => skills[k] ?? 50;

  /// Valoración global ponderada según el puesto (0-99).
  int get overall {
    final w = switch (pos) {
      'GK' => {'pac': 1, 'sho': 0, 'pas': 2, 'dri': 1, 'def': 4, 'phy': 3},
      'DEF' => {'pac': 2, 'sho': 1, 'pas': 2, 'dri': 1, 'def': 4, 'phy': 3},
      'MID' => {'pac': 2, 'sho': 2, 'pas': 4, 'dri': 3, 'def': 2, 'phy': 2},
      _ /* FWD */ => {'pac': 3, 'sho': 4, 'pas': 2, 'dri': 3, 'def': 0, 'phy': 2},
    };
    var sum = 0, wsum = 0;
    for (final k in kSkillOrder) {
      sum += _s(k) * w[k]!;
      wsum += w[k]!;
    }
    return wsum == 0 ? 50 : (sum / wsum).round();
  }
}

/// Datos traídos a demanda (Wikipedia) para jugadores sin perfil curado:
/// reseña en ES/EN y foto. Se cachea para no re-descargar.
class PlayerEnrichment {
  final String? bioEs;
  final String? bioEn;
  final String? photo;

  const PlayerEnrichment({this.bioEs, this.bioEn, this.photo});

  String? bio({required bool isEn}) =>
      isEn ? (bioEn ?? bioEs) : (bioEs ?? bioEn);

  bool get isEmpty =>
      (bioEs == null || bioEs!.isEmpty) &&
      (bioEn == null || bioEn!.isEmpty) &&
      (photo == null || photo!.isEmpty);

  Map<String, dynamic> toJson() => {'es': bioEs, 'en': bioEn, 'p': photo};

  factory PlayerEnrichment.fromJson(Map j) => PlayerEnrichment(
    bioEs: j['es'] as String?,
    bioEn: j['en'] as String?,
    photo: j['p'] as String?,
  );
}

/// Índice de perfiles con búsqueda tolerante a acentos y mayúsculas.
class PlayerDb {
  final Map<String, PlayerProfile> _byName;
  final Map<String, PlayerProfile> _byNormalized;

  const PlayerDb._(this._byName, this._byNormalized);

  static const empty = PlayerDb._({}, {});

  factory PlayerDb.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as Map?) ?? const {};
    final byName = <String, PlayerProfile>{};
    final byNorm = <String, PlayerProfile>{};
    for (final e in players.entries) {
      final p = PlayerProfile.fromJson(
        '${e.key}',
        (e.value as Map).cast<String, dynamic>(),
      );
      byName[p.name] = p;
      byNorm[normalize(p.name)] = p;
    }
    return PlayerDb._(byName, byNorm);
  }

  /// Busca un perfil por nombre exacto y, si falla, por nombre normalizado.
  PlayerProfile? lookup(String name) =>
      _byName[name] ?? _byNormalized[normalize(name)];

  bool has(String name) => lookup(name) != null;

  /// Minúsculas sin acentos ni signos, espacios colapsados.
  static String normalize(String s) {
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().runes) {
      buf.write(_fold[ch] ?? String.fromCharCode(ch));
    }
    return buf
        .toString()
        .replaceAll(RegExp(r"[^a-z0-9 ]"), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Rendimiento real de un jugador en el torneo (del feed de ESPN), más su id
/// de atleta para resolver la foto.
class PlayerTournament {
  final int goals;
  final int penalties;
  final int assists;
  final int saves;
  final int cleanSheets;
  final int yellow;
  final int red;
  final String? espnId;

  const PlayerTournament({
    required this.goals,
    required this.penalties,
    required this.assists,
    required this.saves,
    required this.cleanSheets,
    required this.yellow,
    required this.red,
    required this.espnId,
  });

  bool get isEmpty =>
      goals == 0 &&
      assists == 0 &&
      saves == 0 &&
      cleanSheets == 0 &&
      yellow == 0 &&
      red == 0;
}

/// Plegado de caracteres acentuados frecuentes a su letra base.
const Map<int, String> _fold = {
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a', 0x101: 'a',
  0xE7: 'c', 0x107: 'c', 0x10D: 'c', 0xE8: 'e', 0xE9: 'e', 0xEA: 'e',
  0xEB: 'e', 0x11B: 'e', 0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i',
  0x131: 'i', 0xF1: 'n', 0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o',
  0xF6: 'o', 0xF8: 'o', 0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u',
  0xFD: 'y', 0xFF: 'y', 0x161: 's', 0x15F: 's', 0x15B: 's', 0x17E: 'z',
  0x111: 'd', 0x11F: 'g', 0xDF: 'ss',
};
