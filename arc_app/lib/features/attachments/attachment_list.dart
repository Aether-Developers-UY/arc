import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_provider.dart';
import '../songs/song.dart';
import 'attachment_repository.dart';

final attachmentRepositoryProvider =
    Provider((ref) => AttachmentRepository(ref.watch(apiClientProvider)));

class AttachmentList extends ConsumerStatefulWidget {
  const AttachmentList({super.key, required this.song, required this.onChanged});

  final Song song;

  /// Called after a successful upload or delete so the parent can refresh
  /// the song (and its attachments) from the server.
  final VoidCallback onChanged;

  @override
  ConsumerState<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends ConsumerState<AttachmentList> {
  final _player = AudioPlayer();
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'pdf'],
    );
    if (files.isEmpty) return;

    final file = files.first;
    final extension = file.extension?.toLowerCase();
    final type = extension == 'pdf' ? 'pdf' : 'audio';

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(attachmentRepositoryProvider).upload(
            songId: widget.song.id,
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
    setState(() => _errorMessage = null);
    try {
      final repository = ref.read(attachmentRepositoryProvider);
      // The download route requires auth, so it's fetched through the
      // authenticated Dio client to a local file rather than handed as a
      // bare URL to audioplayers/url_launcher (neither attaches the
      // Authorization header the backend requires).
      final localPath = await repository.downloadToTempFile(attachment);

      if (attachment.type == 'audio') {
        await _player.play(DeviceFileSource(localPath));
      } else {
        await launchUrl(Uri.file(localPath), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo abrir el archivo.');
      }
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
        if (widget.song.attachments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin archivos adjuntos todavía.'),
          ),
        for (final attachment in widget.song.attachments)
          ListTile(
            leading: Icon(attachment.type == 'audio' ? Icons.audiotrack : Icons.picture_as_pdf),
            title: Text(attachment.originalName),
            onTap: () => _openOrPlay(attachment),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(attachment),
            ),
          ),
      ],
    );
  }
}
