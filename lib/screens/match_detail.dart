/// Detalle de un partido: marcador o previa, sede, grupo y pronóstico.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n.dart';
import '../main.dart';
import '../models.dart';
import '../stats.dart';
import '../theme.dart';
import '../widgets.dart';
import 'groups_screen.dart' show GroupTableCard;
import 'team_detail.dart';

class MatchDetailScreen extends StatelessWidget {
  final int matchNo;
  const MatchDetailScreen({super.key, required this.matchNo});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = state.l10n;
    final m = state.byNo[matchNo]!;
    final l = state.liveFor(m);
    final (home, away) = state.realTeams(m);
    final venue = state.venues[m.venue];
    final isLive = l?.isLive == true;
    final finished = l?.isFinished == true;
    final pred = state.preds[m.no];

    final dateStr = toBeginningOfSentenceCase(
      DateFormat(
        l10n.isEn ? 'EEEE, MMMM d, y' : "EEEE d 'de' MMMM 'de' y",
        l10n.locale,
      ).format(localMatchTime(m.dateUtc)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          m.stage == Stage.group
              ? l10n.group(m.group!)
              : l10n.stageLabel(m.stage),
          style: outfit(18, FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            // ------------------------------------------------ marcador / previa
            GradientCard(
              gradient: Wc.heroGradient,
              borderColor: isLive ? Wc.live.withValues(alpha: .5) : null,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Pill('${l10n.match} ${m.no}', color: Wc.textDim),
                      const Spacer(),
                      if (isLive)
                        LiveBadge(
                          text: l!.detail.isEmpty ? l10n.live : l.detail,
                        )
                      else if (finished)
                        Pill(l10n.finished, color: Wc.mint)
                      else
                        Pill(
                          fmtTime(m.dateUtc),
                          color: Wc.goldHi,
                          icon: Icons.schedule,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _bigTeam(context, home, m.homeSlot)),
                      SizedBox(
                        width: 110,
                        child: (isLive || finished) && l?.homeScore != null
                            ? Text(
                                '${l!.homeScore} – ${l.awayScore}',
                                textAlign: TextAlign.center,
                                style: outfit(36, FontWeight.w900),
                              )
                            : Text(
                                'VS',
                                textAlign: TextAlign.center,
                                style: outfit(
                                  22,
                                  FontWeight.w900,
                                  color: Wc.textDim,
                                ),
                              ),
                      ),
                      Expanded(child: _bigTeam(context, away, m.awaySlot)),
                    ],
                  ),
                  if (finished && l != null && l.detail.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      l.detail,
                      style: outfit(11.5, FontWeight.w600, color: Wc.textDim),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ------------------------------------------- goles y tarjetas
            if (state.matchStats[m.espnId] case final ms?
                when ms.goals.isNotEmpty || ms.cards.isNotEmpty) ...[
              SectionTitle(l10n.goalsAndCards),
              _MatchEventsCard(stats: ms, home: home, away: away),
            ],

            // --------------------------------------------------------- ficha
            GradientCard(
              child: Column(
                children: [
                  _infoRow(
                    Icons.calendar_today,
                    dateStr,
                    '${fmtTime(m.dateUtc)} · ${fmtLocalTimeZone(m.dateUtc)} · ${l10n.localPhoneTime}',
                  ),
                  const Divider(height: 18),
                  _infoRow(
                    Icons.stadium,
                    m.venue,
                    venue == null
                        ? ''
                        : '${l10n.venueCity(venue.city)}, ${l10n.venueCountry(venue.country)}',
                  ),
                  if (venue != null) ...[
                    const Divider(height: 18),
                    _infoRow(
                      Icons.reduce_capacity,
                      l10n.spectators(
                        NumberFormat(
                          '#,###',
                          l10n.locale,
                        ).format(venue.capacity),
                      ),
                      l10n.stadiumCapacity,
                    ),
                  ],
                ],
              ),
            ),

            // ------------------------------------------------- tu pronóstico
            if (m.stage == Stage.group && home != null && away != null) ...[
              SectionTitle(l10n.yourPrediction),
              _PredEditorCard(match: m, home: home, away: away),
              if (pred != null && finished && l?.homeScore != null) ...[
                const SizedBox(height: 8),
                _predResult(pred, l!, l10n),
              ],
            ] else if (m.isKnockout && pred != null) ...[
              SectionTitle(l10n.yourPrediction),
              GradientCard(
                child: Builder(
                  builder: (context) {
                    final (ph, pa) = state.predTeams(m);
                    return Text(
                      '${ph == null ? l10n.slotLabel(m.homeSlot) : l10n.teamName(ph)} ${pred.home} – ${pred.away} ${pa == null ? l10n.slotLabel(m.awaySlot) : l10n.teamName(pa)}'
                      '${pred.penWinner != null ? '  ·  ${l10n.teamName(state.teams[pred.penWinner]!)} ${l10n.byPenalties}' : ''}',
                      textAlign: TextAlign.center,
                      style: outfit(15, FontWeight.w800),
                    );
                  },
                ),
              ),
            ],

            // -------------------------------------------- contexto del grupo
            if (m.stage == Stage.group) ...[
              SectionTitle(l10n.groupStandings),
              GroupTableCard(group: m.group!),
            ],

            // ----------------------------------------------- cara a cara
            if (home != null && away != null && !finished && !isLive) ...[
              SectionTitle(l10n.previewHeadToHead),
              GradientCard(
                child: Column(
                  children: [
                    _compareRow(
                      'Ranking FIFA',
                      l10n.rankingPosition(home.rank),
                      l10n.rankingPosition(away.rank),
                      home.rank < away.rank,
                    ),
                    const Divider(height: 16),
                    _compareRow(
                      l10n.worldCups,
                      '${home.apps}',
                      '${away.apps}',
                      home.apps > away.apps,
                    ),
                    const Divider(height: 16),
                    _compareRow(
                      l10n.titles,
                      '${home.titles}',
                      '${away.titles}',
                      home.titles > away.titles,
                    ),
                  ],
                ),
              ),
            ],

            if (m.isKnockout) ...[
              SectionTitle(l10n.howThisTieIsDecided),
              GradientCard(
                child: Text(
                  '${l10n.slotLabel(m.homeSlot)}  vs  ${l10n.slotLabel(m.awaySlot)}',
                  textAlign: TextAlign.center,
                  style: outfit(14, FontWeight.w700, color: Wc.goldHi),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bigTeam(BuildContext context, Team? t, String slot) {
    final strings = AppScope.of(context).l10n;
    if (t == null) {
      return Column(
        children: [
          const UnknownFlag(size: 56),
          const SizedBox(height: 8),
          Text(
            strings.slotLabel(slot),
            textAlign: TextAlign.center,
            style: outfit(12, FontWeight.w600, color: Wc.textDim),
          ),
        ],
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: t.id))),
      child: Column(
        children: [
          Hero(
            tag: 'flag-${t.id}',
            child: FlagImg(t.flag, size: 56, radius: 10),
          ),
          const SizedBox(height: 8),
          Text(
            strings.teamName(t),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: outfit(15, FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Wc.gold.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: Wc.goldHi),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: outfit(14, FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                sub,
                style: outfit(11.5, FontWeight.w500, color: Wc.textDim),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compareRow(String label, String a, String b, bool homeBetter) {
    return Row(
      children: [
        Expanded(
          child: Text(
            a,
            textAlign: TextAlign.start,
            style: outfit(
              15,
              FontWeight.w800,
              color: homeBetter ? Wc.mint : Wc.text,
            ),
          ),
        ),
        Text(label, style: outfit(12, FontWeight.w600, color: Wc.textDim)),
        Expanded(
          child: Text(
            b,
            textAlign: TextAlign.end,
            style: outfit(
              15,
              FontWeight.w800,
              color: !homeBetter ? Wc.mint : Wc.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _predResult(Pred pred, LiveInfo l, AppStrings strings) {
    final exact = pred.home == l.homeScore && pred.away == l.awayScore;
    int sign(int a, int b) => a == b ? 0 : (a > b ? 1 : -1);
    final outcome =
        sign(pred.home, pred.away) == sign(l.homeScore!, l.awayScore!);
    final (text, color) = exact
        ? (strings.exactScore, Wc.mint)
        : outcome
        ? (strings.correctOutcome, Wc.goldHi)
        : (strings.wrongPrediction, Wc.textDim);
    return GradientCard(
      borderColor: color.withValues(alpha: .5),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: outfit(14, FontWeight.w800, color: color),
      ),
    );
  }
}

/// Un evento del partido (gol o tarjeta) normalizado para el timeline.
class _Ev {
  final int? minute;
  final bool isGoal;
  final bool penalty;
  final bool red;
  final String name;
  final String teamEspn;

  const _Ev({
    required this.minute,
    required this.isGoal,
    required this.name,
    required this.teamEspn,
    this.penalty = false,
    this.red = false,
  });
}

/// Tarjeta con el timeline de goles y tarjetas, alineado local/visitante.
class _MatchEventsCard extends StatelessWidget {
  final MatchStats stats;
  final Team? home;
  final Team? away;

  const _MatchEventsCard({required this.stats, required this.home, required this.away});

  @override
  Widget build(BuildContext context) {
    final l = AppScope.of(context).l10n;
    final events = <_Ev>[
      for (final g in stats.goals)
        _Ev(
          minute: g.minute,
          isGoal: true,
          penalty: g.penalty,
          name: g.scorer.name,
          teamEspn: g.scorer.teamEspn,
        ),
      for (final c in stats.cards)
        _Ev(
          minute: c.minute,
          isGoal: false,
          red: c.red,
          name: c.player.name,
          teamEspn: c.player.teamEspn,
        ),
    ]..sort((a, b) => (a.minute ?? 999).compareTo(b.minute ?? 999));

    return GradientCard(
      child: Column(
        children: [
          for (final (i, e) in events.indexed) ...[
            if (i > 0) const Divider(height: 14),
            _eventRow(l, e),
          ],
        ],
      ),
    );
  }

  Widget _eventRow(AppStrings l, _Ev e) {
    final isHome = home != null && e.teamEspn == home!.espn;
    final minute = e.minute != null ? "${e.minute}'" : '';
    final name = e.penalty ? '${e.name} (${l.penaltyMark})' : e.name;

    final marker = e.isGoal ? const _BallBadge() : _CardBadge(red: e.red);

    // Jerarquía: nombre destacado (blanco, bold) + minuto secundario (dorado).
    final nameStyle = outfit(14.5, FontWeight.w800, color: Wc.text);
    final minStyle = outfit(12.5, FontWeight.w800, color: Wc.goldHi);
    final spans = <InlineSpan>[];
    if (minute.isEmpty) {
      spans.add(TextSpan(text: name, style: nameStyle));
    } else if (isHome) {
      spans.add(TextSpan(text: '$name  ', style: nameStyle));
      spans.add(TextSpan(text: minute, style: minStyle));
    } else {
      spans.add(TextSpan(text: '$minute  ', style: minStyle));
      spans.add(TextSpan(text: name, style: nameStyle));
    }

    final text = Flexible(
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: isHome ? TextAlign.start : TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final content = Row(
      mainAxisAlignment: isHome ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: isHome
          ? [marker, const SizedBox(width: 9), text]
          : [text, const SizedBox(width: 9), marker],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: isHome ? content : const SizedBox.shrink()),
          const SizedBox(width: 12),
          Expanded(child: !isHome ? content : const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// Balón clásico blanco y negro para los goles.
class _BallBadge extends StatelessWidget {
  const _BallBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(Icons.sports_soccer, size: 16, color: Colors.black),
    );
  }
}

/// Tarjeta amarilla/roja.
class _CardBadge extends StatelessWidget {
  final bool red;
  const _CardBadge({required this.red});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 18,
      decoration: BoxDecoration(
        color: red ? Wc.live : const Color(0xFFF4C430),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// Editor de pronóstico para un partido de grupos.
class _PredEditorCard extends StatelessWidget {
  final WcMatch match;
  final Team home;
  final Team away;

  const _PredEditorCard({
    required this.match,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final pred = state.preds[match.no];

    void update(int dh, int da) {
      final p = pred ?? Pred(0, 0);
      final nh = (p.home + dh).clamp(0, 19);
      final na = (p.away + da).clamp(0, 19);
      state.setPred(match.no, Pred(nh, na));
    }

    Widget stepper(int? value, void Function(int) delta) {
      return Column(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => delta(1),
            icon: Icon(Icons.keyboard_arrow_up, color: Wc.goldHi),
          ),
          Text(
            value?.toString() ?? '–',
            style: outfit(
              26,
              FontWeight.w900,
              color: value != null ? Wc.text : Wc.textDim,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value == null ? null : () => delta(-1),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: value == null ? Wc.line : Wc.textDim,
            ),
          ),
        ],
      );
    }

    return GradientCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    FlagImg(home.flag, size: 34),
                    const SizedBox(height: 4),
                    Text(
                      l.teamName(home),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: outfit(12, FontWeight.w700),
                    ),
                  ],
                ),
              ),
              stepper(pred?.home, (d) => update(d, 0)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '–',
                  style: outfit(22, FontWeight.w800, color: Wc.textDim),
                ),
              ),
              stepper(pred?.away, (d) => update(0, d)),
              Expanded(
                child: Column(
                  children: [
                    FlagImg(away.flag, size: 34),
                    const SizedBox(height: 4),
                    Text(
                      l.teamName(away),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: outfit(12, FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pred != null)
            TextButton.icon(
              onPressed: () => state.setPred(match.no, null),
              icon: Icon(Icons.close, size: 14, color: Wc.textDim),
              label: Text(
                l.removePrediction,
                style: outfit(12, FontWeight.w600, color: Wc.textDim),
              ),
            ),
        ],
      ),
    );
  }
}
