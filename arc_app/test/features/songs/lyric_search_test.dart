import 'package:arc_app/features/songs/lyric_search.dart';
import 'package:flutter_test/flutter_test.dart';

const _song = '{title: Cuán grande}\n'
    '{verse}\n'
    '[G]Señor mi [C]Dios, al contem[G]plar los cielos\n'
    '[D]El firmamento y las estrellas mil\n'
    '\n'
    '{chorus}\n'
    '[G]Mi corazón entona la canción\n';

void main() {
  group('foldForSearch', () {
    test('drops accents and capitals, keeping the length', () {
      expect(foldForSearch('Señor ÉL Canción'), 'senor el cancion');
      expect(foldForSearch('Señor').length, 'Señor'.length);
    });
  });

  group('plainLyrics', () {
    test('drops chords and directives, joins lines with single spaces', () {
      expect(
        plainLyrics(_song),
        'Señor mi Dios, al contemplar los cielos El firmamento y las estrellas mil '
        'Mi corazón entona la canción',
      );
    });
  });

  group('lyricMatch', () {
    test('finds a phrase even with chords in the middle of it', () {
      final match = lyricMatch(_song, 'al contemplar los')!;

      expect(match.match, 'al contemplar los');
      expect(match.before, endsWith('Dios, '));
      expect(match.after, startsWith(' cielos'));
    });

    test('ignores accents and capitals, but shows the lyric as written', () {
      expect(lyricMatch(_song, 'CORAZON entona')!.match, 'corazón entona');
    });

    test('follows a phrase onto the next line', () {
      expect(lyricMatch(_song, 'cielos el firmamento')!.match, 'cielos El firmamento');
    });

    test('trims long context at a word and marks the cut', () {
      final match = lyricMatch(_song, 'firmamento')!;

      expect(match.before, startsWith('…'));
      expect(match.after, endsWith('…'));
      expect(match.before.length, lessThanOrEqualTo(lyricContext + 1));
      // The cut never splits a word.
      expect(match.before.substring(1), isNot(startsWith('ontemplar')));
    });

    test('no context marks at the very start or end of the song', () {
      expect(lyricMatch(_song, 'señor mi')!.before, '');
      expect(lyricMatch(_song, 'la canción')!.after, '');
    });

    test('section names and chords are not lyrics', () {
      expect(lyricMatch(_song, 'chorus'), isNull);
      expect(lyricMatch(_song, 'Am7'), isNull);
      expect(lyricMatch(_song, '[G]'), isNull);
    });

    test('an empty query matches nothing', () {
      expect(lyricMatch(_song, '   '), isNull);
    });
  });

  group('matchesTitleOrArtist', () {
    test('ignores accents and capitals', () {
      expect(matchesTitleOrArtist('Cuán Grande Es Él', null, 'cuan grande'), isTrue);
      expect(matchesTitleOrArtist('Digno', 'Marcos Witt', 'witt'), isTrue);
      expect(matchesTitleOrArtist('Digno', null, 'gracia'), isFalse);
    });
  });
}
