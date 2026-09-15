import 'package:dio/dio.dart';
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
    final rawTempo = _tempoController.text.trim();
    final tempo = rawTempo.isEmpty ? null : int.tryParse(rawTempo);
    if (rawTempo.isNotEmpty && tempo == null) {
      setState(() => _errorMessage = 'El tempo debe ser un número (BPM).');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final song = Song(
      id: widget.existingSong?.id ?? 0,
      title: _titleController.text.trim(),
      artist: _artistController.text.trim().isEmpty ? null : _artistController.text.trim(),
      originalKey: _keyController.text.trim(),
      tempo: tempo,
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
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo guardar la canción.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Extracts a clean, user-facing message from a failed save request.
  /// Laravel returns validation errors as `{"errors": {"field": ["msg"]}}`
  /// on a 422 — surface the first one instead of the raw exception text.
  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final firstFieldErrors = errors.values.first;
      if (firstFieldErrors is List && firstFieldErrors.isNotEmpty) {
        return firstFieldErrors.first.toString();
      }
    }
    return 'No se pudo guardar la canción. Verificá tu conexión e intentá de nuevo.';
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
