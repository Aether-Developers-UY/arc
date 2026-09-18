# Arca Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the app as "Arca" and give it a coherent visual system — light/dark themes, logo, shared card/header widgets, an adaptive sidebar/bottom-bar shell, and redesigned screens — per `docs/superpowers/specs/2026-09-18-arca-design-system-design.md`.

**Architecture:** A `core/theme` layer defines the palette (`ArcaPalette`), a `ThemeExtension` (`ArcaTokens`) for the gold chord colour and secondary tokens, and `ArcaTheme.light()/dark()`. `core/widgets` holds reusable pieces (`ArcaLogo`, `ContentFrame`, `PageHeader`, `ArcaCard`, `KeyBadge`) and the adaptive `AppShell` (sidebar >= 900 px, bottom bar below). Existing screens keep their providers/repositories untouched; only their widget trees change. Detail/edit screens stay full-screen pushes above the shell.

**Tech Stack:** Flutter 3.44 / Dart 3.12, Riverpod 3.x, `google_fonts` (Bricolage Grotesque, DM Sans, JetBrains Mono), Material 3.

**Conventions for every task:**
- Work in `C:\wamp64\www\arc\arc_app`, branch `working`, commit locally, do not push (final task pushes).
- The bash tool may not find `flutter`; use the PowerShell tool (`flutter analyze`, `flutter test`) if so.
- Baseline before this plan: `flutter analyze` shows exactly 2 pre-existing `info` items (an `onReorder` deprecation in `setlist_detail_screen.dart`, a `use_null_aware_elements` in `setlist_repository.dart`); `flutter test` passes 17 tests. Do not introduce new analyzer issues.
- Brand name in user-visible text is **Arca**. Internal names (`arc_app` package, folders, DB) do NOT change.
- Commit messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

---

## File Structure

**Create**
- `lib/core/theme/arca_palette.dart` — palette values for night/day
- `lib/core/theme/arca_tokens.dart` — `ThemeExtension` (chord colour etc.) + `context.arca` accessor
- `lib/core/theme/arca_theme.dart` — `ArcaTheme.light()/dark()`, text styles, `ArcaTheme.mono()`
- `lib/core/layout.dart` — breakpoint constant + `isWide(context)`
- `lib/core/format/date_format.dart` — Spanish date helpers
- `lib/core/widgets/arca_logo.dart` — logo painter/widget
- `lib/core/widgets/content_frame.dart` — centered max-width padded container
- `lib/core/widgets/page_header.dart` — title + subtitle + trailing action
- `lib/core/widgets/arca_card.dart` — base card
- `lib/core/widgets/key_badge.dart` — key pill
- `lib/core/widgets/app_shell.dart` — adaptive navigation shell
- `test/core/theme/arca_theme_test.dart`, `test/core/format/date_format_test.dart`

**Modify**
- `pubspec.yaml` (add `google_fonts`), `lib/main.dart`
- `lib/features/songs/song_list_screen.dart`, `song_detail_screen.dart`, `song_editor_screen.dart`
- `lib/features/setlists/setlist_list_screen.dart`, `setlist_detail_screen.dart`, `setlist_editor_screen.dart`, `add_song_to_setlist_screen.dart`
- `lib/features/auth/login_screen.dart`
- `test/widget_test.dart`
- `web/index.html`, `web/manifest.json`

---

## Task 1: Palette, tokens, and theme

**Files:**
- Create: `lib/core/theme/arca_palette.dart`, `lib/core/theme/arca_tokens.dart`, `lib/core/theme/arca_theme.dart`
- Modify: `pubspec.yaml`, `lib/main.dart`, `test/widget_test.dart`
- Test: `test/core/theme/arca_theme_test.dart`

