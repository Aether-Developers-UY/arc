import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOut extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

const _verdeNoche = Color(0xFF353C2D);
const _charcoal = Color(0xFF18191C);

Finder panelColored(Color color) =>
    find.byWidgetPredicate((w) => w is Container && w.color == color);

Future<void> pumpLogin(WidgetTester tester, {required ThemeData theme, Size size = const Size(1200, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(_SignedOut.new)],
      child: MaterialApp(theme: theme, home: const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('in light mode the brand panel is verde noche', (tester) async {
    await pumpLogin(tester, theme: ArcaTheme.light());

    expect(panelColored(_verdeNoche), findsOneWidget);
  });

  testWidgets('in dark mode the brand panel is charcoal', (tester) async {
    await pumpLogin(tester, theme: ArcaTheme.dark());

    expect(panelColored(_charcoal), findsOneWidget);
    expect(panelColored(_verdeNoche), findsNothing);
  });

  for (final (label, size) in [('desktop', const Size(1200, 900)), ('phone', const Size(390, 844))]) {
    testWidgets('the theme can be chosen before signing in ($label)', (tester) async {
      await pumpLogin(tester, theme: ArcaTheme.light(), size: size);

      expect(find.byTooltip('Tema'), findsOneWidget);
    });
  }

  for (final (label, size, logo) in [('desktop', const Size(1200, 900), 72.0), ('phone', const Size(390, 844), 54.0)]) {
    testWidgets('the church logo is shown large ($label)', (tester) async {
      await pumpLogin(tester, theme: ArcaTheme.light(), size: size);

      expect(tester.getSize(find.byType(Image).first), Size(logo, logo));
    });
  }
}
