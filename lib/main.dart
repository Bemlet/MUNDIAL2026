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
    const pages = [
      MatchesScreen(),
      GroupsScreen(),
      BracketScreen(),
      StatsScreen(),
      PredictionScreen(),
      TeamsScreen(),
    ];
    final l = state.l10n;
    return Scaffold(
      // SafeArea: la UI no se superpone con la barra de estado ni con la
      // barra de navegación del sistema.
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
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
  }
}
