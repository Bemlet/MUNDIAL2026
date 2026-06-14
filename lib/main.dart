import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_state.dart';
import 'l10n.dart';
import 'notification_service.dart';
import 'screens/bracket_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/prediction_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/teams_screen.dart';
import 'theme.dart';
import 'widgets/coach_tour.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await initializeDateFormatting('en');
  await NotificationService.initialize();
  Intl.defaultLocale = 'es';
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const Mundial26App());
}

/// Acceso al estado global mediante InheritedNotifier.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class Mundial26App extends StatefulWidget {
  const Mundial26App({super.key});

  @override
  State<Mundial26App> createState() => _Mundial26AppState();
}

class _Mundial26AppState extends State<Mundial26App> {
  final AppState state = AppState();
  Timer? _liveSyncTimer;

  @override
  void initState() {
    super.initState();
    state.load();
    _liveSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.loaded) state.sync();
      if (state.loaded) state.checkMatchReminders();
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (_, _) => MaterialApp(
          title: state.l10n.appTitle,
          locale: Locale(state.language.code),
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const Shell(),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  bool _exactAlarmPromptChecked = false;
  int? _tourStep; // null = tour inactivo
  bool _tourStarted = false;

  void _maybeStartTour(AppState state) {
    if (_tourStarted || !state.shouldRunTour) return;
    _tourStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tourStep = 0);
    });
  }

  List<TourStep> _tourSteps(AppStrings l) => [
    TourStep(icon: Icons.sports_soccer, title: l.matchesTab, description: l.tourMatchesDesc),
    TourStep(icon: Icons.table_chart, title: l.groupsTab, description: l.tourGroupsDesc),
    TourStep(icon: Icons.account_tree, title: l.bracketTab, description: l.tourBracketDesc),
    TourStep(icon: Icons.leaderboard, title: l.statsTab, description: l.tourStatsDesc),
    TourStep(icon: Icons.auto_awesome, title: l.simulatorTab, description: l.tourSimulatorDesc),
    TourStep(icon: Icons.flag, title: l.teamsTab, description: l.tourTeamsDesc),
  ];

  void _tourNext(int total) {
    final current = _tourStep ?? 0;
    if (current >= total - 1) {
      _tourFinish();
    } else {
      setState(() => _tourStep = current + 1);
    }
  }

  void _tourFinish() {
    AppScope.of(context).completeTour();
    setState(() => _tourStep = null);
  }

  void _maybePromptExactAlarm(BuildContext context, AppState state) {
    if (_exactAlarmPromptChecked || !state.shouldPromptExactAlarm) return;
    _exactAlarmPromptChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showExactAlarmDialog(context, state);
    });
  }

  Future<void> _showExactAlarmDialog(BuildContext context, AppState state) {
    final l = state.l10n;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.exactAlarmTitle, style: outfit(18, FontWeight.w800)),
        content: Text(
          l.exactAlarmBody,
          style: outfit(14, FontWeight.w500, color: Wc.textSoft, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              state.markExactAlarmAsked();
            },
            child: Text(
              l.exactAlarmNotNow,
              style: outfit(13, FontWeight.w700, color: Wc.textDim),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Wc.gold,
              foregroundColor: Wc.onGold,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              state.requestExactAlarm();
            },
            child: Text(l.exactAlarmEnable, style: outfit(13, FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.loaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Wc.gold)),
      );
    }
    if (!state.onboardingDone) {
      return const OnboardingScreen();
    }
    _maybeStartTour(state);
    _maybePromptExactAlarm(context, state);
    const pages = [
      MatchesScreen(),
      GroupsScreen(),
      BracketScreen(),
      StatsScreen(),
      PredictionScreen(),
      TeamsScreen(),
    ];
    final l = state.l10n;
    // Durante el tour, la pestaña mostrada sigue al paso para "llevar" al usuario.
    final shown = _tourStep ?? index;
    final scaffold = Scaffold(
      // SafeArea: la UI no se superpone con la barra de estado ni con la
      // barra de navegación del sistema.
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          child: KeyedSubtree(key: ValueKey(shown), child: pages[shown]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shown,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: l.matchesTab,
          ),
          NavigationDestination(
            icon: Icon(Icons.table_chart_outlined),
            selectedIcon: Icon(Icons.table_chart),
            label: l.groupsTab,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: l.bracketTab,
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: l.statsTab,
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: l.simulatorTab,
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: l.teamsTab,
          ),
        ],
      ),
    );

    if (_tourStep == null) return scaffold;
    final steps = _tourSteps(l);
    final current = _tourStep!.clamp(0, steps.length - 1);
    return Stack(
      children: [
        scaffold,
        CoachTour(
          steps: steps,
          index: current,
          tabCount: steps.length,
          nextLabel: current >= steps.length - 1 ? l.tourDoneLabel : l.tourNext,
          skipLabel: l.tourSkip,
          stepLabel: l.tourStep(current + 1, steps.length),
          onNext: () => _tourNext(steps.length),
          onSkip: _tourFinish,
        ),
      ],
    );
  }
}
