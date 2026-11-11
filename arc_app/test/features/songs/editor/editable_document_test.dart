import 'package:arc_app/core/chordpro/chordpro_parser.dart';
import 'package:arc_app/features/songs/editor/editable_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseToEditable / editableToChordPro round trip', () {
    test('round-trips chords, words, and section labels', () {
      const original = '{verse}\n'
          '[G]Cantaré de tu [D]amor\n'
          '[Em]Por siempre [C]Señor\n'
          '{chorus}\n'
          '[C]Gracia [G]sublime\n'
          '[D]qué dulce es\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);
      final reparsed = ChordProParser.parse(serialized);

      final labelledLines = reparsed.lines.where((l) => l.sectionLabel != null).toList();
      expect(labelledLines.map((l) => l.sectionLabel), ['verse', 'chorus']);

      final lyricLines = reparsed.lines.where((l) => l.segments.isNotEmpty).toList();
      expect(lyricLines, hasLength(4));
      expect(lyricLines[0].segments.map((s) => s.chord), ['G', 'D']);
      expect(lyricLines[0].segments.map((s) => s.text.trim()), ['Cantaré de tu', 'amor']);
      expect(lyricLines[1].segments.map((s) => s.chord), ['Em', 'C']);
      expect(lyricLines[2].segments.map((s) => s.chord), ['C', 'G']);
      expect(lyricLines[3].segments.map((s) => s.chord), ['D']);
      expect(lyricLines[3].segments.map((s) => s.text.trim()), ['qué dulce es']);
    });

    test('keeps consecutive chords with no lyric between them attached correctly', () {
      const original = '{verse}\n[G][D]Instrumental\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);
      final reparsed = ChordProParser.parse(serialized);

      final lyricLine = reparsed.lines.firstWhere((l) => l.segments.isNotEmpty);
      expect(lyricLine.segments.map((s) => s.chord), ['G', 'D']);
      expect(lyricLine.segments.last.text, 'Instrumental');
    });

    test('preserves a chord placed mid-word with no surrounding space', () {
      const original = '{verse}\nQue a un pecador salv[G]ó\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);

      // The exact source text must survive byte-for-byte — no space should
      // be inserted between "salv" and "[G]ó" just because they came from
      // separate segments.
      expect(serialized, contains('salv[G]ó'));
      expect(serialized, isNot(contains('salv ó')));
    });

    test('parsing blank content never crashes and returns at least one section', () {
      final sections = parseToEditable('');
      expect(sections, isNotEmpty);
      expect(sections.single.lines, isNotEmpty);
    });

    test('preserves metadata directives like {title:} and {key:} verbatim', () {
      const original = '{title: Sublime Gracia}\n'
          '{key: G}\n'
          '{verse}\n'
          '[G]Sublime [C]gracia\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);

      expect(serialized, contains('{title: Sublime Gracia}'));
      expect(serialized, contains('{key: G}'));

      final reparsed = ChordProParser.parse(serialized);
      final lyricLine = reparsed.lines.firstWhere((l) => l.segments.isNotEmpty);
      expect(lyricLine.segments.map((s) => s.chord), ['G', 'C']);
    });

    test('a line with no chords round-trips as plain text', () {
      const original = '{verse}\nSolo letra sin acordes\n';

      final sections = parseToEditable(original);
      final serialized = editableToChordPro(sections);
      final reparsed = ChordProParser.parse(serialized);

      final lyricLine = reparsed.lines.firstWhere((l) => l.segments.isNotEmpty);
      expect(lyricLine.segments.every((s) => s.chord == null), isTrue);
      expect(lyricLine.segments.map((s) => s.text).join(' ').trim(), 'Solo letra sin acordes');
    });
  });

  /// Applies [text] to the first section of [content] and serializes it.
  String applied(String content, String text) =>
      editableToChordPro([applyText(parseToEditable(content).first, text)]);

  group('applyText keeps chords on their words', () {
    test('a corrected word keeps its chord', () {
      expect(
        applied('{verse}\n[G]Sublime [C]gracía del Señor', 'Sublime gracia del Señor'),
        '{verse}\n[G]Sublime [C]gracia del Señor',
      );
    });

    test('a word inserted before chords leaves them on their words', () {
      expect(
        applied('{verse}\n[G]Sublime [C]gracia', 'Oh Sublime gracia'),
        '{verse}\nOh [G]Sublime [C]gracia',
      );
    });

    test('a line inserted above keeps the chords on their lines', () {
      expect(applied('{verse}\n[G]Uno\n[D]Dos', 'Nueva\nUno\nDos'), '{verse}\nNueva\n[G]Uno\n[D]Dos');
    });

    test('a deleted line takes only its own chords', () {
      expect(applied('{verse}\n[G]Uno\n[D]Dos', 'Dos'), '{verse}\n[D]Dos');
    });

    test('a deleted word loses its chord', () {
      expect(applied('{verse}\n[G]Sublime [C]gracia', 'Sublime'), '{verse}\n[G]Sublime');
    });

    test('a mid-word chord survives edits elsewhere in its line', () {
      expect(
        applied('{verse}\nque a un infeliz salv[G]ó', 'que a un pobre infeliz salvó'),
        '{verse}\nque a un pobre infeliz salv[G]ó',
      );
    });

    test('clearing a section and typing it again starts without chords', () {
      final cleared = applyText(parseToEditable('{verse}\n[G]Uno').first, '');
      expect(cleared.lines, hasLength(1));
      expect(editableToChordPro([applyText(cleared, 'Uno')]), '{verse}\nUno');
    });

    test('extra spaces and tabs never create empty words', () {
      expect(applied('{verse}\n[G]Hola', 'Hola   mundo\t '), '{verse}\n[G]Hola mundo');
    });

    test('applying the same text changes nothing, blank lines included', () {
      const content = '{verse}\n[G]Uno\n\n[D]Dos';
      final section = parseToEditable(content).first;
      expect(editableToChordPro([applyText(section, sectionText(section))]), content);
    });

    test('the section keeps its id and lines keep theirs', () {
      final section = parseToEditable('{verse}\n[G]Uno\n[D]Dos').first;
      final updated = applyText(section, 'Nueva\nUno\nDos');
      expect(updated.id, section.id);
      expect(updated.lines[1].id, section.lines[0].id);
    });

    test('applyText preserves {title:} directives', () {
      expect(applied('{verse}\n{title: X}\n[G]Uno', 'Uno'), '{verse}\n{title: X}\n[G]Uno');
    });

    test('sectionText leaves out chords and directives', () {
      final section = parseToEditable('{verse}\n{title: X}\n[G]Sublime [C]gracia\nque a un salv[G]ó').first;
      expect(sectionText(section), 'Sublime gracia\nque a un salvó');
    });
  });

  group('untitled leading content', () {
    test('lyrics before the first section open as a Verso', () {
      final sections = parseToEditable('Hola\n{chorus}\nCoro');
      expect(sections.map((s) => s.label), ['verse', 'chorus']);
    });

    test('directives before the first section join that section', () {
      final sections = parseToEditable('{title: X}\n{verse}\nUno');
      expect(sections, hasLength(1));
      expect(sections.single.label, 'verse');
      expect(sections.single.lines.first.rawDirective, '{title: X}');
    });
  });

  group('chord-only sections', () {
    test('sectionText of an intro lists its chords', () {
      expect(sectionText(parseToEditable('{intro}\n[G]  [D]  [Em]').first), 'G  D  Em');
    });

    test('applying chords to an intro writes chords-only lines', () {
      expect(
        editableToChordPro([applyText(EditableSection(label: 'intro'), 'G D\nEm  C')]),
        '{intro}\n[G]  [D]\n[Em]  [C]',
      );
    });

    test('a chords-only line round-trips unchanged', () {
      expect(editableToChordPro(parseToEditable('{intro}\n[G]  [D]')), '{intro}\n[G]  [D]');
    });
  });

  group('saving twice', () {
    test('does not add a blank line between sections each time', () {
      const content = '{verse}\n[D]Uno\n\n{chorus}\n[G]Dos\n';
      final once = editableToChordPro(parseToEditable(content));
      final twice = editableToChordPro(parseToEditable(once));

      expect(once, '{verse}\n[D]Uno\n\n{chorus}\n[G]Dos');
      expect(twice, once);
    });

    test('keeps blank lines between stanzas inside a section', () {
      const content = '{verse}\nUno\n\nDos\n\n{chorus}\nTres';

      expect(editableToChordPro(parseToEditable(content)), content);
    });
  });

  group('review fixes', () {
    test('lyrics inside an older {intro} are edited as lyrics, not dropped', () {
      expect(
        applied('{intro}\n[G]Oh oh\n[D]  [C]', 'Oh oh!\n'),
        '{intro}\n[G]Oh oh!\n[D]  [C]',
      );
    });

    test('a leading block with only chords opens as an Intro', () {
      expect(parseToEditable('[G]  [D]\n{verse}\nUno').first.label, 'intro');
    });

    test('pressing Enter mid-line keeps both chords', () {
      expect(applied('{verse}\n[G]Uno [D]dos', 'Uno\ndos'), '{verse}\n[G]Uno\n[D]dos');
    });

    test('joining two lines keeps both chords', () {
      expect(applied('{verse}\n[G]Uno\n[D]dos', 'Uno dos'), '{verse}\n[G]Uno [D]dos');
    });

    test('typing a new line at the start and then Enter keeps the chords', () {
      final typed = applyText(parseToEditable('{verse}\n[G]Uno [C]x').first, 'Nueva Uno x');
      expect(
        editableToChordPro([applyText(typed, 'Nueva\nUno x')]),
        '{verse}\nNueva\n[G]Uno [C]x',
      );
    });
  });
}
