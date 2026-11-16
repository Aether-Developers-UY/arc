import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AutoScrollStatus { off, running, paused }

/// Scrolls a song down at a steady pace, for reading it hands-free while
/// playing. Speed is a multiplier of [baseSpeed], remembered per song.
class AutoScroller extends ChangeNotifier {
  AutoScroller({
    required TickerProvider vsync,
    required this.controller,
    required this.songId,
    this.onActiveChanged,
  }) {
    _ticker = vsync.createTicker(_tick);
    _restoreSpeed();
  }

  /// Logical pixels per second at 1×: a slow, readable pace.
  static const baseSpeed = 30.0;
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0];

  final ScrollController controller;
  final int songId;

  /// Called with true when autoscroll turns on and false when it turns
  /// off (stopped, or the screen closed). Pausing keeps it on: the bar is
  /// still up and the musician is still reading.
  final void Function(bool active)? onActiveChanged;
  late final Ticker _ticker;

  AutoScrollStatus _status = AutoScrollStatus.off;
  AutoScrollStatus get status => _status;

  int _speedIndex = speeds.indexOf(1.0);
  double get speed => speeds[_speedIndex];
  bool get canGoFaster => _speedIndex < speeds.length - 1;
  bool get canGoSlower => _speedIndex > 0;

  Duration _last = Duration.zero;

  String get _prefsKey => 'autoscroll_speed_$songId';

  Future<void> _restoreSpeed() async {
    final stored = (await SharedPreferences.getInstance()).getDouble(_prefsKey);
    final index = stored == null ? -1 : speeds.indexOf(stored);
    if (index >= 0 && index != _speedIndex) {
      _speedIndex = index;
      notifyListeners();
    }
  }

  void start() => _run();

  void pause() {
    _ticker.stop();
    _setStatus(AutoScrollStatus.paused);
  }

  /// Carries on; at the very end of the song it starts over from the top.
  void resume() {
    if (controller.hasClients && controller.position.pixels >= controller.position.maxScrollExtent) {
      controller.jumpTo(0);
    }
    _run();
  }

  void stop() {
    _ticker.stop();
    _setStatus(AutoScrollStatus.off);
  }

  void _setStatus(AutoScrollStatus next) {
    final wasActive = _status != AutoScrollStatus.off;
    _status = next;
    final isActive = next != AutoScrollStatus.off;
    if (wasActive != isActive) onActiveChanged?.call(isActive);
    notifyListeners();
  }

  void faster() => _setSpeed(_speedIndex + 1);
  void slower() => _setSpeed(_speedIndex - 1);

  void _setSpeed(int index) {
    _speedIndex = index.clamp(0, speeds.length - 1);
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setDouble(_prefsKey, speed));
  }

  void _run() {
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    _setStatus(AutoScrollStatus.running);
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (!controller.hasClients) return;
    final position = controller.position;
    // While the musician drags or flings the song, let them; the pace
    // picks up again from wherever they leave it.
    if (position.isScrollingNotifier.value) return;

    final next = math.min(position.pixels + baseSpeed * speed * dt, position.maxScrollExtent);
    controller.jumpTo(next);
    if (next >= position.maxScrollExtent) pause();
  }

  @override
  void dispose() {
    if (_status != AutoScrollStatus.off) onActiveChanged?.call(false);
    _ticker.dispose();
    super.dispose();
  }
}

/// The start button, or while scrolling a bar with pause/resume, speed and
/// stop. Meant for the screen's floating action button slot.
class AutoScrollControls extends StatelessWidget {
  const AutoScrollControls({super.key, required this.scroller});

  final AutoScroller scroller;

  static String _label(double speed) =>
      '${speed == speed.roundToDouble() ? speed.toInt() : speed}×';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scroller,
      builder: (context, _) {
        if (scroller.status == AutoScrollStatus.off) {
          return FloatingActionButton(
            // No hero: it can sit on screens that already have one.
            heroTag: null,
            tooltip: 'Desplazamiento automático',
            onPressed: scroller.start,
            child: const Icon(Icons.keyboard_double_arrow_down),
          );
        }

        final running = scroller.status == AutoScrollStatus.running;
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainerHighest,
          elevation: 4,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: running ? 'Pausar' : 'Reanudar',
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  color: scheme.primary,
                  onPressed: running ? scroller.pause : scroller.resume,
                ),
                IconButton(
                  tooltip: 'Más lento',
                  icon: const Icon(Icons.remove),
                  onPressed: scroller.canGoSlower ? scroller.slower : null,
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _label(scroller.speed),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Más rápido',
                  icon: const Icon(Icons.add),
                  onPressed: scroller.canGoFaster ? scroller.faster : null,
                ),
                IconButton(
                  tooltip: 'Detener',
                  icon: const Icon(Icons.close),
                  onPressed: scroller.stop,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
