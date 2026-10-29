/// Song sections by their ChordPro directive name, with the Spanish name the
/// app shows. `tag` is only read from older songs; it isn't offered when
/// adding a section.
const _sectionNames = {
  'intro': 'Intro',
  'verse': 'Verso',
  'chorus': 'Coro',
  'bridge': 'Puente',
  'interlude': 'Interludio',
  'tag': 'Otro',
};

/// The sections offered by "+ Sección", in menu order.
const addableSectionLabels = ['intro', 'verse', 'chorus', 'bridge', 'interlude'];

/// The Spanish name for a section label; 'Sección' when unknown or null.
String sectionName(String? label) => _sectionNames[label] ?? 'Sección';

/// Intro and Interludio hold chords only, no lyrics.
bool isChordOnlySection(String? label) => label == 'intro' || label == 'interlude';
