import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/lyric_search.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_list_screen.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(int id, String title, String content, {String? artist}) => Song(
      id: id,
      title: title,
      artist: artist,
      originalKey: 'G',
      tempo: 80,
      timeSignature: '4/4',
      content: content,
      notes: null,
      attachments: const [],
    );

final _songs = [
  _song(1, 'Cuán Grande Es Él',
      '{verse}\n[G]Señor mi [C]Dios, al contem[G]plar los cielos\n[D]El firmamento y las estrellas mil'),
  _song(2, 'Sublime Gracia', '[G]Sublime gracia del Se[D]ñor\nque a un pecador salvó',
      artist: 'John Newton'),
];

/// Searches like the server: title, artist or lyrics.
class SearchingRepository implements SongRepository {
  final searches = <String?>[];

  /// Searches that take this long to answer, to test out-of-order replies.
  final slow = <String, Duration>{};

  @override
  Future<List<Song>> list({String? search}) async {
    searches.add(search);
    final delay = slow[search];
    if (delay != null) await Future<void>.delayed(delay);
    if (search == null || search.isEmpty) return _songs;
    return [
      for (final s in _songs)
        if (matchesTitleOrArtist(s.title, s.artist, search) || lyricMatch(s.content, search) != null) s,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late SearchingRepository repository;

Future<void> pumpSearch(WidgetTester tester, {Size size = const Size(1000, 1000), String view = 'grid'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'song_list_view': view});
  repository = SearchingRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [songRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: ArcaTheme.light(), home: const Scaffold(body: SongListScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

/// The full text of the rich text showing the lyric match, if any.
String? snippetText(WidgetTester tester) {
  final finder = find.byKey(const Key('lyric-match'));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<RichText>(find.descendant(of: finder, matching: find.byType(RichText)).last).text.toPlainText();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('the search box says it also looks in the lyrics', (tester) async {
    await pumpSearch(tester);

    expect(find.text('Buscar por título, artista o letra'), findsOneWidget);
  });

  for (final view in ['grid', 'list']) {
    testWidgets('a lyric match shows the phrase it found ($view)', (tester) async {
      await pumpSearch(tester, view: view);

      await search(tester, 'al contemplar');

      expect(repository.searches.last, 'al contemplar');
      expect(find.text('Cuán Grande Es Él'), findsOneWidget);
      expect(find.text('Sublime Gracia'), findsNothing);
      expect(snippetText(tester), contains('al contemplar'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the matched words stand out in the phrase', (tester) async {
    await pumpSearch(tester);

    await search(tester, 'FIRMAMENTO');

    final span = tester
        .widget<RichText>(find.descendant(of: find.byKey(const Key('lyric-match')), matching: find.byType(RichText)).last)
        .text as TextSpan;
    final bold = <String>[];
    span.visitChildren((child) {
      if (child is TextSpan && child.style?.fontWeight == FontWeight.w700) bold.add(child.text ?? '');
      return true;
    });
    expect(bold, ['firmamento']);
  });

  testWidgets('a title or artist match does not show a lyric phrase', (tester) async {
    await pumpSearch(tester);

    await search(tester, 'newton');

    expect(find.text('Sublime Gracia'), findsOneWidget);
    expect(snippetText(tester), isNull);
  });

  testWidgets('no results says so, instead of an empty repertoire', (tester) async {
    await pumpSearch(tester);

    await search(tester, 'aleluya');

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.textContaining('«aleluya»'), findsOneWidget);
    expect(find.text('Todavía no hay canciones'), findsNothing);
  });

  testWidgets('clearing the search brings every song back', (tester) async {
    await pumpSearch(tester);
    expect(find.byTooltip('Limpiar búsqueda'), findsNothing);

    await search(tester, 'aleluya');
    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pumpAndSettle();

    expect(find.text('Cuán Grande Es Él'), findsOneWidget);
    expect(find.text('Sublime Gracia'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.byTooltip('Limpiar búsqueda'), findsNothing);
  });

  testWidgets('pulling to refresh keeps the current search', (tester) async {
    await pumpSearch(tester);
    await search(tester, 'newton');

    await tester.fling(find.text('Sublime Gracia'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repository.searches.last, 'newton');
    expect(find.text('Cuán Grande Es Él'), findsNothing);
  });

  group('while typing', () {
    /// Types without pressing Enter.
    Future<void> type(WidgetTester tester, String text) => tester.enterText(find.byType(TextField), text);

    testWidgets('the list filters after a short pause, no Enter needed', (tester) async {
      await pumpSearch(tester);

      await type(tester, 'al contemplar');
      await tester.pump(searchPause);
      await tester.pumpAndSettle();

      expect(find.text('Cuán Grande Es Él'), findsOneWidget);
      expect(find.text('Sublime Gracia'), findsNothing);
      expect(snippetText(tester), contains('al contemplar'));
    });

    testWidgets('it waits for the pause instead of searching every letter', (tester) async {
      await pumpSearch(tester);

      await type(tester, 'a');
      await tester.pump(const Duration(milliseconds: 100));
      await type(tester, 'al');
      await tester.pump(const Duration(milliseconds: 100));
      await type(tester, 'al contemplar');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.searches, [null]);

      await tester.pump(searchPause);
      await tester.pumpAndSettle();
      expect(repository.searches, [null, 'al contemplar']);
    });

    testWidgets('Enter searches right away, without a second search after the pause', (tester) async {
      await pumpSearch(tester);

      await type(tester, 'newton');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(searchPause * 2);
      await tester.pumpAndSettle();

      expect(repository.searches, [null, 'newton']);
      expect(find.text('Sublime Gracia'), findsOneWidget);
    });

    testWidgets('erasing the text brings every song back', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'newton');
      await tester.pump(searchPause);
      await tester.pumpAndSettle();
      expect(find.text('Cuán Grande Es Él'), findsNothing);

      await type(tester, '');
      await tester.pump(searchPause);
      await tester.pumpAndSettle();

      expect(find.text('Cuán Grande Es Él'), findsOneWidget);
      expect(find.text('Sublime Gracia'), findsOneWidget);
    });

    testWidgets('spaces alone or the same search again do not search again', (tester) async {
      await pumpSearch(tester);
      await type(tester, 'newton');
      await tester.pump(searchPause);
      await tester.pumpAndSettle();

      await type(tester, 'newton ');
      await tester.pump(searchPause);
      await tester.pumpAndSettle();

      expect(repository.searches, [null, 'newton']);
    });

    testWidgets('the songs stay on screen while the next search loads', (tester) async {
      await pumpSearch(tester);
      repository.slow['newton'] = const Duration(seconds: 1);

      await type(tester, 'newton');
      await tester.pump(searchPause);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Cuán Grande Es Él'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Cuán Grande Es Él'), findsNothing);
    });

    testWidgets('a slow older answer does not replace a newer one', (tester) async {
      await pumpSearch(tester);
      repository.slow['al'] = const Duration(seconds: 1); // matches both songs

      await type(tester, 'al');
      await tester.pump(searchPause);
      await type(tester, 'al contemplar');
      await tester.pump(searchPause);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2)); // the old answer arrives
      await tester.pumpAndSettle();

      expect(find.text('Cuán Grande Es Él'), findsOneWidget);
      expect(find.text('Sublime Gracia'), findsNothing);
    });
  });

  testWidgets('a lyric match fits a phone-width block without overflow', (tester) async {
    await pumpSearch(tester, size: const Size(360, 800));

    await search(tester, 'que a un pecador');

    expect(snippetText(tester), contains('que a un pecador'));
    expect(tester.takeException(), isNull);
  });
}
