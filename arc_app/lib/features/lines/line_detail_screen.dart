import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chordpro/chordpro_parser.dart';
import '../../core/chordpro/transposer.dart';
import '../../core/theme/arca_tokens.dart';
import '../../core/widgets/key_badge.dart';
import '../attachments/attachment_list.dart';
import '../setlists/setlist.dart';
import '../setlists/stage_screen.dart';
import '../songs/song.dart';
import '../songs/song_list_provider.dart';
import '../songs/song_lyrics_view.dart';
import 'line.dart';
import 'line_editor_screen.dart';
import 'line_repository.dart';

/// Shows a line: its songs one after another, each in the key the line
/// plays it, switched by tapping a name or swiping. The last tab holds the
/// line's files. From here the line is edited or played on stage.
class LineDetailScreen extends ConsumerStatefulWidget {
  const LineDetailScreen({super.key, required this.line});

  final Line line;

  @override
  ConsumerState<LineDetailScreen> createState() => _LineDetailScreenState();
}

class _LineDetailScreenState extends ConsumerState<LineDetailScreen> {
  late Line _line = widget.line;
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final line = await ref.read(lineRepositoryProvider).getOne(_line.id);
      if (!mounted) return;
      setState(() {
        _line = line;
        // The songs may be fewer now; stay on a page that exists.
        _index = _index.clamp(0, line.songs.length);
      });
      if (_pages.hasClients) _pages.jumpToPage(_index);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la línea.')),
      );
    }
  }

  Future<void> _edit() async {
    final change = await Navigator.of(context).push<LineChange>(
      MaterialPageRoute(builder: (_) => LineEditorScreen(line: _line)),
    );
    if (!mounted || change == null) return;
    if (change == LineChange.deleted) {
      Navigator.of(context).pop();
    } else {
      await _reload();
    }
  }

  void _go(int index) {
    setState(() => _index = index);
    _pages.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  /// The line as a one-block setlist, so the stage plays it as it plays
  /// any service.
  void _openStage() {
    final setlist = Setlist(
      id: 0,
      serviceDate: DateTime.now(),
      name: _line.name,
      songs: [
        for (final (i, s) in _line.songs.indexed)
          SetlistSong(
            id: i + 1,
            songId: s.songId,
            position: i,
            key: s.key,
            songTitle: s.title,
            songArtist: s.artist,
            section: SetlistSection.linea,
            lineName: _line.name,
          ),
      ],
    );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StageScreen(setlist: setlist)));
  }

  @override
  Widget build(BuildContext context) {
    final line = _line;
    final text = Theme.of(context).textTheme;
    final tabs = [
      for (final (i, s) in line.songs.indexed) '${i + 1}. ${s.title}',
      'Archivos (${line.attachments.length})',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(line.name),
        actions: [
          IconButton(
            tooltip: 'Editar línea',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Tonalidad de la línea',
                        style: text.bodyMedium?.copyWith(color: context.arca.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    KeyBadge(line.key),
                  ],
                ),
                if (line.songs.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _openStage,
                    icon: const Icon(Icons.slideshow_outlined),
                    label: const Text('Modo escenario'),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Center(
                child: ChoiceChip(
                  label: Text(tabs[i]),
                  selected: i == _index,
                  onSelected: (_) => _go(i),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                for (final s in line.songs) _LineSongPage(key: ValueKey(s), lineKey: line.key, lineSong: s),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: AttachmentList(
                        attachments: line.attachments,
                        owner: 'lines/${line.id}',
                        onChanged: _reload,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One song of the line, in the key the line plays it.
class _LineSongPage extends ConsumerStatefulWidget {
  const _LineSongPage({super.key, required this.lineKey, required this.lineSong});

  final String lineKey;
  final LineSong lineSong;

  @override
  ConsumerState<_LineSongPage> createState() => _LineSongPageState();
}

class _LineSongPageState extends ConsumerState<_LineSongPage> with AutomaticKeepAliveClientMixin {
  late final Future<Song> _song = ref.read(songRepositoryProvider).getOne(widget.lineSong.songId);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = widget.lineSong;
    final text = Theme.of(context).textTheme;
    return FutureBuilder<Song>(
      future: _song,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('No se pudo cargar la canción.'));
        final song = snapshot.data;
        if (song == null) return const Center(child: CircularProgressIndicator());
        final notes = song.notes?.trim();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: text.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    [if (s.key != widget.lineKey) 'Cambio de tono', 'Tonalidad ${s.key}'].join(' · '),
                    style: text.bodyMedium?.copyWith(
                      color: s.key != widget.lineKey
                          ? Theme.of(context).colorScheme.primary
                          : context.arca.textSecondary,
                      fontWeight: s.key != widget.lineKey ? FontWeight.w600 : null,
                    ),
                  ),
                  if (notes != null && notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        notes,
                        style: TextStyle(color: context.arca.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SongLyricsView(
                    document: ChordProParser.parse(song.content),
                    semitones: semitonesBetweenKeys(from: song.originalKey, to: s.key),
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
