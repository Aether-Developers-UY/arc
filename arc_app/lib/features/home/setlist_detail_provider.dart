import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../setlists/setlist.dart';
import '../setlists/setlist_list_provider.dart';

/// A setlist with its songs, for the blocks pinned to Inicio. The list
/// endpoint doesn't include songs, so each block fetches its own detail.
/// Automatic retries are disabled: a failed block shows "Reintentar"
/// instead, and a 404 must surface right away so the pin is dropped.
final setlistDetailProvider = FutureProvider.autoDispose.family<Setlist, int>(
  (ref, id) => ref.read(setlistRepositoryProvider).getOne(id),
  retry: (retryCount, error) => null,
);
