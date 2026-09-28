/// Chromatic root notes, sharps preferred — matches the app's transposer
/// default (see lib/core/chordpro/transposer.dart).
const chordRoots = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Chord qualities offered in the picker. The empty string means "major"
/// (no suffix).
const chordTypes = ['', 'm', '7', 'm7', 'sus2', 'sus4', 'maj7', 'dim', 'aug', '6', '9'];

/// Builds a chord symbol like "D", "Dm7", or "D/F#" from its parts. [root]
/// is expected to be one of [chordRoots]. [type] is one of [chordTypes]
/// ('' for major). [bass] is an optional root-note override for a slash
/// chord — pass null or '' for none.
String buildChord({required String root, String type = '', String? bass}) {
  final base = '$root$type';
  if (bass == null || bass.isEmpty) return base;
  return '$base/$bass';
}
