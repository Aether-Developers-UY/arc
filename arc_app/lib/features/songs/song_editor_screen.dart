import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/content_frame.dart';
import 'editor/editable_document.dart';
import 'editor/song_lyrics_step.dart';
import 'editor/song_metadata_step.dart';
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
  late final _notesController = TextEditingController(text: widget.existingSong?.notes);

  late List<EditableSection> _lyricsSections = _initialSections();

  List<EditableSection> _initialSections() {
    final content = widget.existingSong?.content;
    if (content == null || content.trim().isEmpty) {
      return [EditableSection(label: 'verse')];
    }
    return parseToEditable(content);
  }

  bool _isSaving = false;
  String? _errorMessage;

  /// 0 = metadata, 1 = lyrics. Nothing is persisted until "Guardar" on 1.
  int _step = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _keyController.dispose();
    _tempoController.dispose();
    _timeSignatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Returns a user-facing message for the first invalid step 1 field, or
  /// null when the metadata is valid.
  String? _validateMetadata() {
    if (_titleController.text.trim().isEmpty) return 'Ingresá el título de la canción.';
    if (_keyController.text.trim().isEmpty) return 'Ingresá la tonalidad.';
    final rawTempo = _tempoController.text.trim();
    if (rawTempo.isNotEmpty && int.tryParse(rawTempo) == null) {
      return 'El tempo debe ser un número (BPM).';
    }
    return null;
  }

  void _goNext() {
    final error = _validateMetadata();
    setState(() {
      _errorMessage = error;
      if (error == null) _step = 1;
    });
  }

  void _goBack() {
    setState(() {
      _step = 0;
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    final error = _validateMetadata();
    if (error != null) {
      setState(() {
        _step = 0;
        _errorMessage = error;
      });
      return;
    }
    final rawTempo = _tempoController.text.trim();
    final tempo = rawTempo.isEmpty ? null : int.tryParse(rawTempo);

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
      content: editableToChordPro(_lyricsSections),
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

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Editar canción' : 'Nueva canción'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Paso ${_step + 1} de 2',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.arca.textSecondary),
              ),
            ),
          ),
        ),
        body: ContentFrame(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _step == 0
                ? SongMetadataStep(
                    titleController: _titleController,
                    artistController: _artistController,
                    keyController: _keyController,
                    tempoController: _tempoController,
                    timeSignatureController: _timeSignatureController,
                    errorMessage: _errorMessage,
                    onNext: _goNext,
                  )
                : SongLyricsStep(
                    sections: _lyricsSections,
                    onSectionsChanged: (updated) => setState(() => _lyricsSections = updated),
                    notesController: _notesController,
                    isSaving: _isSaving,
                    errorMessage: _errorMessage,
                    onBack: _goBack,
                    onSave: _save,
                  ),
          ),
        ),
      ),
    );
  }
}