- [ ] **Step 1: Add the dependency**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter pub add google_fonts
```

Expected: `google_fonts` appears under `dependencies:` in `pubspec.yaml`.

- [ ] **Step 2: Write the failing theme test**

Create `test/core/theme/arca_theme_test.dart`:

```dart
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
```

- [ ] **Step 3: Run it to verify it fails**

```powershell
flutter test test/core/theme/arca_theme_test.dart
```

Expected: FAIL — `arca_theme.dart` does not exist (compile error).

- [ ] **Step 4: Create the palette**

Create `lib/core/theme/arca_palette.dart`:

```dart
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
```

- [ ] **Step 5: Create the theme extension**

Create `lib/core/theme/arca_tokens.dart`:

```dart
import 'package:flutter/material.dart';

/// Design tokens that don't fit Material's ColorScheme.
@immutable
class ArcaTokens extends ThemeExtension<ArcaTokens> {
  const ArcaTokens({
    required this.chord,
    required this.textSecondary,
    required this.surfaceElevated,
    required this.border,
  });

  final Color chord;
  final Color textSecondary;
  final Color surfaceElevated;
  final Color border;

  @override
  ArcaTokens copyWith({
    Color? chord,
    Color? textSecondary,
    Color? surfaceElevated,
    Color? border,
  }) =>
      ArcaTokens(
        chord: chord ?? this.chord,
        textSecondary: textSecondary ?? this.textSecondary,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        border: border ?? this.border,
      );

