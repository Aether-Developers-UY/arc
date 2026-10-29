import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/song_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> showSong(WidgetTester tester, String content) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: SongDetailScreen(
          song: Song(
            id: 1,
            title: 'Prueba',
            artist: null,
            originalKey: 'G',
            tempo: null,
            timeSignature: null,
            content: content,
            notes: null,
            attachments: const [],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('section headings show in Spanish', (tester) async {
    await showSong(tester, '{verse}\n[G]Hola\n{chorus}\nCoro\n{intro}\n[G]  [D]');

    expect(find.text('VERSO'), findsOneWidget);
    expect(find.text('CORO'), findsOneWidget);
    expect(find.text('INTRO'), findsOneWidget);
    expect(find.text('VERSE'), findsNothing);
    expect(find.text('CHORUS'), findsNothing);
  });

  testWidgets('a chords-only line shows each chord without a lyric row', (tester) async {
    await showSong(tester, '{intro}\n[F#m7]  [Bsus4]  [C#m]');

    expect(tester.takeException(), isNull);
    expect(find.text('F#m7'), findsOneWidget);
    expect(find.text('Bsus4'), findsOneWidget);
    expect(find.text('C#m'), findsOneWidget);
    // No blank lyric placeholders under the chords.
    expect(find.text(' '), findsNothing);
  });
}
