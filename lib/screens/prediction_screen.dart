/// Pestaña Simulador: simulador de pronósticos (grupos, terceros y bracket).
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'bracket_screen.dart' show BracketView;
import 'groups_screen.dart' show ThirdsCard;

class PredictionScreen extends StatelessWidget {
  const PredictionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final total = state.pickemTotal;
    final (exact, correct) = state.pickemBreakdown;

    return DefaultTabController(
      length: 3,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.pickemScore,
                            style: outfit(
                              11.5,
                              FontWeight.w600,
                              color: Wc.textDim,
                            ),
                          ),
                          Text(
                            l.pickemSummary(exact, correct),
                            style: outfit(
                              11.5,
                              FontWeight.w600,
                              color: Wc.textDim,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '$total',
                        style: outfit(30, FontWeight.w900, color: Wc.goldHi),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Text(
                          l.pts,
                          style: outfit(
                            13,
                            FontWeight.w700,
                            color: Wc.textDim,
                          ),
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
                    Tab(text: l.groupsTab),
                    Tab(text: l.bestThirds),
                    Tab(text: l.bracketTab),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [_GroupsPredTab(), _ThirdsPredTab(), _BracketPredTab()],
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

// ------------------------------------------------------------------ grupos

class _GroupsPredTab extends StatelessWidget {
  const _GroupsPredTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final groups = state.groupMatches.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: groups.length,
      itemBuilder: (_, i) => _GroupPredBlock(group: groups[i]),
    );
  }
}

class _GroupPredBlock extends StatelessWidget {
  final String group;
  const _GroupPredBlock({required this.group});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final ms = state.groupMatches[group]!;
    final complete = state.predGroupComplete(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GradientCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l.group(group), style: outfit(16, FontWeight.w800)),
                const SizedBox(width: 8),
                if (complete)
                  Icon(Icons.check_circle, size: 16, color: Wc.mint),
              ],
            ),
            const SizedBox(height: 4),
            for (final m in ms) _PredRow(match: m),
            if (ms.any((m) => state.preds.containsKey(m.no))) ...[
              const Divider(height: 20),
              _MiniPredTable(group: group),
            ],
          ],
        ),
      ),
    );
  }
}

class _PredRow extends StatelessWidget {
  final WcMatch match;
  const _PredRow({required this.match});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final home = state.teams[match.homeSlot]!;
    final away = state.teams[match.awaySlot]!;
    final pred = state.preds[match.no];

    if (state.pickemLocked(match)) {
      return _LockedPredRow(match: match, home: home, away: away);
    }

    void update(int dh, int da) {
      final p = pred ?? Pred(0, 0);
      state.setPred(
        match.no,
        Pred((p.home + dh).clamp(0, 19), (p.away + da).clamp(0, 19)),
      );
    }

