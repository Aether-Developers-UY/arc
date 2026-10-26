import 'package:arc_app/core/theme/arca_theme.dart';
import 'package:arc_app/features/songs/editor/editable_document.dart';
import 'package:arc_app/features/songs/editor/song_lyrics_step.dart';
import 'package:arc_app/features/songs/editor/song_metadata_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ArcaTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

SongMetadataStep metadataStep({String? errorMessage, VoidCallback? onNext}) {
  return SongMetadataStep(
    titleController: TextEditingController(),
    artistController: TextEditingController(),
    keyController: TextEditingController(),
    tempoController: TextEditingController(),
    timeSignatureController: TextEditingController(),
    errorMessage: errorMessage,
    onNext: onNext ?? () {},
  );
}

SongLyricsStep lyricsStep({
  bool isSaving = false,
  String? errorMessage,
  VoidCallback? onBack,
  VoidCallback? onSave,
}) {
  return SongLyricsStep(
    sections: [EditableSection(label: 'verse')],
    onSectionsChanged: (_) {},
    notesController: TextEditingController(),
    isSaving: isSaving,
    errorMessage: errorMessage,
    onBack: onBack ?? () {},
    onSave: onSave ?? () {},
  );
}

void main() {
  setUp(() {
    ArcaTheme.useGoogleFonts = false;
  });

  testWidgets('metadata step renders its five fields and a Siguiente button',
      (tester) async {
    await pump(tester, metadataStep());

    expect(find.text('Título *'), findsOneWidget);
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Tonalidad *'), findsOneWidget);
    expect(find.text('Tempo (BPM)'), findsOneWidget);
    expect(find.text('Compás (ej: 4/4)'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('metadata step calls onNext when Siguiente is tapped', (tester) async {
    var taps = 0;
    await pump(tester, metadataStep(onNext: () => taps++));

    await tester.tap(find.text('Siguiente'));

    expect(taps, 1);
  });

  testWidgets('metadata step shows the error message when given one', (tester) async {
    await pump(tester, metadataStep(errorMessage: 'Falta el título'));

    expect(find.text('Falta el título'), findsOneWidget);
  });

  testWidgets('lyrics step shows Atrás and Guardar and calls their callbacks',
      (tester) async {
    var backs = 0;
    var saves = 0;
    await pump(tester, lyricsStep(onBack: () => backs++, onSave: () => saves++));

    await tester.tap(find.text('Atrás'));
    await tester.tap(find.text('Guardar'));

    expect(backs, 1);
    expect(saves, 1);
  });

  testWidgets('lyrics step disables Guardar while saving', (tester) async {
    await pump(tester, lyricsStep(isSaving: true));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('lyrics step disables Atrás while saving', (tester) async {
    await pump(tester, lyricsStep(isSaving: true));

    final button =
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Atrás'));
    expect(button.onPressed, isNull);
  });

  testWidgets('lyrics step shows the error message and the Indicaciones field',
      (tester) async {
    await pump(tester, lyricsStep(errorMessage: 'No se pudo guardar'));

    expect(find.text('Indicaciones'), findsOneWidget);
    expect(find.text('No se pudo guardar'), findsOneWidget);
  });
}
