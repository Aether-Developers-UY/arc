import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/setlists/setlist_block.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:arc_app/features/setlists/setlist_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

const _viewKey = 'setlist_list_view';

Future<FakeSetlistRepository> pumpSetlists(
  WidgetTester tester, {
  Map<String, Object> stored = const {},
  Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(stored);
  final repository = FakeSetlistRepository([
    sampleSetlist(),
    sampleSetlist(id: 2, name: null, date: DateTime(2026, 11, 8), songs: const []),
  ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [setlistRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: const Scaffold(body: SetlistListScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('shows the setlists as blocks by default, like Inicio', (tester) async {
    await pumpSetlists(tester);

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(SetlistBlock), findsNWidgets(2));
    expect(find.text('Culto de mañana'), findsOneWidget);
    expect(find.text('Sublime Gracia · G'), findsOneWidget);
    expect(find.text('5 canciones'), findsOneWidget);
    expect(find.text('0 canciones'), findsOneWidget);
  });

  testWidgets('switching to Lista shows the list and remembers it', (tester) async {
    await pumpSetlists(tester);

    await tester.tap(find.byTooltip('Lista'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(SetlistBlock), findsNothing);
    expect(find.text('Culto de mañana'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_viewKey), 'list');
  });

  testWidgets('starts in the list when that was the last choice', (tester) async {
    await pumpSetlists(tester, stored: {_viewKey: 'list'});

    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('the list choice for setlists does not change the songs choice',
      (tester) async {
    await pumpSetlists(tester, stored: {'song_list_view': 'list'});

    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('tapping a block opens the setlist', (tester) async {
    await pumpSetlists(tester);

    await tester.tap(find.text('Culto de mañana'));
    await tester.pumpAndSettle();

    expect(find.byType(SetlistDetailScreen), findsOneWidget);
  });

  testWidgets('coming back from a setlist refreshes its block', (tester) async {
    final repository = await pumpSetlists(tester);

    await tester.tap(find.text('Culto de mañana'));
    await tester.pumpAndSettle();
    repository.setlists[1] = sampleSetlist(songs: const [('Digno', 'E')]);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Digno · E'), findsOneWidget);
    expect(find.text('1 canción'), findsOneWidget);
  });

  testWidgets('blocks fit a phone width without overflow', (tester) async {
    await pumpSetlists(tester, size: const Size(360, 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(SetlistBlock), findsNWidgets(2));
  });
}
