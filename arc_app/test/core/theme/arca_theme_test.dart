import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/core/theme/arca_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // google_fonts fetches over the network; skip it in tests.
    ArcaTheme.useGoogleFonts = false;
  });

  test('dark theme uses a charcoal background and light green chords', () {
    final theme = ArcaTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF1E1F22));
    expect(theme.extension<ArcaTokens>()!.chord, const Color(0xFFA9B19A));
  });

  test('light theme uses the church palette: pérola background, green chords', () {
    final theme = ArcaTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF0EDE4));
    expect(theme.extension<ArcaTokens>()!.chord, const Color(0xFF5D6650));
  });

  test('terracota is the primary colour, lifted in dark mode', () {
    expect(ArcaTheme.dark().colorScheme.primary, const Color(0xFFD98A5E));
    expect(ArcaTheme.light().colorScheme.primary, const Color(0xFF974315));
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

  for (final (label, theme) in [('light', ArcaTheme.light()), ('dark', ArcaTheme.dark())]) {
    test('segmented selectors use terracota, not the chord green ($label)', () {
      final style = theme.segmentedButtonTheme.style!;
      const selected = {WidgetState.selected};
      final primary = theme.colorScheme.primary;

      expect(style.foregroundColor!.resolve(selected), primary);
      expect(style.backgroundColor!.resolve(selected), primary.withValues(alpha: 0.16));
      expect(style.backgroundColor!.resolve({}), Colors.transparent);
    });
  }
}
