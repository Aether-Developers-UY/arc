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

  /// "Diluvio" — deep water.
  static const night = ArcaPalette(
    background: Color(0xFF0B1420),
    surface: Color(0xFF122033),
    surfaceElevated: Color(0xFF1B2E47),
    border: Color(0xFF243A57),
    primary: Color(0xFF4C9BE8),
    onPrimary: Color(0xFF06131F),
    text: Color(0xFFE8EEF6),
    textSecondary: Color(0xFF8FA3BC),
    chord: Color(0xFFF2B441),
    error: Color(0xFFFF7A7A),
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
