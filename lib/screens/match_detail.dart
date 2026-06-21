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
import 'player_detail.dart';
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
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${l!.homeScore} – ${l.awayScore}',
                                    textAlign: TextAlign.center,
                                    style: outfit(36, FontWeight.w900),
                                  ),
                                  if (l.hasPens)
                                    Text(
                                      l.penText(l10n.penaltyMark),
                                      textAlign: TextAlign.center,
                                      style: outfit(12.5, FontWeight.w800,
                                          color: Wc.goldHi),
                                    ),
                                ],
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

            // ------------------------------------------------- alineaciones
            if (state.matchStats[m.espnId] case final ms?
                when ms.lineups.any((lu) => lu.hasStarters)) ...[
              SectionTitle(l10n.lineupsTitle),
              _LineupsCard(stats: ms, home: home, away: away),
            ],

            // -------------------------------------------------- dónde verlo
            if (state.channelsFor(m) case final channels
                when channels.isNotEmpty) ...[
              SectionTitle(
                l10n.whereToWatch,
                trailing: Pill(
                  state.countryName(state.country),
                  color: Wc.mint,
                  icon: Icons.public,
                ),
              ),
              GradientCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final c in channels) _ChannelChip(name: c)],
                ),
              ),
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
            if (home != null && away != null) ...[
              SectionTitle(l10n.yourPrediction),
              state.canEditPickem(m)
                  ? _PredEditorCard(match: m, home: home, away: away)
                  : _LockedPredictionCard(match: m, home: home, away: away),
              if (pred != null && finished && l?.homeScore != null) ...[
                const SizedBox(height: 8),
                _predResult(pred, l!, l10n),
              ],
            ] else if (m.isKnockout && pred != null) ...[
              SectionTitle(l10n.yourPrediction),
              GradientCard(
                child: Builder(
                  builder: (context) {
                    return Text(
                      '${home == null ? l10n.slotLabel(m.homeSlot) : l10n.teamName(home)} ${pred.home} – ${pred.away} ${away == null ? l10n.slotLabel(m.awaySlot) : l10n.teamName(away)}'
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

/// Pronóstico cerrado: muestra marcador real si existe, pick guardado y estado.
class _LockedPredictionCard extends StatelessWidget {
  final WcMatch match;
  final Team home;
  final Team away;

  const _LockedPredictionCard({
    required this.match,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final live = state.liveFor(match);
    final pred = state.preds[match.no];
    final counts = state.pickemCounts(match);
    final real = state.realPredFor(match);
    final pts = state.pickemPoints(match);
    final realScore = live?.homeScore != null && live?.awayScore != null
        ? '${live!.homeScore} – ${live.awayScore}'
        : 'VS';
    final (chipText, chipColor) = !counts
        ? (l.pickemNoScore, Wc.textDim)
        : live?.isLive == true
        ? (l.live, Wc.live)
        : real != null
        ? ('+$pts', pts == 6 ? Wc.mint : (pts == 3 ? Wc.goldHi : Wc.textDim))
        : (l.pickemClosed, Wc.textDim);

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
              SizedBox(
                width: 110,
                child: Column(
                  children: [
                    Text(realScore, style: outfit(24, FontWeight.w900)),
                    const SizedBox(height: 4),
                    FittedBox(child: Pill(chipText, color: chipColor)),
                  ],
                ),
              ),
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
          const SizedBox(height: 8),
          Text(
            pred == null
                ? '${l.pickemYourPick} –'
                : '${l.pickemYourPick} ${pred.home}-${pred.away}',
            style: outfit(12, FontWeight.w600, color: Wc.textDim),
          ),
        ],
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

  const _MatchEventsCard({
    required this.stats,
    required this.home,
    required this.away,
  });

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

    // El nombre (Flexible) se recorta si es largo; el minuto es fijo y SIEMPRE
    // queda visible (antes iba en el mismo texto y se cortaba).
    final nameWidget = Flexible(
      child: Text(
        name,
        textAlign: isHome ? TextAlign.start : TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: outfit(14.5, FontWeight.w800, color: Wc.text),
      ),
    );
    final minuteWidget = Text(
      minute,
      style: outfit(12.5, FontWeight.w800, color: Wc.goldHi),
    );

    final content = Row(
      mainAxisAlignment: isHome
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: isHome
          ? [
              marker,
              const SizedBox(width: 9),
              nameWidget,
              if (minute.isNotEmpty) ...[
                const SizedBox(width: 8),
                minuteWidget,
              ],
            ]
          : [
              if (minute.isNotEmpty) ...[
                minuteWidget,
                const SizedBox(width: 8),
              ],
              nameWidget,
              const SizedBox(width: 9),
              marker,
            ],
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

/// Sección de alineaciones: cancha con los 11, suplentes y stats del partido.
class _LineupsCard extends StatelessWidget {
  final MatchStats stats;
  final Team? home;
  final Team? away;

  const _LineupsCard({required this.stats, required this.home, required this.away});

  Lineup? _lineupFor(Team? t, int fallbackIndex) {
    if (t != null) {
      for (final lu in stats.lineups) {
        if (lu.teamEspn == t.espn) return lu;
      }
    }
    return stats.lineups.length > fallbackIndex
        ? stats.lineups[fallbackIndex]
        : null;
  }

  TeamLine? _teamLineFor(Team? t, int fallbackIndex) {
    if (t != null) {
      for (final tl in stats.teamLines) {
        if (tl.teamEspn == t.espn) return tl;
      }
    }
    return stats.teamLines.length > fallbackIndex
        ? stats.teamLines[fallbackIndex]
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppScope.of(context).l10n;
    final homeLu = _lineupFor(home, 0);
    final awayLu = _lineupFor(away, 1);
    final homeTL = _teamLineFor(home, 0);
    final awayTL = _teamLineFor(away, 1);

    return GradientCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Formaciones.
          Row(
            children: [
              Expanded(
                child: _formationLabel(l, home, homeLu, alignEnd: false),
              ),
              Icon(Icons.stadium, size: 16, color: Wc.textDim),
              Expanded(
                child: _formationLabel(l, away, awayLu, alignEnd: true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PitchView(
            homeLineup: homeLu,
            awayLineup: awayLu,
            homeTeam: home,
            awayTeam: away,
          ),
          if (homeLu != null || awayLu != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _SubsList(team: home, lineup: homeLu, end: false)),
                const SizedBox(width: 8),
                Expanded(child: _SubsList(team: away, lineup: awayLu, end: true)),
              ],
            ),
          ],
          if (homeTL != null && awayTL != null && _hasStats(homeTL, awayTL)) ...[
            const Divider(height: 22),
            _TeamStatsCard(home: homeTL, away: awayTL),
          ],
        ],
      ),
    );
  }

  bool _hasStats(TeamLine a, TeamLine b) =>
      a.possessionPct > 0 ||
      b.possessionPct > 0 ||
      a.shots + b.shots + a.corners + b.corners + a.fouls + b.fouls > 0;

  Widget _formationLabel(AppStrings l, Team? t, Lineup? lu, {required bool alignEnd}) {
    final name = t != null ? l.teamName(t) : '';
    final formation = lu?.formation ?? '';
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: outfit(13, FontWeight.w800),
        ),
        if (formation.isNotEmpty)
          Text(formation, style: outfit(11.5, FontWeight.w700, color: Wc.goldHi)),
      ],
    );
  }
}

/// La cancha con los 11 de cada equipo (local abajo, visitante arriba).
class _PitchView extends StatelessWidget {
  final Lineup? homeLineup;
  final Lineup? awayLineup;
  final Team? homeTeam;
  final Team? awayTeam;

  const _PitchView({
    required this.homeLineup,
    required this.awayLineup,
    required this.homeTeam,
    required this.awayTeam,
  });

  /// Agrupa a los titulares en líneas según la formación (arquero primero).
  /// Si la formación no se puede parsear, cae a agrupar por posición.
  List<List<LineupPlayer>> _lines(Lineup lu) {
    final starters = lu.starters;
    final gk = starters.where((p) => p.goalkeeper).toList();
    final rest = starters.where((p) => !p.goalkeeper).toList()
      ..sort((a, b) => (a.place ?? 99).compareTo(b.place ?? 99));
    final nums = RegExp(r'\d+')
        .allMatches(lu.formation)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    if (gk.length == 1 &&
        nums.isNotEmpty &&
        nums.fold(0, (a, b) => a + b) == rest.length) {
      final lines = <List<LineupPlayer>>[gk];
      var i = 0;
      for (final n in nums) {
        lines.add(rest.sublist(i, i + n));
        i += n;
      }
      return lines;
    }
    // Respaldo: por posición (G/D/M/F).
    final byPos = <String, List<LineupPlayer>>{'G': [], 'D': [], 'M': [], 'F': []};
    for (final p in starters) {
      (byPos[p.pos] ?? byPos['M']!).add(p);
    }
    return [
      for (final k in const ['G', 'D', 'M', 'F'])
        if (byPos[k]!.isNotEmpty) byPos[k]!,
    ];
  }

  List<Widget> _dots(BuildContext context, Lineup? lu, Team? team, bool home) {
    if (lu == null) return const [];
    final lines = _lines(lu);
    final k = lines.length;
    final span = k <= 1 ? 1 : k - 1;
    final color = home ? Wc.gold : Wc.mint;
    final out = <Widget>[];
    for (var li = 0; li < k; li++) {
      final pls = lines[li];
      // local: arquero abajo (0.965) → delanteros cerca del centro (0.55).
      // visitante: espejado en la mitad de arriba.
      final fy = home
          ? 0.965 - li * (0.965 - 0.55) / span
          : 0.035 + li * (0.45 - 0.035) / span;
      for (var i = 0; i < pls.length; i++) {
        final fx = (i + 1) / (pls.length + 1);
        out.add(
          Align(
            alignment: Alignment(fx * 2 - 1, fy * 2 - 1),
            child: _PlayerDot(player: pls[i], team: team, color: color),
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 0.68,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _PitchPainter()),
            ..._dots(context, homeLineup, homeTeam, true),
            ..._dots(context, awayLineup, awayTeam, false),
          ],
        ),
      ),
    );
  }
}

/// Dibuja el campo de juego (césped + líneas).
class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B6B3A), Color(0xFF15823F)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), grass);

    // Franjas de césped.
    final stripe = Paint()..color = Colors.white.withValues(alpha: .04);
    const n = 8;
    for (var i = 0; i < n; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, h * i / n, w, h / n), stripe);
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: .55)
      ..strokeWidth = 1.5;
    final pad = w * 0.04;
    final field = Rect.fromLTWH(pad, pad, w - pad * 2, h - pad * 2);
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(6)), line);
    canvas.drawLine(Offset(pad, h / 2), Offset(w - pad, h / 2), line);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.13, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 2, line..style = PaintingStyle.fill);
    line.style = PaintingStyle.stroke;

    // Áreas (arriba y abajo).
    final boxW = w * 0.46, boxH = h * 0.13;
    canvas.drawRect(
      Rect.fromLTWH((w - boxW) / 2, pad, boxW, boxH),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH((w - boxW) / 2, h - pad - boxH, boxW, boxH),
      line,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Un jugador en la cancha: dorsal + apellido, abre su carta al tocar.
class _PlayerDot extends StatelessWidget {
  final LineupPlayer player;
  final Team? team;
  final Color color;

  const _PlayerDot({required this.player, required this.team, required this.color});

  String get _last {
    final parts = player.player.name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openPlayerProfile(
        context,
        state,
        name: player.player.name,
        teamId: team?.id ?? '',
        espnId: player.player.id,
      ),
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .8), width: 1.5),
              ),
              child: Text(
                player.number > 0 ? '${player.number}' : '',
                style: outfit(12.5, FontWeight.w900, color: const Color(0xFF14201A)),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                player.subbedOut ? '$_last ↓' : _last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: outfit(9.5, FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de suplentes de un equipo (marca con ↑ a los que entraron).
class _SubsList extends StatelessWidget {
  final Team? team;
  final Lineup? lineup;
  final bool end;

  const _SubsList({required this.team, required this.lineup, required this.end});

  String _min(LineupPlayer p) => p.subMinute != null ? "${p.subMinute}'" : '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final bench = lineup?.bench ?? const [];
    final cross = end ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(
          l.substitutesLabel,
          style: outfit(10.5, FontWeight.w800, color: Wc.textDim, spacing: .5),
        ),
        const SizedBox(height: 4),
        if (bench.isEmpty)
          Text('—', style: outfit(12, FontWeight.w600, color: Wc.textDim))
        else
          for (final p in bench)
            InkWell(
              onTap: () => openPlayerProfile(
                context,
                state,
                name: p.player.name,
                teamId: team?.id ?? '',
                espnId: p.player.id,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  p.subbedIn
                      ? (end
                          ? '${p.player.name} ↑${_min(p)}'
                          : '↑${_min(p)} ${p.player.name}')
                      : p.player.name,
                  textAlign: end ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: outfit(
                    11.5,
                    p.subbedIn ? FontWeight.w800 : FontWeight.w500,
                    color: p.subbedIn ? Wc.mint : Wc.textSoft,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Comparativa de estadísticas por equipo (posesión, tiros, córners, faltas).
class _TeamStatsCard extends StatelessWidget {
  final TeamLine home;
  final TeamLine away;

  const _TeamStatsCard({required this.home, required this.away});

  @override
  Widget build(BuildContext context) {
    final l = AppScope.of(context).l10n;
    return Column(
      children: [
        Text(
          l.matchStatsTitle,
          style: outfit(11, FontWeight.w800, color: Wc.textDim, spacing: .5),
        ),
        const SizedBox(height: 8),
        if (home.possessionPct > 0 || away.possessionPct > 0)
          _row('${home.possessionPct.round()}%', l.statPossession,
              '${away.possessionPct.round()}%', home.possessionPct, away.possessionPct),
        _row('${home.shots}', l.statShots, '${away.shots}',
            home.shots.toDouble(), away.shots.toDouble()),
        _row('${home.shotsOnTarget}', l.statShotsOnTarget, '${away.shotsOnTarget}',
            home.shotsOnTarget.toDouble(), away.shotsOnTarget.toDouble()),
        _row('${home.corners}', l.statCorners, '${away.corners}',
            home.corners.toDouble(), away.corners.toDouble()),
        _row('${home.fouls}', l.statFouls, '${away.fouls}',
            home.fouls.toDouble(), away.fouls.toDouble()),
      ],
    );
  }

  Widget _row(String hv, String label, String av, double h, double a) {
    final total = h + a;
    final hf = total <= 0 ? 0.5 : h / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(hv, style: outfit(13, FontWeight.w900)),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: outfit(11.5, FontWeight.w600, color: Wc.textDim),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  av,
                  textAlign: TextAlign.right,
                  style: outfit(13, FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: (hf * 100).round().clamp(1, 99),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: Wc.gold,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                flex: (100 - (hf * 100).round()).clamp(1, 99),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: Wc.mint,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip de un canal de transmisión.
class _ChannelChip extends StatelessWidget {
  final String name;
  const _ChannelChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Wc.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Wc.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.live_tv, size: 15, color: Wc.goldHi),
          const SizedBox(width: 6),
          Text(name, style: outfit(13, FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Editor de pronóstico para un partido con equipos reales resueltos.
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
