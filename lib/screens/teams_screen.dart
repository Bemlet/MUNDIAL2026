/// Pestaña Equipos: las 48 selecciones, con buscador.
library;

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets.dart';
import 'team_detail.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    final q = query.trim().toLowerCase();
    final teams =
        state.teams.values
            .where(
              (t) =>
                  q.isEmpty ||
                  t.name.toLowerCase().contains(q) ||
                  t.espn.toLowerCase().contains(q) ||
                  t.id.toLowerCase().contains(q) ||
                  t.group.toLowerCase() == q,
            )
            .toList()
          ..sort((a, b) {
            final g = a.group.compareTo(b.group);
            return g != 0 ? g : a.rank - b.rank;
          });

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(l.teamsTitle, style: outfit(22, FontWeight.w900)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              style: outfit(14, FontWeight.w600),
              decoration: InputDecoration(
                hintText: l.searchTeamOrGroup,
                hintStyle: outfit(14, FontWeight.w500, color: Wc.textDim),
                prefixIcon: Icon(Icons.search, color: Wc.textDim),
                filled: true,
                fillColor: Wc.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Wc.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Wc.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Wc.gold),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .92,
            ),
            itemCount: teams.length,
            itemBuilder: (_, i) {
              final t = teams[i];
              return GradientCard(
                padding: const EdgeInsets.all(8),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamDetailScreen(teamId: t.id),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(tag: 'flag-${t.id}', child: FlagImg(t.flag, size: 52)),
                    const SizedBox(height: 8),
                    Text(
                      l.teamName(t),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: outfit(12, FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l.group(t.group),
                      style: outfit(10, FontWeight.w600, color: Wc.textDim),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
