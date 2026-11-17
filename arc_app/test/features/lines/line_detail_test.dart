import 'package:arc_app/core/screen_awake.dart';
import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/lines/line.dart';
import 'package:arc_app/features/lines/line_library_screen.dart';
import 'package:arc_app/features/lines/line_repository.dart';
import 'package:arc_app/features/setlists/stage_screen.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'line_library_test.dart' show MemoryLines;

/// Every song is written in C: "[C]Letra de <title>".
class _Songs implements SongRepository {
  static const titles = {1: 'Poderoso', 2: 'Santo Espíritu'};

  @override
  Future<Song> getOne(int id) async => Song(
        id: id,
        title: titles[id]!,
        artist: null,
        originalKey: 'C',
        tempo: null,
        timeSignature: null,
        content: '[C]Letra de ${titles[id]}',
        notes: null,
        attachments: const [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSongs extends SongListNotifier {
  @override
  Future<List<Song>> build() async => [];
}

class _Awake implements ScreenAwake {
  @override
  Future<void> keep(bool on) async {}
}

/// In A, going up to B for the second song.
Line alabanza({List<Attachment> attachments = const []}) => Line(
      id: 7,
      name: 'Alabanza',
      key: 'A',
      songs: const [
        LineSong(songId: 1, key: 'A', title: 'Poderoso', originalKey: 'C'),
        LineSong(songId: 2, key: 'B', title: 'Santo Espíritu', originalKey: 'C'),
      ],
      attachments: attachments,
    );

late MemoryLines repository;

/// Opens the library and taps the line.
Future<void> openLine(WidgetTester tester, {Line? line, Size size = const Size(1000, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  repository = MemoryLines([line ?? alabanza()]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lineRepositoryProvider.overrideWithValue(repository),
        songRepositoryProvider.overrideWithValue(_Songs()),
        songListProvider.overrideWith(_NoSongs.new),
        screenAwakeProvider.overrideWithValue(_Awake()),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: const Scaffold(body: LineLibraryScreen())),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Alabanza'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('tapping a line shows it, starting on its first song in the line key', (tester) async {
    await openLine(tester);

    expect(find.byTooltip('Editar línea'), findsOneWidget);
    expect(find.text('Guardar'), findsNothing); // a view, not the editor
    expect(find.text('Letra de Poderoso'), findsOneWidget);
    expect(find.text('A'), findsWidgets); // C transposed to the line's A
    expect(find.text('C'), findsNothing);
  });

  testWidgets('the songs can be switched by tapping their names', (tester) async {
    await openLine(tester);

    await tester.tap(find.text('2. Santo Espíritu'));
    await tester.pumpAndSettle();

    expect(find.text('Letra de Santo Espíritu'), findsOneWidget);
    expect(find.text('Cambio de tono · Tonalidad B'), findsOneWidget);
  });

  testWidgets('swiping moves to the next song', (tester) async {
    await openLine(tester);

    await tester.fling(find.text('Letra de Poderoso'), const Offset(-600, 0), 1500);
    await tester.pumpAndSettle();

    expect(find.text('Letra de Santo Espíritu'), findsOneWidget);
  });

  testWidgets('the line files have their own tab, with the count', (tester) async {
    await openLine(tester, line: alabanza(attachments: [
      Attachment(id: 3, type: 'audio', originalName: 'ensayo.mp3', filePath: 'a/ensayo.mp3'),
    ]));

    await tester.tap(find.text('Archivos (1)'));
    await tester.pumpAndSettle();

    expect(find.text('ensayo.mp3'), findsOneWidget);
    expect(find.byTooltip('Agregar archivo'), findsOneWidget);
  });

  testWidgets('Modo escenario plays the line, each song in its key', (tester) async {
    await openLine(tester);

    await tester.tap(find.text('Modo escenario'));
    await tester.pumpAndSettle();

    expect(find.byType(StageScreen), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Línea · Tonalidad A'), findsOneWidget);
  });

  testWidgets('the view follows an edit made from it', (tester) async {
    await openLine(tester);

    await tester.tap(find.byTooltip('Editar línea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alabanza alegre');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Alabanza alegre'), findsOneWidget);
    expect(find.byTooltip('Editar línea'), findsOneWidget);
  });

  testWidgets('deleting the line from its editor goes back to the library', (tester) async {
    await openLine(tester);

    await tester.tap(find.byTooltip('Editar línea'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar línea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva línea'), findsOneWidget);
    expect(find.text('Alabanza'), findsNothing);
  });

  testWidgets('the view fits a phone without overflow', (tester) async {
    await openLine(tester, size: const Size(360, 740));

    expect(tester.takeException(), isNull);
  });
}
