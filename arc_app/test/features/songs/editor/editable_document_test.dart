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
}
