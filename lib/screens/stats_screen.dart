/// Pestaña Estadísticas: rankings en vivo del torneo (goleadores, asistencias,
/// figuras, disciplina, equipos y totales). Los datos salen del feed de ESPN
/// agregados en `AppState.stats`.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../main.dart';
import '../stats.dart';
import '../theme.dart';
import '../widgets.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final stats = state.stats;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          _Header(state: state),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Wc.gold,
            indicatorWeight: 3,
            labelColor: Wc.goldHi,
            unselectedLabelColor: Wc.textDim,
            labelStyle: outfit(14, FontWeight.w800),
            unselectedLabelStyle: outfit(14, FontWeight.w600),
            dividerColor: Wc.line,
            tabs: [
              Tab(text: l.statsTabScorers),
              Tab(text: l.statsTabDiscipline),
              Tab(text: l.statsTabTeams),
              Tab(text: l.statsTabSummary),
            ],
          ),
          Expanded(
            child: stats.isEmpty
                ? _EmptyStats(strings: l)
                : TabBarView(
                    children: [
                      _ScorersTab(stats: stats, state: state),
                      _DisciplineTab(stats: stats, state: state),
                      _TeamsTab(stats: stats, state: state),
                      _SummaryTab(stats: stats, state: state),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Icon(Icons.leaderboard, color: Wc.gold, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.statsTitle, style: outfit(22, FontWeight.w900)),
                Text(
                  l.statsLiveNote,
                  style: outfit(11.5, FontWeight.w600, color: Wc.mint),
                ),
              ],
            ),
          ),
          if (state.syncing)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Wc.gold),
              ),
            )
          else
            IconButton(
              icon: Icon(
                state.syncFailed ? Icons.cloud_off : Icons.refresh,
                color: state.syncFailed ? Wc.live : Wc.textDim,
              ),
              onPressed: state.sync,
              tooltip: l.refreshResults,
            ),
        ],
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  final AppStrings strings;
  const _EmptyStats({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.query_stats, color: Wc.textDim, size: 44),
            const SizedBox(height: 14),
            Text(
              strings.statsEmpty,
              textAlign: TextAlign.center,
              style: outfit(15, FontWeight.w700, color: Wc.textSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- tab goleadores

class _ScorersTab extends StatelessWidget {
  final TournamentStats stats;
  final AppState state;
  const _ScorersTab({required this.stats, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    return _Refreshable(
      state: state,
      children: [
        SectionTitle(l.goldenBoot, trailing: _BootIcon()),
        if (stats.scorers.isEmpty)
          _MiniEmpty(strings: l)
        else
          for (final (i, s) in stats.scorers.take(20).indexed)
            _PlayerRow(
              rank: i + 1,
              state: state,
              player: s.player,
              highlight: i == 0,
              value: '${s.goals}',
              valueLabel: l.goalsAbbr,
              subtitle: _scorerSubtitle(l, s),
            ),
        if (stats.assists.isNotEmpty) ...[
          SectionTitle(l.topAssists),
          for (final (i, a) in stats.assists.take(10).indexed)
            _PlayerRow(
              rank: i + 1,
              state: state,
              player: a.player,
              value: '${a.assists}',
              valueLabel: l.assistsAbbr,
              subtitle: a.goals > 0 ? l.goalsCount(a.goals) : null,
            ),
        ],
        if (stats.standouts.isNotEmpty) ...[
          SectionTitle(l.standoutPlayers),
          for (final (i, p) in stats.standouts.take(8).indexed)
            _PlayerRow(
              rank: i + 1,
              state: state,
              player: p.player,
              value: p.impact.toStringAsFixed(0),
              valueLabel: '★',
              subtitle: _standoutSubtitle(l, p),
            ),
          _Note(l.standoutNote),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  String? _scorerSubtitle(AppStrings l, ScorerStat s) {
    final parts = <String>[];
    if (s.assists > 0) parts.add('${s.assists} ${l.assistsAbbr}');
    if (s.penalties > 0) parts.add('${s.penalties} ${l.penaltyMark}');
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _standoutSubtitle(AppStrings l, StandoutPlayer p) {
    final parts = <String>[];
    if (p.goals > 0) parts.add('${p.goals} ${l.goalsAbbr}');
    if (p.assists > 0) parts.add('${p.assists} ${l.assistsAbbr}');
    if (p.cleanSheets > 0) parts.add('${p.cleanSheets} ⛨');
    if (p.saves > 0) parts.add(l.savesCount(p.saves));
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

// ----------------------------------------------------------- tab disciplina

class _DisciplineTab extends StatelessWidget {
  final TournamentStats stats;
  final AppState state;
  const _DisciplineTab({required this.stats, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final fairTeams = [...stats.teams]
      ..sort((a, b) => a.disciplinePoints.compareTo(b.disciplinePoints));
    return _Refreshable(
      state: state,
      children: [
        SectionTitle(l.bookedPlayers),
        if (stats.discipline.isEmpty)
          _MiniEmpty(strings: l)
        else
          for (final (i, d) in stats.discipline.take(15).indexed)
            _PlayerRow(
              rank: i + 1,
              state: state,
              player: d.player,
              trailing: _Cards(yellow: d.yellow, red: d.red),
            ),
        if (fairTeams.any((t) => t.yellow + t.red > 0)) ...[
          SectionTitle(l.fairPlayTeams),
          for (final (i, t) in fairTeams
              .where((t) => t.played > 0)
              .take(12)
              .indexed)
            _TeamRow(
              rank: i + 1,
              state: state,
              teamEspn: t.teamEspn,
              trailing: _Cards(yellow: t.yellow, red: t.red),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// -------------------------------------------------------------- tab equipos

class _TeamsTab extends StatelessWidget {
  final TournamentStats stats;
  final AppState state;
  const _TeamsTab({required this.stats, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final played = stats.teams.where((t) => t.played > 0).toList();
    final attack = [...played]..sort((a, b) => b.goalsFor.compareTo(a.goalsFor));
    final defense = [...played]
      ..sort((a, b) {
        final c = a.goalsAgainst.compareTo(b.goalsAgainst);
        return c != 0 ? c : b.cleanSheets.compareTo(a.cleanSheets);
      });
    final possession = [...played]
      ..sort((a, b) => b.possessionAvg.compareTo(a.possessionAvg));

    return _Refreshable(
      state: state,
      children: [
        SectionTitle(l.bestAttack),
        for (final (i, t) in attack.take(8).indexed)
          _TeamRow(
            rank: i + 1,
            state: state,
            teamEspn: t.teamEspn,
            value: '${t.goalsFor}',
            valueLabel: l.goalsAbbr,
            highlight: i == 0,
          ),
        SectionTitle(l.bestDefense),
        for (final (i, t) in defense.take(8).indexed)
          _TeamRow(
            rank: i + 1,
            state: state,
            teamEspn: t.teamEspn,
            value: '${t.goalsAgainst}',
            valueLabel: '▽',
            subtitle: t.cleanSheets > 0 ? '${t.cleanSheets} ${l.statCleanSheets}' : null,
          ),
        if (possession.any((t) => t.possessionAvg > 0)) ...[
          SectionTitle(l.mostPossession),
          for (final (i, t) in possession
              .where((t) => t.possessionAvg > 0)
              .take(8)
              .indexed)
            _TeamRow(
              rank: i + 1,
              state: state,
              teamEspn: t.teamEspn,
              value: '${t.possessionAvg.toStringAsFixed(0)}%',
            ),
        ],
        if (stats.keepers.isNotEmpty) ...[
          SectionTitle(l.goalkeepers),
          for (final (i, k) in stats.keepers.take(10).indexed)
            _PlayerRow(
              rank: i + 1,
              state: state,
              player: k.player,
              value: '${k.cleanSheets}',
              valueLabel: '⛨',
              subtitle: k.saves > 0 ? l.savesCount(k.saves) : null,
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// -------------------------------------------------------------- tab resumen

class _SummaryTab extends StatelessWidget {
  final TournamentStats stats;
  final AppState state;
  const _SummaryTab({required this.stats, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final t = stats.totals;
    final tiles = <Widget>[
      _StatTile(icon: Icons.stadium, label: l.statMatchesPlayed, value: '${t.matchesPlayed}'),
      _StatTile(icon: Icons.sports_soccer, label: l.statTotalGoals, value: '${t.totalGoals}'),
      _StatTile(
        icon: Icons.show_chart,
        label: l.statAvgGoals,
        value: t.avgGoals.toStringAsFixed(2),
      ),
      _StatTile(icon: Icons.sports, label: l.statPenalties, value: '${t.penalties}'),
      _StatTile(icon: Icons.bolt, label: l.statHatTricks, value: '${t.hatTricks}'),
      _StatTile(
        icon: Icons.groups,
        label: l.statAttendance,
        value: _compact(t.attendance),
      ),
    ];

    return _Refreshable(
      state: state,
      children: [
        SectionTitle(l.tournamentNumbers),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: tiles,
        ),
        if (t.biggestWin != null) ...[
          const SizedBox(height: 14),
          _BiggestWinCard(state: state, win: t.biggestWin!),
        ],
        if (stats.discipline.isNotEmpty) ...[
          const SizedBox(height: 14),
          GradientCard(
            child: Row(
              children: [
                _Cards(yellow: t.yellow, red: t.red, size: 16),
                const SizedBox(width: 12),
                Text(
                  l.fairPlay,
                  style: outfit(14, FontWeight.w700, color: Wc.textSoft),
                ),
                const Spacer(),
                Text(
                  '${t.yellow + t.red}',
                  style: outfit(20, FontWeight.w900, color: Wc.gold),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

// ---------------------------------------------------------------- widgets

class _Refreshable extends StatelessWidget {
  final AppState state;
  final List<Widget> children;
  const _Refreshable({required this.state, required this.children});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Wc.gold,
      backgroundColor: Wc.surface,
      onRefresh: state.sync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: children,
      ),
    );
  }
}

/// Fila de jugador con puesto, bandera, nombre y valor destacado.
class _PlayerRow extends StatelessWidget {
  final int rank;
  final AppState state;
  final PlayerRef player;
  final String? value;
  final String? valueLabel;
  final String? subtitle;
  final Widget? trailing;
  final bool highlight;

  const _PlayerRow({
    required this.rank,
    required this.state,
    required this.player,
    this.value,
    this.valueLabel,
    this.subtitle,
    this.trailing,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final team = state.teamsByEspn[player.teamEspn];
    final teamName = team != null ? state.l10n.teamName(team) : player.teamEspn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GradientCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: highlight ? Wc.gold.withValues(alpha: .5) : null,
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: 10),
            team != null
                ? FlagImg(team.flag, size: 30)
                : const UnknownFlag(size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outfit(14, FontWeight.w800),
                  ),
                  Text(
                    subtitle == null ? teamName : '$teamName · $subtitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outfit(11.5, FontWeight.w500, color: Wc.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else if (value != null)
              _ValuePill(value: value!, label: valueLabel, highlight: highlight),
          ],
        ),
      ),
    );
  }
}

/// Fila de equipo con puesto, bandera y valor.
class _TeamRow extends StatelessWidget {
  final int rank;
  final AppState state;
  final String teamEspn;
  final String? value;
  final String? valueLabel;
  final String? subtitle;
  final Widget? trailing;
  final bool highlight;

  const _TeamRow({
    required this.rank,
    required this.state,
    required this.teamEspn,
    this.value,
    this.valueLabel,
    this.subtitle,
    this.trailing,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final team = state.teamsByEspn[teamEspn];
    final name = team != null ? state.l10n.teamName(team) : teamEspn;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GradientCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: highlight ? Wc.gold.withValues(alpha: .5) : null,
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: 10),
            team != null
                ? FlagImg(team.flag, size: 30)
                : const UnknownFlag(size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outfit(14, FontWeight.w800),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: outfit(11.5, FontWeight.w500, color: Wc.textDim),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else if (value != null)
              _ValuePill(value: value!, label: valueLabel, highlight: highlight),
          ],
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final isPodium = rank <= 3;
    final color = switch (rank) {
      1 => Wc.gold,
      2 => Wc.textSoft,
      3 => const Color(0xFFCD7F32),
      _ => Wc.textDim,
    };
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPodium ? color.withValues(alpha: .16) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isPodium ? color.withValues(alpha: .6) : Wc.line,
        ),
      ),
      child: Text(
        '$rank',
        style: outfit(12.5, FontWeight.w800, color: isPodium ? color : Wc.textDim),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String value;
  final String? label;
  final bool highlight;
  const _ValuePill({required this.value, this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: outfit(
            20,
            FontWeight.w900,
            color: highlight ? Wc.goldHi : Wc.gold,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 3),
          Text(label!, style: outfit(11, FontWeight.w700, color: Wc.textDim)),
        ],
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  final int yellow;
  final int red;
  final double size;
  const _Cards({required this.yellow, required this.red, this.size = 18});

  @override
  Widget build(BuildContext context) {
    Widget card(Color c, int n) => Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size * .72,
            height: size,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 3),
          Text('$n', style: outfit(14, FontWeight.w800)),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        card(const Color(0xFFF4C430), yellow),
        if (red > 0) card(Wc.live, red),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Wc.gold, size: 20),
          Text(value, style: outfit(24, FontWeight.w900)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: outfit(11.5, FontWeight.w600, color: Wc.textDim),
          ),
        ],
      ),
    );
  }
}

class _BiggestWinCard extends StatelessWidget {
  final AppState state;
  final BiggestWin win;
  const _BiggestWinCard({required this.state, required this.win});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final w = state.teamsByEspn[win.winnerEspn];
    final lo = state.teamsByEspn[win.loserEspn];
    return GradientCard(
      gradient: Wc.finalGradient,
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: Wc.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.statBiggestWin,
                  style: outfit(11.5, FontWeight.w700, color: Wc.textDim),
                ),
                const SizedBox(height: 2),
                Text(
                  '${w != null ? l.teamName(w) : win.winnerEspn} ${win.winnerGoals}–${win.loserGoals} ${lo != null ? l.teamName(lo) : win.loserEspn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: outfit(15, FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BootIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.emoji_events, color: Wc.gold, size: 18);
}

class _MiniEmpty extends StatelessWidget {
  final AppStrings strings;
  const _MiniEmpty({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          strings.statsEmpty,
          textAlign: TextAlign.center,
          style: outfit(13, FontWeight.w600, color: Wc.textDim),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        text,
        style: outfit(11, FontWeight.w500, color: Wc.textDim),
      ),
    );
  }
}
