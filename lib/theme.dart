import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}

/// Neon akcentek – a meglévő Profil → Megjelenés választóval kompatibilis.
const List<AccentOption> kAccents = [
  AccentOption('Kék', Color(0xFF258BFF)),
  AccentOption('Zöld', Color(0xFF20C997)),
  AccentOption('Piros', Color(0xFFFF5268)),
  AccentOption('Narancs', Color(0xFFFFA340)),
  AccentOption('Lila', Color(0xFF9B6BFF)),
  AccentOption('Türkiz', Color(0xFF20DCC8)),
  AccentOption('Magenta', Color(0xFFED55C7)),
  AccentOption('Pala', Color(0xFF7186A6)),
];

/// APISCORES neon-glass téma. A képernyők elrendezését nem módosítja.
ThemeData buildTheme({
  required Brightness brightness,
  required int accentIndex,
  bool oled = false,
}) {
  final idx = (accentIndex < 0 || accentIndex >= kAccents.length) ? 0 : accentIndex;
  final dark = brightness == Brightness.dark;
  final accent = kAccents[idx].color;
  final background = dark
      ? (oled ? const Color(0xFF000000) : const Color(0xFF090D18))
      : const Color(0xFFF1F5FC);
  final surface = dark ? const Color(0xFF121A2A) : const Color(0xFFFFFFFF);
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    surface: surface,
  ).copyWith(
    primary: accent,
    secondary: const Color(0xFF28DCC8),
    tertiary: const Color(0xFFB36BFF),
    surface: surface,
    surfaceContainerLowest: dark ? const Color(0xFF080D18) : const Color(0xFFF8FAFF),
    surfaceContainerLow: dark ? const Color(0xFF10182A) : const Color(0xFFEAF0FA),
    surfaceContainer: dark ? const Color(0xFF151F33) : const Color(0xFFE3EBF7),
    surfaceContainerHigh: dark ? const Color(0xFF1B2941) : const Color(0xFFDCE6F4),
    surfaceContainerHighest: dark ? const Color(0xFF22314B) : const Color(0xFFD3DFF0),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: dark
          ? const Color(0xCC101827)
          : const Color(0xDDF8FAFF),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
      iconTheme: IconThemeData(color: accent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark
          ? const Color(0xEE101827)
          : const Color(0xEEF8FAFF),
      indicatorColor: accent.withValues(alpha: dark ? 0.24 : 0.16),
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected ? accent : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? accent : scheme.onSurfaceVariant,
        size: states.contains(WidgetState.selected) ? 25 : 22,
      )),
    ),
    dividerTheme: DividerThemeData(
      color: accent.withValues(alpha: dark ? 0.16 : 0.12),
      thickness: 0.7,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: accent.withValues(alpha: 0.24)),
      selectedColor: accent.withValues(alpha: dark ? 0.25 : 0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF202D43) : const Color(0xFF17243A),
      contentTextStyle: GoogleFonts.inter(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
