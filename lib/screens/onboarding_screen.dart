/// Onboarding de primera apertura: carrusel de 4 slides que presenta la app.
/// Se muestra solo cuando `AppState.onboardingDone` es false; "Saltar" o
/// "Comenzar" lo marcan como visto.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../main.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(int total) {
    if (_page >= total - 1) {
      AppScope.of(context).completeOnboarding();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;

    final slides = <_SlideData>[
      _SlideData(
        icon: Icons.emoji_events,
        gradient: Wc.championGradient,
        title: l.onbWelcomeTitle,
        body: l.onbWelcomeBody,
        showLanguagePicker: true,
      ),
      _SlideData(
        icon: Icons.sports_soccer,
        gradient: Wc.heroGradient,
        title: l.onbLiveTitle,
        body: l.onbLiveBody,
      ),
      _SlideData(
        icon: Icons.leaderboard,
        gradient: Wc.heroGradient,
        title: l.onbStatsTitle,
        body: l.onbStatsBody,
      ),
      _SlideData(
        icon: Icons.badge,
        gradient: Wc.heroGradient,
        title: l.onbPlayersTitle,
        body: l.onbPlayersBody,
      ),
      _SlideData(
        icon: Icons.leaderboard,
        gradient: Wc.finalGradient,
        title: l.onbPlayTitle,
        body: l.onbPlayBody,
      ),
    ];
    final isLast = _page == slides.length - 1;

    return Scaffold(
      backgroundColor: Wc.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior: Saltar (oculto en la última slide).
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLast
                        ? null
                        : () => state.completeOnboarding(),
                    child: Text(
                      l.onbSkip,
                      style: outfit(14, FontWeight.w700, color: Wc.textDim),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _Slide(data: slides[i], state: state),
              ),
            ),
            _Dots(count: slides.length, active: _page),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Wc.gold,
                    foregroundColor: Wc.onGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _next(slides.length),
                  child: Text(
                    isLast ? l.onbStart : l.onbNext,
                    style: outfit(16, FontWeight.w800, color: Wc.onGold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String body;
  final bool showLanguagePicker;

  const _SlideData({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.body,
    this.showLanguagePicker = false,
  });
}

class _Slide extends StatelessWidget {
  final _SlideData data;
  final AppState state;
  const _Slide({required this.data, required this.state});

  @override
  Widget build(BuildContext context) {
    final l = state.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              gradient: data.gradient,
              shape: BoxShape.circle,
              border: Border.all(color: Wc.gold.withValues(alpha: .4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Wc.gold.withValues(alpha: .18),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(data.icon, size: 60, color: Wc.goldHi),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: outfit(28, FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: outfit(15.5, FontWeight.w500, color: Wc.textSoft, height: 1.4),
          ),
          if (data.showLanguagePicker) ...[
            const SizedBox(height: 32),
            _LanguagePicker(state: state, strings: l),
          ],
        ],
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final AppState state;
  final AppStrings strings;
  const _LanguagePicker({required this.state, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          strings.onbChooseLanguage,
          style: outfit(12.5, FontWeight.w700, color: Wc.textDim),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final lang in AppLanguage.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _LangChip(
                  label: lang.label,
                  selected: state.language == lang,
                  onTap: () => state.setLanguage(lang),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Wc.gold.withValues(alpha: .18) : Wc.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Wc.goldHi : Wc.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: outfit(
              14,
              selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Wc.goldHi : Wc.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;
  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? Wc.gold : Wc.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
