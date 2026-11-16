// Basic smoke test: the app boots into the login screen when logged out.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/auth/auth_repository.dart';
import 'package:arc_app/main.dart';
import 'package:flutter/material.dart';

class _SignedIn extends AuthNotifier {
  @override
  AuthState build() => AuthState(user: AuthUser(id: 1, name: 'Ana', email: 'ana@arc.local'));
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
    // flutter_secure_storage has no platform implementation in widget
    // tests; stub its channel to reply "no stored value" immediately so
    // session restoration on startup resolves instead of hanging.
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Shows login screen on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ArcApp()));
    // The app briefly shows a loading spinner (an indefinitely-animating
    // widget) while restoring any stored session, so pumpAndSettle would
    // time out here — pump a bounded number of frames instead.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('an expired session closes the open screens', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [authProvider.overrideWith(_SignedIn.new)], child: const ArcApp()),
    );
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Pantalla abierta')),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Pantalla abierta'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.text('Pantalla abierta')));
    await container.read(authProvider.notifier).sessionExpired();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Pantalla abierta'), findsNothing);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