  @override
  ArcaTokens lerp(ThemeExtension<ArcaTokens>? other, double t) {
    if (other is! ArcaTokens) return this;
    return ArcaTokens(
      chord: Color.lerp(chord, other.chord, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension ArcaContext on BuildContext {
  ArcaTokens get arca => Theme.of(this).extension<ArcaTokens>()!;
}
```

- [ ] **Step 6: Create the theme**

Create `lib/core/theme/arca_theme.dart`. If the installed Flutter SDK expects `InputDecorationThemeData`/`CardThemeData`-style types where the code below uses `InputDecorationTheme`, adapt to whatever `flutter analyze` accepts — the visual result must stay the same.

```dart
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
```

- [ ] **Step 7: Run the theme tests to verify they pass**

```powershell
flutter test test/core/theme/arca_theme_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 8: Wire the theme into `main.dart`**

In `lib/main.dart`, add `import 'core/theme/arca_theme.dart';` and change the `MaterialApp` to:

```dart
return MaterialApp(
  title: 'Arca',
  debugShowCheckedModeBanner: false,
  theme: ArcaTheme.light(),
  darkTheme: ArcaTheme.dark(),
  themeMode: ThemeMode.system,
  home: home,
);
```

(Remove the old `theme: ThemeData(colorSchemeSeed: ...)` line.)

- [ ] **Step 9: Keep the widget smoke test working**

Edit `test/widget_test.dart`: add `import 'package:arc_app/core/theme/arca_theme.dart';` and at the top of the existing `setUp(() { ... })` add `ArcaTheme.useGoogleFonts = false;` as its first statement.

- [ ] **Step 10: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: analyze shows only the 2 pre-existing infos; all tests pass (17 existing + 3 new = 20).

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add Arca palette, theme extension, and light/dark themes

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: Layout helper, date helpers, and the logo

**Files:**
- Create: `lib/core/layout.dart`, `lib/core/format/date_format.dart`, `lib/core/widgets/arca_logo.dart`
- Test: `test/core/format/date_format_test.dart`

- [ ] **Step 1: Write the failing date test**

Create `test/core/format/date_format_test.dart`:

```dart
import 'package:arc_app/core/format/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 9, 18); // a Friday

  test('shortDate formats as dd/mm/yyyy', () {
    expect(shortDate(date), '18/09/2026');
    expect(shortDate(DateTime(2026, 1, 5)), '05/01/2026');
  });

  test('monthAbbr returns the Spanish three-letter month', () {
    expect(monthAbbr(date), 'sep');
    expect(monthAbbr(DateTime(2026, 1, 1)), 'ene');
  });

  test('weekdayName returns the Spanish weekday', () {
    expect(weekdayName(date), 'viernes');
    expect(weekdayName(DateTime(2026, 9, 20)), 'domingo');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```powershell
flutter test test/core/format/date_format_test.dart
```

Expected: FAIL — file not found.

- [ ] **Step 3: Implement the date helpers**

Create `lib/core/format/date_format.dart`:

```dart
const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const _weekdays = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

String shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String monthAbbr(DateTime d) => _months[d.month - 1];

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
```

- [ ] **Step 4: Run to verify it passes**

```powershell
flutter test test/core/format/date_format_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Create the layout helper**

Create `lib/core/layout.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Width at which the app switches from bottom navigation to a sidebar.
const double kWideBreakpoint = 900;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;
```

- [ ] **Step 6: Create the logo**

Create `lib/core/widgets/arca_logo.dart`. The mark is a rounded square in brand blue containing an ark hull (white) under an arc in gold whose ends are two dots — the arc reads as a rainbow and as a musical slur between two notes. Brand colours are fixed (not theme-dependent) so the mark is identical in both themes.

```dart
import 'package:flutter/material.dart';

class ArcaLogo extends StatelessWidget {
  const ArcaLogo({super.key, this.size = 40, this.showWordmark = false, this.wordmarkColor});

  final double size;
  final bool showWordmark;

  /// Colour of the "Arca" word; defaults to the theme's text colour.
  final Color? wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArcaMarkPainter()),
    );
    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        Text(
          'Arca',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: size * 0.6,
                color: wordmarkColor ?? Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}

class _ArcaMarkPainter extends CustomPainter {
  static const _blue = Color(0xFF1F5FA8);
  static const _gold = Color(0xFFF2B441);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;

    // Rounded square background.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(14 * s)),
      Paint()..color = _blue,
    );

    // Arc + note heads (the slur / rainbow).
    final arcPaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6 * s
      ..strokeCap = StrokeCap.round;
    final arcRect = Rect.fromCircle(center: Offset(32 * s, 36 * s), radius: 19 * s);
    canvas.drawArc(arcRect, 3.14159265, 3.14159265, false, arcPaint);
    final dot = Paint()..color = _gold;
    canvas.drawCircle(Offset(13 * s, 36 * s), 3.8 * s, dot);
    canvas.drawCircle(Offset(51 * s, 36 * s), 3.8 * s, dot);

    // Ark hull.
    final hull = Path()
      ..moveTo(15 * s, 41 * s)
      ..lineTo(49 * s, 41 * s)
      ..quadraticBezierTo(46 * s, 53 * s, 39 * s, 53 * s)
      ..lineTo(25 * s, 53 * s)
      ..quadraticBezierTo(18 * s, 53 * s, 15 * s, 41 * s)
      ..close();
    canvas.drawPath(hull, Paint()..color = Colors.white);

    // Cabin on the deck.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(26 * s, 35 * s, 12 * s, 6 * s),
        Radius.circular(1.5 * s),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 7: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass (23).

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add layout helper, Spanish date helpers, and Arca logo

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: Shared widgets (ContentFrame, PageHeader, ArcaCard, KeyBadge)

**Files:**
- Create: `lib/core/widgets/content_frame.dart`, `page_header.dart`, `arca_card.dart`, `key_badge.dart`

- [ ] **Step 1: ContentFrame**

Create `lib/core/widgets/content_frame.dart`:

```dart
import 'package:flutter/material.dart';

import '../layout.dart';

/// Centers content, caps its width, and applies responsive page padding.
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final padding = isWide(context) ? 32.0 : 16.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: ArcaCard**

Create `lib/core/widgets/arca_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/arca_tokens.dart';

/// The base container: surface colour, 1px border, 16px radius.
class ArcaCard extends StatelessWidget {
  const ArcaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: context.arca.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
```

- [ ] **Step 3: KeyBadge**

Create `lib/core/widgets/key_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/arca_theme.dart';

/// Small pill showing a musical key (e.g. "G", "Bb").
class KeyBadge extends StatelessWidget {
  const KeyBadge(this.musicalKey, {super.key});

  final String musicalKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        musicalKey,
        style: ArcaTheme.mono(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: PageHeader**

Create `lib/core/widgets/page_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/arca_tokens.dart';

/// Page title with an optional subtitle and a trailing action (usually a
/// FilledButton.icon).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Verify and commit**

```powershell
flutter analyze
```

Expected: only the 2 pre-existing infos.

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add shared ContentFrame, ArcaCard, KeyBadge, and PageHeader widgets

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: Adaptive AppShell and main wiring

**Files:**
- Create: `lib/core/widgets/app_shell.dart`
- Modify: `lib/main.dart`

The shell hosts the two top-level pages (`SongListScreen`, `SetlistListScreen`). Both screens currently return their own `Scaffold`; nested Scaffolds work, and Tasks 5–6 replace those with plain content.

- [ ] **Step 1: Create the shell**

Create `lib/core/widgets/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/setlists/setlist_list_screen.dart';
import '../../features/songs/song_list_screen.dart';
import '../layout.dart';
import '../theme/arca_tokens.dart';
import 'arca_logo.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Canciones', Icons.library_music_outlined, Icons.library_music),
  _Destination('Setlists', Icons.event_note_outlined, Icons.event_note),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _logout() => ref.read(authProvider.notifier).logout();

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: const [SongListScreen(), SetlistListScreen()],
    );

    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              selectedIndex: _index,
              onSelect: (i) => setState(() => _index = i),
              onLogout: _logout,
              userName: ref.watch(authProvider).user?.name,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const ArcaLogo(size: 32, showWordmark: true),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    required this.userName,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 248,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 32),
            child: ArcaLogo(size: 40, showWordmark: true),
          ),
          for (var i = 0; i < _destinations.length; i++)
            _SidebarItem(
              destination: _destinations[i],
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          const Divider(),
          const SizedBox(height: 12),
          if (userName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                userName!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.arca.textSecondary,
                    ),
              ),
            ),
          const SizedBox(height: 4),
          _SidebarItem(
            destination: const _Destination(
              'Cerrar sesión',
              Icons.logout,
              Icons.logout,
            ),
            selected: false,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(selected ? destination.selectedIcon : destination.icon,
                    color: color, size: 22),
                const SizedBox(width: 12),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Use the shell in `main.dart`**

In `lib/main.dart`, replace `import 'features/songs/song_list_screen.dart';` with `import 'core/widgets/app_shell.dart';`, and in the logged-in branch change `home = const SongListScreen();` to `home = const AppShell();`.

- [ ] **Step 3: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass. (The lists still show their old AppBars/FABs inside the shell — replaced in the next two tasks.)

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Add adaptive AppShell with sidebar and bottom navigation

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Song list screen redesign

**Files:**
- Modify: `lib/features/songs/song_list_screen.dart`

The screen no longer owns a `Scaffold`, `AppBar`, logout, setlist button, or FAB (the shell provides navigation and logout). It becomes a header + search + list of cards. Keep `songListProvider` usage and the pull-to-refresh identical.

- [ ] **Step 1: Rewrite the screen**

Replace the full contents of `lib/features/songs/song_list_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
import '../../core/widgets/page_header.dart';
import 'song_detail_screen.dart';
import 'song_editor_screen.dart';
import 'song_list_provider.dart';

class SongListScreen extends ConsumerStatefulWidget {
  const SongListScreen({super.key});

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songListProvider);

    return ContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Canciones',
            subtitle: 'El repertorio del ministerio',
            trailing: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nueva canción'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SongEditorScreen()),
              ),
            ),
          ),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por título o artista',
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => ref.read(songListProvider.notifier).search(value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: songsAsync.when(
              data: (songs) => songs.isEmpty
                  ? _EmptyState(
                      icon: Icons.library_music_outlined,
                      title: 'Todavía no hay canciones',
                      message: 'Agregá la primera con «Nueva canción».',
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(songListProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: songs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return ArcaCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SongDetailScreen(song: song),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (song.artist?.isNotEmpty == true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          song.artist!,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: context.arca.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                KeyBadge(song.originalKey),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'No se pudieron cargar las canciones',
                message: 'Revisá tu conexión y deslizá hacia abajo para reintentar.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: context.arca.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.arca.textSecondary),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass.

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Redesign song list with header, search, and cards

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Setlist list screen redesign

**Files:**
- Modify: `lib/features/setlists/setlist_list_screen.dart`

Same treatment as the song list: no Scaffold/AppBar/FAB; header with «Nuevo setlist»; cards with a date block (day over month) and the name/weekday.

- [ ] **Step 1: Rewrite the screen**

Replace the full contents of `lib/features/setlists/setlist_list_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/date_format.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/page_header.dart';
import 'setlist.dart';
import 'setlist_detail_screen.dart';
import 'setlist_editor_screen.dart';
import 'setlist_list_provider.dart';

class SetlistListScreen extends ConsumerWidget {
  const SetlistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistListProvider);

    return ContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Setlists',
            subtitle: 'Las canciones de cada servicio',
            trailing: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo setlist'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetlistEditorScreen()),
              ),
            ),
          ),
          Expanded(
            child: setlistsAsync.when(
              data: (setlists) => setlists.isEmpty
                  ? const _EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'Todavía no hay setlists',
                      message: 'Creá el del próximo servicio con «Nuevo setlist».',
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(setlistListProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: setlists.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _SetlistCard(setlist: setlists[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => const _EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'No se pudieron cargar los setlists',
                message: 'Revisá tu conexión y deslizá hacia abajo para reintentar.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetlistCard extends StatelessWidget {
  const _SetlistCard({required this.setlist});

  final Setlist setlist;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = setlist.serviceDate;
    final hasName = setlist.name?.isNotEmpty == true;

    return ArcaCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SetlistDetailScreen(setlistId: setlist.id)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: text.titleLarge?.copyWith(color: scheme.primary, height: 1.1),
                ),
                Text(
                  monthAbbr(date).toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? setlist.name! : weekdayName(date),
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  hasName ? '${weekdayName(date)} · ${shortDate(date)}' : shortDate(date),
                  style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.arca.textSecondary),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: context.arca.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.arca.textSecondary),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass.

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Redesign setlist list with date blocks and cards

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Song detail as a reader

**Files:**
- Modify: `lib/features/songs/song_detail_screen.dart`

Keep all existing behaviour: `initialKey`, `_song` state, `_refreshSongAttachments`, edit button, "Restablecer" resets to `_song.originalKey`. Change the presentation: chords in gold mono, larger lyrics, key chips, and a two-column layout on wide screens (lyrics left, attachments panel right).

- [ ] **Step 1: Rewrite the screen**

Replace the full contents of `lib/features/songs/song_detail_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chordpro/chordpro_parser.dart';
import '../../core/chordpro/transposer.dart';
import '../../core/layout.dart';
import '../../core/theme/arca_theme.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../attachments/attachment_list.dart';
import 'song.dart';
import 'song_editor_screen.dart';
import 'song_list_provider.dart';

class SongDetailScreen extends ConsumerStatefulWidget {
  const SongDetailScreen({super.key, required this.song, this.initialKey});

  final Song song;

  /// The key to show the song in when this screen opens. Defaults to the
  /// song's own original key. Used when opening a song from a setlist,
  /// where the setlist may have chosen a different key for that service.
  final String? initialKey;

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  late Song _song = widget.song;
  late String _currentKey = widget.initialKey ?? _song.originalKey;
  static const _availableKeys = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  Future<void> _refreshSongAttachments() async {
    try {
      final repository = ref.read(songRepositoryProvider);
      final refreshed = await repository.getOne(_song.id);
      if (!mounted) return;
      setState(() => _song = refreshed);
    } catch (_) {
      // The upload/delete itself already succeeded server-side; only this
      // follow-up refresh failed (e.g. dropped connection). Surface it so
      // the UI doesn't silently show stale attachments without explanation.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la lista de archivos.')),
      );
    }
  }

  String? get _metaLine {
    final parts = <String>[
      if (_song.artist?.isNotEmpty == true) _song.artist!,
      if (_song.tempo != null) '${_song.tempo} BPM',
      if (_song.timeSignature?.isNotEmpty == true) _song.timeSignature!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final document = ChordProParser.parse(_song.content);
    final semitones = semitonesBetweenKeys(from: _song.originalKey, to: _currentKey);

    final header = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_song.title, style: Theme.of(context).textTheme.headlineMedium),
          if (_metaLine != null) ...[
            const SizedBox(height: 4),
            Text(
              _metaLine!,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: context.arca.textSecondary),
            ),
          ],
        ],
      ),
    );

    final keyControls = _KeyControls(
      keys: _availableKeys,
      current: _currentKey,
      original: _song.originalKey,
      onSelect: (key) => setState(() => _currentKey = key),
      onReset: () => setState(() => _currentKey = _song.originalKey),
    );

    final lyrics = ArcaCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: _Lyrics(document: document, semitones: semitones),
    );

    final attachments = ArcaCard(
      child: AttachmentList(song: _song, onChanged: _refreshSongAttachments),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Editar canción',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SongEditorScreen(existingSong: _song)),
            ),
          ),
        ],
      ),
      body: ContentFrame(
        maxWidth: 1200,
        child: isWide(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [header, keyControls, const SizedBox(height: 16), lyrics],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8, bottom: 32),
                      child: attachments,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  header,
                  keyControls,
                  const SizedBox(height: 16),
                  lyrics,
                  const SizedBox(height: 16),
                  attachments,
                ],
              ),
      ),
    );
  }
}

