/// Pestaña Bracket: cuadro de eliminatorias real (16avos a final).
library;

import 'package:flutter/material.dart';

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

/// Vista de bracket reutilizable (real o pronosticada).
class BracketView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    List<WcMatch> of(bool Function(WcMatch) test) =>
        state.matches.where(test).toList()..sort((a, b) => a.no - b.no);
    final rounds = <(String, List<WcMatch>)>[
      (state.l10n.roundOf32, of((m) => m.stage == Stage.r32)),
      (state.l10n.roundOf16, of((m) => m.stage == Stage.r16)),
      (state.l10n.quarterfinals, of((m) => m.stage == Stage.qf)),
      (state.l10n.semifinals, of((m) => m.stage == Stage.sf)),
      (
        state.l10n.finalLabel,
        of((m) => m.stage == Stage.third || m.stage == Stage.finalMatch),
      ),
    ];

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        for (final (title, ms) in rounds)
          Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    title.toUpperCase(),
                    style: outfit(
                      13,
                      FontWeight.w900,
                      color: Wc.goldHi,
                      spacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final m in ms)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: KoMatchCard(
                            match: m,
                            teams: teamsOf(m),
                            score: scoreOf(m),
                            winner: winnerOf?.call(m),
                            onTap: () => onTap(m),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
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
