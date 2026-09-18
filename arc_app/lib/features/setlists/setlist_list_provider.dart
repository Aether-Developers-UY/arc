import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'setlist.dart';
import 'setlist_repository.dart';

final setlistRepositoryProvider =
    Provider((ref) => SetlistRepository(ref.watch(apiClientProvider)));

final setlistListProvider =
    AsyncNotifierProvider<SetlistListNotifier, List<Setlist>>(SetlistListNotifier.new);

class SetlistListNotifier extends AsyncNotifier<List<Setlist>> {
  @override
  Future<List<Setlist>> build() => ref.read(setlistRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(setlistRepositoryProvider).list());
  }
}
