import 'package:arc_app/core/screen_awake.dart';
import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/setlist_detail_screen.dart';
import 'package:arc_app/features/setlists/setlist_list_provider.dart';
import 'package:arc_app/features/setlists/stage_screen.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_test_helpers.dart';

class _Songs implements SongRepository {
  @override
  Future<Song> getOne(int id) async => Song(
        id: id,
        title: 'Canción $id',
        artist: null,
        originalKey: 'G',
        tempo: null,
        timeSignature: null,
        content: '[G]Hola',
        notes: null,
        attachments: const [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Awake implements ScreenAwake {
  @override
  Future<void> keep(bool on) async {}
}

Future<void> showSetlist(WidgetTester tester, Setlist setlist) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        setlistRepositoryProvider.overrideWithValue(FakeSetlistRepository([setlist])),
        songRepositoryProvider.overrideWithValue(_Songs()),
        screenAwakeProvider.overrideWithValue(_Awake()),
      ],
      child: MaterialApp(theme: ArcaTheme.light(), home: SetlistDetailScreen(setlistId: setlist.id)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('Modo escenario opens the setlist on stage from its first song', (tester) async {
    await showSetlist(tester, sampleSetlist());

    await tester.tap(find.text('Modo escenario'));
    await tester.pumpAndSettle();

    expect(find.byType(StageScreen), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('an empty setlist has no stage to open', (tester) async {
    await showSetlist(tester, sampleSetlist(songs: const []));

    expect(find.text('Modo escenario'), findsNothing);
  });
}
