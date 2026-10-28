import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/home/pinned_setlists_provider.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

/// Opens setlist 1 on top of a host route, so a pop after deleting lands
/// somewhere observable. Returns the container to inspect the pins.
Future<ProviderContainer> openSetlist(
  WidgetTester tester,
  FakeSetlistRepository repository, {
  Map<String, Object> stored = const {},
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(stored);
  final container = ProviderContainer(
    overrides: [setlistRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetlistDetailScreen(setlistId: 1)),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return container;
}

Future<void> askToDelete(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Eliminar setlist'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('asks for confirmation, saying the songs stay in the library',
      (tester) async {
    await openSetlist(tester, FakeSetlistRepository([sampleSetlist()]));

    await askToDelete(tester);

    expect(find.text('¿Eliminar «Culto de mañana»?'), findsOneWidget);
    expect(find.textContaining('biblioteca'), findsOneWidget);
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);
  });

  testWidgets('Cancelar keeps the setlist', (tester) async {
    final repository = FakeSetlistRepository([sampleSetlist()]);
    await openSetlist(tester, repository);

    await askToDelete(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.deleted, isEmpty);
    expect(find.byType(SetlistDetailScreen), findsOneWidget);
  });

  testWidgets('confirming deletes it, unpins it from Inicio and closes the screen',
      (tester) async {
    final repository = FakeSetlistRepository([sampleSetlist()]);
    final container =
        await openSetlist(tester, repository, stored: {'pinned_setlist_ids': ['1']});

    await askToDelete(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.deleted, [1]);
    expect(await container.read(pinnedSetlistsProvider.future), isEmpty);
    expect(find.byType(SetlistDetailScreen), findsNothing);
  });

  testWidgets('a failed delete shows an error and stays on the setlist', (tester) async {
    final repository = FakeSetlistRepository([sampleSetlist()])..failDelete = true;
    await openSetlist(tester, repository);

    await askToDelete(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo eliminar el setlist.'), findsOneWidget);
    expect(find.byType(SetlistDetailScreen), findsOneWidget);
  });
}
