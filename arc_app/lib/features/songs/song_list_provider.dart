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

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(songRepositoryProvider).list(search: query));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(songRepositoryProvider).list());
  }
}
