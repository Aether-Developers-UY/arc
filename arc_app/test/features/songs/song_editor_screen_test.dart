import 'dart:async';

import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/song.dart';
import 'package:arc_app/features/songs/editor/song_lyrics_editor.dart';
import 'package:arc_app/features/songs/song_editor_screen.dart';
import 'package:arc_app/features/songs/song_list_provider.dart';
import 'package:arc_app/features/songs/song_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Finder field(String label) => find.widgetWithText(TextField, label);

/// A repository whose `create` never completes, so a save stays in flight.
class _PendingSaveRepository implements SongRepository {
  int createCalls = 0;

  @override
  Future<Song> create(Song song) {
    createCalls++;
    return Completer<Song>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the song sent to `create`.
class _RecordingRepository implements SongRepository {
  Song? created;

  @override
  Future<Song> create(Song song) async => created = song;

  @override
  Future<List<Song>> list({String? search}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Opens the editor on top of a host route, so system back has somewhere to
/// go if the editor ever pops itself.
Future<void> openEditor(
  WidgetTester tester, {
  Song? existingSong,
  SongRepository? repository,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null) songRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: ArcaTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SongEditorScreen(existingSong: existingSong)),
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

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
}

Song sampleSong({String content = '{verse}\n[G]Sublime'}) => Song(
      id: 1,
      title: 'Sublime Gracia',
      artist: 'John Newton',
      originalKey: 'G',
      tempo: 80,
      timeSignature: '3/4',
      content: content,
      notes: 'Empezar solo con piano',
      attachments: const [],
    );

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('starts on step 1 with the "Paso 1 de 2" indicator and no lyrics editor',
      (tester) async {
    await openEditor(tester);

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.text('Letra y acordes'), findsNothing);
  });

  testWidgets('Siguiente with an empty title stays on step 1 and shows an error',
      (tester) async {
    await openEditor(tester);

    await next(tester);

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.textContaining('título'), findsOneWidget);
  });

  testWidgets('Siguiente with a whitespace-only title stays on step 1', (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), '   ');
    await next(tester);

    expect(find.text('Paso 1 de 2'), findsOneWidget);
  });

  testWidgets('Siguiente with a whitespace-only key stays on step 1', (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), 'Mi canción');
    await tester.enterText(field('Tonalidad *'), '  ');
    await next(tester);

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.textContaining('tonalidad'), findsOneWidget);
  });

  testWidgets('Siguiente with a non-numeric tempo stays on step 1 and shows a tempo error',
      (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), 'Mi canción');
    await tester.enterText(field('Tempo (BPM)'), 'rápido');
    await next(tester);

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.textContaining('tempo'), findsOneWidget);
  });

  testWidgets('Siguiente with a valid title advances to step 2', (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);

    expect(find.text('Paso 2 de 2'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('Atrás returns to step 1 keeping the typed title', (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    expect(find.text('Mi canción'), findsOneWidget);
  });

  testWidgets('the step 1 error is cleared after advancing and coming back',
      (tester) async {
    await openEditor(tester);

    await next(tester);
    expect(find.textContaining('título'), findsOneWidget);
    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ingresá'), findsNothing);
  });

  testWidgets('system back on step 2 returns to step 1 instead of closing the editor',
      (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SongEditorScreen), findsOneWidget);
    expect(find.text('Paso 1 de 2'), findsOneWidget);
  });

  testWidgets('typed lyrics survive going back to step 1 and forward again',
      (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);
    await tester.enterText(find.byType(TextField).first, 'Cantaré');
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    await next(tester);

    expect(find.text('Cantaré'), findsOneWidget);
  });

  testWidgets('system back is ignored on step 2 while a save is in flight',
      (tester) async {
    final repository = _PendingSaveRepository();
    await openEditor(tester, repository: repository);

    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(repository.createCalls, 1);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Paso 2 de 2'), findsOneWidget);
  });

  testWidgets('system back on step 1 closes the editor', (tester) async {
    await openEditor(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SongEditorScreen), findsNothing);
  });

  testWidgets('editing an existing song prefills both steps', (tester) async {
    await openEditor(tester, existingSong: sampleSong());

    expect(find.text('Sublime Gracia'), findsOneWidget);
    await next(tester);

    expect(find.text('Paso 2 de 2'), findsOneWidget);
    expect(find.text('Empezar solo con piano'), findsOneWidget);
  });

  testWidgets('editing a song with blank content starts step 2 with an empty verse',
      (tester) async {
    await openEditor(tester, existingSong: sampleSong(content: ''));

    await next(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('VERSO'), findsOneWidget);
  });

  testWidgets('a new song starts step 2 in Letra mode', (tester) async {
    await openEditor(tester);

    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);

    expect(find.text('Escribí o pegá la letra'), findsOneWidget);
  });

  testWidgets('an existing song starts step 2 in Acordes mode', (tester) async {
    await openEditor(tester, existingSong: sampleSong());

    await next(tester);

    expect(find.byType(LyricWord), findsOneWidget);
    expect(find.text('Escribí o pegá la letra'), findsNothing);
  });

  testWidgets('write lyrics, add a chord and save', (tester) async {
    final repository = _RecordingRepository();
    await openEditor(tester, repository: repository);

    await tester.enterText(field('Título *'), 'Mi canción');
    await next(tester);
    await tester.enterText(find.byType(TextField).first, 'Cantaré al Señor');
    await tester.pump();
    await tester.tap(find.text('Acordes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Señor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('D'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insertar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.created?.content, '{verse}\nCantaré al [D]Señor');
  });
}
