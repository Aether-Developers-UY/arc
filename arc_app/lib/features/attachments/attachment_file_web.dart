import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../songs/song.dart';
import 'attachment_types.dart';

/// Wraps the attachment in a blob and returns its `blob:` URL, typed so the
/// browser plays the audio or shows the PDF in its own viewer.
Future<Uri> localUriFor(Attachment attachment, Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeTypeFor(attachment.originalName)),
  );
  return Uri.parse(web.URL.createObjectURL(blob));
}
