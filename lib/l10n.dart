import 'models.dart';

enum AppLanguage { es, en }

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.es ? 'es' : 'en';
  String get label => this == AppLanguage.es ? 'Español' : 'English';
}

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get isEn => language == AppLanguage.en;
  String get locale => language.code;

  String get appTitle => 'Golazo';
  String get matchesTab => isEn ? 'Matches' : 'Partidos';
  String get groupsTab => isEn ? 'Groups' : 'Grupos';
  String get bracketTab => isEn ? 'Bracket' : 'Bracket';
  String get simulatorTab => isEn ? 'Simulator' : 'Simulador';
  String get teamsTab => isEn ? 'Teams' : 'Equipos';
  String get languageTooltip => isEn ? 'Language' : 'Idioma';
  String get darkMode => isEn ? 'Dark mode' : 'Modo oscuro';
  String get lightMode => isEn ? 'Light mode' : 'Modo claro';
  String get refreshResults =>
      isEn ? 'Refresh results' : 'Actualizar resultados';
  String get hostCountries => isEn
      ? 'United States · Mexico · Canada'
      : 'Estados Unidos · México · Canadá';
  String get localTimeNotice => isEn
      ? 'Times shown in your phone time zone'
      : 'Horarios en la zona horaria de tu celular';
  String get searchTeamHint => isEn
      ? 'Search team: Colombia, ARG, Mexico...'
      : 'Buscar selección: Colombia, ARG, México...';
  String get clearSearch => isEn ? 'Clear search' : 'Limpiar búsqueda';
  String get noConfirmedMatches => isEn
      ? 'No confirmed matches for this search.'
      : 'No hay partidos confirmados para esa búsqueda.';
  String get noMatchesForFilter => isEn
      ? 'No matches for this filter.'
      : 'No hay partidos para este filtro.';
  String get knockoutOnlyConfirmed => isEn
      ? 'Knockout matches appear only when the team is already confirmed.'
      : 'Las eliminatorias solo aparecen cuando el equipo ya está definido.';
  String get all => isEn ? 'All' : 'Todos';
  String get today => isEn ? 'Today' : 'Hoy';
  String get groupStage => isEn ? 'Group stage' : 'Fase de grupos';
  String get knockoutStage => isEn ? 'Knockout' : 'Eliminatorias';
  String get live => isEn ? 'LIVE' : 'EN VIVO';
  String get now => isEn ? 'NOW' : 'AHORA';
  String get nextMatch => isEn ? 'NEXT MATCH' : 'PRÓXIMO PARTIDO';
  String get startingSoon => isEn ? 'Starting soon' : 'Por iniciar';
  String get localTime => isEn ? 'local time' : 'hora local';
  String get localPhoneTime =>
      isEn ? 'phone local time' : 'hora local del celular';
  String get finished => isEn ? 'FINISHED' : 'FINALIZADO';
  String get finalLabel => isEn ? 'FINAL' : 'FINAL';
  String get match => isEn ? 'MATCH' : 'PARTIDO';
  String get matchShort => isEn ? 'M' : 'P';
  String get groupUpper => isEn ? 'GROUP' : 'GRUPO';
  String group(String group) => isEn ? 'Group $group' : 'Grupo $group';
  String get noMatchesPlayed => isEn ? 'No matches' : 'Sin partidos';
  String get teamHeader => isEn ? 'Team' : 'Equipo';
  String get playedHeader => isEn ? 'P' : 'PJ';
  String get winsHeader => isEn ? 'W' : 'G';
  String get drawsHeader => isEn ? 'D' : 'E';
  String get lossesHeader => isEn ? 'L' : 'P';
  String get goalDiffHeader => isEn ? 'GD' : 'DG';
  String get pointsHeader => 'PTS';
  String get bestThirds =>
      isEn ? 'Best third-placed teams' : 'Mejores terceros';
  String get eightQualify => isEn ? '8 QUALIFY' : '8 CLASIFICAN';
  String get yourPredictionUpper => isEn ? 'YOUR PREDICTION' : 'TU PRONÓSTICO';
  String get bestThirdsRealHelp => isEn
      ? 'The 8 best third-placed teams advance to the round of 32.'
      : 'Los 8 mejores terceros avanzan a dieciseisavos.';
  String get bestThirdsPredHelp => isEn
      ? 'Based on your predictions, these third-placed teams would advance.'
      : 'Según tus pronósticos, estos terceros avanzarían.';
  String get pts => isEn ? 'pts' : 'pts';
  String get realResultsUpper => isEn ? 'REAL RESULTS' : 'RESULTADOS REALES';
  String get roundOf32 => isEn ? 'Round of 32' : 'Dieciseisavos';
  String get roundOf16 => isEn ? 'Round of 16' : 'Octavos';
  String get quarterfinals => isEn ? 'Quarterfinals' : 'Cuartos';
  String get semifinals => isEn ? 'Semifinals' : 'Semifinales';
  String get thirdPlaceUpper => isEn ? 'THIRD PLACE' : 'TERCER PUESTO';
  String get grandFinalUpper => isEn ? 'GRAND FINAL' : 'GRAN FINAL';
  String get teamsTitle => isEn ? 'Teams' : 'Selecciones';
  String get searchTeamOrGroup =>
      isEn ? 'Search team or group...' : 'Buscar selección o grupo…';
  String get fifaRanking =>
      isEn ? 'FIFA ranking\n(Nov. 2025)' : 'Ranking FIFA\n(nov. 2025)';
  String get worldCupsPlayed =>
      isEn ? 'World Cups\nplayed' : 'Mundiales\njugados';
  String get worldTitles => isEn ? 'World\ntitles' : 'Títulos\nmundiales';
  String get bestResultUpper => isEn ? 'BEST RESULT' : 'MEJOR RESULTADO';
  String get confederationUpper => isEn ? 'CONFEDERATION' : 'CONFEDERACIÓN';
  String get stars => isEn ? 'Stars' : 'Figuras';
  String get teamMatches => isEn ? 'Their matches' : 'Sus partidos';
  String get knockoutIfAdvance => isEn
      ? 'If this team advances to the knockouts, its matches will appear here.'
      : 'Si avanza a eliminatorias, sus llaves aparecerán aquí.';
  String get predictionProgress =>
      isEn ? 'Your prediction progress' : 'Progreso de tus pronósticos';
  String predictedMatches(int count) =>
      isEn ? '$count / 104 matches' : '$count / 104 partidos';
  String get simulateRemaining =>
      isEn ? 'Simulate remaining' : 'Simular lo que falta';
  String get clearAll => isEn ? 'Clear all' : 'Borrar todo';
  String get quickSimulation => isEn ? 'Quick simulation' : 'Simulación rápida';
  String get quickSimulationBody => isEn
      ? 'All matches you have not predicted yet will be filled at random, weighted by FIFA ranking. Existing predictions are not changed.'
      : 'Se llenarán al azar (ponderado por ranking FIFA) todos los partidos que aún no hayas pronosticado. Tus pronósticos existentes no se tocan.';
  String get cancel => isEn ? 'Cancel' : 'Cancelar';
  String get simulateAction => isEn ? 'Simulate!' : '¡Simular!';
  String get clearPredictionsTitle =>
      isEn ? 'Clear your predictions?' : '¿Borrar tus pronósticos?';
  String get clearPredictionsBody => isEn
      ? 'All your predictions will be deleted. This cannot be undone.'
      : 'Se eliminarán todos tus pronósticos. No hay vuelta atrás.';
  String get simulateThisGroup =>
      isEn ? 'Simulate this group' : 'Simular este grupo';
  String get completeGroupsForThirds => isEn
      ? 'Predict full groups to see the best third-placed table here.'
      : 'Pronostica grupos completos para ver aquí la tabla de mejores terceros.';
  String get completeAllGroupsForBracketThirds => isEn
      ? 'Complete all 12 groups so the bracket can assign the 8 best third-placed teams.'
      : 'Completa los 12 grupos para que el bracket asigne a los 8 mejores terceros.';
  String get yourWorldChampionUpper =>
      isEn ? 'YOUR WORLD CHAMPION' : 'TU CAMPEÓN DEL MUNDO';
  String get completeGroupsForBracket => isEn
      ? 'Complete the group stage to unlock your bracket. You can also use the dice to simulate what is missing.'
      : 'Completa la fase de grupos para desbloquear tu bracket. También puedes usar el dado para simular lo que falta.';
  String get unknownKnockoutTeams => isEn
      ? 'The teams in this matchup are not known yet: complete the previous rounds.'
      : 'Aún no se conocen los equipos de esta llave: completa las rondas previas.';
  String get tiePenaltyQuestion => isEn
      ? 'Draw: who advances on penalties?'
      : 'Empate: ¿quién avanza por penales?';
  String get remove => isEn ? 'Remove' : 'Quitar';
  String get save => isEn ? 'Save' : 'Guardar';
  String get removePrediction =>
      isEn ? 'Remove prediction' : 'Quitar pronóstico';
  String get yourPrediction => isEn ? 'Your prediction' : 'Tu pronóstico';
  String get groupStandings => isEn ? 'Group standings' : 'Así va el grupo';
  String get previewHeadToHead =>
      isEn ? 'Preview · head to head' : 'Previa · cara a cara';
  String get worldCups => isEn ? 'World Cups' : 'Mundiales';
  String get titles => isEn ? 'Titles' : 'Títulos';
  String get howThisTieIsDecided =>
      isEn ? 'How this matchup is decided' : 'Cómo se define esta llave';
  String get goalsAndCards => isEn ? 'Goals & cards' : 'Goles y tarjetas';
  String get whereToWatch => isEn ? 'Where to watch' : 'Dónde verlo';
  String get broadcastCountry => isEn ? 'TV country' : 'País de TV';
  String get selectCountry =>
      isEn ? 'Choose your country' : 'Elegí tu país';
  String get stadiumCapacity =>
      isEn ? 'Stadium capacity' : 'Capacidad del estadio';
  String spectators(String value) =>
      isEn ? '$value spectators' : '$value espectadores';
  String get exactScore => isEn ? 'Exact score!' : '¡Marcador exacto!';
  String get correctOutcome =>
      isEn ? 'You got the result right' : 'Acertaste el resultado';
  String get wrongPrediction => isEn ? 'Not this time' : 'Esta vez no fue';
  String get byPenalties => isEn ? 'on penalties' : 'por penales';
  String get notificationGoal => isEn ? 'Goal in' : 'Gol en';
  String get notificationKickoffTitle =>
      isEn ? 'Match starting soon' : 'Partido por comenzar';
  String get notificationFinalTitle =>
      isEn ? 'Full time' : 'Partido finalizado';
  String get exactAlarmTitle =>
      isEn ? 'Enable live goal alerts' : 'Activá los avisos de gol en vivo';
  String get exactAlarmBody => isEn
      ? 'To notify goals the instant they happen with the app closed, Android needs permission for exact alarms. Without it, you still get goals, just less immediately.'
      : 'Para avisarte los goles al instante con la app cerrada, Android necesita permiso de alarmas exactas. Sin él igual recibís los goles, pero con menos inmediatez.';
  String get exactAlarmEnable => isEn ? 'Enable' : 'Activar';
  String get exactAlarmNotNow => isEn ? 'Not now' : 'Ahora no';

  // ----------------------------------------------------------- tour guiado
  String get tourSkip => isEn ? 'Skip' : 'Saltar';
  String get tourNext => isEn ? 'Next' : 'Siguiente';
  String get tourDoneLabel => isEn ? 'Got it' : '¡Listo!';
  String tourStep(int i, int n) => isEn ? 'Step $i of $n' : 'Paso $i de $n';
  String get tourMatchesDesc => isEn
      ? 'Full schedule and live scores.'
      : 'El calendario completo y los resultados en vivo.';
  String get tourGroupsDesc =>
      isEn ? 'Standings for the 12 groups.' : 'Las tablas de los 12 grupos.';
  String get tourBracketDesc =>
      isEn ? 'The knockout bracket.' : 'El cuadro de eliminatorias.';
  String get tourStatsDesc => isEn
      ? 'Top scorers, assists and standout players, live.'
      : 'Goleadores, asistencias y figuras, en vivo.';
  String get tourSimulatorDesc => isEn
      ? 'Simulate the tournament and make predictions.'
      : 'Simulá el torneo y armá tus pronósticos.';
  String get tourTeamsDesc => isEn
      ? 'The 48 teams and their stars.'
      : 'Las 48 selecciones y sus figuras.';

  String startsIn(String text) => isEn ? 'starts $text.' : 'arranca $text.';
  String get inMoments => isEn ? 'in moments' : 'en instantes';
  String inMinutes(int minutes) => isEn ? 'in $minutes min' : 'en $minutes min';

  // ------------------------------------------------------------- onboarding
  String get onbSkip => isEn ? 'Skip' : 'Saltar';
  String get onbNext => isEn ? 'Next' : 'Siguiente';
  String get onbStart => isEn ? 'Get started' : 'Comenzar';
  String get onbChooseLanguage =>
      isEn ? 'Choose your language' : 'Elegí tu idioma';
  String get onbWelcomeTitle => 'Golazo';
  String get onbWelcomeBody => isEn
      ? 'Your companion for the whole tournament: 48 teams, 104 matches, all in one place.'
      : 'Tu compañero para todo el torneo: 48 selecciones, 104 partidos, todo en un solo lugar.';
  String get onbLiveTitle => isEn ? 'Follow it live' : 'Seguilo en vivo';
  String get onbLiveBody => isEn
      ? 'Real schedule, live scores, group standings and the full bracket as it unfolds.'
      : 'Calendario real, resultados en vivo, tablas de grupos y el bracket completo a medida que avanza.';
  String get onbStatsTitle => isEn ? 'Live statistics' : 'Estadísticas en vivo';
  String get onbStatsBody => isEn
      ? 'Top scorers, assists and standout players updated in real time as goals go in.'
      : 'Goleadores, asistencias y figuras del torneo actualizados en tiempo real con cada gol.';
  String get onbPlayTitle => isEn ? 'Play along' : 'Jugá vos';
  String get onbPlayBody => isEn
      ? 'Simulate the tournament, build your bracket and predict every match.'
      : 'Simulá el torneo, armá tu bracket y predecí cada partido.';

  // ----------------------------------------------------------- estadísticas
  String get statsTab => isEn ? 'Stats' : 'Stats';
  String get statsTitle => isEn ? 'Statistics' : 'Estadísticas';
  String get statsLiveNote => isEn
      ? 'Live data from the official feed'
      : 'Datos en vivo del feed oficial';
  String get statsEmpty => isEn
      ? 'Stats will appear once the matches kick off.'
      : 'Las estadísticas aparecerán cuando arranquen los partidos.';
  String get statsTabScorers => isEn ? 'Scorers' : 'Goleadores';
  String get statsTabDiscipline => isEn ? 'Discipline' : 'Disciplina';
  String get statsTabTeams => isEn ? 'Teams' : 'Equipos';
  String get statsTabSummary => isEn ? 'Summary' : 'Resumen';
  String get goldenBoot => isEn ? 'Golden Boot' : 'Bota de Oro';
  String get topScorers => isEn ? 'Top scorers' : 'Goleadores';
  String get topAssists => isEn ? 'Assists' : 'Asistencias';
  String get goalkeepers => isEn ? 'Goalkeepers' : 'Arqueros';
  String get standoutPlayers => isEn ? 'Standout players' : 'Figuras del torneo';
  String get standoutNote => isEn
      ? 'Impact index computed by the app (goals, assists, clean sheets, saves).'
      : 'Índice de impacto calculado por la app (goles, asistencias, vallas, atajadas).';
  String get fairPlay => isEn ? 'Fair Play' : 'Juego limpio';
  String get fairPlayTeams => isEn ? 'Team Fair Play' : 'Juego limpio por equipo';
  String get bookedPlayers => isEn ? 'Most booked players' : 'Más amonestados';
  String get bestAttack => isEn ? 'Best attack' : 'Mejor ataque';
  String get bestDefense => isEn ? 'Best defense' : 'Mejor defensa';
  String get mostPossession => isEn ? 'Most possession' : 'Más posesión';
  String get tournamentNumbers =>
      isEn ? 'The tournament in numbers' : 'El torneo en números';
  String get statGoals => isEn ? 'Goals' : 'Goles';
  String get statAssists => isEn ? 'Assists' : 'Asistencias';
  String get statSaves => isEn ? 'Saves' : 'Atajadas';
  String get statCleanSheets => isEn ? 'Clean sheets' : 'Vallas invictas';
  String get statMatchesPlayed => isEn ? 'Matches played' : 'Partidos jugados';
  String get statTotalGoals => isEn ? 'Total goals' : 'Goles totales';
  String get statAvgGoals => isEn ? 'Goals per match' : 'Goles por partido';
  String get statPenalties => isEn ? 'Penalty goals' : 'Goles de penal';
  String get statHatTricks => isEn ? 'Hat-tricks' : 'Hat-tricks';
  String get statAttendance => isEn ? 'Total attendance' : 'Público total';
  String get statBiggestWin => isEn ? 'Biggest win' : 'Goleada del torneo';
  String get statPossession => isEn ? 'Possession' : 'Posesión';
  String get goalsAbbr => isEn ? 'G' : 'G';
  String get assistsAbbr => isEn ? 'A' : 'A';
  String get penaltyMark => isEn ? 'pen' : 'pen';
  String get perMatch => isEn ? '/match' : '/partido';
  String goalsCount(int n) => isEn
      ? '$n ${n == 1 ? 'goal' : 'goals'}'
      : '$n ${n == 1 ? 'gol' : 'goles'}';
  String assistsCount(int n) => isEn
      ? '$n ${n == 1 ? 'assist' : 'assists'}'
      : '$n ${n == 1 ? 'asistencia' : 'asistencias'}';
  String savesCount(int n) => isEn ? '$n saves' : '$n atajadas';

  String stageLabel(Stage stage) => switch (stage) {
    Stage.group => groupStage,
    Stage.r32 => isEn ? 'Round of 32' : 'Dieciseisavos de final',
    Stage.r16 => isEn ? 'Round of 16' : 'Octavos de final',
    Stage.qf => isEn ? 'Quarterfinals' : 'Cuartos de final',
    Stage.sf => isEn ? 'Semifinals' : 'Semifinales',
    Stage.third => isEn ? 'Third place' : 'Tercer puesto',
    Stage.finalMatch => isEn ? 'Final' : 'Final',
  };

  String stageShortLabel(Stage stage) => switch (stage) {
    Stage.group => groupsTab,
    Stage.r32 => isEn ? 'R32' : '16avos',
    Stage.r16 => isEn ? 'R16' : 'Octavos',
    Stage.qf => isEn ? 'QF' : 'Cuartos',
    Stage.sf => isEn ? 'Semis' : 'Semis',
    Stage.third => isEn ? '3rd place' : '3.er puesto',
    Stage.finalMatch => isEn ? 'Final' : 'Final',
  };

  String slotLabel(String slot) {
    if (slot.length == 2 && slot.startsWith('W')) {
      return isEn ? 'Winner Group ${slot[1]}' : '1.º Grupo ${slot[1]}';
    }
    if (slot.length == 2 && slot.startsWith('R')) {
      return isEn ? 'Runner-up Group ${slot[1]}' : '2.º Grupo ${slot[1]}';
    }
    if (slot.startsWith('T')) {
      final groups = slot.substring(1).split('').join('/');
      return isEn ? '3rd $groups' : '3.º $groups';
    }
    if (slot.startsWith('M')) {
      return isEn
          ? 'Winner M${slot.substring(1)}'
          : 'Ganador P${slot.substring(1)}';
    }
    if (slot.startsWith('L')) {
      return isEn
          ? 'Loser M${slot.substring(1)}'
          : 'Perdedor P${slot.substring(1)}';
    }
    return slot;
  }

  String teamName(Team team) => isEn ? team.espn : team.name;
  String teamBest(Team team) =>
      isEn ? _teamBestEn[team.id] ?? team.best : team.best;
  String teamNote(Team team) =>
      isEn ? _teamNoteEn[team.id] ?? team.note : team.note;

  String confRegion(String value) {
    if (!isEn) return value;
    return const {
          'Norte y Centroamérica': 'North and Central America',
          'África': 'Africa',
          'Asia': 'Asia',
          'Europa': 'Europe',
          'Sudamérica': 'South America',
          'Oceanía': 'Oceania',
        }[value] ??
        value;
  }

  String venueCity(String value) {
    if (!isEn) return value;
    return const {
          'Ciudad de México': 'Mexico City',
          'Nueva York / Nueva Jersey': 'New York / New Jersey',
          'Filadelfia': 'Philadelphia',
          'Los Ángeles (Inglewood)': 'Los Angeles (Inglewood)',
        }[value] ??
        value;
  }

  String venueCountry(String value) {
    if (!isEn) return value;
    return const {
          'México': 'Mexico',
          'Canadá': 'Canada',
          'EE. UU.': 'USA',
        }[value] ??
        value;
  }

  String groupPosition(int pos) =>
      isEn ? '${_ordinalEn(pos)} in group' : '$pos.º EN SU GRUPO';

  String rankingPosition(int pos) => isEn ? _ordinalEn(pos) : '$pos.º';
}

