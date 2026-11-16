import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/auth/auth_provider.dart';
import 'package:arc_app/features/home/pinned_setlist_card.dart';
import 'package:arc_app/features/home/pinned_setlists_provider.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_test_helpers.dart';

late ProviderContainer container;

Future<void> pumpCard(WidgetTester tester, FakeSetlistRepository repository, {int id = 1}) async {
  SharedPreferences.setMockInitialValues({'pinned_setlist_ids': ['$id']});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        setlistRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(StaticAuth.new),
        activeAnnexProvider.overrideWith(() => FixedActiveAnnex(testAnnex)),
      ],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: Scaffold(
          body: SizedBox(width: 320, child: PinnedSetlistCard(setlistId: id)),
        ),
      ),
    ),
  );
  container = ProviderScope.containerOf(tester.element(find.byType(PinnedSetlistCard)));
  await container.read(pinnedSetlistsProvider.future);
  await tester.pumpAndSettle();
}

List<int> pinned() => container.read(pinnedSetlistsProvider).value!;

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('shows name, date, first three songs with key and the total', (tester) async {
    await pumpCard(tester, FakeSetlistRepository([sampleSetlist()]));

    expect(find.text('Culto de mañana'), findsOneWidget);
    expect(find.textContaining('01/11/2026'), findsOneWidget);
    expect(find.text('Sublime Gracia · G'), findsOneWidget);
    expect(find.text('Santo Espíritu · A'), findsOneWidget);
    expect(find.textContaining('Digno'), findsNothing);
    expect(find.text('5 canciones'), findsOneWidget);
  });

  testWidgets('uses the weekday as title when the setlist has no name', (tester) async {
    await pumpCard(tester, FakeSetlistRepository([sampleSetlist(name: null)]));

    expect(find.text('domingo'), findsOneWidget);
  });

  testWidgets('renders a setlist with no songs', (tester) async {
    await pumpCard(tester, FakeSetlistRepository([sampleSetlist(songs: const [])]));

    expect(tester.takeException(), isNull);
    expect(find.text('0 canciones'), findsOneWidget);
  });

  testWidgets('a song without key shows only the title', (tester) async {
    await pumpCard(
      tester,
      FakeSetlistRepository([sampleSetlist(songs: const [('Digno', '')])]),
    );

    expect(find.text('Digno'), findsOneWidget);
    expect(find.text('1 canción'), findsOneWidget);
  });

  testWidgets('tapping the card opens SetlistDetailScreen', (tester) async {
    await pumpCard(tester, FakeSetlistRepository([sampleSetlist()]));

    await tester.tap(find.text('Culto de mañana'));
    await tester.pumpAndSettle();

    expect(find.byType(SetlistDetailScreen), findsOneWidget);
  });

  testWidgets('menu "Quitar de fijados" unpins the setlist', (tester) async {
    await pumpCard(tester, FakeSetlistRepository([sampleSetlist()]));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de fijados'));
    await tester.pumpAndSettle();

    expect(pinned(), isEmpty);
  });

  testWidgets('a 404 unpins the setlist', (tester) async {
    final repository = FakeSetlistRepository([])..errors[1] = httpError(404);
    await pumpCard(tester, repository);

    expect(pinned(), isEmpty);
  });

  testWidgets('a 500 shows "No se pudo cargar" with "Reintentar" and keeps the pin',
      (tester) async {
    final repository = FakeSetlistRepository([sampleSetlist()])..errors[1] = httpError(500);
    await pumpCard(tester, repository);

    expect(find.text('No se pudo cargar'), findsOneWidget);
    repository.errors.remove(1);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(repository.getOneCalls[1], 2);
    expect(find.text('Culto de mañana'), findsOneWidget);
    expect(pinned(), [1]);
  });

  testWidgets('a network error (DioException without response) keeps the pin',
      (tester) async {
    final repository = FakeSetlistRepository([sampleSetlist()])..errors[1] = networkError();
    await pumpCard(tester, repository);

    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(pinned(), [1]);
  });
}
