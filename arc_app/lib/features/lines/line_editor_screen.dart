import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/arca_card.dart';
import '../../core/widgets/content_frame.dart';
import '../../core/widgets/key_badge.dart';
import '../songs/song.dart';
import '../songs/song_picker_screen.dart';
import 'line.dart';
import 'line_repository.dart';

const _keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Creates or edits a line: its name and its songs, in order, each in
/// the key the line plays it. Pops with `true` when something changed.
class LineEditorScreen extends ConsumerStatefulWidget {
  const LineEditorScreen({super.key, this.line});

  /// Null for a new line.
  final Line? line;

  @override
  ConsumerState<LineEditorScreen> createState() => _LineEditorScreenState();
}

class _LineEditorScreenState extends ConsumerState<LineEditorScreen> {
  late final _name = TextEditingController(text: widget.line?.name ?? '');
  late List<LineSong> _songs = [...?widget.line?.songs];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addSong() async {
    final song = await Navigator.of(context).push<Song>(
      MaterialPageRoute(builder: (_) => const SongPickerScreen(title: 'Agregar a la línea')),
    );
    if (song == null) return;
    setState(() => _songs = [
          ..._songs,
          LineSong(
            songId: song.id,
            key: song.originalKey,
            title: song.title,
            artist: song.artist,
            originalKey: song.originalKey,
          ),
        ]);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final error = name.isEmpty
        ? 'Poné un nombre a la línea.'
        : _songs.isEmpty
            ? 'Agregá al menos una canción.'
            : null;
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(lineRepositoryProvider);
      final line = widget.line;
      if (line == null) {
        await repository.create(name: name, songs: _songs);
      } else {
        await repository.update(line.id, name: name, songs: _songs);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar la línea.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Line line) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Eliminar «${line.name}»?'),
        content: const Text(
          'Las canciones siguen en la biblioteca. Los setlists que ya la usan no cambian.',
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
    try {
      await ref.read(lineRepositoryProvider).delete(line.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo eliminar la línea.');
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    final songs = [..._songs];
    songs.insert(newIndex, songs.removeAt(oldIndex));
    setState(() => _songs = songs);
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(line == null ? 'Nueva línea' : 'Editar línea'),
        actions: [
          if (line != null)
            IconButton(
              tooltip: 'Eliminar línea',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : () => _delete(line),
            ),
        ],
      ),
      body: ContentFrame(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: Alabanza alegre'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Text('Canciones, en el orden en que se tocan', style: text.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _songs.length,
                onReorderItem: _reorder,
                footer: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _addSong,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar canción'),
                    ),
                  ),
                ),
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  return Padding(
                    key: ObjectKey(song),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ArcaCard(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.drag_indicator, color: context.arca.textSecondary),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              song.title,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Tonalidad de ${song.title}',
                            onSelected: (key) => setState(() => _songs[index] = song.withKey(key)),
                            itemBuilder: (_) => [
                              for (final key in {..._keys, song.originalKey})
                                PopupMenuItem(
                                  value: key,
                                  child: Text(key == song.originalKey ? '$key (original)' : key),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: KeyBadge(song.key),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar de la línea',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _songs = [..._songs]..removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
