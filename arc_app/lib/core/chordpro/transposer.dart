const _sharpScale = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flatScale = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

final _chordRootPattern = RegExp(r'^([A-G])(#|b)?');

/// Transposes a chord symbol like "G", "Am7", "F#sus4" by [semitones].
/// Returns the input unchanged if it doesn't start with a recognizable
/// note letter (e.g. "N.C." for "no chord" markers).
String transposeChord(String chord, {required int semitones, bool preferFlats = false}) {
  final match = _chordRootPattern.firstMatch(chord);
  if (match == null) return chord;

  final rootLetter = match.group(1)!;
  final accidental = match.group(2) ?? '';
  final suffix = chord.substring(match.end);

  final rootIndex = _indexOfNote('$rootLetter$accidental');
  if (rootIndex == -1) return chord;

  final newIndex = (rootIndex + semitones) % 12;
  final normalizedIndex = newIndex < 0 ? newIndex + 12 : newIndex;

  final scale = preferFlats ? _flatScale : _sharpScale;
  return '${scale[normalizedIndex]}$suffix';
}

int _indexOfNote(String note) {
  final sharpIndex = _sharpScale.indexOf(note);
  if (sharpIndex != -1) return sharpIndex;
  return _flatScale.indexOf(note);
}

/// Number of semitones (0-11) to go from key [from] to key [to].
int semitonesBetweenKeys({required String from, required String to}) {
  final fromIndex = _indexOfNote(from);
  final toIndex = _indexOfNote(to);
  if (fromIndex == -1 || toIndex == -1) return 0;
  final diff = (toIndex - fromIndex) % 12;
  return diff < 0 ? diff + 12 : diff;
}
