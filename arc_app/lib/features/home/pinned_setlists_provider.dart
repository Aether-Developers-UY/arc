import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many setlists can be pinned to Inicio at once.
const int kMaxPinnedSetlists = 3;

const _prefsKey = 'pinned_setlist_ids';

final pinnedSetlistsProvider =
    AsyncNotifierProvider<PinnedSetlistsNotifier, List<int>>(PinnedSetlistsNotifier.new);

/// The setlist ids pinned to Inicio on this device, in pinning order.
class PinnedSetlistsNotifier extends AsyncNotifier<List<int>> {
  @override
  Future<List<int>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const [];
    // Drop anything unparseable or repeated, and never exceed the cap,
    // so corrupt storage can't break Inicio.
    final ids = <int>[];
    for (final raw in stored) {
      final id = int.tryParse(raw);
      if (id != null && !ids.contains(id)) ids.add(id);
      if (ids.length == kMaxPinnedSetlists) break;
    }
    return ids;
  }

  // Both mutations read `state` after awaiting the initial load, not the
  // awaited value: calls queued in the same turn (two 404s at once) would
  // otherwise all start from the same list and overwrite each other.
  Future<void> pin(int id) async {
    await future;
    final current = state.requireValue;
    if (current.contains(id) || current.length >= kMaxPinnedSetlists) return;
    await _save([...current, id]);
  }

  Future<void> unpin(int id) async {
    await future;
    final current = state.requireValue;
    if (!current.contains(id)) return;
    await _save(current.where((pinned) => pinned != id).toList());
  }

  Future<void> _save(List<int> ids) async {
    state = AsyncData(ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, [for (final id in ids) '$id']);
  }
}
