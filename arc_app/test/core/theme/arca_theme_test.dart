import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/core/theme/arca_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // google_fonts fetches over the network; skip it in tests.
    ArcaTheme.useGoogleFonts = false;
  });

  test('dark theme uses the night background and gold chords', () {
    final theme = ArcaTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B1420));
    expect(theme.extension<ArcaTokens>()!.chord, const Color(0xFFF2B441));
  });

  test('light theme uses the day background and a darker gold for chords', () {
    final theme = ArcaTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FA));
    expect(theme.extension<ArcaTokens>()!.chord, const Color(0xFFA8650A));
  });

  test('primary colour differs between themes', () {
    expect(ArcaTheme.dark().colorScheme.primary, const Color(0xFF4C9BE8));
    expect(ArcaTheme.light().colorScheme.primary, const Color(0xFF1F5FA8));
  });
}
