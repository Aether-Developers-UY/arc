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

  final songs = [
    for (final (i, s) in setlist.songs.indexed)
      '${i + 1}. ${s.songTitle}'
          '${s.songArtist?.trim().isNotEmpty == true ? ' (${s.songArtist!.trim()})' : ''}'
          ' — *${s.key}*',
  ];

  return [...header, '', ...songs].join('\n');
}

/// Opens WhatsApp (app or web) with [text] ready to send to any chat.
Uri whatsAppUri(String text) => Uri.https('wa.me', '/', {'text': text});
