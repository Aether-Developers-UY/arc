import '../../../core/chordpro/chordpro_parser.dart';

/// One word of lyric text, with an optional chord attached to it — the
/// chord that appears just before this word, ChordPro-style.
class EditableWord {
  EditableWord({required this.text, this.chord, this.spaceAfter = true});

  String text;
  String? chord;

  /// Whether this word was followed by a literal space in the original
  /// ChordPro text. False only when a chord token immediately followed
  /// this word's text with no space between them (e.g. a chord placed
  /// mid-word, like "salv[G]ó") — without tracking this, re-serializing
  /// would insert a space that was never there.
  bool spaceAfter;
}

/// One line of lyrics: a sequence of words, each optionally carrying a
/// chord. A brand new line always has exactly one empty word, so there is
/// always something to tap or type into.
///
/// When [rawDirective] is set, this line represents a ChordPro directive
/// the visual editor doesn't understand (e.g. `{title: ...}`, `{key: ...}`,
/// `{tempo: ...}`) — it round-trips verbatim instead of being edited as
/// words, so metadata from an imported or hand-written ChordPro file is
/// never silently dropped just because it passed through this editor.
class EditableLine {
  EditableLine({List<EditableWord>? words, this.rawDirective})
      : words = words ?? (rawDirective == null ? [EditableWord(text: '')] : const []);

  List<EditableWord> words;
  final String? rawDirective;
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

/// Matches a whole-line ChordPro directive, e.g. `{title: Sublime Gracia}`
/// or `{key: G}` — used to tell an unrecognized directive line (which
/// [ChordProParser] reports identically to a truly blank line: no segments,
/// no sectionLabel) apart from an actual blank line, so it can be preserved
/// verbatim instead of silently dropped.
final _directivePattern = RegExp(r'^\{(\w+)(:.*)?\}$');

/// Converts ChordPro text (as already understood by [ChordProParser]) into
/// the editable structure the visual editor works on.
List<EditableSection> parseToEditable(String content) {
  final document = ChordProParser.parse(content);
  final rawLines = content.split('\n');
  final sections = <EditableSection>[];
  EditableSection? current;

  EditableSection ensureCurrent() {
    if (current == null) {
      current = EditableSection(lines: []);
      sections.add(current!);
    }
    return current!;
  }

  for (var i = 0; i < document.lines.length; i++) {
    final line = document.lines[i];
    if (line.sectionLabel != null && line.segments.isEmpty) {
      current = EditableSection(label: line.sectionLabel, lines: []);
      sections.add(current!);
      continue;
    }
    final section = ensureCurrent();
    if (line.segments.isEmpty) {
      final rawLine = i < rawLines.length ? rawLines[i].trim() : '';
      if (_directivePattern.hasMatch(rawLine)) {
        // A directive the parser doesn't treat as a section (e.g.
        // {title:}/{key:}/{tempo:}) — preserve it verbatim.
        section.lines.add(EditableLine(rawDirective: rawLine));
      } else {
        // A truly blank line — keep it so it round-trips.
        section.lines.add(EditableLine(words: [EditableWord(text: '')]));
      }
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
      final isLastPartOfSegment = i == parts.length - 1;
      // Parts within a segment were split on a real space, so a space
      // belongs between them. The segment's LAST part is different: a
      // chord token consumes zero characters of the original text, so
      // whether a space follows depends only on whether the segment's own
      // text ended in one (not on the presence of a following segment).
      final spaceAfter = isLastPartOfSegment ? segment.text.endsWith(' ') : true;
      words.add(EditableWord(
        text: parts[i],
        chord: i == 0 ? segment.chord : null,
        spaceAfter: spaceAfter,
      ));
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
  if (line.rawDirective != null) return line.rawDirective!;

  final buffer = StringBuffer();
  for (var i = 0; i < line.words.length; i++) {
    final word = line.words[i];
    if (word.chord != null) {
      buffer.write('[${word.chord}]');
    }
    buffer.write(word.text);
    final isLast = i == line.words.length - 1;
    if (!isLast && word.text.isNotEmpty && word.spaceAfter) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}
