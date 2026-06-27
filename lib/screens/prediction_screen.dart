/// Pestaña Pick'em: pronósticos partido por partido del fixture real.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../main.dart';
import '../models.dart';
import '../supabase_service.dart';
import '../theme.dart';
import '../widgets.dart';

class PredictionScreen extends StatelessWidget {
  const PredictionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final total = state.pickemTotal;
    final (exact, correct) = state.pickemBreakdown;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.simulatorTab, style: outfit(22, FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: l.clearAll,
              icon: Icon(Icons.delete_outline, color: Wc.textDim),
              onPressed: () => _confirmClear(context, state),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(92),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.finalPhaseActive
                                  ? l.yourScoreFinal
                                  : l.yourScoreGroups,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: outfit(
                                11.5,
                                FontWeight.w600,
                                color: Wc.textDim,
                              ),
                            ),
                            Text(
                              l.pickemSummary(exact, correct),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: outfit(
                                11.5,
                                FontWeight.w600,
                                color: Wc.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$total',
                        style: outfit(30, FontWeight.w900, color: Wc.goldHi),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Text(
                          l.pts,
                          style: outfit(13, FontWeight.w700, color: Wc.textDim),
                        ),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  indicatorColor: Wc.gold,
                  labelStyle: outfit(13.5, FontWeight.w800),
                  unselectedLabelStyle: outfit(13.5, FontWeight.w600),
                  labelColor: Wc.goldHi,
                  unselectedLabelColor: Wc.textDim,
                  tabs: [
                    Tab(text: l.pickemPredictionsTab),
                    Tab(text: l.rankingTab),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [_PredictionsTab(), _LeaderboardTab()],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Wc.surface,
        title: Text(
          state.l10n.clearPredictionsTitle,
          style: outfit(18, FontWeight.w800),
        ),
        content: Text(
          state.l10n.clearPredictionsBody,
          style: outfit(13.5, FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              state.l10n.cancel,
              style: outfit(13, FontWeight.w600, color: Wc.textDim),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Wc.live),
            onPressed: () {
              state.clearPreds();
              Navigator.pop(ctx);
            },
            child: Text(
              state.l10n.clearAll,
              style: outfit(13, FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- pronósticos

enum _PickemFilter { pending, upcoming, today, mine, closed, all }

class _PredictionsTab extends StatefulWidget {
  const _PredictionsTab();

  @override
  State<_PredictionsTab> createState() => _PredictionsTabState();
}

class _PredictionsTabState extends State<_PredictionsTab> {
  _PickemFilter filter = _PickemFilter.pending;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final now = DateTime.now();
    final visible = [
      for (final match in state.matches)
        if (_matchesFilter(state, match, filter, now)) match,
    ];
    final children = <Widget>[];
    Stage? currentStage;
    String? currentDay;

    for (final match in visible) {
      if (currentStage != match.stage) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 10));
        children.add(SectionTitle(l.stageLabel(match.stage)));
        currentStage = match.stage;
        currentDay = null;
      }
      final day = fmtDay(match.dateUtc, l.locale);
      if (currentDay != day) {
        children.add(_DateHeader(day));
        currentDay = day;
      }
      children.add(_PickemMatchCard(match: match));
      children.add(const SizedBox(height: 8));
    }

    return Column(
      children: [
        if (!state.accountLinked)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _AccountCard(),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _PickemFilters(
            value: filter,
            onChanged: (value) => setState(() => filter = value),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _PickemEmptyState(l.noMatchesForFilter)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: children,
                ),
        ),
      ],
    );
  }

  bool _matchesFilter(
    AppState state,
    WcMatch match,
    _PickemFilter filter,
    DateTime now,
  ) {
    final predSaved = state.preds.containsKey(match.no);
    final editable = state.canEditPickem(match, now);
    final (home, away) = state.realTeams(match);
    final teamsResolved = home != null && away != null;
    final kickoffInFuture = now.toUtc().isBefore(match.dateUtc);
    final localKickoff = localMatchTime(match.dateUtc);
    final isToday =
        localKickoff.year == now.year &&
        localKickoff.month == now.month &&
        localKickoff.day == now.day;

    return switch (filter) {
      _PickemFilter.pending => editable && !predSaved,
      _PickemFilter.upcoming => teamsResolved && kickoffInFuture,
      _PickemFilter.today => isToday,
      _PickemFilter.mine => predSaved,
      _PickemFilter.closed =>
        !editable &&
            (state.pickemLocked(match, now) || !state.pickemCounts(match)),
      _PickemFilter.all => true,
    };
  }
}

class _PickemFilters extends StatelessWidget {
  final _PickemFilter value;
  final ValueChanged<_PickemFilter> onChanged;

  const _PickemFilters({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppScope.of(context).l10n;
    final labels = {
      _PickemFilter.pending: l.pickemFilterPending,
      _PickemFilter.upcoming: l.pickemFilterUpcoming,
      _PickemFilter.today: l.today,
      _PickemFilter.mine: l.pickemFilterMyPicks,
      _PickemFilter.closed: l.pickemFilterClosed,
      _PickemFilter.all: l.all,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _PickemFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(labels[f]!),
                selected: value == f,
                selectedColor: Wc.gold.withValues(alpha: .2),
                checkmarkColor: Wc.goldHi,
                visualDensity: const VisualDensity(
                  horizontal: -3,
                  vertical: -3,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                labelStyle: outfit(
                  13,
                  FontWeight.w600,
                  color: value == f ? Wc.goldHi : Wc.text,
                ),
                onSelected: (_) => onChanged(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickemEmptyState extends StatelessWidget {
  final String text;

  const _PickemEmptyState(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_outlined, size: 44, color: Wc.textDim),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: outfit(14, FontWeight.w600, color: Wc.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String text;
  const _DateHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: outfit(12, FontWeight.w800, color: Wc.goldHi, spacing: .6),
      ),
    );
  }
}

class _PickemMatchCard extends StatelessWidget {
  final WcMatch match;
  const _PickemMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final (home, away) = state.realTeams(match);
    final resolved = home != null && away != null;
    final pred = state.preds[match.no];
    final editable = state.canEditPickem(match);

    return GradientCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Pill('${l.matchShort}${match.no}', color: Wc.textDim),
              const SizedBox(width: 6),
              if (match.stage == Stage.group)
                Pill(l.group(match.group!), color: Wc.goldHi)
              else
                Pill(l.stageShortLabel(match.stage), color: Wc.goldHi),
              const Spacer(),
              Text(
                fmtTime(match.dateUtc),
                style: outfit(11.5, FontWeight.w800, color: Wc.textDim),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PickemTeam(
                  team: home,
                  slot: match.homeSlot,
                  alignEnd: true,
                ),
              ),
              Flexible(
                flex: 2,
                child: Center(
                  child: editable
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _PredictionScoreEditor(
                            match: match,
                            pred: pred,
                          ),
                        )
                      : _PredictionSummary(
                          match: match,
                          pred: pred,
                          teamsResolved: resolved,
                        ),
                ),
              ),
              Expanded(
                child: _PickemTeam(team: away, slot: match.awaySlot),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickemTeam extends StatelessWidget {
  final Team? team;
  final String slot;
  final bool alignEnd;

  const _PickemTeam({
    required this.team,
    required this.slot,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppScope.of(context).l10n;
    final flag = team == null
        ? const UnknownFlag(size: 26)
        : FlagImg(team!.flag, size: 26, radius: 5);
    final label = Text(
      team?.id ?? l.slotLabel(slot),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: outfit(
        team == null ? 10.5 : 12.5,
        FontWeight.w800,
        color: team == null ? Wc.textDim : Wc.text,
        spacing: team == null ? 0 : .5,
      ),
    );

    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: label), const SizedBox(width: 7), flag]
          : [flag, const SizedBox(width: 7), Flexible(child: label)],
    );
  }
}

class _PredictionScoreEditor extends StatelessWidget {
  final WcMatch match;
  final Pred? pred;

  const _PredictionScoreEditor({required this.match, required this.pred});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScoreControl(
          value: pred?.home,
          onChanged: (delta) => _update(context, delta, 0),
        ),
        Text(' – ', style: outfit(13, FontWeight.w700, color: Wc.textDim)),
        _ScoreControl(
          value: pred?.away,
          onChanged: (delta) => _update(context, 0, delta),
        ),
      ],
    );
  }

  void _update(BuildContext context, int homeDelta, int awayDelta) {
    final state = AppScope.of(context);
    final current = state.preds[match.no] ?? Pred(0, 0);
    state.setPred(
      match.no,
      Pred(
        (current.home + homeDelta).clamp(0, 19),
        (current.away + awayDelta).clamp(0, 19),
      ),
    );
  }
}

class _ScoreControl extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  const _ScoreControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniBtn(
          icon: Icons.remove,
          enabled: value != null && value! > 0,
          onTap: () => onChanged(-1),
        ),
        SizedBox(
          width: 26,
          child: Text(
            value?.toString() ?? '·',
            textAlign: TextAlign.center,
            style: outfit(
              17,
              FontWeight.w900,
              color: value != null ? Wc.text : Wc.textDim,
            ),
          ),
        ),
        _MiniBtn(icon: Icons.add, enabled: true, onTap: () => onChanged(1)),
      ],
    );
  }
}

