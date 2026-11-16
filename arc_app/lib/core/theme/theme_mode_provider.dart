import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'theme_mode';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Claro, oscuro, or whatever the device uses (the default). Remembered on
/// this device.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  /// Completes once the stored choice has been read.
  late Future<void> ready;

  @override
  ThemeMode build() {
    ready = _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final stored = (await SharedPreferences.getInstance()).getString(_key);
    final mode = ThemeMode.values.where((m) => m.name == stored).firstOrNull;
    // A choice made while reading wins over the stored one.
    if (mode != null && !_picked) state = mode;
  }

  bool _picked = false;

  Future<void> select(ThemeMode mode) async {
    _picked = true;
    state = mode;
    await (await SharedPreferences.getInstance()).setString(_key, mode.name);
  }
}
