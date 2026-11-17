import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedOut extends AuthNotifier {
  /// The username and password each sign-in was tried with.
  static final attempts = <String>[];

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> login(String username, String password) async => attempts.add('$username $password');
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

  testWidgets('signing in asks for a username and a password, no email', (tester) async {
    _SignedOut.attempts.clear();
    await pumpLogin(tester, theme: ArcaTheme.light());

    expect(find.text('Correo'), findsNothing);
    expect(find.textContaining('correo'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Usuario'), ' admin ');
    await tester.enterText(find.widgetWithText(TextField, 'Contraseña'), 'clave123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(_SignedOut.attempts, ['admin clave123']);
  });

  testWidgets('the username field does not autocorrect or capitalize', (tester) async {
    await pumpLogin(tester, theme: ArcaTheme.light());

    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Usuario'));
    expect(field.autocorrect, isFalse);
    expect(field.textCapitalization, TextCapitalization.none);
    expect(field.keyboardType, isNot(TextInputType.emailAddress));
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
