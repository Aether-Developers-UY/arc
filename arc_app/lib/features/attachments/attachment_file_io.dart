import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../songs/song.dart';

/// Writes the attachment to a temp file and returns its `file://` URI.
Future<Uri> localUriFor(Attachment attachment, Uint8List bytes) async {
  final tempDir = await getTemporaryDirectory();
  final file = File(
    '${tempDir.path}/attachment_${attachment.id}_${attachment.originalName}',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.uri;
}
