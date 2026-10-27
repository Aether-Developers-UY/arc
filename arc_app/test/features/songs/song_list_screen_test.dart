import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _viewKey = 'song_list_view';

class _TwoSongs extends SongListNotifier {
  @override
  Future<List<Song>> build() async => [
        Song(
          id: 1,
          title: 'Sublime Gracia',
          artist: 'John Newton',
          originalKey: 'G',
          tempo: null,
          timeSignature: null,
          content: '',
          notes: null,
          attachments: const [],
        ),
        Song(
          id: 2,
          title: 'Digno',
          artist: null,
          originalKey: 'E',
          tempo: null,
          timeSignature: null,
          content: '',
          notes: null,
          attachments: const [],
        ),
      ];
}

Future<void> pumpSongs(WidgetTester tester, {Map<String, Object> stored = const {}}) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(stored);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [songListProvider.overrideWith(_TwoSongs.new)],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: const Scaffold(body: SongListScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('shows the songs as blocks by default', (tester) async {
    await pumpSongs(tester);

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Sublime Gracia'), findsOneWidget);
  });

  testWidgets('switching to Lista shows a list and remembers it', (tester) async {
    await pumpSongs(tester);

    await tester.tap(find.byTooltip('Lista'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_viewKey), 'list');
  });

  testWidgets('starts in the list when that was the last choice', (tester) async {
    await pumpSongs(tester, stored: {_viewKey: 'list'});

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('a block shows title, artist and key', (tester) async {
    await pumpSongs(tester);

    expect(find.text('Sublime Gracia'), findsOneWidget);
    expect(find.text('John Newton'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Digno'), findsOneWidget);
  });

  testWidgets('switching back to Bloques shows the grid again', (tester) async {
    await pumpSongs(tester, stored: {_viewKey: 'list'});

    await tester.tap(find.byTooltip('Bloques'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_viewKey), 'grid');
  });

  testWidgets('an unknown stored value falls back to blocks', (tester) async {
    await pumpSongs(tester, stored: {_viewKey: 'banana'});

    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks fit a phone width without overflow', (tester) async {
    await pumpSongs(tester);
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
