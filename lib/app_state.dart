/// Estado global de la app: dataset embebido, resultados en vivo (ESPN),
/// pronósticos del usuario y resolución de tablas y bracket.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'logic.dart';
import 'models.dart';
import 'notification_service.dart';
import 'stats.dart';
import 'theme.dart';

const _espnUrl =
    'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard'
    '?dates=20260611-20260719&limit=200';
const _kickoffReminderWindow = Duration(minutes: 15);

class AppState extends ChangeNotifier {
  late final Map<String, Team> teams; // id -> equipo
  late final Map<String, Team> teamsByEspn; // displayName ESPN -> equipo
  late final Map<String, Venue> venues;
  late final List<WcMatch> matches; // ordenados por fecha
  late final Map<int, WcMatch> byNo;
  late final Map<String, WcMatch> byEspnId;
  late final Map<String, List<WcMatch>> groupMatches; // 'A' -> 6 partidos
  late final Map<int, String>
  thirdSlots; // nº partido 16avos -> grupos admitidos

  final Map<String, LiveInfo> live = {}; // espnId -> estado
  final Map<int, Pred> preds = {}; // nº partido -> pronóstico
  final Set<String> _sentNotifications = {};

  // Estadísticas del torneo (Nivel 1: scoreboard; Nivel 2: summary por partido).
  final Map<String, MatchStats> matchStats = {}; // espnId -> stats del partido
  final Map<String, List<PlayerLine>> _playerLines = {}; // espnId -> Nivel 2
  final Set<String> _statsFetched = {}; // 'espnId#firma' ya descargados
  bool _fetchingDetails = false;

  /// Rankings agregados del torneo, recalculados a demanda.
  TournamentStats get stats => TournamentStats.aggregate(matchStats.values);

  SharedPreferences? _prefs;
  DateTime? lastSync;
  bool syncing = false;
  bool syncFailed = false;
  bool loaded = false;
  bool darkMode = true;
  bool onboardingDone = false;
  AppLanguage language = AppLanguage.es;

  AppStrings get l10n => AppStrings(language);

  void toggleTheme() {
    darkMode = !darkMode;
    Wc.dark = darkMode;
    _prefs?.setBool('darkMode', darkMode);
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    language = value;
    _prefs?.setString('language', value.code);
    NotificationService.setLanguage(value.code);
    notifyListeners();
  }

  Future<void> load({bool initialSync = true}) async {
    final tJson = jsonDecode(
      await rootBundle.loadString('assets/data/teams.json'),
    );
    final mJson = jsonDecode(
      await rootBundle.loadString('assets/data/matches.json'),
    );

    final teamList = [for (final t in tJson['teams']) Team.fromJson(t)];
    teams = {for (final t in teamList) t.id: t};
    teamsByEspn = {for (final t in teamList) t.espn: t};
    venues = {
      for (final e in (mJson['venues'] as Map<String, dynamic>).entries)
        e.key: Venue.fromJson(e.key, e.value),
    };
    matches = [for (final m in mJson['matches']) WcMatch.fromJson(m)]
      ..sort((a, b) {
        final c = a.dateUtc.compareTo(b.dateUtc);
        return c != 0 ? c : a.no - b.no;
      });
    byNo = {for (final m in matches) m.no: m};
    byEspnId = {for (final m in matches) m.espnId: m};
    groupMatches = {};
    for (final m in matches.where((m) => m.stage == Stage.group)) {
      groupMatches.putIfAbsent(m.group!, () => []).add(m);
    }
    thirdSlots = {
      for (final m in matches.where(
        (m) => m.stage == Stage.r32 && m.awaySlot.startsWith('T'),
      ))
        m.no: m.awaySlot.substring(1),
    };

    _prefs = await SharedPreferences.getInstance();
    _loadPrefs();
    await NotificationService.setLanguage(language.code);
    loaded = true;
    notifyListeners();
    if (initialSync) sync();
  }

