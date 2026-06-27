/// Pestaña Bracket: cuadro de eliminatorias real (16avos a final) con líneas
/// de conexión entre rondas. Al abrir, hace scroll al partido en vivo (o al
/// próximo).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'match_detail.dart';

class BracketScreen extends StatelessWidget {
  const BracketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.knockoutStage, style: outfit(22, FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Pill(l.realResultsUpper, color: Wc.mint)),
          ),
        ],
      ),
      body: BracketView(
        teamsOf: state.realTeams,
        scoreOf: (m) {
          final l = state.liveFor(m);
          if (l?.homeScore == null || !(l!.isFinished || l.isLive)) {
            return null;
          }
          return (l.homeScore!, l.awayScore!, l.isLive);
        },
        onTap: (m) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MatchDetailScreen(matchNo: m.no)),
        ),
      ),
    );
  }
}

/// Vista de bracket reutilizable (real o pronosticada). Dibuja las rondas como
/// un árbol: cada partido se ubica centrado entre sus dos alimentadores, con
/// líneas (codos) que los conectan. Al montarse hace scroll al partido en vivo
/// (o al próximo).
class BracketView extends StatefulWidget {
  final (Team?, Team?) Function(WcMatch) teamsOf;
  final (int, int, bool)? Function(WcMatch) scoreOf; // (h, a, enVivo)
  final void Function(WcMatch) onTap;

  /// Ganador para resaltar (pronóstico); si es null se usa el marcador.
  final Team? Function(WcMatch)? winnerOf;

