/// Turns a downloaded attachment into something the player or the system
/// can open. Mobile and desktop write it to a temp file; the web has no
/// file system, so it gets an in-memory blob URL instead.
library;

export 'attachment_file_io.dart'
    if (dart.library.js_interop) 'attachment_file_web.dart';
