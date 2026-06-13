/// Pestaña Grupos: tablas reales de los 12 grupos y mejores terceros.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../main.dart';
import '../models.dart' as wc;
import '../theme.dart';
import '../widgets.dart';
import 'match_detail.dart';
import 'team_detail.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final groups = state.groupMatches.keys.toList()..sort();
    final thirds = state.realThirdsRanked();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(l.groupStage, style: outfit(22, FontWeight.w900)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GroupTableCard(group: groups[i]),
            ),
          ),
        ),
        if (thirds.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: ThirdsCard(thirds: thirds, real: true),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Tarjeta con la tabla de un grupo (real o pronosticada).
class GroupTableCard extends StatelessWidget {
  final String group;
  final bool predicted;
  final VoidCallback? onTapHeader;

  const GroupTableCard({
    super.key,
    required this.group,
    this.predicted = false,
    this.onTapHeader,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final rows = predicted ? state.predTable(group) : state.realTable(group);
    final anyPlayed = rows.any((r) => r.played > 0);

    return GradientCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      onTap: onTapHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Wc.gold, const Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  group,
                  style: outfit(
                    16,
                    FontWeight.w900,
                    color: const Color(0xFF221A00),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(l.group(group), style: outfit(16, FontWeight.w800)),
              const Spacer(),
              if (!anyPlayed)
                Text(
                  l.noMatchesPlayed,
                  style: outfit(11, FontWeight.w500, color: Wc.textDim),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _headerRow(l),
          const Divider(height: 12),
          for (var i = 0; i < rows.length; i++)
            _teamRow(context, state, i, rows[i]),
        ],
      ),
    );
  }

  Widget _headerRow(AppStrings l) {
    Widget h(String s, int flex, {bool end = false}) => Expanded(
      flex: flex,
      child: Text(
        s,
        textAlign: end ? TextAlign.center : TextAlign.start,
        style: outfit(10.5, FontWeight.w700, color: Wc.textDim),
      ),
    );
    return Row(
      children: [
        const SizedBox(width: 22),
        h(l.teamHeader, 38),
        h(l.playedHeader, 8, end: true),
        h(l.winsHeader, 8, end: true),
        h(l.drawsHeader, 8, end: true),
        h(l.lossesHeader, 8, end: true),
        h(l.goalDiffHeader, 10, end: true),
        h(l.pointsHeader, 10, end: true),
      ],
    );
  }

  Widget _teamRow(
    BuildContext context,
    AppState state,
    int pos,
    wc.TableRow r,
  ) {
    final team = state.teams[r.teamId]!;
    final qualifies = pos < 2;
    final third = pos == 2;
    Widget cell(
      String s,
      int flex, {
      FontWeight w = FontWeight.w600,
      Color? c,
    }) => Expanded(
      flex: flex,
      child: Text(
        s,
        textAlign: TextAlign.center,
        style: outfit(12.5, w, color: c ?? Wc.text),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: team.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: qualifies
                      ? Wc.mint.withValues(alpha: .18)
                      : third
                      ? Wc.gold.withValues(alpha: .15)
                      : Colors.transparent,
                  border: Border.all(
                    color: qualifies
                        ? Wc.mint
                        : third
                        ? Wc.gold.withValues(alpha: .6)
                        : Wc.line,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${pos + 1}',
                  style: outfit(
                    9.5,
                    FontWeight.w800,
                    color: qualifies
                        ? Wc.mint
                        : third
                        ? Wc.goldHi
                        : Wc.textDim,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 38,
              child: Row(
                children: [
                  FlagImg(team.flag, size: 24, radius: 5),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.l10n.teamName(team),
                      overflow: TextOverflow.ellipsis,
                      style: outfit(13, FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            cell('${r.played}', 8, c: Wc.textDim),
            cell('${r.won}', 8, c: Wc.textDim),
            cell('${r.drawn}', 8, c: Wc.textDim),
            cell('${r.lost}', 8, c: Wc.textDim),
            cell(
              r.gd > 0 ? '+${r.gd}' : '${r.gd}',
              10,
              c: r.gd > 0
                  ? Wc.mint
                  : r.gd < 0
                  ? Wc.live
                  : Wc.textDim,
            ),
            cell('${r.points}', 10, w: FontWeight.w900, c: Wc.goldHi),
          ],
        ),
      ),
    );
  }
}

/// Tabla de mejores terceros (los 8 primeros clasifican).
class ThirdsCard extends StatelessWidget {
  final List<wc.TableRow> thirds;
  final bool real;

  const ThirdsCard({super.key, required this.thirds, required this.real});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    return GradientCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech, color: Wc.gold, size: 20),
              const SizedBox(width: 8),
              Text(l.bestThirds, style: outfit(16, FontWeight.w800)),
              const Spacer(),
              Pill(
                real ? l.eightQualify : l.yourPredictionUpper,
                color: Wc.mint,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            real ? l.bestThirdsRealHelp : l.bestThirdsPredHelp,
            style: outfit(11.5, FontWeight.w500, color: Wc.textDim),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < thirds.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: outfit(
                        11,
                        FontWeight.w800,
                        color: i < 8 ? Wc.mint : Wc.textDim,
                      ),
                    ),
                  ),
                  FlagImg(
                    state.teams[thirds[i].teamId]!.flag,
                    size: 22,
                    radius: 5,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l.teamName(state.teams[thirds[i].teamId]!)}'
                      '  ·  ${l.group(state.teams[thirds[i].teamId]!.group)}',
                      style: outfit(
                        12.5,
                        FontWeight.w600,
                        color: i < 8 ? Wc.text : Wc.textDim,
                      ),
                    ),
                  ),
                  Text(
                    '${thirds[i].points} ${l.pts} · ${thirds[i].gd > 0 ? '+' : ''}${thirds[i].gd}',
                    style: outfit(
                      11.5,
                      FontWeight.w700,
                      color: i < 8 ? Wc.goldHi : Wc.textDim,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Lista compacta de los partidos de un grupo (para detalle).
class GroupMatchesList extends StatelessWidget {
  final String group;
  const GroupMatchesList({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final ms = state.groupMatches[group]!;
    return Column(
      children: [
        for (final m in ms)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MatchDetailScreen(matchNo: m.no),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.teamName(state.teams[m.homeSlot]!),
                      textAlign: TextAlign.end,
                      style: outfit(12.5, FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _score(state, m),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.teamName(state.teams[m.awaySlot]!),
                      style: outfit(12.5, FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _score(AppState state, wc.WcMatch m) {
    final l = state.liveFor(m);
    final has = l?.homeScore != null && (l!.isFinished || l.isLive);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Wc.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Wc.line),
      ),
      child: Text(
        has ? '${l.homeScore} - ${l.awayScore}' : fmtTime(m.dateUtc),
        style: outfit(12, FontWeight.w800, color: has ? Wc.text : Wc.textDim),
      ),
    );
  }
}
