import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/api_client.dart';
import '../songs/song.dart';
import 'attachment_file.dart';

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
  /// `/download` route requires a Sanctum token) and returns a local URI for
  /// it: a temp file on mobile/desktop, a blob URL on the web. A bare
  /// download URL can't be handed directly to `audioplayers`/`url_launcher`
  /// since neither attaches the Authorization header the backend requires.
  Future<Uri> downloadToLocalUri(Attachment attachment) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/attachments/${attachment.id}/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return localUriFor(attachment, Uint8List.fromList(response.data!));
  }
}
