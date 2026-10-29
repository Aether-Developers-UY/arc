import 'package:arc_app/core/chordpro/section_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sectionName gives the Spanish name of each section', () {
    expect(sectionName('interlude'), 'Interludio');
    expect(sectionName('tag'), 'Otro');
    expect(sectionName(null), 'Sección');
    expect(sectionName('unknown'), 'Sección');
  });

  test('only Intro and Interludio are chords-only sections', () {
    expect(isChordOnlySection('intro'), isTrue);
    expect(isChordOnlySection('interlude'), isTrue);
    expect(isChordOnlySection('verse'), isFalse);
    expect(isChordOnlySection(null), isFalse);
  });

  test('the add menu offers the five sections in order', () {
    expect(addableSectionLabels, ['intro', 'verse', 'chorus', 'bridge', 'interlude']);
  });
}
