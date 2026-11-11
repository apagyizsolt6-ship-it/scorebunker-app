import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}

/// Választható akcentszínek (a Profil → Megjelenés alatt).
const List<AccentOption> kAccents = [
  AccentOption('Kék', Color(0xFF1A73E8)),
  AccentOption('Zöld', Color(0xFF2E7D32)),
  AccentOption('Piros', Color(0xFFE53935)),
  AccentOption('Narancs', Color(0xFFFB8C00)),
  AccentOption('Lila', Color(0xFF8E24AA)),
  AccentOption('Türkiz', Color(0xFF00897B)),
  AccentOption('Rózsaszín', Color(0xFFD81B60)),
  AccentOption('Pala', Color(0xFF546E7A)),
];

/// Az app témája. `oled`: valódi fekete háttér a sötét témában.
ThemeData buildTheme({
  required Brightness brightness,
  required int accentIndex,
  bool oled = false,
}) {
  final idx = (accentIndex < 0 || accentIndex >= kAccents.length) ? 0 : accentIndex;
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(
    seedColor: kAccents[idx].color,
    brightness: brightness,
  );
  final black = dark && oled;
  if (black) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0C),
      surfaceContainer: const Color(0xFF101013),
      surfaceContainerHigh: const Color(0xFF16161A),
      surfaceContainerHighest: const Color(0xFF1D1D22),
    );
  }
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );
  return base.copyWith(
    textTheme: dark
        ? GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.interTextTheme(),
    scaffoldBackgroundColor: black ? Colors.black : null,
    appBarTheme: black
        ? const AppBarTheme(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
          )
        : null,
  );
}
