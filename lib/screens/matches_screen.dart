/// Pestaña Partidos: calendario real con resultados en vivo.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'match_detail.dart';

enum MatchFilter { all, today, groups, knockout }

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  MatchFilter filter = MatchFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final now = DateTime.now();

    bool sameLocalDay(DateTime utc, DateTime ref) {
      final l = localMatchTime(utc);
      return l.year == ref.year && l.month == ref.month && l.day == ref.day;
    }

    final query = _normalizeSearch(searchQuery);

    bool matchesSearch(WcMatch m) {
      if (query.isEmpty) return true;
      final (home, away) = state.realTeams(m);
      return _teamMatches(home, query) || _teamMatches(away, query);
    }

    final visible = [
      for (final m in state.matches)
        if (switch (filter) {
              MatchFilter.all => true,
              MatchFilter.today => sameLocalDay(m.dateUtc, now),
              MatchFilter.groups => m.stage == Stage.group,
              MatchFilter.knockout => m.isKnockout,
            } &&
            matchesSearch(m))
          m,
    ];

    // Agrupar por día local.
    final sections = <String, List<WcMatch>>{};
    for (final m in visible) {
      sections.putIfAbsent(fmtDay(m.dateUtc, l.locale), () => []).add(m);
    }

    final next = state.nextMatch;
    final liveNow = [
      for (final m in state.matches)
        if (state.liveFor(m)?.isLive == true) m,
    ];

    return RefreshIndicator(
      color: Wc.gold,
      backgroundColor: Wc.surface,
      onRefresh: state.sync,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            title: Row(
              children: [
                Text('GOLAZO', style: outfit(22, FontWeight.w900)),
                Text(
                  " '26",
                  style: outfit(22, FontWeight.w900, color: Wc.gold),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  state.darkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: Wc.textDim,
                ),
                onPressed: state.toggleTheme,
                tooltip: state.darkMode ? l.lightMode : l.darkMode,
              ),
              PopupMenuButton<AppLanguage>(
                tooltip: l.languageTooltip,
                icon: Text(
                  state.language.code.toUpperCase(),
                  style: outfit(12, FontWeight.w900, color: Wc.goldHi),
                ),
                color: Wc.surface,
                onSelected: state.setLanguage,
                itemBuilder: (_) => [
                  for (final lang in AppLanguage.values)
                    PopupMenuItem(
                      value: lang,
                      child: Text(
                        lang.label,
                        style: outfit(
                          13,
                          state.language == lang
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: state.language == lang ? Wc.goldHi : Wc.text,
                        ),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: l.broadcastCountry,
                icon: Icon(Icons.live_tv, color: Wc.textDim),
                color: Wc.surface,
                onSelected: state.setCountry,
                itemBuilder: (_) => [
                  for (final c in state.countriesSorted)
                    PopupMenuItem(
                      value: c.code,
                      child: Text(
                        state.countryName(c.code),
                        style: outfit(
                          13,
                          state.country == c.code
                              ? FontWeight.w900
                              : FontWeight.w600,
                          color: state.country == c.code ? Wc.goldHi : Wc.text,
                        ),
                      ),
                    ),
                ],
              ),
              if (state.syncing)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Wc.gold,
                    ),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.hostCountries,
                    style: outfit(13, FontWeight.w500, color: Wc.textDim),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.localTimeNotice,
                    style: outfit(12, FontWeight.w600, color: Wc.mint),
                  ),
                  if (liveNow.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _LiveNowStrip(matches: liveNow),
                  ] else if (next != null) ...[
                    const SizedBox(height: 14),
                    _NextMatchCard(match: next),
                  ],
                  const SizedBox(height: 12),
                  _MatchSearchField(
                    controller: _searchController,
                    query: searchQuery,
                    onChanged: (value) => setState(() => searchQuery = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => searchQuery = '');
                    },
                    strings: l,
                  ),
                  const SizedBox(height: 10),
                  _Filters(
                    value: filter,
                    onChanged: (f) => setState(() => filter = f),
                    strings: l,
                  ),
                ],
              ),
            ),
          ),
          for (final e in sections.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Text(
                  e.key,
                  style: outfit(14, FontWeight.w800, color: Wc.goldHi),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: e.value.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: RealMatchCard(match: e.value[i]),
              ),
            ),
          ],
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: _EmptySearchResult(
                  hasQuery: query.isNotEmpty,
                  strings: l,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

bool _teamMatches(Team? team, String query) {
  if (team == null) return false;
  return _normalizeSearch(team.id).contains(query) ||
      _normalizeSearch(team.name).contains(query) ||
      _normalizeSearch(team.espn).contains(query);
}

String _normalizeSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .trim();
}

