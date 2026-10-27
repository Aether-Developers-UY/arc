import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the song library is laid out: rectangular blocks in a grid, or the
/// compact one-per-row list.
enum SongViewMode { grid, list }

const _prefsKey = 'song_list_view';

final songViewModeProvider =
    AsyncNotifierProvider<SongViewModeNotifier, SongViewMode>(SongViewModeNotifier.new);

/// The library layout chosen on this device. Blocks unless the user picked
/// the list; unknown stored values also fall back to blocks.
class SongViewModeNotifier extends AsyncNotifier<SongViewMode> {
  @override
  Future<SongViewMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey) == SongViewMode.list.name
        ? SongViewMode.list
        : SongViewMode.grid;
  }

  Future<void> set(SongViewMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
