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

  test('the WhatsApp link carries the whole text', () {
    final text = setlistShareText(_setlist(name: 'Culto'));
    final uri = whatsAppUri(text);

    expect(uri.host, 'wa.me');
    expect(uri.queryParameters['text'], text);
  });
}
