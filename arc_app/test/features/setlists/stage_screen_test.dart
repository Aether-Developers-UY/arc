import 'package:arc_app/core/screen_awake.dart';
import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/stage_screen.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

/// Every song is written in G; the setlist decides the key it is played in.
class _Songs implements SongRepository {
  @override
  Future<Song> getOne(int id) async => Song(
        id: id,
        title: 'Canción $id',
        artist: null,
        originalKey: 'G',
        tempo: null,
        timeSignature: null,
        // Long enough to scroll; only the first line has a chord.
        content: '{verse}\n[G]Letra de la canción $id\n'
            '${[for (var i = 1; i <= 40; i++) 'verso $i'].join('\n')}',
        notes: null,
        attachments: const [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAwake implements ScreenAwake {
  final calls = <bool>[];

  @override
  Future<void> keep(bool on) async => calls.add(on);
}

late FakeAwake awake;

final Setlist setlist = sampleSetlist(songs: const [
  ('Sublime Gracia', 'G'),
  ('Cuán Grande Es Él', 'A'),
  ('Digno', 'E'),
]);

/// Opens the stage from a plain screen, so closing it can be checked.
Future<void> openStage(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Map<String, Object> stored = const {},
  Setlist? of,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(stored);
  awake = FakeAwake();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songRepositoryProvider.overrideWithValue(_Songs()),
        screenAwakeProvider.overrideWithValue(awake),
      ],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => StageScreen(setlist: of ?? setlist)),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

double lyricSize(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('opens on the first song, in the setlist key', (tester) async {
    await openStage(tester);

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Sublime Gracia'), findsOneWidget);
    expect(find.text('Tonalidad G'), findsOneWidget);
    expect(find.text('Letra de la canción 1'), findsOneWidget);
  });

  testWidgets('the block of the service shows next to the key', (tester) async {
    SetlistSong s(int i, String title, SetlistSection section) =>
        SetlistSong(id: i, songId: i, position: i, key: 'G', songTitle: title, songArtist: null, section: section);
    await openStage(tester, of: Setlist(id: 9, serviceDate: DateTime(2026, 11, 22), name: null, songs: [
      s(1, 'Abre mis ojos', SetlistSection.inicio),
      s(2, 'Poderoso', SetlistSection.linea),
    ]));

    expect(find.text('Inicio · Tonalidad G'), findsOneWidget);
    await tester.tap(find.byTooltip('Canción siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Línea · Tonalidad G'), findsOneWidget);
  });

  testWidgets('next and previous move through the setlist, transposing each song', (tester) async {
    await openStage(tester);

    await tester.tap(find.byTooltip('Canción siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Cuán Grande Es Él'), findsOneWidget);
    expect(find.text('Tonalidad A'), findsOneWidget);
    expect(find.text('Letra de la canción 2'), findsOneWidget);
    // Written in G, played in A: the chord goes up a tone.
    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.byTooltip('Canción anterior'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('there is no going back from the first song or on from the last', (tester) async {
    await openStage(tester);
    IconButton button(String tooltip) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, tooltip == 'prev' ? Icons.chevron_left : Icons.chevron_right));

    expect(button('prev').onPressed, isNull);

    await tester.tap(find.byTooltip('Canción siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Canción siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
    expect(button('next').onPressed, isNull);
  });

  testWidgets('swiping changes the song', (tester) async {
    await openStage(tester);

    await tester.fling(find.text('Letra de la canción 1'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('a pedal or keyboard changes the song with arrows and page keys', (tester) async {
    await openStage(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('space starts and pauses the autoscroll', (tester) async {
    await openStage(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byTooltip('Pausar'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byTooltip('Reanudar'), findsOneWidget);
  });

  testWidgets('the lyrics are large and can be made larger or smaller, remembered', (tester) async {
    await openStage(tester);
    final start = lyricSize(tester, 'Letra de la canción 1');
    expect(start, greaterThan(20), reason: 'bigger than the normal song view');

    await tester.tap(find.byTooltip('Letra más grande'));
    await tester.pumpAndSettle();
    expect(lyricSize(tester, 'Letra de la canción 1'), greaterThan(start));

    await tester.tap(find.byTooltip('Letra más chica'));
    await tester.tap(find.byTooltip('Letra más chica'));
    await tester.pumpAndSettle();
    expect(lyricSize(tester, 'Letra de la canción 1'), lessThan(start));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('stage_text_scale'), isNotNull);
  });

  testWidgets('a stored text size is used when opening', (tester) async {
    await openStage(tester, stored: {'stage_text_scale': 2.0});

    expect(lyricSize(tester, 'Letra de la canción 1'), 40);
  });

  testWidgets('the screen stays on for the whole stage, and sleeps again on leaving', (tester) async {
    await openStage(tester);
    expect(awake.calls, [true]);

    await tester.tap(find.byTooltip('Salir del modo escenario'));
    await tester.pumpAndSettle();

    expect(find.text('Abrir'), findsOneWidget);
    expect(awake.calls, [true, false]);
  });
}
