import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Presencia en vivo: quiénes tienen la app abierta ahora, vía Supabase
/// Realtime Presence. Efímero (sin tablas): el canal mantiene el estado.
/// Defensivo: cualquier fallo se traga y deja el conteo en 0 (no rompe la UI).
class PresenceService {
  static RealtimeChannel? _channel;
  static final Map<String, String> _online = {}; // userId -> nickname

  static void Function()? _onChange;

  static int get count => _online.length;
  static List<String> get nicknames =>
      _online.values.where((n) => n.isNotEmpty).toList();

  static void setOnChange(void Function() cb) => _onChange = cb;

  /// Se une al canal y publica su presencia (user_id + nickname).
  static Future<void> join({
    required String userId,
    required String nickname,
  }) async {
    final client = SupabaseService.client;
    if (client == null || userId.isEmpty) return;
    await leave();
    try {
      final ch = client.channel('online');
      ch
          .onPresenceSync((_) => _refresh(ch))
          .onPresenceJoin((_) => _refresh(ch))
          .onPresenceLeave((_) => _refresh(ch))
          .subscribe((status, _) async {
            if (status == RealtimeSubscribeStatus.subscribed) {
              try {
                await ch.track({'user_id': userId, 'nickname': nickname});
              } catch (_) {}
            }
          });
      _channel = ch;
    } catch (_) {}
  }

  static void _refresh(RealtimeChannel ch) {
    try {
      _online.clear();
      for (final state in ch.presenceState()) {
        for (final presence in state.presences) {
          final p = presence.payload;
          final uid = '${p['user_id'] ?? ''}';
          if (uid.isEmpty) continue;
          _online[uid] = '${p['nickname'] ?? ''}';
        }
      }
    } catch (_) {}
    _onChange?.call();
  }

  /// Deja el canal y limpia el estado.
  static Future<void> leave() async {
    final ch = _channel;
    _channel = null;
    _online.clear();
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {}
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
    _onChange?.call();
  }
}
