import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/lines/line.dart';
import 'package:arc_app/features/lines/line_library_screen.dart';
import 'package:arc_app/features/lines/line_repository.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(int id, String title, String key) => Song(
      id: id,
      title: title,
      artist: null,
      originalKey: key,
      tempo: null,
      timeSignature: null,
      content: '',
      notes: null,
      attachments: const [],
    );

class _Library extends SongListNotifier {
  @override
  Future<List<Song>> build() async =>
      [_song(1, 'Poderoso', 'C'), _song(2, 'Santo Espíritu', 'D'), _song(3, 'Digno', 'B')];
}

/// An in-memory line library that records what was saved.
class MemoryLines implements LineRepository {
  MemoryLines(this.lines);

  final List<Line> lines;
  /// "id|name|key|song:key,song:key" for each save; id empty for a new line.
  final saved = <String>[];
  final deleted = <int>[];

  @override
  Future<Line> getOne(int id) async => lines.firstWhere((l) => l.id == id);

  @override
  Future<List<Line>> list() async => [...lines]..sort((a, b) => a.name.compareTo(b.name));

  Line _store(int id, String name, String key, List<LineSong> songs) {
    saved.add([id < 1000 ? id : '', name, key, [for (final s in songs) '${s.songId}:${s.key}'].join(',')].join('|'));
    final line = Line(id: id, name: name, key: key, songs: songs);
    lines
      ..removeWhere((l) => l.id == id)
      ..add(line);
    return line;
  }

  @override
  Future<Line> create({required String name, required String key, required List<LineSong> songs}) async =>
      _store(1000 + lines.length, name, key, songs);

  @override
  Future<Line> update(int id, {required String name, required String key, required List<LineSong> songs}) async =>
      _store(id, name, key, songs);

  @override
  Future<void> delete(int id) async {
    deleted.add(id);
    lines.removeWhere((l) => l.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In A, going up to D for the second song.
final _alabanza = Line(id: 7, name: 'Alabanza', key: 'A', songs: const [
  LineSong(songId: 1, key: 'A', title: 'Poderoso', originalKey: 'C'),
  LineSong(songId: 2, key: 'D', title: 'Santo Espíritu', originalKey: 'D'),
]);

/// Any song, written in its own key, for the line view behind the editor.
class EchoSongs implements SongRepository {
  @override
  Future<Song> getOne(int id) async => _song(id, 'Canción $id', 'C');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late MemoryLines repository;

Future<void> showLibrary(WidgetTester tester, {List<Line>? lines, Size size = const Size(1000, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  repository = MemoryLines(lines ?? [_alabanza]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lineRepositoryProvider.overrideWithValue(repository),
        songListProvider.overrideWith(_Library.new),
        songRepositoryProvider.overrideWithValue(EchoSongs()),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: const Scaffold(body: LineLibraryScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the line's view, then its editor.
Future<void> openEditor(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Editar línea'));
  await tester.pumpAndSettle();
}

Future<void> addSong(WidgetTester tester, String title) async {
  await tester.tap(find.text('Agregar canción'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('the library shows each line with its songs and the keys they go through', (tester) async {
    await showLibrary(tester);

    expect(find.text('Líneas'), findsOneWidget);
    expect(find.text('Alabanza'), findsOneWidget);
    expect(find.text('Poderoso · Santo Espíritu'), findsOneWidget);
    expect(find.text('A → D'), findsOneWidget);
  });

  testWidgets('an empty library invites to create the first line', (tester) async {
    await showLibrary(tester, lines: []);

    expect(find.textContaining('Todavía no hay líneas'), findsOneWidget);
  });

  testWidgets('a new line takes the key of its first song, and every song follows the line', (tester) async {
    await showLibrary(tester, lines: []);

    await tester.tap(find.text('Nueva línea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Adoración');
    await addSong(tester, 'Digno');
    await addSong(tester, 'Poderoso');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.saved, [
      '|Adoración|B|3:B,1:B',
    ]);
    // Back in the library, with the new line.
    expect(find.text('Adoración'), findsOneWidget);
    expect(find.text('Digno · Poderoso'), findsOneWidget);
  });

  testWidgets('the line key is shown, and the keys only when a song changes key', (tester) async {
    await showLibrary(tester, lines: [
      Line(id: 8, name: 'Pareja', key: 'G', songs: const [
        LineSong(songId: 1, key: 'G', title: 'Poderoso', originalKey: 'C'),
        LineSong(songId: 3, key: 'G', title: 'Digno', originalKey: 'B'),
      ]),
    ]);

    expect(find.text('G'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
    expect(find.text('2 canciones'), findsOneWidget);
  });

  testWidgets('changing the line key moves every song, keeping the step up', (tester) async {
    await showLibrary(tester);
    await openEditor(tester, 'Alabanza');

    await tester.tap(find.byTooltip('Tonalidad de la línea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.saved.single, '7|Alabanza|B|1:B,2:E');
  });

  testWidgets('a song that changes key is marked in the editor', (tester) async {
    await showLibrary(tester);
    await openEditor(tester, 'Alabanza');

    expect(find.text('Cambio de tono'), findsOneWidget);
    final mark = tester.getTopLeft(find.text('Cambio de tono')).dy;
    expect(mark, greaterThan(tester.getTopLeft(find.text('Santo Espíritu')).dy));
  });

  testWidgets('each song in a line can go in another key', (tester) async {
    await showLibrary(tester);
    await openEditor(tester, 'Alabanza');

    await tester.tap(find.byTooltip('Tonalidad de Santo Espíritu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.saved.single, '7|Alabanza|A|1:A,2:E');
  });

  testWidgets('a song can be taken out of a line', (tester) async {
    await showLibrary(tester);
    await openEditor(tester, 'Alabanza');

    await tester.tap(find.byTooltip('Quitar de la línea').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.saved.single, '7|Alabanza|A|2:D');
  });

  testWidgets('a line needs a name and at least one song', (tester) async {
    await showLibrary(tester, lines: []);
    await tester.tap(find.text('Nueva línea'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Poné un nombre a la línea.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Adoración');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Agregá al menos una canción.'), findsOneWidget);
    expect(repository.saved, isEmpty);
  });

  testWidgets('dragging changes the order the songs are played', (tester) async {
    await showLibrary(tester);
    await openEditor(tester, 'Alabanza');

    final handle = find.byIcon(Icons.drag_indicator).last;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.saved.single, '7|Alabanza|A|2:D,1:A');
  });

  testWidgets('a line can be deleted after confirming', (tester) async {
    await showLibrary(tester);
    await openEditor(tester, 'Alabanza');

    await tester.tap(find.byTooltip('Eliminar línea'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Los setlists que ya la usan no cambian'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.deleted, [7]);
    expect(find.text('Alabanza'), findsNothing);
  });

  testWidgets('the editor fits a phone without overflow', (tester) async {
    await showLibrary(tester, size: const Size(360, 740));
    await openEditor(tester, 'Alabanza');

    expect(tester.takeException(), isNull);
  });
}