class _KeyControls extends StatelessWidget {
  const _KeyControls({
    required this.keys,
    required this.current,
    required this.original,
    required this.onSelect,
    required this.onReset,
  });

  final List<String> keys;
  final String current;
  final String original;
  final ValueChanged<String> onSelect;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tonalidad', style: text.titleSmall),
            const SizedBox(width: 8),
            Text(
              'Original: $original',
              style: text.bodySmall?.copyWith(color: context.arca.textSecondary),
            ),
            const Spacer(),
            if (current != original)
              TextButton(onPressed: onReset, child: const Text('Restablecer')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in keys)
              ChoiceChip(
                label: Text(
                  key,
                  style: ArcaTheme.mono(const TextStyle(fontWeight: FontWeight.w700)),
                ),
                selected: key == current,
                onSelected: (_) => onSelect(key),
              ),
          ],
        ),
      ],
    );
  }
}

class _Lyrics extends StatelessWidget {
  const _Lyrics({required this.document, required this.semitones});

  final ChordProDocument document;
  final int semitones;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in document.lines)
          if (line.sectionLabel != null && line.segments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Text(
                line.sectionLabel!.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            )
          else if (line.segments.isEmpty)
            const SizedBox(height: 14)
          else
            _ChordLine(segments: line.segments, semitones: semitones),
      ],
    );
  }
}