  void _loadPrefs() {
    final p = _prefs!;
    final predsRaw = p.getString('preds');
    if (predsRaw != null) {
      (jsonDecode(predsRaw) as Map<String, dynamic>).forEach((k, v) {
        preds[int.parse(k)] = Pred.fromJson(v);
      });
    }
    final cache = p.getString('liveCache');
    if (cache != null) {
      for (final j in jsonDecode(cache) as List) {
        final info = LiveInfo.fromJson(j);
        live[info.espnId] = info;
      }
    }
    final statsCache = p.getString('statsCache');
    if (statsCache != null) {
      try {
        _restorePlayerLines(statsCache);
      } catch (_) {
        // Caché corrupta: se reconstruye en el próximo sync.
      }
    }
    final ts = p.getInt('lastSync');
    if (ts != null) lastSync = DateTime.fromMillisecondsSinceEpoch(ts);
    _sentNotifications.addAll(p.getStringList('sentNotifications') ?? const []);
    language = switch (p.getString('language')) {
      'en' => AppLanguage.en,
      _ => AppLanguage.es,
    };
    darkMode = p.getBool('darkMode') ?? true;
    Wc.dark = darkMode;
    onboardingDone = p.getBool('onboardingDone') ?? false;
  }

  /// Marca el onboarding como visto: no se vuelve a mostrar.
  void completeOnboarding() {
    if (onboardingDone) return;
    onboardingDone = true;
    _prefs?.setBool('onboardingDone', true);
    notifyListeners();
  }

  // ------------------------------------------------------------- sincronía

