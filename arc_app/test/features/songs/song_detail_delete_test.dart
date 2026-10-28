import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_detail_screen.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSongRepository implements SongRepository {
  final deleted = <int>[];
  int listCalls = 0;
  bool failDelete = false;

  @override
  Future<void> delete(int songId) async {
    if (failDelete) throw Exception('offline');
    deleted.add(songId);
  }

  @override
  Future<List<Song>> list({String? search}) async {
    listCalls++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _song = Song(
  id: 7,
  title: 'Sublime Gracia',
  artist: 'John Newton',
  originalKey: 'G',
  tempo: null,
  timeSignature: null,
  content: '{verse}\n[G]Sublime',
  notes: null,
  attachments: const [],
);

/// Opens the song on top of a host route, so a pop after deleting lands
/// somewhere observable.
Future<void> openSong(WidgetTester tester, FakeSongRepository repository) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [songRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SongDetailScreen(song: _song)),
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
}

Future<void> askToDelete(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Eliminar canción'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('asks for confirmation, warning about files and setlists', (tester) async {
    await openSong(tester, FakeSongRepository());

    await askToDelete(tester);

    expect(find.text('¿Eliminar «Sublime Gracia»?'), findsOneWidget);
    expect(find.textContaining('setlists'), findsOneWidget);
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);
  });

  testWidgets('Cancelar keeps the song', (tester) async {
    final repository = FakeSongRepository();
    await openSong(tester, repository);

    await askToDelete(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.deleted, isEmpty);
    expect(find.byType(SongDetailScreen), findsOneWidget);
  });

  testWidgets('confirming deletes the song, refreshes the library and closes the screen',
      (tester) async {
    final repository = FakeSongRepository();
    await openSong(tester, repository);
    final listCallsBefore = repository.listCalls;

    await askToDelete(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.deleted, [7]);
    expect(repository.listCalls, greaterThan(listCallsBefore));
    expect(find.byType(SongDetailScreen), findsNothing);
  });

  testWidgets('a failed delete shows an error and stays on the song', (tester) async {
    final repository = FakeSongRepository()..failDelete = true;
    await openSong(tester, repository);

    await askToDelete(tester);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo eliminar la canción.'), findsOneWidget);
    expect(find.byType(SongDetailScreen), findsOneWidget);
  });
}
