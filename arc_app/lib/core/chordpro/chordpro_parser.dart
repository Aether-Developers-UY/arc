class ChordProSegment {
  const ChordProSegment({required this.chord, required this.text});

  final String? chord;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is ChordProSegment && other.chord == chord && other.text == text;

  @override
  int get hashCode => Object.hash(chord, text);

  @override
  String toString() => 'ChordProSegment(chord: $chord, text: "$text")';
}

class ChordProLine {
  const ChordProLine({required this.segments, this.sectionLabel});

  final List<ChordProSegment> segments;
  final String? sectionLabel;
}

class ChordProDocument {
  const ChordProDocument({required this.lines});

  final List<ChordProLine> lines;
}

class ChordProParser {
  static final _directivePattern = RegExp(r'^\{(\w+)(:.*)?\}$');
  static final _chordTokenPattern = RegExp(r'\[([^\]]+)\]');

  /// Directive names that represent a song section, as opposed to metadata
  /// directives like {title:}/{key:}/{tempo:} which carry no lyric content
  /// and should not be mistaken for a section heading.
  static const _sectionDirectiveNames = {'verse', 'chorus', 'bridge', 'tag'};

  static ChordProDocument parse(String content) {
    final rawLines = content.split('\n');
    final lines = <ChordProLine>[];

    for (final rawLine in rawLines) {
      final directiveMatch = _directivePattern.firstMatch(rawLine.trim());
      if (directiveMatch != null) {
        final name = directiveMatch.group(1)!.toLowerCase();
        final sectionLabel = _sectionDirectiveNames.contains(name) ? name : null;
        lines.add(ChordProLine(segments: const [], sectionLabel: sectionLabel));
        continue;
      }

      if (rawLine.isEmpty) {
        lines.add(const ChordProLine(segments: []));
        continue;
      }

      lines.add(ChordProLine(segments: _parseLineSegments(rawLine)));
    }

    return ChordProDocument(lines: lines);
  }

  /// Splits a lyric line into (chord, text) segments.
  ///
  /// Each [chord] token starts a new segment; the text that follows it
  /// (up to the next chord token or end of line) belongs to that segment.
  /// Text before the first chord token (if any) becomes a leading
  /// chord-less segment. Consecutive chord tokens with no lyric between
  /// them produce a segment with an empty text (e.g. "[G][D]x" ->
  /// (G, ""), (D, "x")).
  static List<ChordProSegment> _parseLineSegments(String line) {
    final matches = _chordTokenPattern.allMatches(line).toList();

    if (matches.isEmpty) {
      return [ChordProSegment(chord: null, text: line)];
    }

    final segments = <ChordProSegment>[];

    final leadingText = line.substring(0, matches.first.start);
    if (leadingText.isNotEmpty) {
      segments.add(ChordProSegment(chord: null, text: leadingText));
    }

    for (var i = 0; i < matches.length; i++) {
      final chord = matches[i].group(1);
      final textStart = matches[i].end;
      final textEnd = i + 1 < matches.length ? matches[i + 1].start : line.length;
      final text = line.substring(textStart, textEnd);
      segments.add(ChordProSegment(chord: chord, text: text));
    }

    return segments;
  }
}
