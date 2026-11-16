import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/annexes/annex.dart';
import 'package:arc_app/features/annexes/annex_selector.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'active_annex_provider_test.dart' show FakeAuth;

final centro = Annex(id: 3, name: 'Centro');
final norte = Annex(id: 7, name: 'Norte');

Future<ProviderContainer> pumpSelector(
  WidgetTester tester,
  List<Annex> annexes, {
  VoidCallback? onManage,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(() => FakeAuth(annexes))],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: Scaffold(body: AnnexSelector(onManage: onManage ?? () {})),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AnnexSelector)));
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('shows the active annex name', (tester) async {
    await pumpSelector(tester, [centro, norte]);

    expect(find.text('Centro'), findsOneWidget);
    expect(find.byIcon(Icons.church_outlined), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });

  testWidgets('choosing another annex makes it active', (tester) async {
    final container = await pumpSelector(tester, [centro, norte]);

    await tester.tap(find.text('Centro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Norte').last);
    await tester.pumpAndSettle();

    expect(container.read(activeAnnexProvider), norte);
    expect(find.text('Norte'), findsOneWidget);
  });

  testWidgets('with one annex there is no dropdown arrow', (tester) async {
    await pumpSelector(tester, [centro]);

    expect(find.text('Centro'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
  });

  for (final (label, annexes, text) in [('with an annex', [centro], 'Centro'), ('without', <Annex>[], 'Sin anexo')]) {
    testWidgets('the church icon matches the text colour ($label)', (tester) async {
      await pumpSelector(tester, annexes);

      final icon = tester.widget<Icon>(find.byIcon(Icons.church_outlined));
      final label = tester.widget<Text>(find.text(text));
      expect(icon.color, label.style!.color);
    });
  }

  testWidgets('without annexes says so', (tester) async {
    await pumpSelector(tester, []);

    expect(find.text('Sin anexo'), findsOneWidget);
  });

  testWidgets('Gestionar mis anexos calls onManage', (tester) async {
    var managed = 0;
    await pumpSelector(tester, [centro], onManage: () => managed++);

    await tester.tap(find.text('Centro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gestionar mis anexos'));
    await tester.pumpAndSettle();

    expect(managed, 1);
  });
}
