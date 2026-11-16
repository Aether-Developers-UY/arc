/// The files a song can carry. Must match the server's `mimes` rule in
/// StoreAttachmentRequest. An .mp4 is played as audio (the app has no
/// video player), like an .m4a.
const attachmentExtensions = ['mp3', 'wav', 'm4a', 'mp4', 'pdf'];

/// The server's `type` for a file extension: `pdf` or `audio`.
String attachmentTypeFor(String? extension) => extension?.toLowerCase() == 'pdf' ? 'pdf' : 'audio';

/// The MIME type the browser needs to play or show the file.
String mimeTypeFor(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => 'application/pdf',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' || 'mp4' => 'audio/mp4',
    _ => 'application/octet-stream',
  };
}
