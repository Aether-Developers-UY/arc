import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/editor/editable_document.dart';
import 'package:arc_app/features/songs/editor/song_lyrics_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sections as last reported by the editor.
late List<EditableSection> current;

String get chordPro => editableToChordPro(current);

Future<void> pumpEditor(WidgetTester tester, String content, LyricsMode mode) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  current = parseToEditable(content);
  await tester.pumpWidget(
    MaterialApp(
      theme: ArcaTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => SongLyricsEditor(
              sections: current,
              mode: mode,
              onChanged: (next) => setState(() => current = next),
            ),
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

  group('lyrics mode', () {
    testWidgets('shows one text field per section with its name', (tester) async {
      await pumpEditor(tester, '{verse}\nUno\n{chorus}\nDos', LyricsMode.lyrics);

      expect(find.text('VERSO'), findsOneWidget);
      expect(find.text('CORO'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('typing in a section updates the song keeping the cursor', (tester) async {
      await pumpEditor(tester, '{verse}\n', LyricsMode.lyrics);

      await tester.enterText(find.byType(TextField), 'Hola mundo');
      await tester.pump();

      expect(chordPro, '{verse}\nHola mundo');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Hola mundo');
      expect(field.controller!.selection.baseOffset, 10);
    });

    testWidgets('+ Sección offers the five types and appends the chosen one', (tester) async {
      await pumpEditor(tester, '{verse}\nUno', LyricsMode.lyrics);

      await tester.tap(find.text('Sección'));
      await tester.pumpAndSettle();
      for (final name in ['Intro', 'Verso', 'Coro', 'Puente', 'Interludio']) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.tap(find.text('Coro'));
      await tester.pumpAndSettle();

      expect(current.map((s) => s.label), ['verse', 'chorus']);
    });

    testWidgets('sections move up and down', (tester) async {
      await pumpEditor(tester, '{verse}\nUno\n{chorus}\nDos', LyricsMode.lyrics);

      await tester.tap(find.byTooltip('Subir sección').last);
      await tester.pumpAndSettle();

      expect(current.map((s) => s.label), ['chorus', 'verse']);
    });

    testWidgets('removing a section with content asks first', (tester) async {
      await pumpEditor(tester, '{verse}\nUno\n{chorus}\nDos', LyricsMode.lyrics);

      await tester.tap(find.byTooltip('Quitar sección').last);
      await tester.pumpAndSettle();
      expect(find.text('¿Quitar este Coro?'), findsOneWidget);
      expect(find.text('Se pierde su letra y sus acordes.'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(current, hasLength(2));

      await tester.tap(find.byTooltip('Quitar sección').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(current.map((s) => s.label), ['verse']);
    });

    testWidgets('removing an empty section does not ask', (tester) async {
      await pumpEditor(tester, '{verse}\nUno\n{chorus}\n', LyricsMode.lyrics);

      await tester.tap(find.byTooltip('Quitar sección').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(current.map((s) => s.label), ['verse']);
    });

    testWidgets('intro field hints at chords', (tester) async {
      await pumpEditor(tester, '{intro}\n', LyricsMode.lyrics);

      expect(find.text('Acordes separados por espacios, ej.: G D Em C'), findsOneWidget);
    });
  });

  group('chords mode', () {
    testWidgets('tapping a word opens the picker and sets the chord', (tester) async {
      await pumpEditor(tester, '{verse}\nSublime gracia', LyricsMode.chords);
      expect(find.text('Tocá una palabra para ponerle acorde'), findsOneWidget);

      await tester.tap(find.text('gracia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('G'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insertar'));
      await tester.pumpAndSettle();

      expect(chordPro, '{verse}\nSublime [G]gracia');
      expect(find.text('Tocá una palabra para ponerle acorde'), findsNothing);
    });

    testWidgets('a word with a chord reopens the picker with Quitar acorde', (tester) async {
      await pumpEditor(tester, '{verse}\n[G]Hola', LyricsMode.chords);

      await tester.tap(find.text('Hola'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar acorde'));
      await tester.pumpAndSettle();

      expect(chordPro, '{verse}\nHola');
    });

    testWidgets('blank lines are spacing, not words', (tester) async {
      await pumpEditor(tester, '{verse}\nUno\n\nDos', LyricsMode.chords);

      expect(tester.takeException(), isNull);
      expect(find.byType(LyricWord), findsNWidgets(2));
    });

    testWidgets('empty sections explain where to write', (tester) async {
      await pumpEditor(tester, '{verse}\n\n{intro}\n', LyricsMode.chords);

      expect(find.text('Sin letra todavía. Escribila en el modo Letra.'), findsOneWidget);
      expect(find.text('Sin acordes todavía. Escribilos en el modo Letra.'), findsOneWidget);
    });

    testWidgets('an intro shows its chords as a row', (tester) async {
      await pumpEditor(tester, '{intro}\n[F#m7]  [Bsus4]', LyricsMode.chords);

      expect(find.text('F#m7'), findsOneWidget);
      expect(find.text('Bsus4'), findsOneWidget);
      expect(find.byType(LyricWord), findsNothing);
    });
  });

  testWidgets('switching back to lyrics mode shows the latest text', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    current = parseToEditable('{verse}\nSublime gracia');
    var mode = LyricsMode.lyrics;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: ArcaTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(builder: (context, setState) {
              rebuild = setState;
              return SongLyricsEditor(
                sections: current,
                mode: mode,
                onChanged: (next) => setState(() => current = next),
              );
            }),
          ),
        ),
      ),
    );

    rebuild(() => mode = LyricsMode.chords);
    await tester.pumpAndSettle();
    rebuild(() => current = [applyText(current.first, 'Sublime gracia del Señor')]);
    rebuild(() => mode = LyricsMode.lyrics);
    await tester.pumpAndSettle();

    expect(find.text('Sublime gracia del Señor'), findsOneWidget);
  });

  testWidgets('a section with only chords is not empty: removing it asks first',
      (tester) async {
    await pumpEditor(tester, '{verse}\nUno\n{chorus}\n[G]  [D]', LyricsMode.lyrics);

    await tester.tap(find.byTooltip('Quitar sección').last);
    await tester.pumpAndSettle();

    expect(find.text('¿Quitar este Coro?'), findsOneWidget);
  });

  testWidgets('chords mode shows a chords-only row inside a lyrics section', (tester) async {
    await pumpEditor(tester, '{verse}\n[F#m7]  [Bsus4]', LyricsMode.chords);

    expect(find.text('F#m7'), findsOneWidget);
    expect(find.text('Sin letra todavía. Escribila en el modo Letra.'), findsNothing);
  });

  testWidgets('an older intro with lyrics is edited as lyrics', (tester) async {
    await pumpEditor(tester, '{intro}\n[G]Oh oh', LyricsMode.lyrics);

    expect(find.text('Oh oh'), findsOneWidget);
  });
}