  const BracketView({
    super.key,
    required this.teamsOf,
    required this.scoreOf,
    required this.onTap,
    this.winnerOf,
  });

  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView> {
  // Dimensiones del cuadro.
  static const double _cardW = 232;
  static const double _cardH = 112;
  static const double _vGap = 16;
  static const double _hGap = 56;
  static const double _titleH = 30;
  static const double _rowUnit = _cardH + _vGap;

  final _hCtrl = ScrollController();
  final _vCtrl = ScrollController();
  bool _scrolled = false;

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  int? _feeder(String slot) {
    final m = RegExp(r'^M(\d+)$').firstMatch(slot);
    return m == null ? null : int.parse(m.group(1)!);
  }

  int _roundOf(Stage s) => switch (s) {
    Stage.r32 => 0,
    Stage.r16 => 1,
    Stage.qf => 2,
    Stage.sf => 3,
    _ => 4, // final y tercer puesto
  };

  /// Partido a enfocar al abrir: el que está en vivo; si no, el próximo a
  /// jugarse; si no (torneo terminado), la final.
  WcMatch? _focusMatch(AppState state) {
    final ko = state.matches.where((m) => m.isKnockout).toList();
    if (ko.isEmpty) return null;
    for (final m in ko) {
      if (state.liveFor(m)?.isLive == true) return m;
    }
    final now = DateTime.now().toUtc();
    final upcoming = ko.where((m) => m.dateUtc.isAfter(now)).toList()
      ..sort((a, b) => a.dateUtc.compareTo(b.dateUtc));
    if (upcoming.isNotEmpty) return upcoming.first;
    return ko.last;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final byNo = state.byNo;

    final finalM = state.matches.firstWhere((m) => m.stage == Stage.finalMatch);

    // Orden vertical de los 16avos: DFS desde la final siguiendo los slots
    // (homeSlot/awaySlot tipo "M73"), así cada subárbol queda contiguo y las
    // líneas no se cruzan.
    final leafOrder = <int>[];
    void dfs(WcMatch m) {
      final hf = _feeder(m.homeSlot);
      final af = _feeder(m.awaySlot);
      if (hf == null && af == null) {
        leafOrder.add(m.no);
        return;
      }
      if (hf != null && byNo[hf] != null) dfs(byNo[hf]!);
      if (af != null && byNo[af] != null) dfs(byNo[af]!);
    }

    dfs(finalM);

    // Posición vertical: hojas (16avos) por su orden; internos = promedio de
    // sus alimentadores.
    final yOf = <int, double>{};
    for (var i = 0; i < leafOrder.length; i++) {
      yOf[leafOrder[i]] = i * _rowUnit;
    }
    double computeY(WcMatch m) {
      final cached = yOf[m.no];
      if (cached != null) return cached;
      final ys = <double>[];
      for (final fn in [_feeder(m.homeSlot), _feeder(m.awaySlot)]) {
        if (fn != null && byNo[fn] != null) ys.add(computeY(byNo[fn]!));
      }
      final v = ys.isEmpty ? 0.0 : ys.reduce((a, b) => a + b) / ys.length;
      yOf[m.no] = v;
      return v;
    }

    final champ = state.matches
        .where((m) => m.isKnockout && m.stage != Stage.third)
        .toList();
    for (final m in champ) {
      computeY(m);
    }

    // 3er puesto: debajo de todo, en la columna de la final.
    final thirdM = state.matches.firstWhere((m) => m.stage == Stage.third);
    final maxY = yOf.values.fold(0.0, (a, b) => b > a ? b : a);
    yOf[thirdM.no] = maxY + _rowUnit;

    Offset posOf(WcMatch m) =>
        Offset(_roundOf(m.stage) * (_cardW + _hGap), _titleH + (yOf[m.no] ?? 0));

    // Conectores (codos) alimentador -> partido siguiente.
    final connectors = <(Offset, Offset)>[];
    for (final m in champ) {
      for (final fn in [_feeder(m.homeSlot), _feeder(m.awaySlot)]) {
        if (fn == null || byNo[fn] == null) continue;
        final fp = posOf(byNo[fn]!);
        final tp = posOf(m);
        connectors.add((
          Offset(fp.dx + _cardW, fp.dy + _cardH / 2),
          Offset(tp.dx, tp.dy + _cardH / 2),
        ));
      }
    }

    final totalW = 5 * _cardW + 4 * _hGap;
    final totalH = _titleH + (yOf[thirdM.no] ?? 0) + _cardH + 16;

    // Scroll automático (una vez) al partido en vivo / próximo.
    if (!_scrolled) {
      final focus = _focusMatch(state);
      if (focus != null) {
        _scrolled = true;
        final fp = posOf(focus);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_hCtrl.hasClients || !_vCtrl.hasClients) return;
          final hx = (fp.dx - (_hCtrl.position.viewportDimension - _cardW) / 2)
              .clamp(0.0, _hCtrl.position.maxScrollExtent);
          final vy =
              (fp.dy + _cardH / 2 - _vCtrl.position.viewportDimension / 2)
                  .clamp(0.0, _vCtrl.position.maxScrollExtent);
          _hCtrl.animateTo(
            hx,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
          _vCtrl.animateTo(
            vy,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }

    final titles = <String>[
      state.l10n.roundOf32,
      state.l10n.roundOf16,
      state.l10n.quarterfinals,
      state.l10n.semifinals,
      state.l10n.finalLabel,
    ];

    return SingleChildScrollView(
      controller: _hCtrl,
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        controller: _vCtrl,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        child: SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _BracketPainter(connectors)),
              ),
              for (var r = 0; r < titles.length; r++)
                Positioned(
                  left: r * (_cardW + _hGap),
                  top: 0,
                  width: _cardW,
                  child: Center(
                    child: Text(
                      titles[r].toUpperCase(),
                      style: outfit(
                        13,
                        FontWeight.w900,
                        color: Wc.goldHi,
                        spacing: 1.5,
                      ),
                    ),
                  ),
                ),
              for (final m in state.matches.where((m) => m.isKnockout))
                Positioned(
                  left: posOf(m).dx,
                  top: posOf(m).dy,
                  width: _cardW,
                  height: _cardH,
                  child: KoMatchCard(
                    match: m,
                    teams: widget.teamsOf(m),
                    score: widget.scoreOf(m),
                    winner: widget.winnerOf?.call(m),
                    onTap: () => widget.onTap(m),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinta los codos de conexión entre rondas del bracket.
class _BracketPainter extends CustomPainter {
  final List<(Offset, Offset)> connectors;
  const _BracketPainter(this.connectors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Wc.textDim.withValues(alpha: .5)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final (from, to) in connectors) {
      final midX = (from.dx + to.dx) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(midX, from.dy)
        ..lineTo(midX, to.dy)
        ..lineTo(to.dx, to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.connectors != connectors;
}

/// Tarjeta compacta de partido de eliminatorias.
class KoMatchCard extends StatelessWidget {
  final WcMatch match;
  final (Team?, Team?) teams;
  final (int, int, bool)? score;
  final Team? winner;
  final VoidCallback onTap;

  const KoMatchCard({
    super.key,
    required this.match,
    required this.teams,
    required this.score,
    required this.onTap,
    this.winner,
  });

  @override
  Widget build(BuildContext context) {
    final (home, away) = teams;
    final l = AppScope.of(context).l10n;
    final isFinal = match.stage == Stage.finalMatch;

    Team? hi = winner;
    if (hi == null && score != null && !score!.$3) {
      if (score!.$1 > score!.$2) hi = home;
      if (score!.$2 > score!.$1) hi = away;
    }

    Widget row(Team? t, String slot, int? s, bool dimOther) {
      final isWinner = hi != null && t?.id == hi.id;
      final dim = hi != null && t != null && t.id != hi.id;
      return Row(
        children: [
          if (t != null)
            Opacity(
              opacity: dim ? .45 : 1,
              child: FlagImg(t.flag, size: 26, radius: 5),
            )
          else
            const UnknownFlag(size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t == null ? l.slotLabel(slot) : l.teamName(t),
              overflow: TextOverflow.ellipsis,
              style: t != null
                  ? outfit(
                      13.5,
                      isWinner ? FontWeight.w900 : FontWeight.w600,
                      color: dim ? Wc.textDim : Wc.text,
                    )
                  : outfit(11.5, FontWeight.w600, color: Wc.textDim),
            ),
          ),
          if (isWinner)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.check_circle, size: 14, color: Wc.mint),
            ),
          if (s != null)
            Text(
              '$s',
              style: outfit(
                15,
                isWinner ? FontWeight.w900 : FontWeight.w700,
                color: dim ? Wc.textDim : Wc.text,
              ),
            ),
        ],
      );
    }

    return GradientCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderColor: isFinal ? Wc.gold.withValues(alpha: .6) : null,
      gradient: isFinal ? Wc.finalGradient : Wc.cardGradient,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (isFinal) ...[
                Icon(Icons.emoji_events, size: 13, color: Wc.gold),
                const SizedBox(width: 4),
              ],
              Text(
                match.stage == Stage.third
                    ? l.thirdPlaceUpper
                    : isFinal
                    ? l.grandFinalUpper
                    : '${l.matchShort}${match.no}',
                style: outfit(
                  10,
                  FontWeight.w800,
                  color: isFinal ? Wc.gold : Wc.textDim,
                  spacing: .8,
                ),
              ),
              const Spacer(),
              if (score?.$3 == true)
                LiveBadge(text: l.live)
              else
                Text(
                  '${fmtDayShort(match.dateUtc, l.locale)} · ${fmtTime(match.dateUtc)}',
                  style: outfit(10, FontWeight.w600, color: Wc.textDim),
                ),
            ],
          ),
          const SizedBox(height: 8),
          row(home, match.homeSlot, score?.$1, false),
          const SizedBox(height: 7),
          row(away, match.awaySlot, score?.$2, false),
        ],
      ),
    );
  }
}
