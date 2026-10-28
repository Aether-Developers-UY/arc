import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a library screen lays out its items: rectangular blocks in a grid,
/// or the compact one-per-row list.
enum ViewMode { grid, list }

/// The layout chosen on this device for the screen stored under the given
/// SharedPreferences key. Blocks unless the user picked the list; unknown
/// stored values also fall back to blocks.
final viewModeProvider =
    AsyncNotifierProvider.family<ViewModeNotifier, ViewMode, String>(ViewModeNotifier.new);

class ViewModeNotifier extends AsyncNotifier<ViewMode> {
  ViewModeNotifier(this.prefsKey);

  final String prefsKey;

  @override
  Future<ViewMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsKey) == ViewMode.list.name ? ViewMode.list : ViewMode.grid;
  }

  Future<void> set(ViewMode mode) async {
    state = AsyncData(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, mode.name);
  }
}