    Widget score(int? v, void Function(int) delta) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniBtn(
            icon: Icons.remove,
            enabled: v != null && v > 0,
            onTap: () => delta(-1),
          ),
          SizedBox(
            width: 26,
            child: Text(
              v?.toString() ?? '·',
              textAlign: TextAlign.center,
              style: outfit(
                17,
                FontWeight.w900,
                color: v != null ? Wc.text : Wc.textDim,
              ),
            ),
          ),
          _MiniBtn(icon: Icons.add, enabled: true, onTap: () => delta(1)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  home.id,
                  style: outfit(12.5, FontWeight.w800, spacing: .5),
                ),
                const SizedBox(width: 7),
                FlagImg(home.flag, size: 24, radius: 5),
              ],
            ),
          ),
          const SizedBox(width: 10),
          score(pred?.home, (d) => update(d, 0)),
          Text(' – ', style: outfit(13, FontWeight.w700, color: Wc.textDim)),
          score(pred?.away, (d) => update(0, d)),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                FlagImg(away.flag, size: 24, radius: 5),
                const SizedBox(width: 7),
                Text(
                  away.id,
                  style: outfit(12.5, FontWeight.w800, spacing: .5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un partido ya cerrado (kickoff pasado): muestra el resultado real,
/// tu pronóstico y los puntos obtenidos (o "no puntúa" si es previo al cutoff).
class _LockedPredRow extends StatelessWidget {
  final WcMatch match;
  final Team home;
  final Team away;
  const _LockedPredRow({
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
    final finished = state.realPredFor(match) != null;
    final pts = state.pickemPoints(match);
    final realScore = live?.homeScore != null
        ? '${live!.homeScore} – ${live.awayScore}'
        : '– · –';

    final (String chipText, Color chipColor) = !counts
        ? (l.pickemNoScore, Wc.textDim)
        : !finished
        ? (l.live, Wc.live)
        : ('+$pts', pts == 6 ? Wc.mint : (pts == 3 ? Wc.goldHi : Wc.textDim));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(home.id, style: outfit(12.5, FontWeight.w800, spacing: .5)),
                const SizedBox(width: 7),
                FlagImg(home.flag, size: 24, radius: 5),
              ],
            ),
          ),
          SizedBox(
            width: 126,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(realScore, style: outfit(16, FontWeight.w900)),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pred == null
                          ? '${l.pickemYourPick} –'
                          : '${l.pickemYourPick} ${pred.home}-${pred.away}',
                      style: outfit(10, FontWeight.w600, color: Wc.textDim),
                    ),
                    const SizedBox(width: 6),
                    _LockChip(chipText, chipColor),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                FlagImg(away.flag, size: 24, radius: 5),
                const SizedBox(width: 7),
                Text(away.id, style: outfit(12.5, FontWeight.w800, spacing: .5)),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(text, style: outfit(10, FontWeight.w800, color: color)),
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

class _MiniPredTable extends StatelessWidget {
  final String group;
  const _MiniPredTable({required this.group});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final rows = state.predTable(group);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Text(
                    '${i + 1}',
                    style: outfit(
                      10.5,
                      FontWeight.w800,
                      color: i < 2
                          ? Wc.mint
                          : i == 2
                          ? Wc.goldHi
                          : Wc.textDim,
                    ),
                  ),
                ),
                FlagImg(state.teams[rows[i].teamId]!.flag, size: 18, radius: 4),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.teamName(state.teams[rows[i].teamId]!),
                    style: outfit(11.5, FontWeight.w600),
                  ),
                ),
                Text(
                  '${rows[i].gd > 0 ? '+' : ''}${rows[i].gd}  ',
                  style: outfit(11, FontWeight.w600, color: Wc.textDim),
                ),
                Text(
                  '${rows[i].points} ${l.pts}',
                  style: outfit(11.5, FontWeight.w800, color: Wc.goldHi),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------- terceros

class _ThirdsPredTab extends StatelessWidget {
  const _ThirdsPredTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final thirds = state.predThirdsRanked();
    if (thirds.isEmpty) {
      return _emptyState(state.l10n.completeGroupsForThirds);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ThirdsCard(thirds: thirds, real: false),
        if (!state.allGroupsPredicted)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              state.l10n.completeAllGroupsForBracketThirds,
              textAlign: TextAlign.center,
              style: outfit(12.5, FontWeight.w500, color: Wc.textDim),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ bracket

class _BracketPredTab extends StatelessWidget {
  const _BracketPredTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final champion = state.predChampion;

    return Column(
      children: [
        if (champion != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: GradientCard(
              gradient: Wc.championGradient,
              borderColor: Wc.gold,
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: Wc.gold, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.yourWorldChampionUpper,
                          style: outfit(
                            10.5,
                            FontWeight.w800,
                            color: Wc.goldHi,
                            spacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.teamName(champion),
                          style: outfit(20, FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  FlagImg(champion.flag, size: 44),
                ],
              ),
            ),
          )
        else if (!state.allGroupsPredicted)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: GradientCard(
              child: Text(
                l.completeGroupsForBracket,
                textAlign: TextAlign.center,
                style: outfit(12.5, FontWeight.w600, color: Wc.textDim),
              ),
            ),
          ),
        Expanded(
          child: BracketView(
            teamsOf: state.predTeams,
            scoreOf: (m) {
              final p = state.preds[m.no];
              return p == null ? null : (p.home, p.away, false);
            },
            winnerOf: state.predWinner,
            onTap: (m) => _editKo(context, state, m),
          ),
        ),
      ],
    );
  }

  void _editKo(BuildContext context, AppState state, WcMatch m) {
    if (state.pickemLocked(m)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.l10n.pickemLockedToast)),
      );
      return;
    }
    final (home, away) = state.predTeams(m);
    if (home == null || away == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.l10n.unknownKnockoutTeams)));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Wc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => _KoEditorSheet(match: m, home: home, away: away),
    );
  }
}

