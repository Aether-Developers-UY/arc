import 'package:flutter/material.dart';

/// Raw colour values for one theme, from the church's palette (cr-iglesia):
/// terracota for the interface, green reserved for chords.
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
  /// the eyes. Surfaces get lighter as they rise; the terracota is lifted
  /// to keep its contrast on grey.
  static const night = ArcaPalette(
    background: Color(0xFF1E1F22),
    surface: Color(0xFF26282C),
    surfaceElevated: Color(0xFF303338),
    border: Color(0xFF3C3F45),
    primary: Color(0xFFD98A5E),
    onPrimary: Color(0xFF2A1408),
    text: Color(0xFFE6E7EA),
    textSecondary: Color(0xFFA0A4AB),
    chord: Color(0xFFA9B19A),
    error: Color(0xFFFF8A80),
  );

  /// "Día" — pérola and bege, brown ink, terracota accents.
  static const day = ArcaPalette(
    background: Color(0xFFF0EDE4),
    surface: Color(0xFFF8F6F1),
    surfaceElevated: Color(0xFFE9E2D6),
    border: Color(0xFFD2C4AE),
    primary: Color(0xFF974315),
    onPrimary: Color(0xFFFBF8F3),
    text: Color(0xFF3A2418),
    textSecondary: Color(0xFF5C4636),
    chord: Color(0xFF5D6650),
    error: Color(0xFFB3261E),
  );
}
