import 'package:flutter/material.dart';

import '../../core/chordpro/chordpro_parser.dart';
import '../../core/chordpro/section_names.dart';
import '../../core/chordpro/transposer.dart';
import '../../core/theme/arca_theme.dart';
import '../../core/theme/arca_tokens.dart';

/// A song's lyrics with chords above, transposed by [semitones]. [scale]
/// enlarges the text, e.g. for reading on stage.
class SongLyricsView extends StatelessWidget {
  const SongLyricsView({super.key, required this.document, required this.semitones, this.scale = 1});

  final ChordProDocument document;
  final int semitones;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in document.lines)
          if (line.sectionLabel != null && line.segments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Text(
                sectionName(line.sectionLabel).toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
              ),
            )
          else if (line.segments.isEmpty)
            SizedBox(height: 14 * scale)
          else
            _ChordLine(segments: line.segments, semitones: semitones, scale: scale),
      ],
    );
  }
}

class _ChordLine extends StatelessWidget {
  const _ChordLine({required this.segments, required this.semitones, required this.scale});

  final List<ChordProSegment> segments;
  final int semitones;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final chordStyle = ArcaTheme.mono(
      TextStyle(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w700,
        color: context.arca.chord,
      ),
    );
    final lyricStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 20 * scale,
          height: 1.3,
          fontWeight: FontWeight.w500,
        );

    // An Intro/Interludio line: just the chords, spaced out, no lyric row.
    if (segments.every((segment) => segment.text.trim().isEmpty)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(
          spacing: 16,
          children: [
            for (final segment in segments)
              if (segment.chord != null)
                Text(transposeChord(segment.chord!, semitones: semitones), style: chordStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final segment in segments)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.chord == null
                      ? ' '
                      : transposeChord(segment.chord!, semitones: semitones),
                  style: chordStyle,
                ),
                Text(segment.text.isEmpty ? ' ' : segment.text, style: lyricStyle),
              ],
            ),
        ],
      ),
    );
  }
}
