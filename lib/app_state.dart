/// Estado global de la app: dataset embebido, resultados en vivo (ESPN),
/// pronósticos del usuario y resolución de tablas y bracket.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'l10n.dart';
import 'logic.dart';
import 'models.dart';
import 'notification_service.dart';
import 'players.dart';
import 'stats.dart';
import 'update_service.dart';
import 'supabase_service.dart';
import 'theme.dart';

const _espnUrl =
    'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard'
    '?dates=20260611-20260719&limit=200';
const _kickoffReminderWindow = Duration(minutes: 15);

class AppState extends ChangeNotifier {
  late final Map<String, Team> teams; // id -> equipo
  late final Map<String, Team> teamsByEspn; // displayName ESPN -> equipo
  PlayerDb players = PlayerDb.empty; // perfiles curados de figuras
  late final Map<String, Venue> venues;

  /// Override del "ahora" para tests deterministas (null en producción).
  @visibleForTesting
  DateTime? clockOverride;
  late final Map<String, CountryBroadcast> broadcasters; // ISO-2 -> canales
  final Map<String, List<String>> liveBroadcasts =
      {}; // espnId -> canales (ESPN)
  String country = 'US'; // país para canales de TV (autodetectado/elegido)
  String? nickname; // apodo en el leaderboard (Supabase)
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
  final Map<String, List<Lineup>> _lineups = {}; // espnId -> alineaciones
  final Map<String, PlayerEnrichment> _enrich = {}; // nombre norm. -> bio/foto
  final Set<String> _statsFetched = {}; // 'espnId#firma' ya descargados
  bool _fetchingDetails = false;

  /// Rankings agregados del torneo, recalculados a demanda.
  TournamentStats get stats => TournamentStats.aggregate(matchStats.values);

  /// Stats reales del torneo para un jugador (por nombre, tolerante a acentos),
  /// más su id de atleta de ESPN para la foto. Devuelve `null` si no figura en
  /// ningún ranking todavía.
  PlayerTournament? playerTournament(String name) {
    final n = PlayerDb.normalize(name);
    final s = stats;
    String? id;
    int goals = 0, pen = 0, assists = 0, saves = 0, clean = 0, yellow = 0, red = 0;
    var found = false;
    for (final x in s.scorers) {
      if (PlayerDb.normalize(x.player.name) == n) {
        goals = x.goals;
        pen = x.penalties;
        assists = x.assists;
        id ??= x.player.id;
        found = true;
      }
    }
    for (final x in s.assists) {
      if (PlayerDb.normalize(x.player.name) == n) {
        if (x.assists > assists) assists = x.assists;
        id ??= x.player.id;
        found = true;
      }
    }
    for (final x in s.keepers) {
      if (PlayerDb.normalize(x.player.name) == n) {
        saves = x.saves;
        clean = x.cleanSheets;
        id ??= x.player.id;
        found = true;
      }
    }
    for (final x in s.discipline) {
      if (PlayerDb.normalize(x.player.name) == n) {
        yellow = x.yellow;
        red = x.red;
        id ??= x.player.id;
        found = true;
      }
    }
    if (!found) return null;
    return PlayerTournament(
      goals: goals,
      penalties: pen,
      assists: assists,
      saves: saves,
      cleanSheets: clean,
      yellow: yellow,
      red: red,
      espnId: id,
    );
  }

  SharedPreferences? _prefs;
  DateTime? lastSync;
  bool syncing = false;
  bool syncFailed = false;
  bool loaded = false;
  bool darkMode = true;
  bool analyticsEnabled = true; // opt-out: activado por defecto
  bool onboardingDone = false;
  bool tourDone = false; // ya corrió el tour guiado
  bool exactAlarmGranted =
      true; // true por defecto: no molestar fuera de Android
  bool exactAlarmAsked = false; // ya mostramos el prompt una vez
  bool pickemNudgeShown = false; // ya avisamos del pick'em a este usuario
  bool playerIntroShown = false; // ya avisamos de las cartas de jugador
  bool lineupsIntroShown = false; // ya avisamos de formaciones + perfiles
  bool accountIntroShown = false; // ya avisamos de vincular la cuenta
  int? jumpTab; // pedido de cambio de pestaña inferior (lo consume el Shell)

