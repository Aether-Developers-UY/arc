import 'dart:math';

import '../../../core/chordpro/chordpro_parser.dart';
import '../../../core/chordpro/section_names.dart';

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

int _nextEditableId = 0;

/// A fresh, process-unique id for a new [EditableLine]/[EditableSection].
/// The visual editor treats these objects as immutable — every edit builds
/// a *new* instance rather than mutating the old one — so widget `Key`s
/// can't be based on object identity (that would change on every
/// keystroke) or list position (that breaks when a line/section is
/// removed from the middle). [id] is threaded through every "copy with an
/// edit applied" call site so the same logical line/section keeps the same
/// id for its whole lifetime, giving widgets a stable key to reuse
/// TextEditingController state by.
int _newEditableId() => _nextEditableId++;

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
  EditableLine({List<EditableWord>? words, this.rawDirective, int? id})
      : id = id ?? _newEditableId(),
        words = words ?? (rawDirective == null ? [EditableWord(text: '')] : const []);

  /// Stable across edits — see [_newEditableId]. Pass the previous line's
  /// [id] when constructing an updated copy of it; omit only for a
  /// genuinely new line.
  final int id;
  List<EditableWord> words;
  final String? rawDirective;

  /// A row of chords with no lyrics, like an Intro or Interludio line.
  bool get isChordOnly =>
      words.isNotEmpty &&
      words.every((w) => w.text.isEmpty) &&
      words.any((w) => w.chord != null);
}

/// A section of the song (a verse, chorus, bridge, or an untitled block),
/// with its own lines. A brand new section always has one empty line.
class EditableSection {
  EditableSection({this.label, List<EditableLine>? lines, int? id})
      : id = id ?? _newEditableId(),
        lines = lines ?? [EditableLine()];

