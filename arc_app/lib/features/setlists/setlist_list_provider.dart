import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../annexes/active_annex_provider.dart';
import '../auth/auth_provider.dart';
import 'setlist.dart';
import 'setlist_repository.dart';

final setlistRepositoryProvider =
    Provider((ref) => SetlistRepository(ref.watch(apiClientProvider)));

final setlistListProvider =
    AsyncNotifierProvider<SetlistListNotifier, List<Setlist>>(SetlistListNotifier.new);

/// The setlists of the active annex (none without one).
class SetlistListNotifier extends AsyncNotifier<List<Setlist>> {
  @override
  Future<List<Setlist>> build() => _load(ref.watch(activeAnnexProvider)?.id);

  Future<List<Setlist>> _load(int? annexId) async =>
      annexId == null ? [] : ref.read(setlistRepositoryProvider).list(annexId: annexId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(ref.read(activeAnnexProvider)?.id));
  }
}
