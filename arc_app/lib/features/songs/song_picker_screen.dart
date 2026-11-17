import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
import 'song.dart';
import 'song_list_provider.dart';

/// Picks a song from the library; pops with the chosen [Song].
class SongPickerScreen extends ConsumerWidget {
  const SongPickerScreen({super.key, this.title = 'Elegir canción'});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songListProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ContentFrame(
        maxWidth: 720,
        child: songsAsync.when(
          data: (songs) => ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final song = songs[index];
              return ArcaCard(
                onTap: () => Navigator.of(context).pop<Song>(song),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          if (song.artist?.isNotEmpty == true)
                            Text(
                              song.artist!,
                              style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    KeyBadge(song.originalKey),
                  ],
                ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('No se pudieron cargar las canciones.')),
        ),
      ),
    );
  }
}
