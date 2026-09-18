import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../songs/song.dart';
import '../songs/song_detail_screen.dart';
import '../songs/song_list_provider.dart';
import 'add_song_to_setlist_screen.dart';
import 'setlist.dart';
import 'setlist_list_provider.dart';

class SetlistDetailScreen extends ConsumerStatefulWidget {
  const SetlistDetailScreen({super.key, required this.setlistId});

  final int setlistId;

  @override
  ConsumerState<SetlistDetailScreen> createState() => _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  Setlist? _setlist;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final setlist = await ref.read(setlistRepositoryProvider).getOne(widget.setlistId);
      if (mounted) setState(() => _setlist = setlist);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo cargar el setlist.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final setlist = _setlist;
    if (setlist == null) return;

    final songs = List<SetlistSong>.from(setlist.songs);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = songs.removeAt(oldIndex);
    songs.insert(newIndex, moved);

    // Optimistic: reorder locally immediately, persist in background.
    setState(() => _setlist = Setlist(
          id: setlist.id,
          serviceDate: setlist.serviceDate,
          name: setlist.name,
          songs: songs,
        ));

    try {
      await ref.read(setlistRepositoryProvider).reorder(
            setlistId: setlist.id,
            setlistSongIds: songs.map((s) => s.id).toList(),
          );
    } catch (_) {
      // Revert to the last known-good server state.
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo guardar el nuevo orden.');
      }
      await _load();
    }
  }

  Future<void> _removeSong(SetlistSong setlistSong) async {
    final setlist = _setlist;
    if (setlist == null) return;
    try {
      await ref.read(setlistRepositoryProvider).removeSong(
            setlistId: setlist.id,
            setlistSongId: setlistSong.id,
          );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo quitar la canción.');
    }
  }

  Future<void> _openAddSong() async {
    final setlist = _setlist;
    if (setlist == null) return;
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddSongToSetlistScreen(setlistId: setlist.id)),
    );
    if (added == true) await _load();
  }

  /// A setlist entry only carries title/artist/key for display in this
  /// list — not the full song (content, tempo, attachments). Navigate to a
  /// loader that fetches the real song before handing off to
  /// SongDetailScreen, passing this setlist's chosen key as the initial key.
  void _openSong(SetlistSong setlistSong) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SongFromSetlistLoader(
          songId: setlistSong.songId,
          initialKey: setlistSong.key,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setlist = _setlist;
    final dateLabel = setlist == null
        ? ''
        : '${setlist.serviceDate.day.toString().padLeft(2, '0')}/${setlist.serviceDate.month.toString().padLeft(2, '0')}/${setlist.serviceDate.year}';

    return Scaffold(
      appBar: AppBar(title: Text(setlist?.name?.isNotEmpty == true ? setlist!.name! : dateLabel)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : setlist == null
              ? Center(child: Text(_errorMessage ?? 'Setlist no encontrado.'))
              : Column(
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    Expanded(
                      child: setlist.songs.isEmpty
                          ? const Center(child: Text('Todavía no hay canciones en este setlist.'))
                          : ReorderableListView.builder(
                              itemCount: setlist.songs.length,
                              onReorder: _onReorder,
                              itemBuilder: (context, index) {
                                final setlistSong = setlist.songs[index];
                                return ListTile(
                                  key: ValueKey(setlistSong.id),
                                  title: Text(setlistSong.songTitle),
                                  subtitle: Text(setlistSong.songArtist ?? ''),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(setlistSong.key),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => _removeSong(setlistSong),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _openSong(setlistSong),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: setlist == null
          ? null
          : FloatingActionButton(
              onPressed: _openAddSong,
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// Fetches the full [Song] (content, tempo, attachments) for [songId] before
/// handing off to [SongDetailScreen], since a setlist entry only carries
/// enough data (title/artist/key) for display in the setlist list itself.
class _SongFromSetlistLoader extends ConsumerWidget {
  const _SongFromSetlistLoader({required this.songId, required this.initialKey});

  final int songId;
  final String initialKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Song>(
      future: ref.read(songRepositoryProvider).getOne(songId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('No se pudo cargar la canción.')),
          );
        }
        return SongDetailScreen(song: snapshot.data!, initialKey: initialKey);
      },
    );
  }
}
