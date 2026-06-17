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

  /// Asegura una sesión anónima.
  static Future<void> signInAnonymously() async {
    final c = _client;
    if (c == null) return;
    try {
      if (c.auth.currentUser == null) await c.auth.signInAnonymously();
    } catch (_) {}
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
          .limit(100);
      return [
        for (final r in rows as List)
          LeaderEntry(
            userId: '${r['user_id'] ?? ''}',
            nickname: '${r['nickname'] ?? '—'}',
            points: (r['points'] as num?)?.toInt() ?? 0,
            exactCount: (r['exact_count'] as num?)?.toInt() ?? 0,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}
