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

/// APISCORES prémium neon-glass téma.
/// A képernyők elrendezését nem változtatja; egységes, kifinomult
/// felületet ad a meglévő kártyáknak, gomboknak és beviteli mezőknek.
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
  final border = accent.withValues(alpha: dark ? 0.20 : 0.15);
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

  final radius = BorderRadius.circular(20);
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: border, width: 1),
  );
  final focusedOutline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: accent, width: 1.6),
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xCC101827) : const Color(0xDDF8FAFF),
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
    cardTheme: CardThemeData(
      color: surface.withValues(alpha: dark ? 0.94 : 0.98),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border, width: 0.75),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xEE101827) : const Color(0xEEF8FAFF),
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.10),
        disabledForegroundColor: scheme.onSurfaceVariant,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, letterSpacing: 0.1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        minimumSize: const Size(48, 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: border),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(44, 44),
        side: BorderSide(color: border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF0D1422) : const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: outline,
      enabledBorder: outline,
      focusedBorder: focusedOutline,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.72)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: border),
      ),
      titleTextStyle: GoogleFonts.inter(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: GoogleFonts.inter(color: scheme.onSurfaceVariant, height: 1.45),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: accent.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: accent.withValues(alpha: 0.15),
      circularTrackColor: accent.withValues(alpha: 0.15),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? accent : scheme.onSurfaceVariant),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.34)
              : scheme.onSurface.withValues(alpha: 0.10)),
      trackOutlineColor: WidgetStateProperty.all(border),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? accent : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.white),
    ),
    dividerTheme: DividerThemeData(
      color: accent.withValues(alpha: dark ? 0.16 : 0.12),
      thickness: 0.7,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: border),
      selectedColor: accent.withValues(alpha: dark ? 0.25 : 0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF202D43) : const Color(0xFF17243A),
      contentTextStyle: GoogleFonts.inter(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
