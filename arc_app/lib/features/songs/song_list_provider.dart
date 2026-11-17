import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'song.dart';
import 'song_repository.dart';

final songRepositoryProvider =
    Provider((ref) => SongRepository(ref.watch(apiClientProvider)));

final songListProvider =
    AsyncNotifierProvider<SongListNotifier, List<Song>>(SongListNotifier.new);

class SongListNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() => ref.read(songRepositoryProvider).list();

  /// Counts the requests, so only the answer to the latest one is shown.
  int _latest = 0;

  /// Searches while the current songs stay on screen (no spinner between
  /// keystrokes). An answer that arrives after a newer search is dropped.
  Future<void> search(String query) async {
    final request = ++_latest;
    final result = await AsyncValue.guard(() => ref.read(songRepositoryProvider).list(search: query));
    if (request == _latest) state = result;
  }

  Future<void> refresh() async {
    final request = ++_latest;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(songRepositoryProvider).list());
    if (request == _latest) state = result;
  }
}