class _MatchSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final AppStrings strings;

  const _MatchSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: outfit(14, FontWeight.w700),
      decoration: InputDecoration(
        hintText: strings.searchTeamHint,
        hintStyle: outfit(13, FontWeight.w500, color: Wc.textDim),
        prefixIcon: Icon(Icons.search, color: Wc.textDim),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, color: Wc.textDim),
                onPressed: onClear,
                tooltip: strings.clearSearch,
              ),
        filled: true,
        fillColor: Wc.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Wc.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Wc.goldHi, width: 1.3),
        ),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  final bool hasQuery;
  final AppStrings strings;

  const _EmptySearchResult({required this.hasQuery, required this.strings});

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      child: Column(
        children: [
          Icon(Icons.search_off, color: Wc.textDim, size: 32),
          const SizedBox(height: 10),
          Text(
            hasQuery ? strings.noConfirmedMatches : strings.noMatchesForFilter,
            textAlign: TextAlign.center,
            style: outfit(14, FontWeight.w800),
          ),
          if (hasQuery) ...[
            const SizedBox(height: 4),
            Text(
              strings.knockoutOnlyConfirmed,
              textAlign: TextAlign.center,
              style: outfit(12, FontWeight.w500, color: Wc.textDim),
            ),
          ],
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final MatchFilter value;
  final ValueChanged<MatchFilter> onChanged;
  final AppStrings strings;

  const _Filters({
    required this.value,
    required this.onChanged,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {
      MatchFilter.all: strings.all,
      MatchFilter.today: strings.today,
      MatchFilter.groups: strings.groupStage,
      MatchFilter.knockout: strings.knockoutStage,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in MatchFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[f]!),
                selected: value == f,
                selectedColor: Wc.gold.withValues(alpha: .2),
                checkmarkColor: Wc.goldHi,
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

/// Tarjeta destacada: próximo partido o partido en vivo, con cuenta regresiva.
class _NextMatchCard extends StatelessWidget {
  final WcMatch match;
  const _NextMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.l10n;
    final live = state.liveFor(match);
    final (home, away) = state.realTeams(match);
    final isLive = live?.isLive == true;
    final venue = state.venues[match.venue];

    // En vivo: marcador grande estilo transmisión.
    if (isLive) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchNo: match.no),
            ),
          ),
          child: LiveScorebug(match: match, big: true),
        ),
      );
    }

    return GradientCard(
      gradient: Wc.heroGradient,
      borderColor: isLive
          ? Wc.live.withValues(alpha: .55)
          : Wc.gold.withValues(alpha: .35),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchDetailScreen(matchNo: match.no)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Pill(
                isLive ? strings.now : strings.nextMatch,
                color: isLive ? Wc.live : Wc.mint,
                icon: isLive ? null : Icons.schedule,
              ),
              const Spacer(),
              Text(
                match.stage == Stage.group
                    ? strings.group(match.group!)
                    : strings.stageLabel(match.stage),
                style: outfit(12, FontWeight.w700, color: Wc.textDim),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TeamCell(
                  team: home,
                  placeholder: _ph(state, match.homeSlot),
                  displayName: home == null ? null : strings.teamName(home),
                ),
              ),
              Expanded(
                child: isLive && live != null
                    ? Column(
                        children: [
                          Text(
                            '${live.homeScore ?? '-'} – ${live.awayScore ?? '-'}',
                            style: outfit(32, FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          LiveBadge(
                            text: live.detail.isEmpty
                                ? strings.live
                                : live.detail,
                          ),
                        ],
                      )
                    : _Countdown(target: match.dateUtc),
              ),
              Expanded(
                child: TeamCell(
                  team: away,
                  placeholder: _ph(state, match.awaySlot),
                  displayName: away == null ? null : strings.teamName(away),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${match.venue} · ${venue == null ? '' : strings.venueCity(venue.city)}',
            style: outfit(12, FontWeight.w500, color: Wc.textDim),
          ),
        ],
      ),
    );
  }
}

