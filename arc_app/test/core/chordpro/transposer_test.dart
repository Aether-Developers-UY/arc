import 'package:flutter_test/flutter_test.dart';
import 'package:arc_app/core/chordpro/transposer.dart';

void main() {
  group('transposeChord', () {
    test('transposes a simple major chord up by semitones', () {
      expect(transposeChord('G', semitones: 2), 'A');
      expect(transposeChord('C', semitones: 1), 'C#');
    });

    test('transposes minor chords, preserving the "m" suffix', () {
      expect(transposeChord('Am', semitones: 3), 'Cm');
    });

    test('transposes chords with extensions, preserving the suffix', () {
      expect(transposeChord('G7', semitones: 2), 'A7');
      expect(transposeChord('Dsus4', semitones: 5), 'Gsus4');
      expect(transposeChord('Cmaj7', semitones: 2), 'Dmaj7');
    });

    test('wraps around the octave correctly', () {
      expect(transposeChord('B', semitones: 1), 'C');
      expect(transposeChord('C', semitones: -1), 'B');
    });

    test('handles negative transposition', () {
      expect(transposeChord('D', semitones: -2), 'C');
    });

    test('prefers flats when transposing into a flat-friendly key context', () {
      expect(transposeChord('A', semitones: 1, preferFlats: true), 'Bb');
    });

    test('prefers sharps by default', () {
      expect(transposeChord('A', semitones: 1), 'A#');
    });

    test('leaves non-chord input unchanged if unrecognized', () {
      expect(transposeChord('N.C.', semitones: 2), 'N.C.');
    });

    test('transposes slash chords, moving both root and bass note', () {
      expect(transposeChord('D/F#', semitones: 2), 'E/G#');
      expect(transposeChord('G/B', semitones: -2), 'F/A');
    });
  });

  group('semitonesBetweenKeys', () {
    test('computes the distance between two keys', () {
      expect(semitonesBetweenKeys(from: 'C', to: 'D'), 2);
      expect(semitonesBetweenKeys(from: 'G', to: 'C'), -7 % 12);
      expect(semitonesBetweenKeys(from: 'C', to: 'C'), 0);
    });
  });
}
