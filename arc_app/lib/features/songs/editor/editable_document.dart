import '../../../core/chordpro/chordpro_parser.dart';

/// One word of lyric text, with an optional chord attached to it — the
/// chord that appears just before this word, ChordPro-style.
class EditableWord {
  EditableWord({required this.text, this.chord});

  String text;
  String? chord;
}

/// One line of lyrics: a sequence of words, each optionally carrying a
/// chord. A brand new line always has exactly one empty word, so there is
/// always something to tap or type into.
class EditableLine {
  EditableLine({List<EditableWord>? words}) : words = words ?? [EditableWord(text: '')];

  List<EditableWord> words;
}

/// A section of the song (a verse, chorus, bridge, or an untitled block),
/// with its own lines. A brand new section always has one empty line.
class EditableSection {
  EditableSection({this.label, List<EditableLine>? lines})
      : lines = lines ?? [EditableLine()];

  /// One of 'verse', 'chorus', 'bridge', 'tag', or null for an untitled
  /// block (used so content the parser couldn't confidently place under a
  /// section heading is still shown, never silently dropped).
  String? label;
  List<EditableLine> lines;
}

/// Converts ChordPro text (as already understood by [ChordProParser]) into
/// the editable structure the visual editor works on.
List<EditableSection> parseToEditable(String content) {
  final document = ChordProParser.parse(content);
  final sections = <EditableSection>[];
  EditableSection? current;

  EditableSection ensureCurrent() {
    if (current == null) {
      current = EditableSection(lines: []);
      sections.add(current!);
    }
    return current!;
  }

  for (final line in document.lines) {
    if (line.sectionLabel != null && line.segments.isEmpty) {
      current = EditableSection(label: line.sectionLabel, lines: []);
      sections.add(current!);
      continue;
    }
    final section = ensureCurrent();
    if (line.segments.isEmpty) {
      // A blank line inside a section — keep it so it round-trips.
      section.lines.add(EditableLine(words: [EditableWord(text: '')]));
      continue;
    }
    section.lines.add(_segmentsToLine(line.segments));
  }

  if (sections.isEmpty) {
    sections.add(EditableSection());
  }
  for (final section in sections) {
    if (section.lines.isEmpty) {
      section.lines.add(EditableLine());
    }
  }
  return sections;
}

EditableLine _segmentsToLine(List<ChordProSegment> segments) {
  final words = <EditableWord>[];
  for (final segment in segments) {
    final parts = segment.text.split(' ');
    for (var i = 0; i < parts.length; i++) {
      words.add(EditableWord(text: parts[i], chord: i == 0 ? segment.chord : null));
    }
  }
  if (words.isEmpty) {
    words.add(EditableWord(text: ''));
  }
  return EditableLine(words: words);
}

/// Converts the editable structure back into ChordPro text, ready to save
/// as a [Song]'s `content`.
String editableToChordPro(List<EditableSection> sections) {
  final buffer = StringBuffer();
  for (var s = 0; s < sections.length; s++) {
    final section = sections[s];
    if (section.label != null) {
      buffer.writeln('{${section.label}}');
    }
    for (final line in section.lines) {
      buffer.writeln(_lineToChordProText(line));
    }
    if (s < sections.length - 1) {
      buffer.writeln();
    }
  }
  return buffer.toString().trimRight();
}

String _lineToChordProText(EditableLine line) {
  final buffer = StringBuffer();
  for (var i = 0; i < line.words.length; i++) {
    final word = line.words[i];
    if (word.chord != null) {
      buffer.write('[${word.chord}]');
    }
    buffer.write(word.text);
    final isLast = i == line.words.length - 1;
    if (!isLast && word.text.isNotEmpty) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}
