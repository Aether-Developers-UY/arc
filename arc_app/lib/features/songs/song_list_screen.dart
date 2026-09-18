import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../setlists/setlist_list_screen.dart';
import 'song_detail_screen.dart';
import 'song_editor_screen.dart';
import 'song_list_provider.dart';

class SongListScreen extends ConsumerStatefulWidget {
  const SongListScreen({super.key});

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Setlists',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SetlistListScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por título o artista',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => ref.read(songListProvider.notifier).search(value),
            ),
          ),
          Expanded(
            child: songsAsync.when(
              data: (songs) => songs.isEmpty
                  ? const Center(child: Text('No hay canciones todavía.'))
                  : RefreshIndicator(
                      onRefresh: () => ref.read(songListProvider.notifier).refresh(),
                      child: ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return ListTile(
                            title: Text(song.title),
                            subtitle: Text(song.artist ?? ''),
                            trailing: Text(song.originalKey),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SongDetailScreen(song: song)),
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error al cargar canciones: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SongEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
