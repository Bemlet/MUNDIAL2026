/// Capa de acceso a Supabase para el pick'em (auth anónima, apodo, sincronía de
/// predicciones y leaderboard). Todo está envuelto en try/catch y hace no-op si
/// Supabase no está inicializado (p. ej. en tests o sin red), para que la app
/// nunca crashee por el backend.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class LeaderEntry {
  final String userId;
  final String nickname;
  final int points;
  final int exactCount;

  const LeaderEntry({
    required this.userId,
    required this.nickname,
    required this.points,
    required this.exactCount,
  });
}

/// Predicción de un participante para un partido ya bloqueado (kickoff pasado),
/// con el resultado real y los puntos que sumó. Por transparencia solo se
/// exponen partidos que ya empezaron.
class ParticipantPick {
  final int matchNo;
  final int home;
  final int away;
  final int? resultHome;
  final int? resultAway;
  final bool finished;
  final int points;

  const ParticipantPick({
    required this.matchNo,
    required this.home,
    required this.away,
    required this.resultHome,
    required this.resultAway,
    required this.finished,
    required this.points,
  });

  bool get hasResult => resultHome != null && resultAway != null;
}

class SupabaseService {
  static bool _ready = false;
  static bool get ready => _ready;

  /// Inicializa el cliente. Idempotente y tolerante a fallos.
  static Future<void> init() async {
    if (_ready) return;
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return;
    try {
      // anonKey (JWT legacy) es la clave provista; publishableKey es para el
      // formato nuevo sb_publishable_.
      // ignore: deprecated_member_use
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _ready = true;
    } catch (_) {}
  }

  static SupabaseClient? get _client =>
      _ready ? Supabase.instance.client : null;

  static String? get userId => _client?.auth.currentUser?.id;

  /// Deep link de vuelta del login OAuth (declarado en AndroidManifest).
  static const _redirect = 'com.ever.mundial2026://login-callback';

  /// ¿La sesión actual es anónima? (sin Google/email vinculado).
  static bool get isAnonymous => _client?.auth.currentUser?.isAnonymous ?? true;

  /// Email de la cuenta vinculada (Google), si hay.
  static String? get userEmail => _client?.auth.currentUser?.email;

  /// Emite cuando la sesión cambia por login/link/recuperación (para refrescar).
  static Stream<void>? get sessionChanges => _client?.auth.onAuthStateChange
      .where((s) =>
          s.event == AuthChangeEvent.signedIn ||
          s.event == AuthChangeEvent.userUpdated)
      .map((_) {});

  /// Vincula la cuenta ANÓNIMA actual con Google (retroactivo: conserva el id y
  /// los picks). Devuelve null si OK, o el mensaje de error si falla.
  static Future<String?> linkGoogle() async {
    final c = _client;
    if (c == null) return 'Sin conexión a Supabase';
    try {
      await c.auth.linkIdentity(OAuthProvider.google, redirectTo: _redirect);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Inicia sesión con Google (recuperación). Devuelve null si OK, o el error.
  static Future<String?> signInWithGoogle() async {
    final c = _client;
    if (c == null) return 'Sin conexión a Supabase';
    try {
      await c.auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirect);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Asegura una sesión anónima.
  static Future<void> signInAnonymously() async {
    final c = _client;
    if (c == null) return;
    try {
      if (c.auth.currentUser == null) await c.auth.signInAnonymously();
    } catch (_) {}
  }

  /// Predicciones propias (todas, incl. futuras) para repoblar tras recuperar
  /// la cuenta en un dispositivo nuevo. La RLS permite leer las propias.
  static Future<List<({int matchNo, int home, int away})>>
      fetchMyPredictions() async {
    final c = _client;
    final uid = userId;
    if (c == null || uid == null) return const [];
    try {
      final rows = await c
          .from('predictions')
          .select('match_no, home, away')
          .eq('user_id', uid);
      return [
        for (final r in rows as List)
          (
            matchNo: (r['match_no'] as num).toInt(),
            home: (r['home'] as num).toInt(),
            away: (r['away'] as num).toInt(),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> fetchNickname() async {
    final c = _client;
    final uid = userId;
    if (c == null || uid == null) return null;
    try {
      final row = await c
          .from('profiles')
          .select('nickname')
          .eq('id', uid)
          .maybeSingle();
      return row?['nickname'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setNickname(String nickname, {String? country}) async {
    final c = _client;
    final uid = userId;
    if (c == null || uid == null) return false;
    try {
      await c.from('profiles').upsert({
        'id': uid,
        'nickname': nickname,
        if (country != null) 'country': country,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> upsertPrediction(int matchNo, int home, int away) async {
    final c = _client;
    final uid = userId;
    if (c == null || uid == null) return;
    try {
      await c.from('predictions').upsert({
        'user_id': uid,
        'match_no': matchNo,
        'home': home,
        'away': away,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> deletePrediction(int matchNo) async {
    final c = _client;
    final uid = userId;
    if (c == null || uid == null) return;
    try {
      await c
          .from('predictions')
          .delete()
          .eq('user_id', uid)
          .eq('match_no', matchNo);
    } catch (_) {}
  }

  static Future<List<LeaderEntry>> fetchLeaderboard() async {
    final c = _client;
    if (c == null) return const [];
    try {
      final rows = await c
          .from('leaderboard')
          .select('user_id, nickname, points, exact_count')
          .order('points', ascending: false)
          .order('exact_count', ascending: false)
          .order('nickname', ascending: true)
          .limit(100);
      return sortLeaderboardForDisplay([
        for (final r in rows as List)
          LeaderEntry(
            userId: '${r['user_id'] ?? ''}',
            nickname: '${r['nickname'] ?? '—'}',
            points: (r['points'] as num?)?.toInt() ?? 0,
            exactCount: (r['exact_count'] as num?)?.toInt() ?? 0,
          ),
      ]);
    } catch (_) {
      return const [];
    }
  }

  /// Predicciones de un participante para partidos ya bloqueados (transparencia).
  /// Lee la vista `locked_predictions` (solo expone kickoff <= ahora).
  static Future<List<ParticipantPick>> fetchUserPredictions(
    String userId,
  ) async {
    final c = _client;
    if (c == null || userId.isEmpty) return const [];
    try {
      final rows = await c
          .from('locked_predictions')
          .select(
            'match_no, home, away, result_home, result_away, finished, points',
          )
          .eq('user_id', userId)
          .order('match_no', ascending: false);
      return [
        for (final r in rows as List)
          ParticipantPick(
            matchNo: (r['match_no'] as num).toInt(),
            home: (r['home'] as num?)?.toInt() ?? 0,
            away: (r['away'] as num?)?.toInt() ?? 0,
            resultHome: (r['result_home'] as num?)?.toInt(),
            resultAway: (r['result_away'] as num?)?.toInt(),
            finished: r['finished'] == true,
            points: (r['points'] as num?)?.toInt() ?? 0,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static List<LeaderEntry> sortLeaderboardForDisplay(
    Iterable<LeaderEntry> entries,
  ) {
    final sorted = entries.toList()
      ..sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) return points;
        final exacts = b.exactCount.compareTo(a.exactCount);
        if (exacts != 0) return exacts;
        final nickname = a.nickname.toLowerCase().compareTo(
          b.nickname.toLowerCase(),
        );
        if (nickname != 0) return nickname;
        return a.userId.compareTo(b.userId);
      });
    return sorted;
  }
}
