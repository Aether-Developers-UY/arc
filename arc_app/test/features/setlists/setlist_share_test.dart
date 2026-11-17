import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/setlist_share.dart';
import 'package:flutter_test/flutter_test.dart';

SetlistSong _entry(int position, String title, String key, {String? artist}) => SetlistSong(
      id: position,
      songId: position,
      position: position,
      key: key,
      songTitle: title,
      songArtist: artist,
    );

Setlist _setlist({String? name}) => Setlist(
      id: 3,
      serviceDate: DateTime(2026, 11, 22), // a Sunday
      name: name,
      songs: [
        _entry(1, 'Sublime Gracia', 'G', artist: 'John Newton'),
        _entry(2, 'Cuán Grande Es Él', 'A'),
      ],
    );

void main() {
  test('a named setlist: name, date and annex, then the songs with their keys', () {
    expect(
      setlistShareText(_setlist(name: 'Culto de jóvenes'), annexName: 'Anexo principal'),
      '*Culto de jóvenes*\n'
      'Domingo 22/11/2026 · Anexo principal\n'
      '\n'
      '1. Sublime Gracia (John Newton) — *G*\n'
      '2. Cuán Grande Es Él — *A*',
    );
  });

  test('without a name the date is the title', () {
    expect(
      setlistShareText(_setlist()).split('\n').take(2).toList(),
      ['*Domingo 22/11/2026*', ''],
    );
  });

  test('a blank name counts as no name', () {
    expect(setlistShareText(_setlist(name: '  ')).split('\n').first, '*Domingo 22/11/2026*');
  });

  test('without a name the annex goes under the date', () {
    expect(
      setlistShareText(_setlist(), annexName: 'Anexo norte').split('\n').take(3).toList(),
      ['*Domingo 22/11/2026*', 'Anexo norte', ''],
    );
  });

  test('a setlist with blocks groups the songs under each block, numbered through', () {
    SetlistSong s(int i, String title, String key, SetlistSection? section, {String? line}) => SetlistSong(
          id: i, songId: i, position: i, key: key, songTitle: title, songArtist: null,
          section: section, lineName: line,
        );
    final setlist = Setlist(
      id: 1,
      serviceDate: DateTime(2026, 11, 22),
      name: 'Culto',
      songs: [
        s(1, 'Abre mis ojos', 'G', SetlistSection.inicio),
        s(2, 'Poderoso', 'A', SetlistSection.linea, line: 'Alabanza'),
        s(3, 'Santo Espíritu', 'D', SetlistSection.linea, line: 'Alabanza'),
        s(4, 'Todo lo que soy', 'E', SetlistSection.ofrenda),
        s(5, 'Sublime Gracia', 'G', null),
      ],
    );

    expect(
      setlistShareText(setlist),
      '*Culto*\n'
      'Domingo 22/11/2026\n'
      '\n'
      '*Inicio*\n'
      '1. Abre mis ojos — *G*\n'
      '\n'
      '*Línea · Alabanza*\n'
      '2. Poderoso — *A*\n'
      '3. Santo Espíritu — *D*\n'
      '\n'
      '*Ofrenda*\n'
      '4. Todo lo que soy — *E*\n'
      '\n'
      '*Otras canciones*\n'
      '5. Sublime Gracia — *G*',
    );
  });

  test('the WhatsApp link carries the whole text', () {
    final text = setlistShareText(_setlist(name: 'Culto'));
    final uri = whatsAppUri(text);

    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], text);
  });
}
