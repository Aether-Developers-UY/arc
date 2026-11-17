import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_provider.dart';
import '../songs/song.dart';
import 'attachment_repository.dart';
import 'attachment_types.dart';

final attachmentRepositoryProvider =
    Provider((ref) => AttachmentRepository(ref.watch(apiClientProvider)));

class AttachmentList extends ConsumerStatefulWidget {
  const AttachmentList({
    super.key,
    required this.attachments,
    required this.owner,
    required this.onChanged,
  });

  final List<Attachment> attachments;

  /// The API path of what the files belong to: 'songs/5' or 'lines/7'.
  final String owner;

  /// Called after a successful upload or delete so the parent can refresh
  /// the files from the server.
  final VoidCallback onChanged;

  @override
  ConsumerState<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends ConsumerState<AttachmentList> {
  final _player = AudioPlayer();
  late final StreamSubscription<void> _completion;
  bool _isUploading = false;
  String? _errorMessage;

  /// The attachment being downloaded, and the audio currently playing.
  int? _openingId;
  int? _playingId;

  @override
  void initState() {
    super.initState();
    _completion = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _completion.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: attachmentExtensions,
    );
    if (files.isEmpty) return;

    final file = files.first;
    final type = attachmentTypeFor(file.extension);

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(attachmentRepositoryProvider).upload(
            owner: widget.owner,
            file: file,
            type: type,
          );
      widget.onChanged();
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo subir el archivo.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Extracts a clean, user-facing message from a failed upload request,
  /// mirroring the pattern used in SongEditorScreen's `_messageFor`.
  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      final firstFieldErrors = errors.values.first;
      if (firstFieldErrors is List && firstFieldErrors.isNotEmpty) {
        return firstFieldErrors.first.toString();
      }
    }
    return 'No se pudo subir el archivo. Verificá tu conexión e intentá de nuevo.';
  }

  Future<void> _delete(Attachment attachment) async {
    setState(() => _errorMessage = null);
    try {
      await ref.read(attachmentRepositoryProvider).delete(attachment.id);
      widget.onChanged();
    } on DioException catch (e) {
      setState(() => _errorMessage = _messageFor(e));
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo eliminar el archivo.');
    }
  }

  Future<void> _openOrPlay(Attachment attachment) async {
    if (_openingId != null) return;
    // Tapping the audio that's playing stops it.
    if (attachment.id == _playingId) {
      await _player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }

    setState(() {
      _errorMessage = null;
      _openingId = attachment.id;
    });
    try {
      final uri = await ref
          .read(attachmentRepositoryProvider)
          .downloadToLocalUri(attachment);

      if (attachment.type == 'audio') {
        await _player.stop();
        await _player.play(
          uri.isScheme('file')
              ? DeviceFileSource(uri.toFilePath())
              : UrlSource(uri.toString()),
        );
        if (mounted) setState(() => _playingId = attachment.id);
      } else {
        // On the web this opens the browser's PDF viewer in a new tab.
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo abrir el archivo.');
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Archivos adjuntos',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Agregar archivo',
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onPressed: _isUploading ? null : _pickAndUpload,
            ),
          ],
        ),
        if (_errorMessage != null)
          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (widget.attachments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin archivos adjuntos todavía.'),
          ),
        for (final attachment in widget.attachments)
          ListTile(
            leading: attachment.id == _openingId
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    attachment.id == _playingId
                        ? Icons.stop_circle_outlined
                        : attachment.type == 'audio'
                        ? Icons.audiotrack
                        : Icons.picture_as_pdf,
                    color: attachment.id == _playingId
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
            title: Text(attachment.originalName),
            subtitle: attachment.id == _playingId
                ? const Text('Reproduciendo · tocá para detener')
                : null,
            onTap: () => _openOrPlay(attachment),
            trailing: IconButton(
              tooltip: 'Eliminar archivo',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(attachment),
            ),
          ),
      ],
    );
  }
}
