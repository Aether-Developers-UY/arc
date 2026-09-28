import 'package:arc_app/features/songs/editor/chord_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildChord', () {
    test('builds a plain major chord with no suffix', () {
      expect(buildChord(root: 'G'), 'G');
    });

    test('builds a chord with a quality suffix', () {
      expect(buildChord(root: 'D', type: 'm7'), 'Dm7');
    });

    test('builds a slash chord when a bass note is given', () {
      expect(buildChord(root: 'D', bass: 'F#'), 'D/F#');
      expect(buildChord(root: 'D', type: 'm', bass: 'F'), 'Dm/F');
    });

    test('ignores an empty bass string the same as no bass', () {
      expect(buildChord(root: 'C', bass: ''), 'C');
    });
  });

  test('chordRoots has exactly the 12 chromatic notes, sharps preferred', () {
    expect(chordRoots, [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ]);
  });
}
