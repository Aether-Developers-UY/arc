import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_helpers.dart';

/// Deleting a song also drops it from the fake setlist, like the backend's
/// cascade does.
class _SongRepository implements SongRepository {
  _SongRepository(this.setlists);

  final FakeSetlistRepository setlists;

  @override
  Future<Song> getOne(int id) async => Song(
        id: id,
        title: 'Sublime Gracia',
        artist: null,
        originalKey: 'G',
        tempo: null,
        timeSignature: null,
        content: '{verse}\n[G]Sublime',
        notes: null,
        attachments: const [],
      );

  @override
  Future<void> delete(int songId) async {
    setlists.setlists[1] = sampleSetlist(songs: const [('Digno', 'E')]);
  }

  @override
  Future<List<Song>> list({String? search}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('a song deleted from inside the setlist disappears when coming back',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final setlists = FakeSetlistRepository([
      sampleSetlist(songs: const [('Sublime Gracia', 'G'), ('Digno', 'E')]),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setlistRepositoryProvider.overrideWithValue(setlists),
          songRepositoryProvider.overrideWithValue(_SongRepository(setlists)),
        ],
        child: MaterialApp(
          theme: ArcaTheme.light(),
          home: const SetlistDetailScreen(setlistId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sublime Gracia'), findsOneWidget);

    await tester.tap(find.text('Sublime Gracia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar canción'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.byType(SetlistDetailScreen), findsOneWidget);
    expect(find.text('Sublime Gracia'), findsNothing);
    expect(find.text('Digno'), findsOneWidget);
  });
}
