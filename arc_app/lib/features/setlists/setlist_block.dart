import 'package:flutter/material.dart';

import '../../core/format/date_format.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import 'setlist.dart';

/// How many songs a block previews before the total count.
const _previewSongs = 3;

/// A setlist as a rectangular block: date, name, the first songs with their
/// key and the total. Shared by Inicio's pinned row and the Setlists grid.
class SetlistBlock extends StatelessWidget {
  const SetlistBlock({super.key, required this.setlist, required this.onTap, this.menu});

  final Setlist setlist;
  final VoidCallback onTap;

  /// Optional actions button shown at the top right (e.g. unpin).
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = setlist.serviceDate;
    final hasName = setlist.name?.isNotEmpty == true;
    final count = setlist.songs.length;

    return ArcaCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed height so blocks with and without a menu line up.
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${weekdayName(date)} · ${shortDate(date)}'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ?menu,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? setlist.name! : weekdayName(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                for (final song in setlist.songs.take(_previewSongs))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      song.key.isEmpty ? song.songTitle : '${song.songTitle} · ${song.key}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  count == 1 ? '1 canción' : '$count canciones',
                  style: text.bodySmall?.copyWith(color: context.arca.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
