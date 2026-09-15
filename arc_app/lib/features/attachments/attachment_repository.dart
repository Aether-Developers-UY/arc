import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

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

  String downloadUrl(int attachmentId) =>
      '${ApiClient.baseUrl}/attachments/$attachmentId/download';
}
