import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../annexes/active_annex_provider.dart';

/// How many setlists each annex can pin to Inicio at once.
const int kMaxPinnedSetlists = 3;

/// Before annexes, pins were one list per device.
const _legacyPrefsKey = 'pinned_setlist_ids';

String _prefsKey(int annexId) => 'pinned_setlist_ids_$annexId';

final pinnedSetlistsProvider =
    AsyncNotifierProvider<PinnedSetlistsNotifier, List<int>>(PinnedSetlistsNotifier.new);

/// The setlist ids pinned to Inicio on this device for the active annex,
/// in pinning order. Each annex keeps its own pins.
class PinnedSetlistsNotifier extends AsyncNotifier<List<int>> {
  int? _annexId;

  @override
  Future<List<int>> build() async {
    _annexId = ref.watch(activeAnnexProvider)?.id;
    final annexId = _annexId;
    if (annexId == null) return const [];

    final prefs = await SharedPreferences.getInstance();
    // The pins from before annexes go to the first annex that loads, which
    // is "Anexo principal", where every existing setlist went.
    final legacy = prefs.getStringList(_legacyPrefsKey);
    if (legacy != null && !prefs.containsKey(_prefsKey(annexId))) {
      await prefs.setStringList(_prefsKey(annexId), legacy);
      await prefs.remove(_legacyPrefsKey);
    }
    final stored = prefs.getStringList(_prefsKey(annexId)) ?? const [];
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
    final annexId = _annexId;
    if (annexId == null) return;
    state = AsyncData(ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(annexId), [for (final id in ids) '$id']);
  }
}
