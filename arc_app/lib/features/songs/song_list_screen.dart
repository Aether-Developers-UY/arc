import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_theme.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/view_mode.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/view_mode_toggle.dart';
import 'lyric_search.dart';
import 'song_detail_screen.dart';
import 'song_editor_screen.dart';
import 'song.dart';
import 'song_list_provider.dart';

const _viewModeKey = 'song_list_view';

class SongListScreen extends ConsumerStatefulWidget {
  const SongListScreen({super.key});

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  final _searchController = TextEditingController();

  /// The search the list is showing (what was submitted, not what is being
  /// typed): it decides the lyric phrases and the no-results message.
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _query = value.trim());
    ref.read(songListProvider.notifier).search(_query);
  }

  void _clearSearch() {
    _searchController.clear();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songListProvider);
    final viewMode = ref.watch(viewModeProvider(_viewModeKey)).value ?? ViewMode.grid;

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
                child: ValueListenableBuilder(
                  valueListenable: _searchController,
                  builder: (context, value, _) => TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar por título, artista o letra',
                      suffixIcon: value.text.isEmpty && _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const ViewModeToggle(prefsKey: _viewModeKey),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: songsAsync.when(
              data: (songs) => songs.isEmpty
                  ? _query.isNotEmpty
                      ? _EmptyState(
                          icon: Icons.search_off,
                          title: 'Sin resultados',
                          message: 'Ninguna canción tiene «$_query» en el título, el artista o la letra.',
                        )
                      : _EmptyState(
                          icon: Icons.library_music_outlined,
                          title: 'Todavía no hay canciones',
                          message: 'Agregá la primera con «Nueva canción».',
                        )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(songListProvider.notifier).refresh(),
                      child: viewMode == ViewMode.grid
                          ? GridView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisExtent: 168,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: songs.length,
                              itemBuilder: (context, index) =>
                                  _SongBlock(song: songs[index], match: _lyricMatchFor(songs[index])),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: songs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _SongRow(song: songs[index], match: _lyricMatchFor(songs[index])),
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

  /// The lyric phrase to show under a search result, only when the title
  /// and artist don't already explain why the song is there.
  LyricMatch? _lyricMatchFor(Song song) {
    if (_query.isEmpty || matchesTitleOrArtist(song.title, song.artist, _query)) return null;
    return lyricMatch(song.content, _query);
  }
}

/// A line of lyric with the searched words in bold.
class _LyricSnippet extends StatelessWidget {
  const _LyricSnippet(this.match, {required this.maxLines});

  final LyricMatch match;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.arca.textSecondary,
          fontStyle: FontStyle.italic,
          height: 1.3,
        );
    return Row(
      key: const Key('lyric-match'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 6),
          child: Icon(Icons.lyrics_outlined, size: 14, color: context.arca.textSecondary),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                TextSpan(text: match.before),
                TextSpan(
                  text: match.match,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextSpan(text: match.after),
              ],
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

void _openSong(BuildContext context, Song song) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SongDetailScreen(song: song)),
    );

/// One song per row: title and artist on the left, key on the right.
class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, this.match});

  final Song song;
  final LyricMatch? match;

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
                if (match != null) ...[
                  const SizedBox(height: 6),
                  _LyricSnippet(match!, maxLines: 2),
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

/// A rectangular block for the grid. Mirrors the setlist cards: the key sits
/// in a tinted tile (like the setlist date), with the reference files the
/// song carries flagged beside it; title and artist follow, and tempo and
/// time signature close the block when the song has them.
class _SongBlock extends StatelessWidget {
  const _SongBlock({required this.song, this.match});

  final Song song;

  /// When set, the matching lyric takes the place of tempo and time
  /// signature, and the title keeps to one line to make room.
  final LyricMatch? match;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasAudio = song.attachments.any((a) => a.type == 'audio');
    final hasPdf = song.attachments.any((a) => a.type == 'pdf');
    final meta = [
      if (song.tempo != null) '${song.tempo} BPM',
      if (song.timeSignature?.isNotEmpty == true) song.timeSignature!,
    ].join(' · ');

    return ArcaCard(
      onTap: () => _openSong(context, song),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  song.originalKey,
                  style: ArcaTheme.mono(
                    TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (hasAudio) const _AttachmentFlag(Icons.headphones_outlined, 'Tiene audio'),
              if (hasPdf) const _AttachmentFlag(Icons.picture_as_pdf_outlined, 'Tiene PDF'),
            ],
          ),
          const Spacer(),
          Text(
            song.title,
            maxLines: match == null ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
          ),
          if (song.artist?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              song.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
            ),
          ],
          if (match != null) ...[
            const SizedBox(height: 6),
            _LyricSnippet(match!, maxLines: 2),
          ] else if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(
                color: context.arca.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentFlag extends StatelessWidget {
  const _AttachmentFlag(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(icon, size: 18, color: context.arca.textSecondary),
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