class _PredictionSummary extends StatelessWidget {
  final WcMatch match;
  final Pred? pred;
  final bool teamsResolved;

  const _PredictionSummary({
    required this.match,
    required this.pred,
    required this.teamsResolved,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final live = state.liveFor(match);
    final real = state.realPredFor(match);
    final pts = state.pickemPoints(match);
    final realScore = live?.homeScore != null && live?.awayScore != null
        ? '${live!.homeScore} – ${live.awayScore}'
        : 'VS';
    final (chipText, chipColor) = !teamsResolved
        ? (l.pickemUnavailable, Wc.textDim)
        : !state.pickemCounts(match)
        ? (l.pickemNoScore, Wc.textDim)
        : live?.isLive == true
        ? (l.live, Wc.live)
        : real != null
        ? ('+$pts', pts == 6 ? Wc.mint : (pts == 3 ? Wc.goldHi : Wc.textDim))
        : (l.pickemClosed, Wc.textDim);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(realScore, style: outfit(17, FontWeight.w900)),
        const SizedBox(height: 3),
        Text(
          pred == null
              ? '${l.pickemYourPick} –'
              : '${l.pickemYourPick} ${pred!.home}-${pred!.away}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: outfit(10, FontWeight.w600, color: Wc.textDim),
        ),
        const SizedBox(height: 4),
        _LockChip(chipText, chipColor),
      ],
    );
  }
}

