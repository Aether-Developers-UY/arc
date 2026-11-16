import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chordpro/chordpro_parser.dart';
import '../../core/chordpro/transposer.dart';
import '../../core/layout.dart';
import '../../core/screen_awake.dart';
import '../../core/theme/arca_theme.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../attachments/attachment_list.dart';
import 'autoscroll.dart';
import 'song.dart';
import 'song_editor_screen.dart';
import 'song_list_provider.dart';
import 'song_lyrics_view.dart';

class SongDetailScreen extends ConsumerStatefulWidget {
  const SongDetailScreen({super.key, required this.song, this.initialKey});

  final Song song;

  /// The key to show the song in when this screen opens. Defaults to the
  /// song's own original key. Used when opening a song from a setlist,
  /// where the setlist may have chosen a different key for that service.
  final String? initialKey;

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  // Read once here: dispose can't use ref, and it must still let the
  // screen sleep when the song closes mid-scroll.
  late final _screenAwake = ref.read(screenAwakeProvider);
  late final _autoScroller = AutoScroller(
    vsync: this,
    controller: _scrollController,
    songId: widget.song.id,
    onActiveChanged: _screenAwake.keep,
  );

  @override
  void dispose() {
    _autoScroller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  late Song _song = widget.song;
  late String _currentKey = widget.initialKey ?? _song.originalKey;
  static const _availableKeys = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  Future<void> _refreshSongAttachments() async {
    try {
      final repository = ref.read(songRepositoryProvider);
      final refreshed = await repository.getOne(_song.id);
      if (!mounted) return;
      setState(() => _song = refreshed);
    } catch (_) {
      // The upload/delete itself already succeeded server-side; only this
      // follow-up refresh failed (e.g. dropped connection). Surface it so
      // the UI doesn't silently show stale attachments without explanation.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la lista de archivos.')),
      );
    }
  }

  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar «${_song.title}»?'),
        content: const Text(
          'También se borran sus archivos adjuntos y se quita de los setlists '
          'donde esté. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(songRepositoryProvider).delete(_song.id);
      await ref.read(songListProvider.notifier).refresh();
      // `true` tells the opener the song is gone, so it can reload.
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la canción.')),
      );
    }
  }

  String? get _metaLine {
    final parts = <String>[
      if (_song.artist?.isNotEmpty == true) _song.artist!,
      if (_song.tempo != null) '${_song.tempo} BPM',
      if (_song.timeSignature?.isNotEmpty == true) _song.timeSignature!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget? get _indicationsCard {
    final notes = _song.notes?.trim();
    if (notes == null || notes.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ArcaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INDICACIONES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 6),
            Text(notes),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final document = ChordProParser.parse(_song.content);
    final semitones = semitonesBetweenKeys(from: _song.originalKey, to: _currentKey);

    final header = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_song.title, style: Theme.of(context).textTheme.headlineMedium),
          if (_metaLine != null) ...[
            const SizedBox(height: 4),
            Text(
              _metaLine!,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: context.arca.textSecondary),
            ),
          ],
        ],
      ),
    );

    final indications = _indicationsCard;

    final keyControls = _KeyControls(
      keys: _availableKeys,
      current: _currentKey,
      original: _song.originalKey,
      onSelect: (key) => setState(() => _currentKey = key),
      onReset: () => setState(() => _currentKey = _song.originalKey),
    );

    final lyrics = SizedBox(
      width: double.infinity,
      child: ArcaCard(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SongLyricsView(document: document, semitones: semitones),
      ),
    );

    final attachments = ArcaCard(
      child: AttachmentList(song: _song, onChanged: _refreshSongAttachments),
    );

    return Scaffold(
      floatingActionButton: AutoScrollControls(scroller: _autoScroller),
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Editar canción',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SongEditorScreen(existingSong: _song)),
            ),
          ),
          IconButton(
            tooltip: 'Eliminar canción',
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
        ],
      ),
      body: ContentFrame(
        maxWidth: 1200,
        child: isWide(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('song-scroll'),
                      controller: _scrollController,
                      // Room so the last lines clear the autoscroll bar.
                      padding: const EdgeInsets.only(bottom: 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          ?indications,
                          keyControls,
                          const SizedBox(height: 16),
                          lyrics,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 320,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8, bottom: 32),
                      child: attachments,
                    ),
                  ),
                ],
              )
            : ListView(
                key: const Key('song-scroll'),
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  header,
                  ?indications,
                  keyControls,
                  const SizedBox(height: 16),
                  lyrics,
                  const SizedBox(height: 16),
                  attachments,
                ],
              ),
      ),
    );
  }
}

class _KeyControls extends StatelessWidget {
  const _KeyControls({
    required this.keys,
    required this.current,
    required this.original,
    required this.onSelect,
    required this.onReset,
  });

  final List<String> keys;
  final String current;
  final String original;
  final ValueChanged<String> onSelect;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tonalidad', style: text.titleSmall),
            const SizedBox(width: 8),
            Text(
              'Original: $original',
              style: text.bodySmall?.copyWith(color: context.arca.textSecondary),
            ),
            const Spacer(),
            if (current != original)
              TextButton(onPressed: onReset, child: const Text('Restablecer')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in keys)
              ChoiceChip(
                label: Text(
                  key,
                  style: ArcaTheme.mono(const TextStyle(fontWeight: FontWeight.w700)),
                ),
                selected: key == current,
                onSelected: (_) => onSelect(key),
              ),
          ],
        ),
      ],
    );
  }
}