String _ph(AppState state, String slot) {
  // Solo para eliminatorias: etiqueta del slot.
  return state.teams.containsKey(slot) ? '' : state.l10n.slotLabel(slot);
}

class _Countdown extends StatefulWidget {
  final DateTime target;
  const _Countdown({required this.target});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.of(context).l10n;
    final diff = widget.target.difference(DateTime.now().toUtc());
    if (diff.isNegative) {
      return Text(
        strings.startingSoon,
        style: outfit(15, FontWeight.w800, color: Wc.mint),
      );
    }
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    final text = d > 0
        ? '${d}d ${h}h ${m}m'
        : '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return Column(
      children: [
        Text(text, style: outfit(24, FontWeight.w900, color: Wc.goldHi)),
        const SizedBox(height: 2),
        Text(
          '${fmtTime(widget.target)} · ${strings.localTime}',
          style: outfit(12, FontWeight.w600, color: Wc.textDim),
        ),
      ],
    );
  }
}

/// Marcador en vivo estilo transmisión ("score bug" del Mundial 26):
/// pill oscura con banderas + códigos de 3 letras, marcador grande, logo
/// oficial al centro y minuto en vivo. La línea superior multicolor evoca la
/// identidad "We Are 26".
class LiveScorebug extends StatelessWidget {
  final WcMatch match;
  final bool big;
  const LiveScorebug({super.key, required this.match, this.big = false});

  static const _accent = LinearGradient(
    colors: [
      Color(0xFFFF6B6B),
      Color(0xFF2DD4BF),
      Color(0xFFA78BFA),
      Color(0xFFA3E635),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final live = state.liveFor(match);
    final (home, away) = state.realTeams(match);
    final flagSize = big ? 46.0 : 34.0;
    final scoreSize = big ? 40.0 : 30.0;

    return Container(
      decoration: BoxDecoration(
        gradient: Wc.heroGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Wc.live.withValues(alpha: .45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Acento multicolor superior.
          Container(height: 4, decoration: const BoxDecoration(gradient: _accent)),
          Padding(
            padding: EdgeInsets.fromLTRB(14, big ? 16 : 12, 14, big ? 16 : 12),
            child: Row(
              children: [
                Expanded(child: _side(state, home, match.homeSlot, flagSize)),
                _center(l, live, scoreSize),
                Expanded(
                  child: _side(state, away, match.awaySlot, flagSize, end: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _side(AppState state, Team? team, String slot, double flagSize,
      {bool end = false}) {
    final code = team?.id ?? state.l10n.slotLabel(slot);
    final flag =
        team != null ? FlagImg(team.flag, size: flagSize) : UnknownFlag(size: flagSize);
    final label = Flexible(
      child: Text(
        code,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: end ? TextAlign.right : TextAlign.left,
        style: outfit(big ? 20 : 16, FontWeight.w900, spacing: .5),
      ),
    );
    final children = end
        ? [label, const SizedBox(width: 10), flag]
        : [flag, const SizedBox(width: 10), label];
    return Row(
      mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: children,
    );
  }

  Widget _center(AppStrings l, LiveInfo? live, double scoreSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/branding/fifa_logo.png',
          height: big ? 30 : 22,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${live?.homeScore ?? '-'} — ${live?.awayScore ?? '-'}',
            style: outfit(scoreSize, FontWeight.w900),
          ),
        ),
        if (live?.hasPens ?? false)
          Text(
            live!.penText(l.penaltyMark),
            style: outfit(11, FontWeight.w800, color: Wc.goldHi),
          ),
        const SizedBox(height: 6),
        LiveBadge(text: (live?.detail.isEmpty ?? true) ? l.live : live!.detail),
      ],
    );
  }
}

/// Tira "EN VIVO ahora": lista todos los partidos en curso (para simultáneos),
/// cada uno con su scorebug. El primero grande; el resto, compactos.
class _LiveNowStrip extends StatelessWidget {
  final List<WcMatch> matches;
  const _LiveNowStrip({required this.matches});

  @override
  Widget build(BuildContext context) {
    final l = AppScope.of(context).l10n;
    final single = matches.length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              const LivePulse(),
              const SizedBox(width: 7),
              Text(
                matches.length > 1
                    ? '${l.liveNowTitle} · ${matches.length}'
                    : l.liveNowTitle,
                style: outfit(13, FontWeight.w900, color: Wc.live, spacing: .5),
              ),
            ],
          ),
        ),
        for (final m in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchDetailScreen(matchNo: m.no),
                  ),
                ),
                child: LiveScorebug(match: m, big: single),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta estándar de partido (datos reales).
class RealMatchCard extends StatelessWidget {
  final WcMatch match;
  final bool dense;

  const RealMatchCard({super.key, required this.match, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strings = state.l10n;
    final live = state.liveFor(match);
    final (home, away) = state.realTeams(match);
    final isLive = live?.isLive == true;
    final finished = live?.isFinished == true;

    // En vivo (lista normal): marcador estilo transmisión.
    if (isLive && !dense) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MatchDetailScreen(matchNo: match.no),
              ),
            ),
            child: LiveScorebug(match: match),
          ),
        ),
      );
    }