  /// Pide al Shell saltar a una pestaña (p. ej. Pick'em desde la tira de picks).
  void goToTab(int index) {
    jumpTab = index;
    notifyListeners();
  }
  AppLanguage language = AppLanguage.es;

  AppStrings get l10n => AppStrings(language);

  void toggleTheme() {
    darkMode = !darkMode;
    Wc.dark = darkMode;
    _prefs?.setBool('darkMode', darkMode);
    notifyListeners();
  }

  void setAnalyticsEnabled(bool value) {
    analyticsEnabled = value;
    _prefs?.setBool('analyticsEnabled', value);
    AnalyticsService.setEnabled(value);
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

    final bJson = jsonDecode(
      await rootBundle.loadString('assets/data/broadcasters.json'),
    );
    broadcasters = {
      for (final e in (bJson['countries'] as Map<String, dynamic>).entries)
        e.key: CountryBroadcast.fromJson(e.key, e.value),
    };

    players = PlayerDb.fromJson(
      jsonDecode(await rootBundle.loadString('assets/data/players.json')),
    );

    _prefs = await SharedPreferences.getInstance();
    _loadPrefs();
    try {
      await AnalyticsService.initialize(enabled: analyticsEnabled);
      AnalyticsService.logEvent('app_open');
      AnalyticsService.logScreen('matches'); // pantalla inicial (Shell arranca en la tab Partidos)
    } catch (_) {
      // La analítica nunca debe impedir el arranque de la app.
    }
    await NotificationService.setLanguage(language.code);
    loaded = true;
    notifyListeners();
    if (initialSync) {
      sync();
      unawaited(refreshExactAlarm());
      unawaited(_initLeaderboard());
      unawaited(checkForUpdate());
      _listenAuth();
    }
  }

  // ----------------------------------------------------- leaderboard (Supabase)

  Future<void> _initLeaderboard() async {
    await SupabaseService.signInAnonymously();
    final n = await SupabaseService.fetchNickname();
    if (n != null && n != nickname) {
      nickname = n;
      notifyListeners();
    }
  }

  /// Define/actualiza el apodo del usuario en el leaderboard.
  Future<void> setNickname(String name) async {
    nickname = name.trim();
    notifyListeners();
    await SupabaseService.setNickname(nickname!, country: country);
  }

  Future<List<LeaderEntry>> fetchLeaderboard() =>
      SupabaseService.fetchLeaderboard();

  Future<List<LeaderEntry>> fetchLeaderboardFinal() =>
      SupabaseService.fetchLeaderboardFinal();

  Future<List<ParticipantPick>> fetchUserPredictions(String userId) =>
      SupabaseService.fetchUserPredictions(userId);

  // -------------------------------------------------- cuenta (Google)
  StreamSubscription<void>? _authSub;

  /// ¿La cuenta está vinculada (Google) o sigue anónima?
  bool get accountLinked => !SupabaseService.isAnonymous;
  String? get userEmail => SupabaseService.userEmail;

  /// Vincula la cuenta anónima actual con Google (conserva picks). Devuelve el
  /// error o null si arrancó OK.
  Future<String?> linkGoogle() async {
    final err = await SupabaseService.linkGoogle();
    if (err == null) {
      AnalyticsService.logEvent('account_linked', props: {'provider': 'google'});
    }
    return err;
  }

  /// Inicia sesión con Google (recupera la cuenta). Devuelve el error o null.
  Future<String?> signInWithGoogle() => SupabaseService.signInWithGoogle();

  void _listenAuth() {
    _authSub ??= SupabaseService.sessionChanges?.listen((_) {
      unawaited(_recoverAccount());
    });
  }

  /// Tras vincular/recuperar: trae apodo y picks propios del servidor.
  Future<void> _recoverAccount() async {
    final n = await SupabaseService.fetchNickname();
    if (n != null && n != nickname) nickname = n;
    final mine = await SupabaseService.fetchMyPredictions();
    for (final r in mine) {
      preds[r.matchNo] = Pred(r.home, r.away);
    }
    if (mine.isNotEmpty) _savePreds();
    notifyListeners();
  }