String _ordinalEn(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

const _teamBestEn = {
  'MEX': 'Quarterfinals (1970, 1986)',
  'RSA': 'Group stage',
  'KOR': 'Fourth place (2002)',
  'CZE': 'Runner-up as Czechoslovakia (1934, 1962)',
  'CAN': 'Group stage',
  'BIH': 'Group stage (2014)',
  'QAT': 'Group stage (2022)',
  'SUI': 'Quarterfinals (1934, 1938, 1954)',
  'BRA': 'Champion (1958, 1962, 1970, 1994, 2002)',
  'MAR': 'Fourth place (2022)',
  'SCO': 'Group stage',
  'HAI': 'Group stage (1974)',
  'USA': 'Semifinals (1930)',
  'PAR': 'Quarterfinals (2010)',
  'AUS': 'Round of 16 (2006, 2022)',
  'TUR': 'Third place (2002)',
  'GER': 'Champion (1954, 1974, 1990, 2014)',
  'CUW': 'Debut',
  'CIV': 'Group stage',
  'ECU': 'Round of 16 (2006)',
  'NED': 'Runner-up (1974, 1978, 2010)',
  'JPN': 'Round of 16 (2002, 2010, 2018, 2022)',
  'SWE': 'Runner-up (1958)',
  'TUN': 'Group stage',
  'BEL': 'Third place (2018)',
  'EGY': 'Group stage',
  'IRN': 'Group stage',
  'NZL': 'Group stage (unbeaten in 2010)',
  'ESP': 'Champion (2010)',
  'CPV': 'Debut',
  'KSA': 'Round of 16 (1994)',
  'URU': 'Champion (1930, 1950)',
  'FRA': 'Champion (1998, 2018)',
  'SEN': 'Quarterfinals (2002)',
  'IRQ': 'Group stage (1986)',
  'NOR': 'Round of 16 (1998)',
  'ARG': 'Champion (1978, 1986, 2022)',
  'ALG': 'Round of 16 (2014)',
  'AUT': 'Third place (1954)',
  'JOR': 'Debut',
  'POR': 'Third place (1966)',
  'COD': 'Group stage (1974, as Zaire)',
  'UZB': 'Debut',
  'COL': 'Quarterfinals (2014)',
  'ENG': 'Champion (1966)',
  'CRO': 'Runner-up (2018)',
  'GHA': 'Quarterfinals (2010)',
  'PAN': 'Group stage (2018)',
};

const _teamNoteEn = {
  'MEX':
      'Host for the third time in its history: no country has hosted more World Cups. Opened the tournament at the Azteca with a win.',
  'RSA':
      'Bafana Bafana return to a World Cup they are not hosting for the first time since 2002.',
  'KOR':
      'Eleventh consecutive appearance, a streak only surpassed by the major powers.',
  'CZE':
      'First qualification as the Czech Republic since 2006; heir to historic Czechoslovakia.',
  'CAN':
      'Co-host with its best generation ever; chasing its first World Cup win at home.',
  'BIH': 'Returns to the World Cup 12 years after its debut in Brazil 2014.',
  'QAT':
      'First time qualifying through competition after hosting the 2022 World Cup.',
  'SUI':
      'Sixth straight World Cup; a regular round-of-16 side in recent editions.',
  'BRA':
      'The only country present at all 23 World Cups and record champion with five stars. Now coached by Carlo Ancelotti.',
  'MAR':
      'Made history in 2022 as the first African semifinalist; arrives as the continent leader.',
  'SCO':
      'Back at a World Cup after 28 years away: its last appearance was France 1998.',
  'HAI': 'Its second appearance, 52 years after debuting in West Germany 1974.',
  'USA': 'Main host: stages 78 of the 104 matches, including the final.',
  'PAR':
      'La Albirroja returns after 16 years; it had not played a World Cup since South Africa 2010.',
  'AUS': 'Sixth consecutive World Cup for the Socceroos.',
  'TUR': 'Returns after 24 years with a golden generation led by Arda Güler.',
  'GER':
      'Four-time champion looking to rebound after two straight group-stage exits.',
  'CUW':
      'The smallest country in World Cup history, with about 156,000 people. Absolute debutant.',
  'CIV':
      'Africa Cup of Nations 2024 champion; fourth World Cup appearance for the Elephants.',
  'ECU':
      'Had an outstanding qualifying campaign: second in South America only behind Argentina.',
  'NED':
      'The eternal contender: three finals played, none won. The Oranje chase their first star.',
  'JPN':
      'The first team to qualify for 2026. Dreams of finally breaking the round-of-16 barrier.',
  'SWE':
      'Returns after winning the playoff; the Isak-Gyökeres duo is one of Europe’s most feared.',
  'TUN': 'Third consecutive World Cup for the Eagles of Carthage.',
  'BEL': 'The golden generation has given way to a new wave led by Doku.',
  'EGY': 'Salah, a Liverpool legend, is likely playing his final World Cup.',
  'IRN': 'Fourth consecutive World Cup; has never gone beyond the first round.',
  'NZL':
      'Oceania’s only representative; in 2010 it finished unbeaten without winning a match.',
  'ESP':
      'Number 1 in the FIFA ranking and European champion in 2024. A major favorite alongside Argentina and France.',
  'CPV':
      'Historic debutant: the archipelago of about 525,000 people achieved an epic qualification.',
  'KSA':
      'In 2022 it produced the tournament shock by beating eventual champion Argentina.',
  'URU':
      'Two-time world champion; Bielsa’s Celeste finished third in South American qualifying.',
  'FRA':
      'Finalist in 2022 and champion in two of the last three World Cups. Dembélé arrives as the 2025 Ballon d’Or winner.',
  'SEN': 'The top African team in the ranking alongside Morocco.',
  'IRQ':
      'Back at a World Cup 40 years after Mexico 1986; won the Asian playoff.',
  'NOR':
      'Qualified with a perfect record and Haaland in record mode: 16 goals in qualifying.',
  'ARG':
      'Defending champion. Messi, at 38, plays his sixth World Cup: no one has played more.',
  'ALG': 'The Desert Foxes return after missing Qatar 2022.',
  'AUT':
      'First qualification since 1998; Rangnick’s team presses like few others.',
  'JOR': 'Absolute debutant; runner-up at the 2023 Asian Cup.',
  'POR':
      'Cristiano Ronaldo, at 41, matches Messi’s record: sixth World Cup. 2025 Nations League champion.',
  'COD':
      'Returns 52 years after appearing as Zaire; won the intercontinental playoff.',
  'UZB': 'Absolute debutant after decades of coming close to qualification.',
  'COL':
      'La Tricolor returns after missing 2022. James, 2014 Golden Boot winner, leads; Lucho Díaz is the star.',
  'ENG':
      'Qualified with a perfect record and without conceding. With Tuchel, it seeks a second star 60 years later.',
  'CRO':
      'Runner-up in 2018 and third in 2022. Modrić, at 40, plays his fifth World Cup.',
  'GHA':
      'The Black Stars came within inches of the semifinals in 2010; back again after missing 2022.',
  'PAN':
      'Second appearance; won its qualifying group ahead of historic rivals.',
};
