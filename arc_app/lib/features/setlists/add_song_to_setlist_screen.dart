import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../songs/song.dart';
import '../songs/song_list_provider.dart';
import 'setlist_list_provider.dart';

/// A song picker that adds the chosen song to [setlistId] and pops with
/// `true` on success (so the caller knows to refresh), or pops with `false`/
/// nothing if the user backs out.
class AddSongToSetlistScreen extends ConsumerStatefulWidget {
  const AddSongToSetlistScreen({super.key, required this.setlistId});

  final int setlistId;

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
      appBar: AppBar(title: const Text('Agregar canción')),
      body: Column(
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
              data: (songs) => ListView.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return ListTile(
                    title: Text(song.title),
                    subtitle: Text(song.artist ?? ''),
                    trailing: Text(song.originalKey),
                    onTap: _isAdding ? null : () => _add(song),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error al cargar canciones: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