  Future<void> sync() async {
    if (syncing) return;
    syncing = true;
    syncFailed = false;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse(_espnUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body);
      for (final e in data['events'] as List) {
        final comp = e['competitions'][0];
        String he = '', ae = '';
        int? hs, as;
        for (final c in comp['competitors']) {
          final name = c['team']?['displayName'] ?? '';
          final score = int.tryParse('${c['score'] ?? ''}');
          if (c['homeAway'] == 'home') {
            he = name;
            hs = score;
          } else {
            ae = name;
            as = score;
          }
        }
        final type = e['status']?['type'] ?? {};
        final id = '${e['id']}';
        final previous = live[id];
        final info = LiveInfo(
          espnId: id,
          status: type['name'] ?? '',
          detail:
              (e['status']?['displayClock'] != null &&
                  (type['state'] ?? '') == 'in')
              ? '${e['status']['displayClock']}'
              : (type['shortDetail'] ?? ''),
          homeScore: hs,
          awayScore: as,
          homeEspn: he,
          awayEspn: ae,
        );
        live[id] = info;
        // Estadísticas Nivel 1 del scoreboard; preserva datos Nivel 2 cacheados.
        final ms = MatchStats.fromScoreboardEvent(
          Map<String, dynamic>.from(e as Map),
        );
        final cachedLines = _playerLines[id];
        matchStats[id] = cachedLines == null
            ? ms
            : ms.copyWith(playerLines: cachedLines);
        final match = byEspnId[id];
        if (match != null) {
          await _processLiveNotifications(match, previous, info);
        }
      }
      await checkMatchReminders();
      lastSync = DateTime.now();
      final p = _prefs;
      if (p != null) {
        await p.setString(
          'liveCache',
          jsonEncode([for (final l in live.values) l.toJson()]),
        );
        await p.setInt('lastSync', lastSync!.millisecondsSinceEpoch);
      }
      unawaited(syncPlayerDetails());
    } catch (_) {
      syncFailed = true;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> checkMatchReminders() async {
    if (!loaded) return;
    final now = DateTime.now().toUtc();
    for (final m in matches) {
      final l = liveFor(m);
      if (l?.isLive == true || l?.isFinished == true) continue;
      final untilKickoff = m.dateUtc.difference(now);
      if (untilKickoff < Duration.zero ||
          untilKickoff > _kickoffReminderWindow) {
        continue;
      }
      final when = untilKickoff.inMinutes <= 1
          ? l10n.inMoments
          : l10n.inMinutes(untilKickoff.inMinutes);
      await _notifyOnce(
        key: 'start_${m.no}',
        id: 100000 + m.no,
        title: l10n.notificationKickoffTitle,
        body: '${_matchName(m)} ${l10n.startsIn(when)}',
      );
    }
  }

  Future<void> _processLiveNotifications(
    WcMatch match,
    LiveInfo? previous,
    LiveInfo current,
  ) async {
    if (previous == null) return;

    final previousTotal = _totalScore(previous);
    final currentTotal = _totalScore(current);
    if (current.isLive &&
        previousTotal != null &&
        currentTotal != null &&
        currentTotal > previousTotal) {
      await _notifyOnce(
        key: 'goal_${match.no}_${current.homeScore}_${current.awayScore}',
        id: 200000 + match.no * 10 + currentTotal,
        title: '${l10n.notificationGoal} ${_matchName(match, current)}',
        body: _scoreBody(match, current),
      );
    }

    if (!previous.isFinished && current.isFinished) {
      await _notifyOnce(
        key: 'final_${match.no}',
        id: 300000 + match.no,
        title: l10n.notificationFinalTitle,
        body: _scoreBody(match, current),
      );
    }
  }

  int? _totalScore(LiveInfo info) {
    final home = info.homeScore;
    final away = info.awayScore;
    return home == null || away == null ? null : home + away;
  }

  String _matchName(WcMatch match, [LiveInfo? info]) {
    final (home, away) = realTeams(match);
    final homeName = _resolvedTeamName(
      home,
      info?.homeEspn ?? '',
      match.homeSlot,
    );
    final awayName = _resolvedTeamName(
      away,
      info?.awayEspn ?? '',
      match.awaySlot,
    );
    return '$homeName vs $awayName';
  }

  String _scoreBody(WcMatch match, LiveInfo info) {
    final (home, away) = realTeams(match);
    final homeName = _resolvedTeamName(home, info.homeEspn, match.homeSlot);
    final awayName = _resolvedTeamName(away, info.awayEspn, match.awaySlot);
    if (info.homeScore == null || info.awayScore == null) {
      return '$homeName vs $awayName';
    }
    final detail = info.detail.isEmpty ? '' : ' · ${info.detail}';
    return '$homeName ${info.homeScore} - ${info.awayScore} $awayName$detail';
  }

  String _resolvedTeamName(Team? team, String espnName, String slot) {
    if (team != null) return l10n.teamName(team);
    final espnTeam = teamsByEspn[espnName];
    if (espnTeam != null) return l10n.teamName(espnTeam);
    return espnName.isNotEmpty ? espnName : l10n.slotLabel(slot);
  }

  Future<void> _notifyOnce({
    required String key,
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_sentNotifications.add(key)) return;
    await _prefs?.setStringList(
      'sentNotifications',
      _sentNotifications.toList(growable: false),
    );
    await NotificationService.show(key: key, id: id, title: title, body: body);
  }

  // ------------------------------------------------------------ pronósticos

  void setPred(int matchNo, Pred? pred) {
    if (pred == null) {
      preds.remove(matchNo);
    } else {
      preds[matchNo] = pred;
    }
    _prunePenWinners();
    _savePreds();
    notifyListeners();
  }

  void _savePreds() {
    _prefs?.setString(
      'preds',
      jsonEncode(preds.map((k, v) => MapEntry('$k', v.toJson()))),
    );
  }

  /// Quita ganadores por penales que ya no correspondan a los equipos
  /// resueltos de la llave (p. ej. tras cambiar la fase de grupos).
  void _prunePenWinners() {
    for (final m in matches.where((m) => m.isKnockout)) {
      final p = preds[m.no];
      if (p?.penWinner == null) continue;
      final (h, a) = predTeams(m);
      if (h?.id != p!.penWinner && a?.id != p.penWinner) p.penWinner = null;
    }
  }

  /// Llena al azar el grupo indicado (solo partidos sin pronóstico).
  void simulateGroup(String g, [Random? rng]) {
    final r = rng ?? Random();
    for (final m in groupMatches[g]!) {
      if (preds.containsKey(m.no)) continue;
      preds[m.no] = _randomScore(m.homeSlot, m.awaySlot, r);
    }
    _prunePenWinners();
    _savePreds();
    notifyListeners();
  }

  /// Llena al azar todo lo que falte: grupos y luego eliminatorias en orden.
  void simulateRemaining() {
    final r = Random();
    for (final g in groupMatches.keys) {
      for (final m in groupMatches[g]!) {
        if (!preds.containsKey(m.no)) {
          preds[m.no] = _randomScore(m.homeSlot, m.awaySlot, r);
        }
      }
    }
    final ko = matches.where((m) => m.isKnockout).toList()
      ..sort((a, b) => a.no - b.no);
    for (final m in ko) {
      if (preds.containsKey(m.no)) continue;
      final (h, a) = predTeams(m);
      if (h == null || a == null) continue;
      final p = _randomScore(h.id, a.id, r);
      if (p.home == p.away) {
        p.penWinner = r.nextBool() ? h.id : a.id;
      }
      preds[m.no] = p;
    }
    _prunePenWinners();
    _savePreds();
    notifyListeners();
  }

  /// Marcador aleatorio sesgado por la diferencia de ranking FIFA.
  Pred _randomScore(String homeId, String awayId, Random r) {
    double strength(String id) => 1.6 - (_rankOf(id) / 90).clamp(0.0, 1.1);
    int goals(double s) {
      final x = r.nextDouble() * s;
      if (x < .45) return 0;
      if (x < .95) return 1;
      if (x < 1.35) return 2;
      if (x < 1.6) return 3;
      return 4;
    }

    return Pred(goals(strength(homeId)), goals(strength(awayId)));
  }

  void clearPreds() {
    preds.clear();
    _prefs?.remove('preds');
    notifyListeners();
  }

  int get groupPredCount => matches
      .where((m) => m.stage == Stage.group && preds.containsKey(m.no))
      .length;

  // ------------------------------------------------- estadísticas (Nivel 2)

  static const _summaryUrl =
      'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/summary?event=';

  /// Firma del partido para saber si cambió desde la última descarga.
  String _statsSig(MatchStats ms) => '${ms.goals.length}-${ms.finished}';

  /// Descarga el `summary` (asistencias, atajadas, arqueros) de los partidos
  /// jugados que aún no se bajaron o cuyo marcador cambió. Acota a un máximo de
  /// descargas por ciclo para no saturar la red en el arranque.
  Future<void> syncPlayerDetails() async {
    if (_fetchingDetails) return;
    _fetchingDetails = true;
    try {
      var budget = 8;
      var changed = false;
      for (final ms in matchStats.values) {
        if (!ms.started) continue;
        final key = '${ms.espnId}#${_statsSig(ms)}';
        if (_statsFetched.contains(key)) continue;
        if (budget <= 0) break;
        budget -= 1;
        try {
          final res = await http
              .get(Uri.parse('$_summaryUrl${ms.espnId}'))
              .timeout(const Duration(seconds: 12));
          if (res.statusCode != 200) continue;
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final merged = ms.mergeSummary(data);
          _playerLines[ms.espnId] = merged.playerLines;
          matchStats[ms.espnId] = merged;
          _statsFetched.add(key);
          changed = true;
        } catch (_) {
          // Un partido que falla no corta el resto.
        }
      }
      if (changed) {
        await _persistPlayerLines();
        notifyListeners();
      }
    } finally {
      _fetchingDetails = false;
    }
  }

  Future<void> _persistPlayerLines() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
      'statsCache',
      jsonEncode({
        for (final e in _playerLines.entries)
          e.key: [for (final pl in e.value) _playerLineToJson(pl)],
      }),
    );
  }

  void _restorePlayerLines(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in map.entries) {
      _playerLines[e.key] = [
        for (final j in e.value as List) _playerLineFromJson(j as Map),
      ];
    }
  }

  static Map<String, dynamic> _playerLineToJson(PlayerLine p) => {
    'i': p.player.id,
    'n': p.player.name,
    't': p.player.teamEspn,
    'gk': p.goalkeeper,
    's': p.starter,
    'g': p.goals,
    'a': p.assists,
    'sv': p.saves,
    'c': p.conceded,
    'y': p.yellow,
    'r': p.red,
  };

  static PlayerLine _playerLineFromJson(Map j) => PlayerLine(
    player: PlayerRef(
      id: '${j['i']}',
      name: '${j['n']}',
      teamEspn: '${j['t']}',
    ),
    goalkeeper: j['gk'] == true,
    starter: j['s'] == true,
    goals: j['g'] ?? 0,
    assists: j['a'] ?? 0,
    saves: j['sv'] ?? 0,
    conceded: j['c'] ?? 0,
    yellow: j['y'] ?? 0,
    red: j['r'] ?? 0,
  );

  // --------------------------------------------------------------- en vivo

  LiveInfo? liveFor(WcMatch m) => live[m.espnId];

  int _rankOf(String id) => teams[id]?.rank ?? 999;

  /// Equipos reales de un partido (null si la llave aún no se define).
  (Team?, Team?) realTeams(WcMatch m) {
    if (m.stage == Stage.group) {
      return (teams[m.homeSlot], teams[m.awaySlot]);
    }
    final l = liveFor(m);
    Team? h = l != null ? teamsByEspn[l.homeEspn] : null;
    Team? a = l != null ? teamsByEspn[l.awayEspn] : null;
    // Respaldo: calcular desde resultados reales si ESPN aún no resuelve.
    h ??= _realTeamForSlot(m.homeSlot, m.no);
    a ??= _realTeamForSlot(m.awaySlot, m.no);
    return (h, a);
  }

  Team? _realTeamForSlot(String slot, int matchNo) {
    if (slot.startsWith('W') && slot.length == 2) {
      final t = realTableIfComplete(slot[1]);
      return t == null ? null : teams[t[0].teamId];
    }
    if (slot.startsWith('R') && slot.length == 2) {
      final t = realTableIfComplete(slot[1]);
      return t == null ? null : teams[t[1].teamId];
    }
    if (slot.startsWith('T')) {
      final alloc = _realThirdAlloc();
      return alloc == null ? null : teams[alloc[matchNo]];
    }
    // M{n}/L{n}: ganador o perdedor de otro partido.
    final isWinner = slot.startsWith('M');
    final src = byNo[int.parse(slot.substring(1))];
    if (src == null) return null;
    final l = liveFor(src);
    if (l == null || !l.isFinished || l.homeScore == null) return null;
    final (h, a) = realTeams(src);
    if (h == null || a == null) return null;
    if (l.homeScore == l.awayScore) return null; // penales: lo resolverá ESPN
    final homeWon = l.homeScore! > l.awayScore!;
    return isWinner ? (homeWon ? h : a) : (homeWon ? a : h);
  }

  List<ScoreEntry> _realGroupResults(String g) => [
    for (final m in groupMatches[g]!)
      if (liveFor(m) case final l?
          when l.homeScore != null && (l.isFinished || l.isLive))
        ScoreEntry(m.homeSlot, m.awaySlot, l.homeScore!, l.awayScore!),
  ];

  /// Tabla real del grupo (incluye partidos en juego).
  List<TableRow> realTable(String g) {
    final ids = [for (final t in teams.values.where((t) => t.group == g)) t.id];
    return computeTable(ids, _realGroupResults(g), _rankOf);
  }

  List<TableRow>? realTableIfComplete(String g) {
    final done = groupMatches[g]!.every((m) => liveFor(m)?.isFinished == true);
    return done ? realTable(g) : null;
  }

  /// Terceros reales ordenados (solo de grupos terminados).
  List<TableRow> realThirdsRanked() {
    final thirds = <TableRow>[];
    for (final g in groupMatches.keys) {
      final t = realTableIfComplete(g);
      if (t != null) thirds.add(t[2]);
    }
    return rankThirds(thirds, _rankOf);
  }

  Map<int, String>? _realThirdAlloc() {
    final qualified = <String, String>{};
    for (final g in groupMatches.keys) {
      final t = realTableIfComplete(g);
      if (t == null) return null; // requiere los 12 grupos completos
      qualified[g] = t[2].teamId;
    }
    final top8 = rankThirds(
      qualified.entries.map((e) {
        final t = realTableIfComplete(e.key)!;
        return t[2];
      }).toList(),
      _rankOf,
    ).take(8).toList();
    final qualifiedTop = <String, String>{
      for (final r in top8) teams[r.teamId]!.group: r.teamId,
    };
    final alloc = allocateThirds({
      for (final e in thirdSlots.entries) e.key: e.value,
    }, qualifiedTop);
    return alloc.isEmpty ? null : alloc;
  }

  // ----------------------------------------------------------- predicciones

  List<ScoreEntry> _predGroupResults(String g) => [
    for (final m in groupMatches[g]!)
      if (preds[m.no] case final p?)
        ScoreEntry(m.homeSlot, m.awaySlot, p.home, p.away),
  ];

  List<TableRow> predTable(String g) {
    final ids = [for (final t in teams.values.where((t) => t.group == g)) t.id];
    return computeTable(ids, _predGroupResults(g), _rankOf);
  }

  bool predGroupComplete(String g) =>
      groupMatches[g]!.every((m) => preds.containsKey(m.no));

  bool get allGroupsPredicted => groupMatches.keys.every(predGroupComplete);

  List<TableRow> predThirdsRanked() {
    final thirds = <TableRow>[];
    for (final g in groupMatches.keys) {
      if (predGroupComplete(g)) thirds.add(predTable(g)[2]);
    }
    return rankThirds(thirds, _rankOf);
  }

  Map<int, String>? _predThirdAllocCache;
  int _predThirdAllocVersion = -1;

  Map<int, String>? _predThirdAlloc() {
    if (!allGroupsPredicted) return null;
    final version = preds.length * 1000 + groupPredCount;
    if (_predThirdAllocVersion == version) return _predThirdAllocCache;
    final top8 = predThirdsRanked().take(8).toList();
    final qualified = <String, String>{
      for (final r in top8) teams[r.teamId]!.group: r.teamId,
    };
    _predThirdAllocCache = () {
      final alloc = allocateThirds({
        for (final e in thirdSlots.entries) e.key: e.value,
      }, qualified);
      return alloc.isEmpty ? null : alloc;
    }();
    _predThirdAllocVersion = version;
    return _predThirdAllocCache;
  }

  /// Equipo pronosticado para un slot (null si aún no se puede resolver).
  Team? predTeamForSlot(String slot, int matchNo) {
    if (teams.containsKey(slot)) return teams[slot];
    if (slot.startsWith('W') && slot.length == 2) {
      return predGroupComplete(slot[1])
          ? teams[predTable(slot[1])[0].teamId]
          : null;
    }
    if (slot.startsWith('R') && slot.length == 2) {
      return predGroupComplete(slot[1])
          ? teams[predTable(slot[1])[1].teamId]
          : null;
    }
    if (slot.startsWith('T')) {
      final alloc = _predThirdAlloc();
      return alloc == null ? null : teams[alloc[matchNo]];
    }
    final isWinner = slot.startsWith('M');
    final src = byNo[int.parse(slot.substring(1))];
    if (src == null) return null;
    final w = predWinner(src);
    if (w == null) return null;
    if (isWinner) return w;
    final (h, a) = predTeams(src);
    if (h == null || a == null) return null;
    return w.id == h.id ? a : h;
  }

  (Team?, Team?) predTeams(WcMatch m) =>
      (predTeamForSlot(m.homeSlot, m.no), predTeamForSlot(m.awaySlot, m.no));

  /// Ganador pronosticado de un partido de eliminatorias.
  Team? predWinner(WcMatch m) {
    final (h, a) = predTeams(m);
    final p = preds[m.no];
    if (h == null || a == null || p == null) return null;
    if (p.home > p.away) return h;
    if (p.away > p.home) return a;
    if (p.penWinner == h.id) return h;
    if (p.penWinner == a.id) return a;
    return null;
  }

  Team? get predChampion => predWinner(byNo[104]!);

  /// Invalida pronósticos de eliminatorias que dependían de equipos que ya
  /// no clasifican (cuando el usuario cambia la fase de grupos).
  void prunePredsFor(WcMatch changed) {
    if (changed.stage != Stage.group) {
      // Cambió una llave: borrar predicciones de partidos posteriores cuyos
      // equipos resueltos cambien queda cubierto por la resolución dinámica;
      // solo hay que borrar penWinner inválidos.
      for (final m in matches.where((m) => m.isKnockout)) {
        final p = preds[m.no];
        if (p?.penWinner == null) continue;
        final (h, a) = predTeams(m);
        if (h?.id != p!.penWinner && a?.id != p.penWinner) {
          p.penWinner = null;
        }
      }
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- varios

  WcMatch? get nextMatch {
    final now = DateTime.now().toUtc();
    for (final m in matches) {
      final l = liveFor(m);
      if (l?.isLive == true) return m;
      if (l?.isFinished != true && m.dateUtc.isAfter(now)) return m;
    }
    return null;
  }

  List<WcMatch> matchesOfTeam(String teamId) {
    return [
      for (final m in matches)
        if (m.stage == Stage.group
            ? (m.homeSlot == teamId || m.awaySlot == teamId)
            : () {
                final (h, a) = realTeams(m);
                return h?.id == teamId || a?.id == teamId;
              }())
          m,
    ];
  }
}