class _KoEditorSheet extends StatefulWidget {
  final WcMatch match;
  final Team home;
  final Team away;

  const _KoEditorSheet({
    required this.match,
    required this.home,
    required this.away,
  });

  @override
  State<_KoEditorSheet> createState() => _KoEditorSheetState();
}

class _KoEditorSheetState extends State<_KoEditorSheet> {
  int h = 0;
  int a = 0;
  String? penWinner;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final p = AppScope.of(context).preds[widget.match.no];
    h = p?.home ?? 0;
    a = p?.away ?? 0;
    penWinner = p?.penWinner;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final tie = h == a;
    final canSave = !tie || penWinner != null;

    Widget stepper(int v, void Function(int) set) {
      return Column(
        children: [
          IconButton(
            onPressed: () => set((v + 1).clamp(0, 19)),
            icon: Icon(Icons.keyboard_arrow_up, size: 30, color: Wc.goldHi),
          ),
          Text('$v', style: outfit(34, FontWeight.w900)),
          IconButton(
            onPressed: v > 0 ? () => set(v - 1) : null,
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 30,
              color: v > 0 ? Wc.textDim : Wc.line,
            ),
          ),
        ],
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Wc.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.stageLabel(widget.match.stage),
              style: outfit(12, FontWeight.w800, color: Wc.goldHi, spacing: 1),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      FlagImg(widget.home.flag, size: 46),
                      const SizedBox(height: 6),
                      Text(
                        l.teamName(widget.home),
                        textAlign: TextAlign.center,
                        style: outfit(13.5, FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                stepper(
                  h,
                  (v) => setState(() {
                    h = v;
                    if (h != a) penWinner = null;
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '–',
                    style: outfit(26, FontWeight.w800, color: Wc.textDim),
                  ),
                ),
                stepper(
                  a,
                  (v) => setState(() {
                    a = v;
                    if (h != a) penWinner = null;
                  }),
                ),
                Expanded(
                  child: Column(
                    children: [
                      FlagImg(widget.away.flag, size: 46),
                      const SizedBox(height: 6),
                      Text(
                        l.teamName(widget.away),
                        textAlign: TextAlign.center,
                        style: outfit(13.5, FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (tie) ...[
              const SizedBox(height: 14),
              Text(
                l.tiePenaltyQuestion,
                style: outfit(13, FontWeight.w700, color: Wc.textDim),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final t in [widget.home, widget.away])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ChoiceChip(
                        avatar: FlagImg(t.flag, size: 18, radius: 4),
                        label: Text(l.teamName(t)),
                        selected: penWinner == t.id,
                        selectedColor: Wc.gold.withValues(alpha: .25),
                        labelStyle: outfit(
                          12.5,
                          FontWeight.w700,
                          color: penWinner == t.id ? Wc.goldHi : Wc.text,
                        ),
                        onSelected: (_) => setState(() => penWinner = t.id),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (AppScope.of(context).preds[widget.match.no] != null)
                  TextButton(
                    onPressed: () {
                      state.setPred(widget.match.no, null);
                      Navigator.pop(context);
                    },
                    child: Text(
                      l.remove,
                      style: outfit(13, FontWeight.w600, color: Wc.textDim),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: canSave ? Wc.gold : Wc.line,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                  onPressed: canSave
                      ? () {
                          state.setPred(
                            widget.match.no,
                            Pred(h, a, h == a ? penWinner : null),
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(
                    l.save,
                    style: outfit(
                      14,
                      FontWeight.w800,
                      color: const Color(0xFF221A00),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _emptyState(String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note, size: 48, color: Wc.textDim),
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
