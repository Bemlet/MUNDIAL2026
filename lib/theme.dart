/// Tema visual con dos modos: oscuro premium (azul profundo + dorado) y
/// claro elegante. `Wc.dark` conmuta la paleta; la UI lee todo vía getters.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class Wc {
  static bool dark = true;

  // ----------------------------------------------------------- superficies
  static Color get bg =>
      dark ? const Color(0xFF070B16) : const Color(0xFFF3F5FB);
  static Color get surface =>
      dark ? const Color(0xFF101830) : const Color(0xFFFFFFFF);
  static Color get surfaceHi =>
      dark ? const Color(0xFF182244) : const Color(0xFFE9EDF8);
  static Color get navBg =>
      dark ? const Color(0xF20A1020) : const Color(0xF7FFFFFF);
  static Color get line =>
      dark ? const Color(0xFF232E55) : const Color(0xFFD9DFEF);

  // ----------------------------------------------------------------- texto
  static Color get text => dark ? Colors.white : const Color(0xFF151A2E);
  static Color get textSoft =>
      dark ? const Color(0xFFC6CDE4) : const Color(0xFF3D4763);
  static Color get textDim =>
      dark ? const Color(0xFF8A93B2) : const Color(0xFF5D6680);

  // --------------------------------------------------------------- acentos
  static Color get gold =>
      dark ? const Color(0xFFF2C14E) : const Color(0xFFDB9E0A);
  static Color get goldHi =>
      dark ? const Color(0xFFFFD97A) : const Color(0xFF9A7008);
  static Color get onGold => const Color(0xFF221A00);
  static Color get mint =>
      dark ? const Color(0xFF2EE6A8) : const Color(0xFF0B9E6C);
  static Color get live =>
      dark ? const Color(0xFFFF4D6D) : const Color(0xFFE11D48);
  static Color get flagBorder => dark
      ? Colors.white.withValues(alpha: .14)
      : Colors.black.withValues(alpha: .10);

  // ------------------------------------------------------------ degradados
  static Gradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF141E3C), Color(0xFF0C1226)]
        : const [Color(0xFFFFFFFF), Color(0xFFF2F5FD)],
  );

  static Gradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF1B2A5E), Color(0xFF101830), Color(0xFF0A1020)]
        : const [Color(0xFFDFE7FA), Color(0xFFF0F3FC), Color(0xFFFFFFFF)],
  );

  static Gradient get finalGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF2A2410), Color(0xFF141E3C)]
        : const [Color(0xFFFFF2CF), Color(0xFFFFFFFF)],
  );

  static Gradient get championGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF3A2E0A), Color(0xFF191406)]
        : const [Color(0xFFFFEDB8), Color(0xFFFFF9E8)],
  );
}

TextStyle outfit(
  double size,
  FontWeight weight, {
  Color? color,
  double? height,
  double? spacing,
}) => TextStyle(
  fontFamily: 'Outfit',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', _wghtOf(weight))],
  color: color,
  height: height,
  letterSpacing: spacing,
);

double _wghtOf(FontWeight w) => switch (w) {
  FontWeight.w100 => 100,
  FontWeight.w200 => 200,
  FontWeight.w300 => 300,
  FontWeight.w400 => 400,
  FontWeight.w500 => 500,
  FontWeight.w600 => 600,
  FontWeight.w700 => 700,
  FontWeight.w800 => 800,
  _ => 900,
};

ThemeData buildTheme() {
  final scheme = ColorScheme(
    brightness: Wc.dark ? Brightness.dark : Brightness.light,
    primary: Wc.gold,
    onPrimary: Wc.onGold,
    secondary: Wc.mint,
    onSecondary: Colors.white,
    surface: Wc.bg,
    onSurface: Wc.text,
    surfaceContainerHighest: Wc.surface,
    outline: Wc.line,
    error: Wc.live,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Wc.bg,
    fontFamily: 'Outfit',
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Outfit',
      bodyColor: Wc.text,
      displayColor: Wc.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: outfit(22, FontWeight.w800, color: Wc.text),
      iconTheme: IconThemeData(color: Wc.text),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Wc.dark ? Brightness.light : Brightness.dark,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Wc.navBg,
      indicatorColor: Wc.gold.withValues(alpha: .16),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => outfit(
          11.5,
          states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? Wc.goldHi : Wc.textDim,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? Wc.goldHi : Wc.textDim,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Wc.surface,
      side: BorderSide(color: Wc.line),
      labelStyle: outfit(13, FontWeight.w600, color: Wc.text),
    ),
    dividerTheme: DividerThemeData(color: Wc.line, thickness: 1),
    dialogTheme: DialogThemeData(backgroundColor: Wc.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: Wc.surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Wc.surfaceHi,
      contentTextStyle: outfit(14, FontWeight.w500, color: Wc.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
