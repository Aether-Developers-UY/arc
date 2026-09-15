import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api_client.dart';
import '../songs/song.dart';

class AttachmentRepository {
  AttachmentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Attachment> upload({
    required int songId,
    required PlatformFile file,
    required String type,
  }) async {
    // file_picker v13's PlatformFile exposes an XFile (`xFile`) and an
    // async `readAsBytes()` rather than a synchronous `.bytes`/`.path`
    // pair, so reading bytes is the one approach that works uniformly
    // across web, mobile, and desktop.
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'type': type,
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });

    final response =
        await _apiClient.dio.post('/songs/$songId/attachments', data: formData);
    return Attachment.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int attachmentId) =>
      _apiClient.dio.delete('/attachments/$attachmentId');

  /// Downloads an attachment through the authenticated [Dio] client (the
  /// `/download` route requires a Sanctum token) and saves it to a local
  /// temp file, returning its path. A bare download URL can't be handed
  /// directly to `audioplayers`/`url_launcher` since neither attaches the
  /// Authorization header the backend requires.
  Future<String> downloadToTempFile(Attachment attachment) async {
    final tempDir = await getTemporaryDirectory();
    final localPath = '${tempDir.path}/attachment_${attachment.id}_${attachment.originalName}';

    await _apiClient.dio.download(
      '/attachments/${attachment.id}/download',
      localPath,
    );

    return localPath;
  }
}