class _ChordLine extends StatelessWidget {
  const _ChordLine({required this.segments, required this.semitones});

  final List<ChordProSegment> segments;
  final int semitones;

  @override
  Widget build(BuildContext context) {
    final chordStyle = ArcaTheme.mono(
      TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: context.arca.chord,
      ),
    );
    final lyricStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w500,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final segment in segments)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.chord == null
                      ? ' '
                      : transposeChord(segment.chord!, semitones: semitones),
                  style: chordStyle,
                ),
                Text(segment.text.isEmpty ? ' ' : segment.text, style: lyricStyle),
              ],
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass.

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Redesign song detail as a reader with gold chords and key chips

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: Setlist detail redesign

**Files:**
- Modify: `lib/features/setlists/setlist_detail_screen.dart`

Keep ALL state/logic exactly as-is (`_load`, `_reloadSilently`, `_isMutating`, `_onReorder`, `_removeSong`, `_openAddSong`, `_openSong`, `_SongFromSetlistLoader`). Only the `build` method's widget tree and imports change.

- [ ] **Step 1: Add imports**

At the top of `lib/features/setlists/setlist_detail_screen.dart` add:

```dart
import '../../core/format/date_format.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
```

- [ ] **Step 2: Replace the `build` method**

Replace the entire `build` method of `_SetlistDetailScreenState` (from `@override Widget build(BuildContext context) {` through its closing brace, just before the `_SongFromSetlistLoader` class doc comment) with:

```dart
  @override
  Widget build(BuildContext context) {
    final setlist = _setlist;
    final text = Theme.of(context).textTheme;
    final title = setlist == null
        ? ''
        : (setlist.name?.isNotEmpty == true ? setlist.name! : weekdayName(setlist.serviceDate));
    final subtitle = setlist == null
        ? ''
        : '${weekdayName(setlist.serviceDate)} · ${shortDate(setlist.serviceDate)}';

    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : setlist == null
              ? Center(child: Text(_errorMessage ?? 'Setlist no encontrado.'))
              : ContentFrame(
                  maxWidth: 800,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: text.headlineMedium),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: text.bodyLarge?.copyWith(color: context.arca.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      Expanded(
                        child: setlist.songs.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.queue_music_outlined,
                                        size: 40, color: context.arca.textSecondary),
                                    const SizedBox(height: 12),
                                    Text('Este setlist está vacío', style: text.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Agregá canciones con «Agregar canción».',
                                      style: text.bodyMedium
                                          ?.copyWith(color: context.arca.textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.only(bottom: 96),
                                itemCount: setlist.songs.length,
                                onReorder: _onReorder,
                                itemBuilder: (context, index) {
                                  final setlistSong = setlist.songs[index];
                                  return Padding(
                                    key: ValueKey(setlistSong.id),
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ArcaCard(
                                      onTap: () => _openSong(setlistSong),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.14),
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  setlistSong.songTitle,
                                                  style: text.titleMedium
                                                      ?.copyWith(fontWeight: FontWeight.w600),
                                                ),
                                                if (setlistSong.songArtist?.isNotEmpty == true)
                                                  Text(
                                                    setlistSong.songArtist!,
                                                    style: text.bodyMedium?.copyWith(
                                                      color: context.arca.textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          KeyBadge(setlistSong.key),
                                          IconButton(
                                            tooltip: 'Quitar del setlist',
                                            icon: const Icon(Icons.close),
                                            onPressed: _isMutating
                                                ? null
                                                : () => _removeSong(setlistSong),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: setlist == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAddSong,
              icon: const Icon(Icons.add),
              label: const Text('Agregar canción'),
            ),
    );
  }
```

