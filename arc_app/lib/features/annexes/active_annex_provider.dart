import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart';
import 'annex.dart';

const _prefsKey = 'active_annex_id';

/// The annex chosen last on this device, as stored.
final _storedAnnexIdProvider = FutureProvider<int?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_prefsKey);
});

final activeAnnexProvider = NotifierProvider<ActiveAnnexNotifier, Annex?>(ActiveAnnexNotifier.new);

/// The annex the app is showing: setlists, pins and new setlists all go
/// through it. It is the stored choice while it is still one of the user's
/// annexes, otherwise their first one, or null when they have none.
class ActiveAnnexNotifier extends Notifier<Annex?> {
  @override
  Annex? build() {
    final annexes = ref.watch(authProvider.select((s) => s.user?.annexes ?? const <Annex>[]));
    final storedId = ref.watch(_storedAnnexIdProvider).value;
    if (annexes.isEmpty) return null;
    return annexes.firstWhere((a) => a.id == storedId, orElse: () => annexes.first);
  }

  /// Completes once the stored choice has been read.
  Future<void> get ready => ref.read(_storedAnnexIdProvider.future);

  Future<void> select(Annex annex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, annex.id);
    ref.invalidate(_storedAnnexIdProvider);
    await ref.read(_storedAnnexIdProvider.future);
  }
}
