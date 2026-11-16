import 'package:flutter/material.dart';

/// Raw colour values for one theme. Water blue for the interface, gold
/// reserved for chords — the only warm colour in the app.
class ArcaPalette {
  const ArcaPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.textSecondary,
    required this.chord,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color text;
  final Color textSecondary;
  final Color chord;
  final Color error;

  /// "Carbón" — soft charcoal greys, never pure black, so it is easy on
  /// the eyes. Surfaces get lighter as they rise; the blue is lifted a
  /// little to keep its contrast on grey.
  static const night = ArcaPalette(
    background: Color(0xFF1E1F22),
    surface: Color(0xFF26282C),
    surfaceElevated: Color(0xFF303338),
    border: Color(0xFF3C3F45),
    primary: Color(0xFF6AA8EC),
    onPrimary: Color(0xFF0E1A26),
    text: Color(0xFFE6E7EA),
    textSecondary: Color(0xFFA0A4AB),
    chord: Color(0xFFF2B441),
    error: Color(0xFFFF8A80),
  );

  /// "Día".
  static const day = ArcaPalette(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEEF2F7),
    border: Color(0xFFE3E8EF),
    primary: Color(0xFF1F5FA8),
    onPrimary: Color(0xFFFFFFFF),
    text: Color(0xFF0F1B2D),
    textSecondary: Color(0xFF5B6B80),
    chord: Color(0xFFA8650A),
    error: Color(0xFFC0392B),
  );
}