    Widget center;
    if ((isLive || finished) && live?.homeScore != null) {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${live!.homeScore} – ${live.awayScore}',
            style: outfit(dense ? 19 : 24, FontWeight.w900),
          ),
          if (live.hasPens)
            Text(
              live.penText(strings.penaltyMark),
              style: outfit(10, FontWeight.w800, color: Wc.goldHi),
            ),
          const SizedBox(height: 3),
          if (isLive)
            LiveBadge(text: live.detail.isEmpty ? strings.live : live.detail)
          else
            Text(
              strings.finalLabel,
              style: outfit(10.5, FontWeight.w800, color: Wc.mint),
            ),
        ],
      );
    } else {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fmtTime(match.dateUtc),
            style: outfit(dense ? 16 : 20, FontWeight.w800, color: Wc.goldHi),
          ),
          const SizedBox(height: 3),
          Text(
            fmtDayShort(match.dateUtc, strings.locale),
            style: outfit(10.5, FontWeight.w600, color: Wc.textDim),
          ),
        ],
      );
    }

    return GradientCard(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchDetailScreen(matchNo: match.no)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Pill(
                match.stage == Stage.group
                    ? '${strings.matchShort}${match.no} · ${strings.groupUpper} ${match.group}'
                    : '${strings.matchShort}${match.no} · ${strings.stageShortLabel(match.stage).toUpperCase()}',
                color: Wc.textDim,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  match.venue,
                  overflow: TextOverflow.ellipsis,
                  style: outfit(11, FontWeight.w500, color: Wc.textDim),
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: TeamCell(
                  team: home,
                  placeholder: _ph(state, match.homeSlot),
                  displayName: home == null ? null : strings.teamName(home),
                ),
              ),
              SizedBox(width: 90, child: Center(child: center)),
              Expanded(
                child: TeamCell(
                  team: away,
                  placeholder: _ph(state, match.awaySlot),
                  displayName: away == null ? null : strings.teamName(away),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (state.channelsFor(match) case final ch when ch.isNotEmpty) ...[
            SizedBox(height: dense ? 6 : 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.live_tv, size: 12, color: Wc.textDim),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    ch.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: outfit(10.5, FontWeight.w600, color: Wc.textDim),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
