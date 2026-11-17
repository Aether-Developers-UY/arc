/// Helpers to show *where* a search matched a song's lyrics. The server
/// does the actual search; these mirror its rules (no chords, no
/// {directives}, accents and capitals ignored, lines joined by a space) so
/// the list can show the matching phrase.
library;

/// How many characters of lyric to show on each side of the match.
const lyricContext = 32;

final _directive = RegExp(r'^\{.*\}$');
final _chord = RegExp(r'\[[^\]]*\]');
final _spaces = RegExp(r'\s+');

const _plain = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Lowercase and without accents. Keeps the length, so a position found in
/// the folded text is the same position in the original.
String foldForSearch(String text) {
  final out = StringBuffer();
  for (final ch in text.split('')) {
    final lower = ch.toLowerCase();
    final one = lower.length == 1 ? lower : ch;
    out.write(_plain[one] ?? one);
  }
  return out.toString();
}

String _collapse(String text) => text.replaceAll(_spaces, ' ').trim();

/// The words of the song in one line: no chords, no directives.
String plainLyrics(String content) => _collapse([
      for (final line in content.split('\n'))
        if (!_directive.hasMatch(line.trim())) line.replaceAll(_chord, ''),
    ].join(' '));

bool matchesTitleOrArtist(String title, String? artist, String query) {
  final q = foldForSearch(_collapse(query));
  if (q.isEmpty) return false;
  return foldForSearch(title).contains(q) || foldForSearch(artist ?? '').contains(q);
}

/// The matching phrase with a little lyric around it. [before] and [after]
/// start or end with "…" when the lyric was cut there.
class LyricMatch {
  const LyricMatch(this.before, this.match, this.after);

  final String before;
  final String match;
  final String after;
}

LyricMatch? lyricMatch(String content, String query) {
  final q = foldForSearch(_collapse(query));
  if (q.isEmpty) return null;
  final lyrics = plainLyrics(content);
  final start = foldForSearch(lyrics).indexOf(q);
  if (start < 0) return null;
  final end = start + q.length;

  var before = lyrics.substring(0, start);
  final from = start - lyricContext;
  if (from > 0) {
    // Cut at the first space after [from], so no word is split.
    final space = lyrics.indexOf(' ', from);
    final cut = space < 0 || space >= start ? from : space + 1;
    before = '…${lyrics.substring(cut, start)}';
  }

  var after = lyrics.substring(end);
  final to = end + lyricContext;
  if (to < lyrics.length) {
    final space = lyrics.lastIndexOf(' ', to);
    final cut = space <= end ? to : space;
    after = '${lyrics.substring(end, cut)}…';
  }

  return LyricMatch(before, lyrics.substring(start, end), after);
}
