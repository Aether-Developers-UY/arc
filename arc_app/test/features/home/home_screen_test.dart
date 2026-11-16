import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/annexes/active_annex_provider.dart';
import 'package:arc_app/features/home/home_screen.dart';
import 'package:arc_app/features/home/pinned_setlist_card.dart';
import 'package:arc_app/features/home/pinned_setlists_provider.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_test_helpers.dart';

int songsTaps = 0;
int setlistsTaps = 0;
int chooseAnnexTaps = 0;

Future<void> pumpHome(
  WidgetTester tester, {
  List<int> pinned = const [],
  List<int> existing = const [],
  Size size = const Size(1200, 1000),
  bool settle = true,
  Map<int, Object> failing = const {},
  bool withoutAnnex = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'pinned_setlist_ids': [for (final id in pinned) '$id'],
  });
  songsTaps = 0;
  setlistsTaps = 0;
  final repository = FakeSetlistRepository([
    for (final id in existing)
      sampleSetlist(id: id, name: 'Culto $id', date: DateTime(2026, 11, id)),
  ])..errors.addAll(failing);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        setlistRepositoryProvider.overrideWithValue(repository),
        activeAnnexProvider.overrideWith(() => FixedActiveAnnex(withoutAnnex ? null : testAnnex)),
      ],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: Scaffold(
          body: HomeScreen(
            onOpenSongs: () => songsTaps++,
            onOpenSetlists: () => setlistsTaps++,
            onChooseAnnexes: () => chooseAnnexTaps++,
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('without annexes shows the join prompt', (tester) async {
    chooseAnnexTaps = 0;
    await pumpHome(tester, pinned: [1], existing: [1], withoutAnnex: true);

    expect(find.text('Todavía no estás en ningún anexo'), findsOneWidget);
    expect(find.text('Todavía no elegiste un culto'), findsNothing);
    await tester.tap(find.text('Elegir anexos'));
    expect(chooseAnnexTaps, 1);
  });

  testWidgets('with no pins shows the empty state and the shortcuts', (tester) async {
    await pumpHome(tester);

    expect(find.text('Todavía no elegiste un culto'), findsOneWidget);
    expect(find.text('Elegir setlist'), findsOneWidget);
    expect(find.text('Biblioteca de canciones'), findsOneWidget);
    expect(find.text('Todos los setlists'), findsOneWidget);
    expect(find.text('Próximamente'), findsOneWidget);
  });

  testWidgets('does not flash the empty state while the pinned ids load', (tester) async {
    await pumpHome(tester, pinned: [1], existing: [1], settle: false);

    expect(find.text('Todavía no elegiste un culto'), findsNothing);
  });

  testWidgets('shows one card per pinned id plus a "+ Fijar setlist" block when fewer than 3',
      (tester) async {
    await pumpHome(tester, pinned: [1, 2], existing: [1, 2]);

    expect(find.byType(PinnedSetlistCard), findsNWidgets(2));
    expect(find.text('+ Fijar setlist'), findsOneWidget);
  });

  testWidgets('with 3 pins there is no "+ Fijar setlist" block', (tester) async {
    await pumpHome(tester, pinned: [1, 2, 3], existing: [1, 2, 3]);

    expect(find.byType(PinnedSetlistCard), findsNWidgets(3));
    expect(find.text('+ Fijar setlist'), findsNothing);
  });

  testWidgets('Biblioteca de canciones and Todos los setlists call their callbacks',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Biblioteca de canciones'));
    await tester.tap(find.text('Todos los setlists'));

    expect(songsTaps, 1);
    expect(setlistsTaps, 1);
  });

  testWidgets('"+ Fijar setlist" opens the sheet listing only unpinned setlists, newest first',
      (tester) async {
    await pumpHome(tester, pinned: [1], existing: [1, 8, 15]);

    await tester.tap(find.text('+ Fijar setlist'));
    await tester.pumpAndSettle();

    expect(find.text('Culto 1'), findsOneWidget); // only its pinned card
    final newest = tester.getTopLeft(find.text('Culto 15')).dy;
    final older = tester.getTopLeft(find.text('Culto 8')).dy;
    expect(newest, lessThan(older));

    await tester.tap(find.text('Culto 8'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(PinnedSetlistCard), findsNWidgets(2));
  });

  testWidgets('the sheet says to create a setlist first when there are none', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Elegir setlist'));
    await tester.pumpAndSettle();

    expect(find.text('Primero creá un setlist en la pestaña Setlists.'), findsOneWidget);

    await tester.tap(find.text('Ir a Setlists'));
    await tester.pumpAndSettle();

    expect(setlistsTaps, 1);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('two pinned setlists answering 404 at once are both unpinned', (tester) async {
    await pumpHome(tester, pinned: [1, 2, 3], existing: [1]);

    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(container.read(pinnedSetlistsProvider).value, [1]);
    expect(find.byType(PinnedSetlistCard), findsOneWidget);
  });

  testWidgets('a failing block does not break the others', (tester) async {
    await pumpHome(tester, pinned: [1, 2, 3], existing: [1, 2], failing: {2: httpError(500)});

    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(find.text('Culto 1'), findsOneWidget);
    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(container.read(pinnedSetlistsProvider).value, [1, 2]);
  });

  testWidgets('the sheet explains when every setlist is already pinned', (tester) async {
    await pumpHome(tester, pinned: [1], existing: [1]);

    await tester.tap(find.text('+ Fijar setlist'));
    await tester.pumpAndSettle();

    expect(find.text('Ya fijaste todos tus setlists.'), findsOneWidget);
  });

  testWidgets('desktop width shows the three cards side by side', (tester) async {
    await pumpHome(tester, pinned: [1, 2, 3], existing: [1, 2, 3]);

    final tops = [
      for (final e in find.byType(PinnedSetlistCard).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    expect(tops.toSet().length, 1);
  });

  testWidgets('phone width (360) with three pins does not overflow', (tester) async {
    await pumpHome(tester, pinned: [1, 2, 3], existing: [1, 2, 3], size: const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(PinnedSetlistCard), findsNWidgets(3));
  });
}
