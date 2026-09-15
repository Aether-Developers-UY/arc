// Basic smoke test: the app boots into the login screen when logged out.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arc_app/main.dart';

void main() {
  testWidgets('Shows login screen on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ArcApp()));

    expect(find.text('Ingresar'), findsOneWidget);
  });
}
