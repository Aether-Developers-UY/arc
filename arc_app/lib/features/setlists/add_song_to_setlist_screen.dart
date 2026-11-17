import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
import '../songs/song.dart';
import '../songs/song_list_provider.dart';
import 'setlist.dart';
import 'setlist_list_provider.dart';

/// A song picker that adds the chosen song to [setlistId] and pops with
/// `true` on success (so the caller knows to refresh), or pops with `false`/
/// nothing if the user backs out.
class AddSongToSetlistScreen extends ConsumerStatefulWidget {
  const AddSongToSetlistScreen({super.key, required this.setlistId, required this.section});

  final int setlistId;

  /// The block of the service the song goes into.
  final SetlistSection section;

  @override
  ConsumerState<AddSongToSetlistScreen> createState() => _AddSongToSetlistScreenState();
}

class _AddSongToSetlistScreenState extends ConsumerState<AddSongToSetlistScreen> {
  bool _isAdding = false;
  String? _errorMessage;

  Future<void> _add(Song song) async {
    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });
    try {
      await ref.read(setlistRepositoryProvider).addSong(
            setlistId: widget.setlistId,
            songId: song.id,
            section: widget.section,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo agregar la canción.');
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songListProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Agregar a ${widget.section.label}')),
      body: ContentFrame(
        maxWidth: 720,
        child: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_isAdding) const LinearProgressIndicator(),
          Expanded(
            child: songsAsync.when(
              data: (songs) => ListView.separated(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: songs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return ArcaCard(
                    onTap: _isAdding ? null : () => _add(song),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (song.artist?.isNotEmpty == true)
                                Text(
                                  song.artist!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: context.arca.textSecondary),
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
              error: (error, _) => Center(child: Text('Error al cargar canciones: $error')),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
