import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/core/theme/arca_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // google_fonts fetches over the network; skip it in tests.
    ArcaTheme.useGoogleFonts = false;
  });

  test('dark theme uses a charcoal background and gold chords', () {
    final theme = ArcaTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF1E1F22));
    expect(theme.extension<ArcaTokens>()!.chord, const Color(0xFFF2B441));
  });

  test('light theme uses the day background and a darker gold for chords', () {
    final theme = ArcaTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FA));
    expect(theme.extension<ArcaTokens>()!.chord, const Color(0xFFA8650A));
  });

  test('primary colour differs between themes', () {
    expect(ArcaTheme.dark().colorScheme.primary, const Color(0xFF6AA8EC));
    expect(ArcaTheme.light().colorScheme.primary, const Color(0xFF1F5FA8));
  });

  test('dark theme surfaces are neutral greys, never pure black', () {
    final theme = ArcaTheme.dark();
    final greys = [
      theme.scaffoldBackgroundColor,
      theme.colorScheme.surface,
      theme.extension<ArcaTokens>()!.surfaceElevated,
    ];
    for (final c in greys) {
      // Charcoal: red, green and blue stay within a few steps of each
      // other, and well above black.
      final channels = [c.r, c.g, c.b].map((v) => (v * 255).round()).toList()..sort();
      expect(channels.last - channels.first, lessThanOrEqualTo(8));
      expect(channels.first, greaterThanOrEqualTo(0x1A));
    }
  });
}
