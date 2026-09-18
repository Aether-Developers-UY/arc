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

  /// True while a reorder/remove/add mutation is in flight. Guards against
  /// overlapping mutations (e.g. dragging again before the previous reorder
  /// persisted, or removing a song mid-reorder) racing each other and
  /// leaving the UI in a state that matches neither request.
  bool _isMutating = false;

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

  /// Re-fetches the setlist from the server without toggling `_isLoading`
  /// (so it doesn't replace the list with a full-screen spinner) — used
  /// after a mutation to re-sync local state with the server, whether the
  /// mutation succeeded or failed.
  Future<void> _reloadSilently() async {
    try {
      final setlist = await ref.read(setlistRepositoryProvider).getOne(widget.setlistId);
      if (mounted) setState(() => _setlist = setlist);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo actualizar el setlist.');
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;

    final songs = List<SetlistSong>.from(setlist.songs);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = songs.removeAt(oldIndex);
    songs.insert(newIndex, moved);

    // Optimistic: reorder locally immediately, persist in background.
    setState(() {
      _isMutating = true;
      _setlist = Setlist(
        id: setlist.id,
        serviceDate: setlist.serviceDate,
        name: setlist.name,
        songs: songs,
      );
    });

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
    } finally {
      // Re-sync after every persist attempt (success or failure), not just
      // on failure — this is what keeps local state matching the server
      // and clears the mutation guard so the next reorder/remove can run.
      await _reloadSilently();
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _removeSong(SetlistSong setlistSong) async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;
    setState(() => _isMutating = true);
    try {
      await ref.read(setlistRepositoryProvider).removeSong(
            setlistId: setlist.id,
            setlistSongId: setlistSong.id,
          );
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'No se pudo quitar la canción.');
    } finally {
      await _reloadSilently();
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _openAddSong() async {
    final setlist = _setlist;
    if (setlist == null || _isMutating) return;
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddSongToSetlistScreen(setlistId: setlist.id)),
    );
    if (added == true) await _reloadSilently();
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
                                        onPressed: _isMutating
                                            ? null
                                            : () => _removeSong(setlistSong),
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
class _SongFromSetlistLoader extends ConsumerStatefulWidget {
  const _SongFromSetlistLoader({required this.songId, required this.initialKey});

  final int songId;
  final String initialKey;

  @override
  ConsumerState<_SongFromSetlistLoader> createState() => _SongFromSetlistLoaderState();
}

class _SongFromSetlistLoaderState extends ConsumerState<_SongFromSetlistLoader> {
  // Fetched once in initState (not inside build) so a widget rebuild for an
  // unrelated reason (theme/orientation change, hot reload) doesn't hand
  // FutureBuilder a new Future identity and re-trigger the network request.
  late final Future<Song> _songFuture =
      ref.read(songRepositoryProvider).getOne(widget.songId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Song>(
      future: _songFuture,
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
        return SongDetailScreen(song: snapshot.data!, initialKey: widget.initialKey);
      },
    );
  }
}
