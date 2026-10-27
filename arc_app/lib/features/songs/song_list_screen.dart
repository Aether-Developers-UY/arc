import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
import '../../core/widgets/page_header.dart';
import 'song_detail_screen.dart';
import 'song_editor_screen.dart';
import 'song.dart';
import 'song_list_provider.dart';
import 'song_view_mode_provider.dart';

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
    final viewMode = ref.watch(songViewModeProvider).value ?? SongViewMode.grid;

    return ContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Canciones',
            subtitle: 'El repertorio del ministerio',
            trailing: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nueva canción'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SongEditorScreen()),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por título o artista',
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => ref.read(songListProvider.notifier).search(value),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<SongViewMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: SongViewMode.grid,
                    icon: Icon(Icons.grid_view),
                    tooltip: 'Bloques',
                  ),
                  ButtonSegment(
                    value: SongViewMode.list,
                    icon: Icon(Icons.view_agenda_outlined),
                    tooltip: 'Lista',
                  ),
                ],
                selected: {viewMode},
                onSelectionChanged: (selection) =>
                    ref.read(songViewModeProvider.notifier).set(selection.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: songsAsync.when(
              data: (songs) => songs.isEmpty
                  ? _EmptyState(
                      icon: Icons.library_music_outlined,
                      title: 'Todavía no hay canciones',
                      message: 'Agregá la primera con «Nueva canción».',
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(songListProvider.notifier).refresh(),
                      child: viewMode == SongViewMode.grid
                          ? GridView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisExtent: 132,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: songs.length,
                              itemBuilder: (context, index) => _SongBlock(song: songs[index]),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: songs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _SongRow(song: songs[index]),
                            ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'No se pudieron cargar las canciones',
                message: 'Revisá tu conexión y deslizá hacia abajo para reintentar.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openSong(BuildContext context, Song song) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SongDetailScreen(song: song)),
    );

/// One song per row: title and artist on the left, key on the right.
class _SongRow extends StatelessWidget {
  const _SongRow({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return ArcaCard(
      onTap: () => _openSong(context, song),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (song.artist?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    song.artist!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.arca.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          KeyBadge(song.originalKey),
        ],
      ),
    );
  }
}

/// A rectangular block for the grid: key on top, title and artist below.
class _SongBlock extends StatelessWidget {
  const _SongBlock({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ArcaCard(
      onTap: () => _openSong(context, song),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note_outlined, size: 20, color: context.arca.textSecondary),
              const Spacer(),
              KeyBadge(song.originalKey),
            ],
          ),
          const Spacer(),
          Text(
            song.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
          ),
          if (song.artist?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              song.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: context.arca.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: context.arca.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.arca.textSecondary),
          ),
        ],
      ),
    );
  }
}
