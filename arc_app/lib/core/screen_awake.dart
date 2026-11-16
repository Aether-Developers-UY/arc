import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device screen from turning off, e.g. while a song scrolls by
/// itself during a service.
abstract class ScreenAwake {
  Future<void> keep(bool on);
}

class WakelockScreenAwake implements ScreenAwake {
  @override
  Future<void> keep(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {
      // Not supported here (an old browser, a desktop): the screen just
      // follows its usual timeout. Nothing to tell the user.
    }
  }
}

final screenAwakeProvider = Provider<ScreenAwake>((ref) => WakelockScreenAwake());