- [ ] **Step 3: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos (the `onReorder` deprecation line number may shift; that is fine); all tests pass.

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Redesign setlist detail with ordered cards and key badges

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: Login redesign

**Files:**
- Modify: `lib/features/auth/login_screen.dart`

Keep the state class logic (`_emailController`, `_passwordController`, `authProvider` login call, error and loading display). Keep the button label `Ingresar` (the widget smoke test finds it). Wide: brand panel left + form right. Narrow: logo above form.

- [ ] **Step 1: Rewrite the screen**

Replace the full contents of `lib/features/auth/login_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_logo.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final form = _LoginForm(
      emailController: _emailController,
      passwordController: _passwordController,
      onSubmit: _submit,
      showLogo: !wide,
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: Center(child: form)),
              ],
            )
          : SafeArea(child: Center(child: SingleChildScrollView(child: form))),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B1F38),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ArcaLogo(size: 64, showWordmark: true, wordmarkColor: Colors.white),
          const SizedBox(height: 32),
          Text(
            'Las canciones del ministerio, listas para el servicio.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Letra, acordes y tonalidad en un solo lugar.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF9DB4D0),
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends ConsumerWidget {
  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
    required this.showLogo,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final bool showLogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final text = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLogo) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: ArcaLogo(size: 48, showWordmark: true),
              ),
              const SizedBox(height: 32),
            ],
            Text('Ingresá a Arca', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Usá tu correo y contraseña.',
              style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 20),
            if (authState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  authState.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: authState.isLoading ? null : onSubmit,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ingresar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass (the smoke test still finds `Ingresar`).

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Redesign login with brand panel and Arca wording

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: Editors and picker polish, web title and manifest

**Files:**
- Modify: `lib/features/songs/song_editor_screen.dart`, `lib/features/setlists/setlist_editor_screen.dart`, `lib/features/setlists/add_song_to_setlist_screen.dart`, `web/index.html`, `web/manifest.json`

- [ ] **Step 1: Center and cap the width of both editors**

In `lib/features/songs/song_editor_screen.dart` and `lib/features/setlists/setlist_editor_screen.dart`:
1. Add `import '../../core/widgets/content_frame.dart';`.
2. Wrap the existing `body:` widget of the `Scaffold` in `ContentFrame(maxWidth: 640, child: ...)`. Keep the `SingleChildScrollView` (song editor) or `Padding`+`Column` (setlist editor) inside as-is; in the setlist editor replace the outer `Padding(padding: const EdgeInsets.all(16), child: Column(...))` by `ContentFrame(maxWidth: 640, child: Padding(padding: const EdgeInsets.only(top: 16), child: Column(...)))` so the horizontal padding comes from `ContentFrame` only.
3. In `song_editor_screen.dart`, the outer `SingleChildScrollView(padding: const EdgeInsets.all(16), ...)` becomes `SingleChildScrollView(padding: const EdgeInsets.symmetric(vertical: 16), ...)` inside the `ContentFrame`.

- [ ] **Step 2: Restyle the song picker as cards**

In `lib/features/setlists/add_song_to_setlist_screen.dart`:
1. Add imports: `../../core/theme/arca_tokens.dart`, `../../core/widgets/arca_card.dart`, `../../core/widgets/content_frame.dart`, `../../core/widgets/key_badge.dart`.
2. Wrap the `Column` that is the `Scaffold` body in `ContentFrame(maxWidth: 720, child: ...)`.
3. Replace the `ListView.builder` in the `data:` branch with:

```dart
data: (songs) => ListView.separated(
  padding: const EdgeInsets.only(top: 8, bottom: 24),
  itemCount: songs.length,
  separatorBuilder: (_, __) => const SizedBox(height: 10),
  itemBuilder: (context, index) {
    final song = songs[index];
    return ArcaCard(
      onTap: _isAdding ? null : () => _add(song),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (song.artist?.isNotEmpty == true)
                  Text(
                    song.artist!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: context.arca.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          KeyBadge(song.originalKey),
        ],
      ),
    );
  },
),
```

- [ ] **Step 3: Rename the web title and manifest**

In `web/index.html` change `<title>arc_app</title>` to `<title>Arca</title>` and any `apple-mobile-web-app-title` content to `Arca`. In `web/manifest.json` set `"name": "Arca"` and `"short_name": "Arca"`, and `"description"` to `"Las canciones del ministerio, listas para el servicio."`.

- [ ] **Step 4: Verify and commit**

```powershell
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass.

```powershell
cd "C:\wamp64\www\arc"
git add arc_app
git commit -m "Polish editors and song picker; rename web title to Arca

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: Visual verification and push

**Files:** none (verification + git)

- [ ] **Step 1: Full checks**

```powershell
cd "C:\wamp64\www\arc\arc_app"
flutter analyze
flutter test
```

Expected: only the 2 pre-existing infos; all tests pass.

- [ ] **Step 2: Visual check in the browser**

Run the app (`flutter run -d web-server --web-port 4201` with the Laravel backend on 4200, test user `test@arc.local` / `password123`) and check, in BOTH light and dark colour schemes and at BOTH a wide (>= 1100 px) and a narrow (~390 px) viewport: login, song list, setlist list, song detail (chords in gold, key chips, attachments panel right on wide / below on narrow), setlist detail, and the two editors. Confirm the sidebar appears only when wide and the bottom bar only when narrow, and that no screen overflows or has unreadable contrast.

- [ ] **Step 3: Push**

```powershell
cd "C:\wamp64\www\arc"
git branch --show-current
git push origin working
```

Expected: branch is `working`; push succeeds.
