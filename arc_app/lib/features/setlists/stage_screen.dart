import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/chordpro/chordpro_parser.dart';
import '../../core/chordpro/transposer.dart';
import '../../core/screen_awake.dart';
import '../../core/theme/arca_tokens.dart';
import '../songs/autoscroll.dart';
import '../songs/song.dart';
import '../songs/song_list_provider.dart';
import '../songs/song_lyrics_view.dart';
import 'setlist.dart';

const _scaleKey = 'stage_text_scale';

/// Text sizes on stage, as multiples of the normal song view.
const _scales = [1.0, 1.15, 1.3, 1.5, 1.75, 2.0, 2.5];
const _defaultScale = 1.3;

/// Modo escenario: the setlist's songs one after another, each in the key
/// chosen for the service, with large text, autoscroll and the screen kept
/// on. Songs change with the arrows, a swipe, or a keyboard or Bluetooth
/// pedal (left/right arrows, Page Up/Down); space starts and pauses the
/// autoscroll.
class StageScreen extends ConsumerStatefulWidget {
  const StageScreen({super.key, required this.setlist, this.initialIndex = 0});

  final Setlist setlist;
  final int initialIndex;

  @override
  ConsumerState<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends ConsumerState<StageScreen> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  double _scale = _defaultScale;
  final _scrollers = <int, AutoScroller>{};
  late final ScreenAwake _awake;

  List<SetlistSong> get _songs => widget.setlist.songs;

  @override
  void initState() {
    super.initState();
    _awake = ref.read(screenAwakeProvider)..keep(true);
    _restoreScale();
  }

  Future<void> _restoreScale() async {
    final stored = (await SharedPreferences.getInstance()).getDouble(_scaleKey);
    if (stored != null && _scales.contains(stored) && mounted) setState(() => _scale = stored);
  }

  @override
  void dispose() {
    _awake.keep(false);
    _pages.dispose();
    super.dispose();
  }

  void _register(int index, AutoScroller? scroller) {
    if (scroller == null) {
      // A page leaving the tree; no rebuild allowed (or needed) here.
      _scrollers.remove(index);
      return;
    }
    if (mounted) setState(() => _scrollers[index] = scroller);
  }

  void _go(int index) {
    if (index < 0 || index >= _songs.length) return;
    _pages.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _changeScale(int step) {
    final next = _scales[(_scales.indexOf(_scale) + step).clamp(0, _scales.length - 1)];
    setState(() => _scale = next);
    SharedPreferences.getInstance().then((p) => p.setDouble(_scaleKey, next));
  }

  void _toggleAutoscroll() {
    final scroller = _scrollers[_index];
    if (scroller == null) return;
    switch (scroller.status) {
      case AutoScrollStatus.off:
        scroller.start();
      case AutoScrollStatus.running:
        scroller.pause();
      case AutoScrollStatus.paused:
        scroller.resume();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.pageDown) {
      _go(_index + 1);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.pageUp) {
      _go(_index - 1);
    } else if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      _toggleAutoscroll();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final current = _songs[_index];
    final text = Theme.of(context).textTheme;
    final scroller = _scrollers[_index];

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Salir del modo escenario',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.songTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge,
                          ),
                          Text(
                            'Tonalidad ${current.key}',
                            style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text('${_index + 1} / ${_songs.length}', style: text.titleMedium),
                    IconButton(
                      tooltip: 'Letra más chica',
                      icon: const Icon(Icons.text_decrease),
                      onPressed: _scale > _scales.first ? () => _changeScale(-1) : null,
                    ),
                    IconButton(
                      tooltip: 'Letra más grande',
                      icon: const Icon(Icons.text_increase),
                      onPressed: _scale < _scales.last ? () => _changeScale(1) : null,
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _songs.length,
                  onPageChanged: (index) {
                    // The song left behind stops scrolling on its own.
                    _scrollers[_index]?.stop();
                    setState(() => _index = index);
                  },
                  itemBuilder: (context, index) => _StagePage(
                    key: ValueKey(_songs[index].id),
                    setlistSong: _songs[index],
                    scale: _scale,
                    onScroller: (scroller) => _register(index, scroller),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Canción anterior',
                      iconSize: 32,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _index > 0 ? () => _go(_index - 1) : null,
                    ),
                    Expanded(
                      child: Center(
                        child: scroller == null ? null : AutoScrollControls(scroller: scroller),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Canción siguiente',
                      iconSize: 32,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _index < _songs.length - 1 ? () => _go(_index + 1) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One song on stage: loads it, shows it transposed to the setlist key,
/// and owns its own scroll and autoscroll.
class _StagePage extends ConsumerStatefulWidget {
  const _StagePage({
    super.key,
    required this.setlistSong,
    required this.scale,
    required this.onScroller,
  });

  final SetlistSong setlistSong;
  final double scale;
  final ValueChanged<AutoScroller?> onScroller;

  @override
  ConsumerState<_StagePage> createState() => _StagePageState();
}

class _StagePageState extends ConsumerState<_StagePage> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AutoScroller _scroller =
      AutoScroller(vsync: this, controller: _scroll, songId: widget.setlistSong.songId);
  late final Future<Song> _song = ref.read(songRepositoryProvider).getOne(widget.setlistSong.songId);

  @override
  void initState() {
    super.initState();
    // The parent rebuilds when told; wait until this frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onScroller(_scroller));
  }

  @override
  void dispose() {
    widget.onScroller(null);
    _scroller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Song>(
      future: _song,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudo cargar la canción.'));
        }
        final song = snapshot.data;
        if (song == null) return const Center(child: CircularProgressIndicator());

        final notes = song.notes?.trim();
        return SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes != null && notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        notes,
                        style: TextStyle(color: context.arca.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  SongLyricsView(
                    document: ChordProParser.parse(song.content),
                    semitones: semitonesBetweenKeys(from: song.originalKey, to: widget.setlistSong.key),
                    scale: widget.scale,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
