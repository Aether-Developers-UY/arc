import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside Arca (another app or the browser). Returns false
/// when nothing could open it.
typedef OpenExternal = Future<bool> Function(Uri uri);

final openExternalProvider = Provider<OpenExternal>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);
