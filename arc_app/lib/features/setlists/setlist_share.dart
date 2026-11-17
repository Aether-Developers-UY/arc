/// Builds the setlist message for WhatsApp: *bold* is WhatsApp's own
/// formatting, so the title and each key stand out in the chat.
library;

import '../../core/format/date_format.dart';
import 'setlist.dart';

String _capitalized(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String setlistShareText(Setlist setlist, {String? annexName}) {
  final date = '${_capitalized(weekdayName(setlist.serviceDate))} ${shortDate(setlist.serviceDate)}';
  final name = setlist.name?.trim() ?? '';
  final annex = annexName?.trim() ?? '';

  final header = name.isNotEmpty
      ? ['*$name*', [date, if (annex.isNotEmpty) annex].join(' · ')]
      : ['*$date*', if (annex.isNotEmpty) annex];

  String songLine(SetlistSong s) => '${setlist.songs.indexOf(s) + 1}. ${s.songTitle}'
      '${s.songArtist?.trim().isNotEmpty == true ? ' (${s.songArtist!.trim()})' : ''}'
      ' — *${s.key}*';

  // A setlist from before the blocks is just its list of songs.
  if (setlist.songs.every((s) => s.section == null)) {
    return [...header, '', ...setlist.songs.map(songLine)].join('\n');
  }

  // Otherwise, each block that has songs under its own heading.
  final blocks = <String>[];
  for (final section in [...SetlistSection.values, null]) {
    final songs = setlist.songs.where((s) => s.section == section).toList();
    if (songs.isEmpty) continue;
    final lineName = songs.map((s) => s.lineName).nonNulls.firstOrNull;
    final title = switch (section) {
      null => 'Otras canciones',
      SetlistSection.linea when lineName != null => 'Línea · $lineName',
      _ => section.label,
    };
    blocks.add(['*$title*', ...songs.map(songLine)].join('\n'));
  }

  return [...header, '', blocks.join('\n\n')].join('\n');
}

/// Opens WhatsApp (app or web) with [text] ready to send to any chat.
Uri whatsAppUri(String text) => Uri.https('wa.me', '/', {'text': text});