  // ------------------------------------------------ actualización in-app
  AppUpdate? availableUpdate; // versión nueva detectada (la consume el Shell)

  /// Chequea si hay una versión más nueva publicada. Tolerante a fallos.
  Future<void> checkForUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null) {
      availableUpdate = update;
      notifyListeners();
    }
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
    final lineupsCache = p.getString('lineupsCache');
    if (lineupsCache != null) {
      try {
        _restoreLineups(lineupsCache);
      } catch (_) {
        // Caché corrupta: se reconstruye en el próximo sync.
      }
    }
    final enrichCache = p.getString('playerEnrichCache');
    if (enrichCache != null) {
      try {
        _restoreEnrich(enrichCache);
      } catch (_) {
        // Caché corrupta: se vuelve a pedir a demanda.
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
    analyticsEnabled = p.getBool('analyticsEnabled') ?? true;
    onboardingDone = p.getBool('onboardingDone') ?? false;
    tourDone = p.getBool('tourDone') ?? false;
    exactAlarmAsked = p.getBool('exactAlarmAsked') ?? false;
    pickemNudgeShown = p.getBool('pickemNudgeShown') ?? false;
    playerIntroShown = p.getBool('playerIntroShown') ?? false;
    lineupsIntroShown = p.getBool('lineupsIntroShown') ?? false;
    accountIntroShown = p.getBool('accountIntroShown') ?? false;
    country = p.getString('country') ?? _detectCountry();
    _pruneUnresolvedKnockoutPickemPreds(notify: false);
  }

  /// País por defecto según el locale del dispositivo (si lo conocemos).
  String _detectCountry() {
    final cc = ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    // Si no es un país soportado, no mostramos canales (en vez de datos erróneos).
    return cc ?? 'US';
  }

  /// Cambia el país de transmisión elegido por el usuario.
  void setCountry(String code) {
    if (country == code) return;
    country = code;
    _prefs?.setString('country', code);
    notifyListeners();
  }

  /// Nombre localizado del país.
  String countryName(String code) {
    final b = broadcasters[code];
    if (b == null) return code;
    return l10n.isEn ? b.nameEn : b.nameEs;
  }

  /// Países disponibles, ordenados por nombre localizado.
  List<CountryBroadcast> get countriesSorted {
    final list = broadcasters.values.toList()
      ..sort((a, b) => countryName(a.code).compareTo(countryName(b.code)));
    return list;
  }

  /// Canales para un partido según el país:
  /// - `live` (EE.UU.): usa el feed por partido de ESPN si existe.
  /// - resto: canales de todo el torneo + abiertos solo si juega la selección
  ///   local, es la inauguración o es eliminatoria.
  List<String> channelsFor(WcMatch m) {
    final c = broadcasters[country];
    if (c == null) return const [];
    if (c.live) {
      final live = liveBroadcasts[m.espnId];
      return (live != null && live.isNotEmpty) ? live : c.all;
    }
    final out = <String>[...c.all];
    final involvesTeam =
        c.teamId != null &&
        m.stage == Stage.group &&
        (m.homeSlot == c.teamId || m.awaySlot == c.teamId);
    if (m.no == 1 || m.isKnockout || involvesTeam) {
      out.addAll(c.select);
    }
    return out;
  }

  /// Marca el onboarding como visto: no se vuelve a mostrar.
  void completeOnboarding() {
    if (onboardingDone) return;
    onboardingDone = true;
    _prefs?.setBool('onboardingDone', true);
    // Los usuarios nuevos ya vieron el Pick'em en el onboarding: no repetir el aviso.
    pickemNudgeShown = true;
    _prefs?.setBool('pickemNudgeShown', true);
    // Tampoco repetir el aviso de cartas de jugador: ya está en el onboarding.
    playerIntroShown = true;
    _prefs?.setBool('playerIntroShown', true);
    lineupsIntroShown = true;
    _prefs?.setBool('lineupsIntroShown', true);
    // Los nuevos ven el slide de cuenta en el onboarding: no repetir el aviso.
    accountIntroShown = true;
    _prefs?.setBool('accountIntroShown', true);
    notifyListeners();
  }

  /// ¿Mostrar el aviso del Pick'em? (una vez, para usuarios que ya tenían la app
  /// antes de la feature). Espera a que se resuelvan onboarding/tour/alarma.
  bool get shouldShowPickemNudge =>
      loaded &&
      onboardingDone &&
      tourDone &&
      !pickemNudgeShown &&
      (exactAlarmGranted || exactAlarmAsked);

  void markPickemNudgeShown() {
    if (pickemNudgeShown) return;
    pickemNudgeShown = true;
    _prefs?.setBool('pickemNudgeShown', true);
    notifyListeners();
  }

  /// ¿Mostrar el aviso de cartas de jugador? (una vez, para usuarios que ya
  /// tenían la app antes de la feature). Va último, tras los otros avisos.
  bool get shouldShowPlayerIntro =>
      loaded &&
      onboardingDone &&
      tourDone &&
      pickemNudgeShown &&
      !playerIntroShown &&
      (exactAlarmGranted || exactAlarmAsked);

  void markPlayerIntroShown() {
    if (playerIntroShown) return;
    playerIntroShown = true;
    _prefs?.setBool('playerIntroShown', true);
    notifyListeners();
  }

  /// ¿Mostrar el aviso de formaciones + perfiles? (una vez, tras el de cartas).
  bool get shouldShowLineupsIntro =>
      loaded &&
      onboardingDone &&
      tourDone &&
      playerIntroShown &&
      !lineupsIntroShown &&
      (exactAlarmGranted || exactAlarmAsked);

  /// ¿Avisar de vincular la cuenta? (una vez, solo a usuarios anónimos que ya
  /// tenían la app, tras los otros avisos).
  bool get shouldShowAccountIntro =>
      loaded &&
      onboardingDone &&
      tourDone &&
      lineupsIntroShown &&
      !accountIntroShown &&
      !accountLinked &&
      (exactAlarmGranted || exactAlarmAsked);

  void markAccountIntroShown() {
    if (accountIntroShown) return;
    accountIntroShown = true;
    _prefs?.setBool('accountIntroShown', true);
    notifyListeners();
  }

  void markLineupsIntroShown() {
    if (lineupsIntroShown) return;
    lineupsIntroShown = true;
    _prefs?.setBool('lineupsIntroShown', true);
    notifyListeners();
  }

  /// ¿Correr el tour guiado? (una sola vez, después del onboarding).
  bool get shouldRunTour => loaded && onboardingDone && !tourDone;

  /// Marca el tour como visto.
  void completeTour() {
    if (tourDone) return;
    tourDone = true;
    _prefs?.setBool('tourDone', true);
    notifyListeners();
  }

  /// ¿Mostrar el prompt para activar alarmas exactas? (una sola vez, tras el tour).
  bool get shouldPromptExactAlarm =>
      loaded &&
      onboardingDone &&
      tourDone &&
      !exactAlarmGranted &&
      !exactAlarmAsked;

  /// Refresca si el sistema permite alarmas exactas (Android 12+).
  Future<void> refreshExactAlarm() async {
    final granted = await NotificationService.canScheduleExactAlarms();
    if (granted != exactAlarmGranted) {
      exactAlarmGranted = granted;
      notifyListeners();
    }
  }

  /// Marca el prompt como mostrado para no repetirlo.
  void markExactAlarmAsked() {
    if (exactAlarmAsked) return;
    exactAlarmAsked = true;
    _prefs?.setBool('exactAlarmAsked', true);
    notifyListeners();
  }

  /// Abre los ajustes del sistema para conceder la alarma exacta.
  Future<void> requestExactAlarm() async {
    markExactAlarmAsked();
    await NotificationService.requestExactAlarm();
  }

  // ------------------------------------------------------------- sincronía

  Future<void> sync() async {
    if (syncing) return;
    syncing = true;
    syncFailed = false;
    notifyListeners();
    try {
      _pruneUnresolvedKnockoutPickemPreds(notify: false);
      final res = await http
          .get(Uri.parse(_espnUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(res.body);
      for (final e in data['events'] as List) {
        final comp = e['competitions'][0];
        String he = '', ae = '';
        int? hs, as;
        int? hp, ap;
        for (final c in comp['competitors']) {
          final name = c['team']?['displayName'] ?? '';
          final score = int.tryParse('${c['score'] ?? ''}');
          final pens = int.tryParse('${c['shootoutScore'] ?? ''}');
          if (c['homeAway'] == 'home') {
            he = name;
            hs = score;
            hp = pens;
          } else {
            ae = name;
            as = score;
            ap = pens;
          }
        }
        final type = e['status']?['type'] ?? {};
        final id = '${e['id']}';
        // Canales de TV (EE.UU.) del feed de ESPN.
        final gb = (comp['geoBroadcasts'] as List?) ?? const [];
        final chans = <String>[];
        for (final g in gb) {
          var name = '${(g['media'] ?? const {})['shortName'] ?? ''}'.trim();
          if (name.isEmpty) continue;
          if (name == 'Tele') name = 'Telemundo';
          if (!chans.contains(name)) chans.add(name);
        }
        if (chans.isNotEmpty) liveBroadcasts[id] = chans;
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
          homePens: hp,
          awayPens: ap,
        );
        live[id] = info;
        // Estadísticas Nivel 1 del scoreboard; preserva datos Nivel 2 cacheados.
        final ms = MatchStats.fromScoreboardEvent(
          Map<String, dynamic>.from(e as Map),
        );
        final cachedLines = _playerLines[id];
        final cachedLineups = _lineups[id];
        matchStats[id] = (cachedLines == null && cachedLineups == null)
            ? ms
            : ms.copyWith(playerLines: cachedLines, lineups: cachedLineups);
        final match = byEspnId[id];
        if (match != null) {
          await _processLiveNotifications(match, previous, info);
        }
      }
      _pruneUnresolvedKnockoutPickemPreds(notify: false);
      await checkMatchReminders();
      await checkPickemReminder();
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
    } catch (e) {
      syncFailed = true;
      AnalyticsService.logError('sync', e.toString());
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

  /// Partidos de HOY (hora local) editables y todavía SIN pronóstico del usuario.
  List<WcMatch> pendingPicksToday() {
    final today = DateTime.now().toLocal();
    bool sameDay(DateTime utc) {
      final d = utc.toLocal();
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }

    return [
      for (final m in matches)
        if (preds[m.no] == null && canEditPickem(m) && sameDay(m.dateUtc)) m,
    ];
  }

  int get pendingPicksTodayCount => pendingPicksToday().length;

  /// Recordatorio (una vez por día) si faltan pronósticos de hoy y el primer
  /// partido pendiente está a pocas horas. Se apoya en el sync/alarma existente.
  Future<void> checkPickemReminder() async {
    if (!loaded) return;
    final pending = pendingPicksToday();
    if (pending.isEmpty) return;
    final now = DateTime.now().toUtc();
    final firstKick = pending
        .map((m) => m.dateUtc)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final until = firstKick.difference(now);
    if (until <= Duration.zero || until > const Duration(hours: 4)) return;
    final d = firstKick.toLocal();
    await _notifyOnce(
      key: 'pickem_pending_${d.year}-${d.month}-${d.day}',
      id: 400000 + d.month * 100 + d.day,
      title: l10n.pickemReminderTitle,
      body: l10n.pickemReminderBody(pending.length),
    );
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

  void setPred(int matchNo, Pred? pred, {DateTime? now}) {
    final match = byNo[matchNo];
    if (match == null || !canEditPickem(match, now)) return;
    final existed = preds.containsKey(matchNo);
    if (pred == null) {
      preds.remove(matchNo);
    } else {
      preds[matchNo] = pred;
    }
    _prunePenWinners();
    _savePreds();
    notifyListeners();
    // Sincroniza con el leaderboard (no bloquea; no-op si no hay sesión).
    if (pred == null) {
      unawaited(SupabaseService.deletePrediction(matchNo));
    } else {
      AnalyticsService.logEvent(
        existed ? 'prediction_updated' : 'prediction_created',
        props: {'match_no': matchNo},
      );
      unawaited(
        SupabaseService.upsertPrediction(matchNo, pred.home, pred.away),
      );
    }
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

  /// Pronóstico tomado del resultado REAL si el partido ya terminó; null si aún
  /// no se jugó (o si fue por penales y todavía no se puede resolver el ganador).
  Pred? realPredFor(WcMatch m) {
    final l = liveFor(m);
    if (l == null ||
        !l.isFinished ||
        l.homeScore == null ||
        l.awayScore == null) {
      return null;
    }
    final p = Pred(l.homeScore!, l.awayScore!);
    if (m.isKnockout && l.homeScore == l.awayScore) {
      final w = _realKnockoutWinner(m);
      if (w == null) return null; // empate por penales aún no resoluble
      p.penWinner = w;
    }
    return p;
  }

  // ------------------------------------------------------------- pick'em

  /// Inicio del pick'em: los partidos anteriores se rellenan con el real pero
  /// NO suman puntos (el "campeonato de aciertos" arranca acá).
  static final DateTime pickemStart = DateTime.utc(2026, 6, 17);

  /// ¿El partido suma puntos? (kickoff desde el 17/jun).
  bool pickemCounts(WcMatch m) => !m.dateUtc.isBefore(pickemStart);

  /// ¿La predicción está bloqueada? Se cierra al kickoff (no se edita más).
  bool pickemLocked(WcMatch m, [DateTime? now]) =>
      !(now ?? DateTime.now()).toUtc().isBefore(m.dateUtc);

  bool canEditPickem(WcMatch m, [DateTime? now]) {
    final (home, away) = realTeams(m);
    return home != null &&
        away != null &&
        pickemCounts(m) &&
        !pickemLocked(m, now);
  }

  /// Puntos del pick'em para un partido (0 si no puntúa, no hay real o no hay
  /// pronóstico).
  int pickemPoints(WcMatch m) {
    if (!pickemCounts(m)) return 0;
    final pred = preds[m.no];
    final real = realPredFor(m);
    if (pred == null || real == null) return 0;
    return scorePick(pred, real);
  }

  /// Puntos del pick'em de GRUPOS (base, solo fase de grupos, respeta cutoff).
  int pickemPointsGroups(WcMatch m) {
    if (m.stage != Stage.group || !pickemCounts(m)) return 0;
    final pred = preds[m.no];
    final real = realPredFor(m);
    if (pred == null || real == null) return 0;
    return scorePick(pred, real);
  }

  /// Puntos del pick'em de FASE FINAL (knockout, con multiplicador por ronda).
  int pickemPointsFinal(WcMatch m) {
    if (!m.isKnockout) return 0;
    final pred = preds[m.no];
    final real = realPredFor(m);
    if (pred == null || real == null) return 0;
    return scorePick(pred, real) * roundMultiplier(m.stage);
  }

  int get pickemTotalGroups {
    var t = 0;
    for (final m in matches) {
      t += pickemPointsGroups(m);
    }
    return t;
  }

  int get pickemTotalFinal {
    var t = 0;
    for (final m in matches) {
      t += pickemPointsFinal(m);
    }
    return t;
  }

  /// La fase final está activa cuando ya empezó el primer partido de knockout.
  bool get finalPhaseActive {
    final firstKo = matches
        .where((m) => m.isKnockout)
        .map((m) => m.dateUtc)
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final now = (clockOverride ?? DateTime.now()).toUtc();
    return firstKo != null && !now.isBefore(firstKo);
  }

  /// La fase de grupos concluyó (se congela el ranking de grupos) cuando arranca
  /// el knockout. Se usa para coronar al Campeón de Grupos.
  bool get groupsConcluded => finalPhaseActive;

  /// El torneo terminó cuando el partido final (Stage.finalMatch) está finalizado.
  /// Se usa para coronar al Campeón del torneo (ranking de fase final).
  bool get tournamentOver {
    final fin = matches.where((m) => m.stage == Stage.finalMatch);
    if (fin.isEmpty) return false;
    final m = fin.first;
    return liveFor(m)?.isFinished == true;
  }

  /// Puntaje total acumulado del pick'em (fase activa).
  int get pickemTotal => finalPhaseActive ? pickemTotalFinal : pickemTotalGroups;

  /// (exactos, resultados) que puntuaron en la fase activa.
  /// Categoriza por puntaje BASE (antes del multiplicador), no por el total.
  (int, int) get pickemBreakdown {
    var exact = 0, correct = 0;
    for (final m in matches) {
      if (finalPhaseActive) {
        if (!m.isKnockout) continue;
      } else {
        if (m.stage != Stage.group || !pickemCounts(m)) continue;
      }
      final pred = preds[m.no];
      final real = realPredFor(m);
      if (pred == null || real == null) continue;
      final base = scorePick(pred, real);
      switch (base) {
        case 6:
          exact++;
        case 3:
          correct++;
      }
    }
    return (exact, correct);
  }

  /// Ganador real de una llave definida por penales: lo deduce del equipo que
  /// ESPN ya colocó en la ronda siguiente.
  String? _realKnockoutWinner(WcMatch m) {
    final slot = 'M${m.no}';
    for (final nxt in matches.where(
      (x) => x.homeSlot == slot || x.awaySlot == slot,
    )) {
      final (h, a) = realTeams(nxt);
      if (nxt.homeSlot == slot && h != null) return h.id;
      if (nxt.awaySlot == slot && a != null) return a.id;
    }
    return null;
  }

  /// Llena el grupo: usa el resultado real si ya se jugó; si no, al azar (solo
  /// partidos sin pronóstico).
  void simulateGroup(String g, [Random? rng]) {
    final r = rng ?? Random();
    for (final m in groupMatches[g]!) {
      final real = realPredFor(m);
      if (real != null) {
        preds[m.no] = real;
      } else if (!preds.containsKey(m.no)) {
        preds[m.no] = _randomScore(m.homeSlot, m.awaySlot, r);
      }
    }
    _prunePenWinners();
    _savePreds();
    notifyListeners();
  }

  /// Completa todo: toma los resultados REALES de los partidos ya jugados y
  /// simula al azar solo los que faltan (grupos y luego eliminatorias en orden).
  void simulateRemaining() {
    final r = Random();
    for (final g in groupMatches.keys) {
      for (final m in groupMatches[g]!) {
        final real = realPredFor(m);
        if (real != null) {
          preds[m.no] = real;
        } else if (!preds.containsKey(m.no)) {
          preds[m.no] = _randomScore(m.homeSlot, m.awaySlot, r);
        }
      }
    }
    final ko = matches.where((m) => m.isKnockout).toList()
      ..sort((a, b) => a.no - b.no);
    for (final m in ko) {
      final real = realPredFor(m);
      if (real != null) {
        preds[m.no] = real;
        continue;
      }
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

  void clearPreds({DateTime? now}) {
    final editable = [
      for (final matchNo in preds.keys)
        if (byNo[matchNo] case final match? when canEditPickem(match, now))
          matchNo,
    ];
    if (editable.isEmpty) return;
    for (final matchNo in editable) {
      preds.remove(matchNo);
      unawaited(SupabaseService.deletePrediction(matchNo));
    }
    if (preds.isEmpty) {
      _prefs?.remove('preds');
    } else {
      _savePreds();
    }
    notifyListeners();
  }

  bool _pruneUnresolvedKnockoutPickemPreds({bool notify = true}) {
    final stale = <int>[];
    for (final m in matches.where((m) => m.isKnockout)) {
      if (!preds.containsKey(m.no)) continue;
      final (home, away) = realTeams(m);
      if (home == null || away == null) stale.add(m.no);
    }
    if (stale.isEmpty) return false;
    for (final matchNo in stale) {
      preds.remove(matchNo);
      unawaited(SupabaseService.deletePrediction(matchNo));
    }
    if (preds.isEmpty) {
      _prefs?.remove('preds');
    } else {
      _savePreds();
    }
    if (notify) notifyListeners();
    return true;
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
          _lineups[ms.espnId] = merged.lineups;
          matchStats[ms.espnId] = merged;
          _statsFetched.add(key);
          changed = true;
        } catch (_) {
          // Un partido que falla no corta el resto.
        }
      }
      if (changed) {
        await _persistPlayerLines();
        await _persistLineups();
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

  Future<void> _persistLineups() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
      'lineupsCache',
      jsonEncode({
        for (final e in _lineups.entries)
          e.key: [
            for (final lu in e.value)
              {
                't': lu.teamEspn,
                'f': lu.formation,
                'p': [for (final pl in lu.players) _lineupPlayerToJson(pl)],
              },
          ],
      }),
    );
  }

  void _restoreLineups(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in map.entries) {
      _lineups[e.key] = [
        for (final lu in e.value as List)
          Lineup(
            teamEspn: '${(lu as Map)['t']}',
            formation: '${lu['f'] ?? ''}',
            players: [
              for (final pj in (lu['p'] as List? ?? const []))
                _lineupPlayerFromJson(pj as Map),
            ],
          ),
      ];
    }
  }

  static Map<String, dynamic> _lineupPlayerToJson(LineupPlayer p) => {
    'i': p.player.id,
    'n': p.player.name,
    't': p.player.teamEspn,
    'num': p.number,
    'pos': p.pos,
    's': p.starter,
    'pl': p.place,
    'in': p.subbedIn,
    'out': p.subbedOut,
    'm': p.subMinute,
  };

  static LineupPlayer _lineupPlayerFromJson(Map j) => LineupPlayer(
    player: PlayerRef(
      id: '${j['i']}',
      name: '${j['n']}',
      teamEspn: '${j['t']}',
    ),
    number: j['num'] ?? 0,
    pos: '${j['pos'] ?? ''}',
    starter: j['s'] == true,
    place: j['pl'],
    subbedIn: j['in'] == true,
    subbedOut: j['out'] == true,
    subMinute: j['m'],
  );

  // ---------------------------------------- enriquecimiento de jugadores
  static const _wikiUa = 'Golazo-WC2026/1.0 (personal; evermosquerag@gmail.com)';

  /// Trae a demanda (y cachea) la reseña + foto de un jugador desde Wikipedia.
  /// Devuelve datos vacíos si no hay artículo. No bloquea si falla la red.
  Future<PlayerEnrichment?> enrichPlayer(String name) async {
    final key = PlayerDb.normalize(name);
    final cached = _enrich[key];
    if (cached != null) return cached;
    final fetched = await _fetchEnrichment(name);
    final result = fetched ?? const PlayerEnrichment();
    _enrich[key] = result; // cachea también el "vacío" para no reintentar
    if (!result.isEmpty) await _persistEnrich();
    return result;
  }

  Future<PlayerEnrichment?> _fetchEnrichment(String name) async {
    final es = await _wikiSummary('es', name);
    final en = await _wikiSummary('en', name);
    final bioEs = _trimExtract(es?['extract']);
    final bioEn = _trimExtract(en?['extract']);
    final photo = (es?['thumbnail']?['source'] ?? en?['thumbnail']?['source'])
        as String?;
    if (bioEs == null && bioEn == null && (photo == null || photo.isEmpty)) {
      return null;
    }
    return PlayerEnrichment(bioEs: bioEs, bioEn: bioEn, photo: photo);
  }

  Future<Map<String, dynamic>?> _wikiSummary(String lang, String title) async {
    try {
      final t = Uri.encodeComponent(title.trim().replaceAll(' ', '_'));
      final res = await http
          .get(
            Uri.parse('https://$lang.wikipedia.org/api/rest_v1/page/summary/$t'),
            headers: {'User-Agent': _wikiUa},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      if (d['type'] == 'disambiguation') return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  String? _trimExtract(dynamic s) {
    if (s is! String) return null;
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return null;
    if (t.length <= 320) return t;
    final cut = t.substring(0, 320);
    final dot = cut.lastIndexOf('. ');
    return dot > 140 ? cut.substring(0, dot + 1) : '${cut.trimRight()}…';
  }

  Future<void> _persistEnrich() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
      'playerEnrichCache',
      jsonEncode({
        for (final e in _enrich.entries)
          if (!e.value.isEmpty) e.key: e.value.toJson(),
      }),
    );
  }

  void _restoreEnrich(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in map.entries) {
      _enrich[e.key] = PlayerEnrichment.fromJson(e.value as Map);
    }
  }

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

  /// Terceros reales ordenados (los 12 grupos, según resultados actuales;
  /// provisional mientras un grupo no haya terminado).
  List<TableRow> realThirdsRanked() {
    final thirds = <TableRow>[];
    for (final g in groupMatches.keys) {
      thirds.add(realTable(g)[2]);
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
