import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'song.dart';
import 'song_list_provider.dart';

class SongEditorScreen extends ConsumerStatefulWidget {
  const SongEditorScreen({super.key, this.existingSong});

  /// Null when creating a new song, non-null when editing one.
  final Song? existingSong;

  @override
  ConsumerState<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends ConsumerState<SongEditorScreen> {
  late final _titleController = TextEditingController(text: widget.existingSong?.title);
  late final _artistController = TextEditingController(text: widget.existingSong?.artist);
  late final _keyController =
      TextEditingController(text: widget.existingSong?.originalKey ?? 'C');
  late final _tempoController =
      TextEditingController(text: widget.existingSong?.tempo?.toString());
  late final _timeSignatureController =
      TextEditingController(text: widget.existingSong?.timeSignature);
  late final _contentController = TextEditingController(text: widget.existingSong?.content);
  late final _notesController = TextEditingController(text: widget.existingSong?.notes);

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _keyController.dispose();
    _tempoController.dispose();
    _timeSignatureController.dispose();
    _contentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final song = Song(
      id: widget.existingSong?.id ?? 0,
      title: _titleController.text.trim(),
      artist: _artistController.text.trim().isEmpty ? null : _artistController.text.trim(),
      originalKey: _keyController.text.trim(),
      tempo: int.tryParse(_tempoController.text.trim()),
      timeSignature:
          _timeSignatureController.text.trim().isEmpty ? null : _timeSignatureController.text.trim(),
      content: _contentController.text,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      attachments: widget.existingSong?.attachments ?? [],
    );

    try {
      final repository = ref.read(songRepositoryProvider);
      if (widget.existingSong == null) {
        await repository.create(song);
      } else {
        await repository.update(song);
      }
      await ref.read(songListProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo guardar la canción: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSong != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar canción' : 'Nueva canción')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artista'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(labelText: 'Tonalidad *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tempoController,
                    decoration: const InputDecoration(labelText: 'Tempo (BPM)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeSignatureController,
              decoration: const InputDecoration(labelText: 'Compás (ej: 4/4)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Letra y acordes (formato ChordPro) *',
                alignLabelWithHint: true,
              ),
              maxLines: 12,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
