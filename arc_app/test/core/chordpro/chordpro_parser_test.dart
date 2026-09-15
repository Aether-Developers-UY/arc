import 'package:flutter_test/flutter_test.dart';
import 'package:arc_app/core/chordpro/chordpro_parser.dart';

void main() {
  group('ChordProParser', () {
    test('parses plain lyric lines with inline chords', () {
      final doc = ChordProParser.parse('[G]Cantaré de tu [D]amor');

      expect(doc.lines, hasLength(1));
      expect(doc.lines.first.segments, [
        const ChordProSegment(chord: 'G', text: 'Cantaré de tu '),
        const ChordProSegment(chord: 'D', text: 'amor'),
      ]);
    });

    test('parses lines with no chords as a single text segment', () {
      final doc = ChordProParser.parse('Solo letra sin acordes');

      expect(doc.lines.first.segments, [
        const ChordProSegment(chord: null, text: 'Solo letra sin acordes'),
      ]);
    });

    test('recognizes section directives like {verse} and {chorus}', () {
      final doc = ChordProParser.parse('{verse}\n[G]Letra\n{chorus}\n[D]Otra letra');

      expect(doc.lines[0].sectionLabel, 'verse');
      expect(doc.lines[1].sectionLabel, isNull);
      expect(doc.lines[2].sectionLabel, 'chorus');
    });

    test('handles multiple chords back-to-back with no lyric between them', () {
      final doc = ChordProParser.parse('[G][D]Instrumental');

      expect(doc.lines.first.segments, [
        const ChordProSegment(chord: 'G', text: ''),
        const ChordProSegment(chord: 'D', text: 'Instrumental'),
      ]);
    });

    test('does not treat metadata directives like {title:} or {key:} as sections', () {
      final doc = ChordProParser.parse('{title: Sublime Gracia}\n{key: G}\n[G]Letra');

      expect(doc.lines[0].sectionLabel, isNull);
      expect(doc.lines[1].sectionLabel, isNull);
    });

    test('preserves blank lines', () {
      final doc = ChordProParser.parse('[G]Primera\n\n[D]Segunda');

      expect(doc.lines, hasLength(3));
      expect(doc.lines[1].segments, isEmpty);
    });
  });
}
