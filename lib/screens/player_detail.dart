/// Carta de jugador estilo ficha: foto/avatar, valoración global, radar de
/// habilidades curadas y stats reales del torneo cuando el jugador ya jugó.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics_service.dart';
import '../app_state.dart';
import '../l10n.dart';
import '../main.dart';
import '../players.dart';
import '../theme.dart';
import '../widgets.dart';

/// Abre la carta de un jugador. Si no tiene perfil curado, la carta trae su
/// reseña y foto de Wikipedia a demanda.
void openPlayerProfile(
  BuildContext context,
  AppState state, {
  required String name,
  required String teamId,
  String? espnId,
}) {
  if (name.trim().isEmpty) return;
  final profile = state.players.lookup(name);
  final tour = state.playerTournament(name);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerDetailScreen(
        name: name,
        teamId: teamId.isNotEmpty ? teamId : (profile?.teamId ?? ''),
        espnId: espnId ?? tour?.espnId,
      ),
    ),
  );
}

class PlayerDetailScreen extends StatefulWidget {
  final String name;
  final String teamId;
  final String? espnId;

  const PlayerDetailScreen({
    super.key,
    required this.name,
    required this.teamId,
    this.espnId,
  });

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  Future<PlayerEnrichment?>? _enrich;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('player_detail');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Solo para jugadores sin perfil curado: traer bio + foto de Wikipedia.
    if (_enrich == null) {
      final state = AppScope.of(context);
      if (state.players.lookup(widget.name) == null) {
        _enrich = state.enrichPlayer(widget.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.players.lookup(widget.name);
    if (profile != null) return _content(state, profile, null);
    return FutureBuilder<PlayerEnrichment?>(
      future: _enrich,
      builder: (_, snap) => _content(state, null, snap.data),
    );
  }

  Widget _content(
    AppState state,
    PlayerProfile? profile,
    PlayerEnrichment? enrich,
  ) {
    final l = state.l10n;
    final tour = state.playerTournament(widget.name);
    final team = state.teams[widget.teamId];
    final photoUrl = profile?.photo ?? enrich?.photo;
    final photoId = widget.espnId ?? tour?.espnId;
    final bio = profile?.bio(isEn: l.isEn) ?? enrich?.bio(isEn: l.isEn);
    final loadingBio = profile == null &&
        enrich == null &&
        (_enrich != null);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _Header(
                  state: state,
                  name: widget.name,
                  teamId: widget.teamId,
                  profile: profile,
                  photoUrl: photoUrl,
                  photoId: photoId,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              sliver: SliverList.list(
                children: [
                  if (bio != null && bio.isNotEmpty) ...[
                    SectionTitle(l.playerAbout),
                    GradientCard(
                      child: Text(
                        bio,
                        style: outfit(13.5, FontWeight.w500,
                            color: Wc.textSoft, height: 1.5),
                      ),
                    ),
                  ] else if (loadingBio) ...[
                    SectionTitle(l.playerAbout),
                    const GradientCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (profile != null) ...[
                    SectionTitle(l.playerSkills),
                    _SkillsCard(state: state, profile: profile),
                  ],
                  SectionTitle(l.playerTournamentTitle),
                  _TournamentCard(state: state, tour: tour, team: team),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      profile != null
                          ? l.playerCuratedNote
                          : (bio != null || photoUrl != null
                              ? l.playerWikiNote
                              : ''),
                      style: outfit(11, FontWeight.w500, color: Wc.textDim),
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
}

// --------------------------------------------------------------- encabezado

class _Header extends StatelessWidget {
  final AppState state;
  final String name;
  final String teamId;
  final PlayerProfile? profile;
  final String? photoUrl;
  final String? photoId;

  const _Header({
    required this.state,
    required this.name,
    required this.teamId,
    required this.profile,
    required this.photoUrl,
    required this.photoId,
  });

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final team = state.teams[teamId];
    return Container(
      decoration: BoxDecoration(gradient: Wc.heroGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  _Avatar(
                    name: name,
                    photoUrl: photoUrl,
                    photoId: photoId,
                  ),
                  if (profile != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _OverallBadge(value: profile!.overall, l: l),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: outfit(24, FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (team != null) ...[
                    FlagImg(team.flag, size: 24),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        l.teamName(team),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: outfit(14, FontWeight.w700, color: Wc.textSoft),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (profile != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(l.posLabel(profile!.pos).toUpperCase(), color: Wc.goldHi),
                    if (profile!.club.isNotEmpty)
                      Pill(profile!.club, color: Wc.mint),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl; // foto curada (Wikimedia)
  final String? photoId; // id de atleta ESPN (fallback)
  const _Avatar({required this.name, this.photoUrl, this.photoId});

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    final fallback = _Initials(name: name, size: size);
    final url = (photoUrl != null && photoUrl!.isNotEmpty)
        ? photoUrl
        : (photoId != null && photoId!.isNotEmpty)
            ? 'https://a.espncdn.com/i/headshots/soccer/players/full/$photoId.png'
            : null;
    final child = url == null
        ? fallback
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // Sesgo hacia arriba: en fotos de cuerpo la cara queda en el tercio superior.
            alignment: const Alignment(0, -0.35),
            headers: const {'User-Agent': 'Golazo-WC2026/1.0'},
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
          );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Wc.surface,
        border: Border.all(color: Wc.gold.withValues(alpha: .7), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(child: child),
    );
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final double size;
  const _Initials({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'
        : (name.isNotEmpty ? name[0] : '?');
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: Wc.finalGradient,
      ),
      child: Text(
        initials.toUpperCase(),
        style: outfit(size * .38, FontWeight.w900, color: Wc.gold),
      ),
    );
  }
}

class _OverallBadge extends StatelessWidget {
  final int value;
  final AppStrings l;
  const _OverallBadge({required this.value, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Wc.gold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Wc.bg, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: outfit(18, FontWeight.w900, color: Wc.onGold)),
          Text(
            l.playerOverall,
            style: outfit(8, FontWeight.w800, color: Wc.onGold, spacing: .5),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- habilidades

class _SkillsCard extends StatelessWidget {
  final AppState state;
  final PlayerProfile profile;
  const _SkillsCard({required this.state, required this.profile});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    final values = [for (final k in kSkillOrder) (profile.skills[k] ?? 50) / 99];
    final labels = [for (final k in kSkillOrder) l.skillShort(k)];
    return GradientCard(
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _RadarPainter(
                values: values,
                labels: labels,
                gridColor: Wc.line,
                fillColor: Wc.gold,
                labelColor: Wc.textDim,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          for (final k in kSkillOrder)
            _SkillBar(
              label: l.skillLabel(k),
              value: profile.skills[k] ?? 50,
            ),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final String label;
  final int value;
  const _SkillBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 85
        ? Wc.gold
        : value >= 70
            ? Wc.mint
            : Wc.textSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: outfit(12.5, FontWeight.w700, color: Wc.textSoft),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 99,
                minHeight: 8,
                backgroundColor: Wc.line,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 26,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: outfit(13, FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Radar hexagonal de las seis habilidades.
class _RadarPainter extends CustomPainter {
  final List<double> values; // 0..1
  final List<String> labels;
  final Color gridColor;
  final Color fillColor;
  final Color labelColor;

  _RadarPainter({
    required this.values,
    required this.labels,
    required this.gridColor,
    required this.fillColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 26;
    final n = values.length;
    double angle(int i) => -math.pi / 2 + i * 2 * math.pi / n;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = gridColor
      ..strokeWidth = 1;

    // Anillos concéntricos.
    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = center + Offset(math.cos(angle(i)) * r, math.sin(angle(i)) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }

    // Ejes.
    for (var i = 0; i < n; i++) {
      final p =
          center + Offset(math.cos(angle(i)) * radius, math.sin(angle(i)) * radius);
      canvas.drawLine(center, p, grid);
    }

    // Polígono de valores.
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor.withValues(alpha: .22);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = fillColor
      ..strokeWidth = 2;
    final poly = Path();
    for (var i = 0; i < n; i++) {
      final r = radius * values[i].clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angle(i)) * r, math.sin(angle(i)) * r);
      i == 0 ? poly.moveTo(p.dx, p.dy) : poly.lineTo(p.dx, p.dy);
    }
    poly.close();
    canvas.drawPath(poly, fill);
    canvas.drawPath(poly, stroke);

    final dot = Paint()..color = fillColor;
    for (var i = 0; i < n; i++) {
      final r = radius * values[i].clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angle(i)) * r, math.sin(angle(i)) * r);
      canvas.drawCircle(p, 2.5, dot);
    }

    // Etiquetas.
    for (var i = 0; i < n; i++) {
      final p = center +
          Offset(math.cos(angle(i)) * (radius + 16),
              math.sin(angle(i)) * (radius + 16));
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: outfit(10.5, FontWeight.w800, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values || old.labels != labels;
}

// ----------------------------------------------------------- stats torneo

class _TournamentCard extends StatelessWidget {
  final AppState state;
  final PlayerTournament? tour;
  final dynamic team;
  const _TournamentCard({required this.state, required this.tour, this.team});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    if (tour == null || tour!.isEmpty) {
      return GradientCard(
        child: Row(
          children: [
            Icon(Icons.query_stats, color: Wc.textDim, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.playerNoTournament,
                style: outfit(13, FontWeight.w600, color: Wc.textDim),
              ),
            ),
          ],
        ),
      );
    }
    final t = tour!;
    final chips = <Widget>[
      if (t.goals > 0) _StatChip(icon: Icons.sports_soccer, value: '${t.goals}', label: l.statGoals),
      if (t.assists > 0) _StatChip(icon: Icons.handshake, value: '${t.assists}', label: l.statAssists),
      if (t.saves > 0) _StatChip(icon: Icons.back_hand, value: '${t.saves}', label: l.statSaves),
      if (t.cleanSheets > 0) _StatChip(icon: Icons.shield, value: '${t.cleanSheets}', label: l.statCleanSheets),
      if (t.penalties > 0) _StatChip(icon: Icons.sports, value: '${t.penalties}', label: l.statPenalties),
      if (t.yellow + t.red > 0)
        _StatChip(icon: Icons.style, value: '${t.yellow + t.red}', label: l.fairPlay),
    ];
    return GradientCard(
      child: Wrap(spacing: 10, runSpacing: 10, children: chips),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Wc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Wc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Wc.gold, size: 18),
          const SizedBox(height: 6),
          Text(value, style: outfit(20, FontWeight.w900)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: outfit(10.5, FontWeight.w600, color: Wc.textDim),
          ),
        ],
      ),
    );
  }
}