class _LockChip extends StatelessWidget {
  final String text;
  final Color color;
  const _LockChip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: outfit(10, FontWeight.w800, color: color),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MiniBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: enabled ? Wc.surfaceHi : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? Wc.line : Wc.line.withValues(alpha: .4),
          ),
        ),
        child: Icon(icon, size: 14, color: enabled ? Wc.goldHi : Wc.line),
      ),
    );
  }
}

// --------------------------------------------------------------- ranking

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  bool? _isFinalTab;
  Future<List<LeaderEntry>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set default sub-tab once (Fase Final prominent when knockouts active).
    _isFinalTab ??= AppScope.of(context).finalPhaseActive;
  }

  void _switchTab(bool isFinal) {
    final state = AppScope.of(context);
    setState(() {
      _isFinalTab = isFinal;
      _future = isFinal
          ? state.fetchLeaderboardFinal()
          : state.fetchLeaderboard();
    });
  }

  void _reload() {
    final state = AppScope.of(context);
    setState(() {
      _future = _isFinalTab!
          ? state.fetchLeaderboardFinal()
          : state.fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final isFinal = _isFinalTab!;

    if (state.nickname == null) {
      return _NicknameForm(onSaved: _reload);
    }

    _future ??= isFinal
        ? state.fetchLeaderboardFinal()
        : state.fetchLeaderboard();
    final me = SupabaseService.userId;

    return Column(
      children: [
        // Sub-selector: Grupos / Fase Final
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Wc.gold.withValues(alpha: .18),
              selectedForegroundColor: Wc.goldHi,
              foregroundColor: Wc.textDim,
              textStyle: outfit(13, FontWeight.w700),
            ),
            segments: [
              ButtonSegment<bool>(
                value: false,
                label: Text(l.groupsRankingTab),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: const Icon(Icons.emoji_events, size: 15),
                label: Text(l.finalRankingTab),
              ),
            ],
            selected: {isFinal},
            onSelectionChanged: (s) => _switchTab(s.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: Wc.gold,
            backgroundColor: Wc.surface,
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: FutureBuilder<List<LeaderEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Wc.gold),
                  );
                }
                final entries = snap.data ?? const <LeaderEntry>[];
                if (entries.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
                        child: Text(
                          SupabaseService.ready
                              ? l.leaderboardEmpty
                              : l.leaderboardOffline,
                          textAlign: TextAlign.center,
                          style: outfit(14, FontWeight.w600, color: Wc.textDim),
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _ChampionBanner(
                      entry: entries.first,
                      isFinalTab: isFinal,
                      state: state,
                    ),
                    for (int i = 1; i < entries.length; i++)
                      _LeaderRow(
                        rank: i + 1,
                        entry: entries[i],
                        isMe: entries[i].userId == me,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  final LeaderEntry entry;
  final bool isFinalTab;
  final AppState state;

  const _ChampionBanner({
    required this.entry,
    required this.isFinalTab,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final isChampion =
        isFinalTab ? state.tournamentOver : state.groupsConcluded;
    final label = isFinalTab
        ? (state.tournamentOver ? l.tournamentChampionLabel : l.leaderLabel)
        : (state.groupsConcluded ? l.groupsChampionLabel : l.leaderLabel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GradientCard(
        gradient: Wc.finalGradient,
        borderColor: Wc.gold.withValues(alpha: .5),
        child: Row(
          children: [
            Icon(
              isChampion ? Icons.emoji_events : Icons.leaderboard,
              color: Wc.gold,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: outfit(11, FontWeight.w700, color: Wc.textDim),
                  ),
                  Text(
                    entry.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outfit(15, FontWeight.w900),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.points}',
              style: outfit(22, FontWeight.w900, color: Wc.gold),
            ),
            const SizedBox(width: 3),
            Text(l.pts, style: outfit(11, FontWeight.w700, color: Wc.textDim)),
          ],
        ),
      ),
    );
  }
}

class _NicknameForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _NicknameForm({required this.onSaved});

  @override
  State<_NicknameForm> createState() => _NicknameFormState();
}

class _NicknameFormState extends State<_NicknameForm> {
  final _controller = TextEditingController();
  String _text = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final valid = _text.trim().length >= 2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard, size: 44, color: Wc.gold),
            const SizedBox(height: 16),
            Text(
              l.nicknamePrompt,
              textAlign: TextAlign.center,
              style: outfit(15, FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLength: 24,
              textAlign: TextAlign.center,
              onChanged: (v) => setState(() => _text = v),
              style: outfit(16, FontWeight.w800),
              decoration: InputDecoration(
                hintText: l.nicknameHint,
                counterText: '',
                filled: true,
                fillColor: Wc.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Wc.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Wc.goldHi, width: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: valid ? Wc.gold : Wc.line,
                  foregroundColor: Wc.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: valid
                    ? () async {
                        await state.setNickname(_text);
                        widget.onSaved();
                      }
                    : null,
                child: Text(l.nicknameSave, style: outfit(15, FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final LeaderEntry entry;
  final bool isMe;
  const _LeaderRow({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppScope.of(context).l10n;
    final color = switch (rank) {
      1 => Wc.gold,
      2 => Wc.textSoft,
      3 => const Color(0xFFCD7F32),
      _ => Wc.textDim,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GradientCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: isMe ? Wc.gold.withValues(alpha: .55) : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParticipantPicksScreen(entry: entry, isMe: isMe),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: outfit(14, FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: outfit(
                  14.5,
                  FontWeight.w800,
                  color: isMe ? Wc.goldHi : Wc.text,
                ),
              ),
            ),
            Text(
              l.exactShort(entry.exactCount),
              style: outfit(11, FontWeight.w600, color: Wc.textDim),
            ),
            const SizedBox(width: 12),
            Text(
              '${entry.points}',
              style: outfit(20, FontWeight.w900, color: Wc.gold),
            ),
            const SizedBox(width: 3),
            Text(l.pts, style: outfit(11, FontWeight.w700, color: Wc.textDim)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Wc.textDim),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta para vincular/recuperar la cuenta con Google (solo si es anónima).
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  void _showErr(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: outfit(12.5, FontWeight.w600)),
        backgroundColor: Wc.surfaceHi,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    return GradientCard(
      gradient: Wc.finalGradient,
      borderColor: Wc.gold.withValues(alpha: .5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Wc.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.accountProtectTitle,
                  style: outfit(14.5, FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.accountProtectBody,
            style: outfit(12.5, FontWeight.w500, color: Wc.textSoft, height: 1.4),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Wc.gold,
                foregroundColor: Wc.onGold,
              ),
              onPressed: () async {
                final err = await state.linkGoogle();
                if (err != null && context.mounted) _showErr(context, err);
              },
              icon: const Icon(Icons.link, size: 18),
              label: Text(l.accountLinkGoogle, style: outfit(13.5, FontWeight.w800)),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () async {
                final err = await state.signInWithGoogle();
                if (err != null && context.mounted) _showErr(context, err);
              },
              child: Text(
                l.accountRecover,
                style: outfit(12.5, FontWeight.w700, color: Wc.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Predicciones de un participante en partidos ya jugados/empezados, con su
/// resultado real y cuánto sumó (transparencia).
class ParticipantPicksScreen extends StatefulWidget {
  final LeaderEntry entry;
  final bool isMe;
  const ParticipantPicksScreen({
    super.key,
    required this.entry,
    required this.isMe,
  });

  @override
  State<ParticipantPicksScreen> createState() => _ParticipantPicksScreenState();
}

class _ParticipantPicksScreenState extends State<ParticipantPicksScreen> {
  Future<List<ParticipantPick>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).fetchUserPredictions(widget.entry.userId);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.nickname, style: outfit(18, FontWeight.w800)),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<ParticipantPick>>(
          future: _future,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: Wc.gold));
            }
            final picks = snap.data ?? const <ParticipantPick>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                GradientCard(
                  gradient: Wc.heroGradient,
                  child: Row(
                    children: [
                      Icon(Icons.leaderboard, color: Wc.gold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.exactShort(widget.entry.exactCount),
                          style: outfit(13, FontWeight.w700, color: Wc.textSoft),
                        ),
                      ),
                      Text(
                        '${widget.entry.points}',
                        style: outfit(24, FontWeight.w900, color: Wc.gold),
                      ),
                      const SizedBox(width: 3),
                      Text(l.pts,
                          style: outfit(12, FontWeight.w700, color: Wc.textDim)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (picks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      l.participantNoPicks,
                      textAlign: TextAlign.center,
                      style: outfit(13, FontWeight.w600, color: Wc.textDim),
                    ),
                  )
                else
                  for (final p in picks) _PickRow(pick: p, state: state),
                const SizedBox(height: 12),
                Text(
                  l.participantPicksNote,
                  textAlign: TextAlign.center,
                  style: outfit(11, FontWeight.w500, color: Wc.textDim),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final ParticipantPick pick;
  final AppState state;
  const _PickRow({required this.pick, required this.state});

  static final _cutoff = DateTime.utc(2026, 6, 17);

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final m = state.byNo[pick.matchNo];
    final (home, away) = m == null ? (null, null) : state.realTeams(m);
    final homeName =
        home != null ? l.teamName(home) : (m != null ? l.slotLabel(m.homeSlot) : '?');
    final awayName =
        away != null ? l.teamName(away) : (m != null ? l.slotLabel(m.awaySlot) : '?');

    final scores = pick.hasResult
        ? '${l.pickPredictionShort}: ${pick.home}-${pick.away}  ·  ${l.pickResultLabel}: ${pick.resultHome}-${pick.resultAway}'
        : '${l.pickPredictionShort}: ${pick.home}-${pick.away}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GradientCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (home != null) FlagImg(home.flag, size: 22) else const UnknownFlag(size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$homeName – $awayName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outfit(13.5, FontWeight.w800),
                  ),
                  Text(
                    scores,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outfit(11.5, FontWeight.w600, color: Wc.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (away != null) FlagImg(away.flag, size: 22) else const UnknownFlag(size: 22),
            const SizedBox(width: 8),
            _pill(l, m),
          ],
        ),
      ),
    );
  }

  Widget _pill(AppStrings l, WcMatch? m) {
    // Antes del cutoff (17 jun): no puntúa.
    if (m != null && m.dateUtc.isBefore(_cutoff)) {
      return Pill(l.pickemNoScore, color: Wc.textDim);
    }
    if (!pick.finished) {
      return Pill(l.live, color: Wc.live);
    }
    final (text, c) = switch (pick.points) {
      6 => ('+6', Wc.mint),
      3 => ('+3', Wc.goldHi),
      _ => ('+0', Wc.textDim),
    };
    return Pill(text, color: c);
  }
}
