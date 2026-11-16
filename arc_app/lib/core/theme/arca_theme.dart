import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'arca_palette.dart';
import 'arca_tokens.dart';

class ArcaTheme {
  ArcaTheme._();

  /// When false, the system default fonts are used instead of fetching
  /// Google Fonts. Tests set this to false to avoid network access.
  static bool useGoogleFonts = true;

  static ThemeData light() => _build(ArcaPalette.day, Brightness.light);
  static ThemeData dark() => _build(ArcaPalette.night, Brightness.dark);

  /// Monospace style for chords, so they align over the lyrics.
  static TextStyle mono(TextStyle base) => useGoogleFonts
      ? GoogleFonts.jetBrainsMono(textStyle: base)
      : base.copyWith(fontFamily: 'monospace');

  static TextTheme _textTheme(ArcaPalette p, Brightness brightness) {
    final base = ThemeData(brightness: brightness)
        .textTheme
        .apply(bodyColor: p.text, displayColor: p.text);
    if (!useGoogleFonts) return base;

    final body = GoogleFonts.dmSansTextTheme(base);
    TextStyle? head(TextStyle? s) =>
        GoogleFonts.bricolageGrotesque(textStyle: s, fontWeight: FontWeight.w700);

    return body.copyWith(
      displaySmall: head(body.displaySmall),
      headlineLarge: head(body.headlineLarge),
      headlineMedium: head(body.headlineMedium),
      headlineSmall: head(body.headlineSmall),
      titleLarge: head(body.titleLarge),
    );
  }

  static ThemeData _build(ArcaPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.chord,
      onSecondary: isDark ? const Color(0xFF1A1200) : Colors.white,
      error: p.error,
      onError: isDark ? const Color(0xFF2A0A0A) : Colors.white,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerHighest: p.surfaceElevated,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.border,
    );

    final text = _textTheme(p, brightness);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: p.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      textTheme: text,
      dividerColor: p.border,
      dividerTheme: DividerThemeData(color: p.border, space: 1, thickness: 1),
      extensions: [
        ArcaTokens(
          chord: p.chord,
          textSecondary: p.textSecondary,
          surfaceElevated: p.surfaceElevated,
          border: p.border,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(color: p.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text),
        ),
      ),
      // Material picks the secondary colour (the chord green) for the
      // selected segment; use the same terracota tint as the sidebar.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? p.primary.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? p.primary : p.text,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.border)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary.withValues(alpha: 0.2),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(color: p.text),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceElevated,
        contentTextStyle: TextStyle(color: p.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
