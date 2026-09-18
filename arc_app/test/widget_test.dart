// Basic smoke test: the app boots into the login screen when logged out.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/main.dart';

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
}
