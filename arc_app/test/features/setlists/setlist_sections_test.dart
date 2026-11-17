import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/lines/line.dart';
import 'package:arc_app/features/lines/line_repository.dart';
import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

SetlistSong entry(int id, String title, String key, SetlistSection? section, {String? line}) => SetlistSong(
      id: id,
      songId: id,
      position: id,
      key: key,
      songTitle: title,
      songArtist: null,
      section: section,
      lineName: line,
    );

Song librarySong(int id, String title, String key) => Song(
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

final alabanza = Line(id: 7, name: 'Alabanza', songs: const [
  LineSong(songId: 21, key: 'A', title: 'Poderoso', originalKey: 'C'),
  LineSong(songId: 22, key: 'D', title: 'Santo Espíritu', originalKey: 'D'),
]);

/// Keeps the blocks in service order, like the server.
List<SetlistSong> inServiceOrder(List<SetlistSong> songs) {
  int rank(SetlistSong s) => s.section?.index ?? SetlistSection.values.length;
  final sorted = [...songs]..sort((a, b) => rank(a).compareTo(rank(b)));
  return sorted;
}

/// Behaves like the server for adding songs, lines and reordering.
class BlocksRepository extends FakeSetlistRepository {
  BlocksRepository(super.setlists);

  final added = <(int, SetlistSection?)>[];
  final usedLines = <int>[];
  final reorders = <List<int>>[];

  Setlist _with(Setlist s, List<SetlistSong> songs) =>
      Setlist(id: s.id, serviceDate: s.serviceDate, name: s.name, songs: inServiceOrder(songs), annexId: s.annexId);

  @override
  Future<SetlistSong> addSong({
    required int setlistId,
    required int songId,
    String? key,
    SetlistSection? section,
  }) async {
    added.add((songId, section));
    final s = setlists[setlistId]!;
    final created = entry(900 + added.length, 'Agregada $songId', key ?? 'G', section);
    setlists[setlistId] = _with(s, [...s.songs, created]);
    return created;
  }

  @override
  Future<Setlist> useLine({required int setlistId, required int lineId}) async {
    usedLines.add(lineId);
    final s = setlists[setlistId]!;
    setlists[setlistId] = _with(s, [
      ...s.songs.where((x) => x.section != SetlistSection.linea),
      for (final (i, ls) in alabanza.songs.indexed)
        entry(800 + i, ls.title, ls.key, SetlistSection.linea, line: alabanza.name),
    ]);
    return setlists[setlistId]!;
  }

  @override
  Future<void> reorder({required int setlistId, required List<int> setlistSongIds}) async {
    reorders.add(setlistSongIds);
    final s = setlists[setlistId]!;
    final byId = {for (final x in s.songs) x.id: x};
    setlists[setlistId] = _with(s, [for (final id in setlistSongIds) byId[id]!]);
  }
}

class FakeLines implements LineRepository {
  FakeLines(this.lines);
  final List<Line> lines;

  @override
  Future<List<Line>> list() async => lines;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Library extends SongListNotifier {
  @override
  Future<List<Song>> build() async => [librarySong(31, 'Te doy gloria', 'E'), librarySong(32, 'Digno', 'B')];
}

final full = Setlist(
  id: 1,
  serviceDate: DateTime(2026, 11, 22),
  name: 'Culto',
  songs: [
    entry(1, 'Abre mis ojos', 'G', SetlistSection.inicio),
    entry(2, 'Poderoso', 'A', SetlistSection.linea, line: 'Alabanza'),
    entry(3, 'Santo Espíritu', 'D', SetlistSection.linea, line: 'Alabanza'),
    entry(4, 'Todo lo que soy', 'E', SetlistSection.ofrenda),
  ],
);

late BlocksRepository repository;

Future<void> showSetlist(WidgetTester tester, Setlist setlist, {Size size = const Size(1200, 1400), List<Line>? lines}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  repository = BlocksRepository([setlist]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        setlistRepositoryProvider.overrideWithValue(repository),
        lineRepositoryProvider.overrideWithValue(FakeLines(lines ?? [alabanza])),
        songListProvider.overrideWith(_Library.new),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: SetlistDetailScreen(setlistId: setlist.id)),
    ),
  );
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('the setlist shows the service blocks in order, each song under its block', (tester) async {
    await showSetlist(tester, full);

    final inicio = top(tester, find.text('Inicio'));
    final linea = top(tester, find.text('Línea · Alabanza'));
    final ofrenda = top(tester, find.text('Ofrenda'));
    final cena = top(tester, find.text('Santa cena'));
    expect([inicio, linea, ofrenda, cena], orderedEquals([inicio, linea, ofrenda, cena]..sort()));

    expect(top(tester, find.text('Abre mis ojos')), inInclusiveRange(inicio, linea));
    expect(top(tester, find.text('Poderoso')), inInclusiveRange(linea, ofrenda));
    expect(top(tester, find.text('Santo Espíritu')), inInclusiveRange(linea, ofrenda));
    expect(top(tester, find.text('Todo lo que soy')), inInclusiveRange(ofrenda, cena));
  });

  testWidgets('the numbers run through the whole service', (tester) async {
    await showSetlist(tester, full);

    expect(top(tester, find.text('2')), closeTo(top(tester, find.text('Poderoso')), 20));
    expect(top(tester, find.text('4')), closeTo(top(tester, find.text('Todo lo que soy')), 20));
  });

  testWidgets('empty blocks say so', (tester) async {
    await showSetlist(tester, Setlist(id: 1, serviceDate: DateTime(2026, 11, 22), name: null, songs: const []));

    expect(find.text('Sin canción de inicio'), findsOneWidget);
    expect(find.textContaining('Elegí una línea o agregá'), findsOneWidget);
    expect(find.text('Sin canción de ofrenda'), findsOneWidget);
    expect(find.text('Sin santa cena'), findsOneWidget);
  });

  testWidgets('a song is added straight into its block', (tester) async {
    await showSetlist(tester, full);

    await tester.tap(find.byTooltip('Agregar a Ofrenda'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar a Ofrenda'), findsOneWidget); // the picker's title
    await tester.tap(find.text('Digno'));
    await tester.pumpAndSettle();

    expect(repository.added, [(32, SetlistSection.ofrenda)]);
    expect(top(tester, find.text('Agregada 32')), greaterThan(top(tester, find.text('Ofrenda'))));
    expect(top(tester, find.text('Agregada 32')), lessThan(top(tester, find.text('Santa cena'))));
  });

  testWidgets('a line is chosen from the library and fills the line block', (tester) async {
    await showSetlist(tester, Setlist(id: 1, serviceDate: DateTime(2026, 11, 22), name: null, songs: const []));

    await tester.tap(find.text('Elegir línea'));
    await tester.pumpAndSettle();
    expect(find.text('Poderoso · Santo Espíritu'), findsOneWidget); // the line's songs, in the picker
    await tester.tap(find.text('Alabanza'));
    await tester.pumpAndSettle();

    expect(repository.usedLines, [7]);
    expect(find.text('Línea · Alabanza'), findsOneWidget);
    expect(find.text('Poderoso'), findsOneWidget);
    expect(find.text('Santo Espíritu'), findsOneWidget);
  });

  testWidgets('replacing a line that is already there asks first', (tester) async {
    await showSetlist(tester, full);

    await tester.tap(find.text('Cambiar línea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alabanza'));
    await tester.pumpAndSettle();

    expect(find.text('¿Reemplazar la línea?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.usedLines, isEmpty);
  });

  testWidgets('with no lines yet, the picker says where to create them', (tester) async {
    await showSetlist(tester, full, lines: const []);

    await tester.tap(find.text('Cambiar línea'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Creá la primera en la pestaña Líneas'), findsOneWidget);
  });

  testWidgets('songs from before the blocks show under Otras canciones', (tester) async {
    await showSetlist(tester, sampleSetlist(songs: const [('Sublime Gracia', 'G')]));

    expect(find.text('Otras canciones'), findsOneWidget);
    expect(top(tester, find.text('Sublime Gracia')), greaterThan(top(tester, find.text('Otras canciones'))));
    expect(find.byTooltip('Agregar a Otras canciones'), findsNothing);
  });

  testWidgets('dragging reorders inside a block and keeps the rest in place', (tester) async {
    await showSetlist(tester, full);

    final handle = find.descendant(
      of: find.ancestor(of: find.text('Santo Espíritu'), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.drag_indicator),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(repository.reorders, [
      [1, 3, 2, 4],
    ]);
    expect(top(tester, find.text('Santo Espíritu')), lessThan(top(tester, find.text('Poderoso'))));
  });
}
