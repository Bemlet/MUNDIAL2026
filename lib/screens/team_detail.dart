/// Detalle de una selección: ficha, figuras y sus partidos.
library;

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'matches_screen.dart' show RealMatchCard;
import 'player_detail.dart';

class TeamDetailScreen extends StatelessWidget {
  final String teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final t = state.teams[teamId]!;
    final matches = state.matchesOfTeam(teamId);
    final table = state.realTable(t.group);
    final pos = table.indexWhere((r) => r.teamId == teamId) + 1;

    return Scaffold(
      body: SafeArea(
        top: false, // el encabezado se extiende tras la barra de estado
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: Wc.heroGradient),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28),
                        Hero(
                          tag: 'flag-${t.id}',
                          child: FlagImg(t.flag, size: 96, radius: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(l.teamName(t), style: outfit(26, FontWeight.w900)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Pill(
                              l.group(t.group).toUpperCase(),
                              color: Wc.goldHi,
                            ),
                            const SizedBox(width: 6),
                            Pill(t.conf, color: Wc.mint),
                            const SizedBox(width: 6),
                            if (pos > 0)
                              Pill(
                                l.groupPosition(pos).toUpperCase(),
                                color: Wc.textDim,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(child: _stat('${t.rank}', l.fifaRanking)),
                      const SizedBox(width: 10),
                      Expanded(child: _stat('${t.apps}', l.worldCupsPlayed)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _stat(
                          t.titles > 0 ? '${t.titles}' : '—',
                          l.worldTitles,
                          gold: t.titles > 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GradientCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.bestResultUpper,
                          style: outfit(
                            10.5,
                            FontWeight.w800,
                            color: Wc.textDim,
                            spacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(l.teamBest(t), style: outfit(15, FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(
                          l.confederationUpper,
                          style: outfit(
                            10.5,
                            FontWeight.w800,
                            color: Wc.textDim,
                            spacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${t.conf} · ${l.confRegion(t.confRegion)}',
                          style: outfit(15, FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.teamNote(t),
                          style: outfit(
                            13.5,
                            FontWeight.w500,
                            color: Wc.textSoft,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionTitle(l.stars),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in t.stars)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => openPlayerProfile(
                              context,
                              state,
                              name: p,
                              teamId: t.id,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Wc.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Wc.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 14, color: Wc.gold),
                                  const SizedBox(width: 6),
                                  Text(p, style: outfit(13, FontWeight.w700)),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Wc.textDim,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SectionTitle(l.teamMatches),
                  for (final m in matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RealMatchCard(match: m, dense: true),
                    ),
                  if (matches.where((m) => m.stage != Stage.group).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l.knockoutIfAdvance,
                        style: outfit(12, FontWeight.w500, color: Wc.textDim),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, {bool gold = false}) {
    return GradientCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: outfit(22, FontWeight.w900, color: gold ? Wc.gold : Wc.text),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: outfit(10.5, FontWeight.w600, color: Wc.textDim),
          ),
        ],
      ),
    );
  }
}