  /// Stable across edits — see [_newEditableId]. Pass the previous
  /// section's [id] when constructing an updated copy of it; omit only for
  /// a genuinely new section.
  final int id;

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
    final isChordsOnly = line.segments.every((s) => s.text.trim().isEmpty) &&
        line.segments.any((s) => s.chord != null);
    section.lines.add(isChordsOnly
        ? EditableLine(words: [
            for (final s in line.segments)
              if (s.chord != null) EditableWord(text: '', chord: s.chord),
          ])
        : _segmentsToLine(line.segments));
  }

  // Content before the first section heading opens as a Verso — unless it
  // is only directives ({title:}, {key:}), which join the next section.
  if (sections.isNotEmpty && sections.first.label == null) {
    final leading = sections.first;
    final onlyDirectives = leading.lines
        .every((l) => l.rawDirective != null || _isBlank(l));
    if (onlyDirectives && sections.length > 1) {
      sections[1].lines.insertAll(0, leading.lines.where((l) => l.rawDirective != null));
      sections.removeAt(0);
    } else {
      leading.label = 'verse';
    }
  }
  if (sections.isEmpty) {
    sections.add(EditableSection(label: 'verse'));
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
  if (line.isChordOnly) return line.words.map((w) => '[${w.chord}]').join('  ');

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

bool _isBlank(EditableLine line) =>
    line.rawDirective == null && line.words.every((w) => w.text.isEmpty && w.chord == null);

/// The section as plain text for its text field: lyrics without chords, or
/// for an Intro/Interludio its chords. Directives are left out.
String sectionText(EditableSection section) {
  final chordOnly = isChordOnlySection(section.label);
  return section.lines
      .where((line) => line.rawDirective == null)
      .map((line) => chordOnly
          ? line.words.where((w) => w.chord != null).map((w) => w.chord).join('  ')
          : _lineText(line))
      .join('\n');
}

/// Rebuilds [section] from the text typed in its field, keeping each chord
/// on its word: lines are aligned old-to-new first, then the words of each
/// pair of lines. A word edited in place keeps the chord of the word it
/// replaces; a deleted word loses its chord. Directives stay at the top.
EditableSection applyText(EditableSection section, String text) {
  final directives = section.lines.where((l) => l.rawDirective != null);
  final oldLines = section.lines.where((l) => l.rawDirective == null).toList();
  final newTexts = text.split('\n');
  final lines = <EditableLine>[...directives];

  if (isChordOnlySection(section.label)) {
    for (final row in newTexts) {
      final chords = _splitWords(row);
      lines.add(chords.isEmpty
          ? EditableLine()
          : EditableLine(words: [for (final c in chords) EditableWord(text: '', chord: c)]));
    }
  } else {
    final newNormalized = newTexts.map((t) => _splitWords(t).join(' ')).toList();
    final oldTexts = oldLines.map(_lineText).toList();
    for (final (o, n) in _align(oldTexts, newNormalized)) {
      if (n == null) continue;
      if (o == null) {
        lines.add(_plainLine(newTexts[n]));
      } else if (oldTexts[o] == newNormalized[n]) {
        lines.add(oldLines[o]);
      } else {
        lines.add(_mergeLine(oldLines[o], newTexts[n]));
      }
    }
  }

  if (lines.every((l) => l.rawDirective != null)) lines.add(EditableLine());
  return EditableSection(id: section.id, label: section.label, lines: lines);
}

List<String> _splitWords(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Groups a line's words into what the text field shows as one word: a word
/// glued to the next one (a mid-word chord, `salv[G]ó`) or a chord with no
/// text of its own joins its neighbour.
List<List<EditableWord>> _tokens(EditableLine line) {
  final tokens = <List<EditableWord>>[];
  var current = <EditableWord>[];
  String textOf(List<EditableWord> words) => words.map((w) => w.text).join();
  for (final word in line.words) {
    current.add(word);
    if (word.spaceAfter && textOf(current).isNotEmpty) {
      tokens.add(current);
      current = [];
    }
  }
  if (current.isNotEmpty) {
    if (textOf(current).isEmpty && tokens.isNotEmpty) {
      tokens.last.addAll(current);
    } else if (textOf(current).isNotEmpty || current.any((w) => w.chord != null)) {
      tokens.add(current);
    }
  }
  return tokens;
}

String _tokenText(List<EditableWord> token) => token.map((w) => w.text).join();

String _lineText(EditableLine line) =>
    _tokens(line).map(_tokenText).where((t) => t.isNotEmpty).join(' ');

EditableLine _plainLine(String text) {
  final words = _splitWords(text);
  return words.isEmpty
      ? EditableLine()
      : EditableLine(words: [for (final w in words) EditableWord(text: w)]);
}

EditableLine _mergeLine(EditableLine old, String text) {
  final oldTokens = _tokens(old);
  final newWords = _splitWords(text);
  final words = <EditableWord>[];
  for (final (o, n) in _align(oldTokens.map(_tokenText).toList(), newWords)) {
    if (n == null) continue;
    final List<EditableWord> token;
    if (o != null && _tokenText(oldTokens[o]) == newWords[n]) {
      token = [
        for (final w in oldTokens[o])
          EditableWord(text: w.text, chord: w.chord, spaceAfter: w.spaceAfter),
      ];
    } else {
      final chord = o == null
          ? null
          : oldTokens[o].firstWhere((w) => w.chord != null, orElse: () => EditableWord(text: '')).chord;
      token = [EditableWord(text: newWords[n], chord: chord)];
    }
    // A space always separates one token from the next.
    token.last.spaceAfter = true;
    words.addAll(token);
  }
  return words.isEmpty ? EditableLine(id: old.id) : EditableLine(id: old.id, words: words);
}

/// Pairs (old index, new index). Matches come from the longest common
/// subsequence; within each stretch between matches, elements are paired in
/// order and the leftovers get null on the other side.
List<(int?, int?)> _align(List<String> a, List<String> b) {
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  final pairs = <(int?, int?)>[];
  final gapA = <int>[], gapB = <int>[];
  void flush() {
    for (var k = 0; k < max(gapA.length, gapB.length); k++) {
      pairs.add((k < gapA.length ? gapA[k] : null, k < gapB.length ? gapB[k] : null));
    }
    gapA.clear();
    gapB.clear();
  }

  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      flush();
      pairs.add((i++, j++));
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      gapA.add(i++);
    } else {
      gapB.add(j++);
    }
  }
  while (i < a.length) {
    gapA.add(i++);
  }
  while (j < b.length) {
    gapB.add(j++);
  }
  flush();
  return pairs;
}
