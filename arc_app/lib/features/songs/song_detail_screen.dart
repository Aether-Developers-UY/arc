import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chordpro/chordpro_parser.dart';
import '../../core/chordpro/transposer.dart';
import '../attachments/attachment_list.dart';
import 'song.dart';
import 'song_editor_screen.dart';
import 'song_list_provider.dart';

class SongDetailScreen extends ConsumerStatefulWidget {
  const SongDetailScreen({super.key, required this.song});

  final Song song;

  @override
  ConsumerState<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends ConsumerState<SongDetailScreen> {
  late Song _song = widget.song;
  late String _currentKey = _song.originalKey;
  static const _availableKeys = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  @override
  Widget build(BuildContext context) {
    final document = ChordProParser.parse(_song.content);
    final semitones =
        semitonesBetweenKeys(from: _song.originalKey, to: _currentKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(_song.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SongEditorScreen(existingSong: _song)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Tonalidad:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _currentKey,
                  items: _availableKeys
                      .map((key) => DropdownMenuItem(value: key, child: Text(key)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _currentKey = value);
                  },
                ),
                if (_currentKey != _song.originalKey) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => setState(() => _currentKey = _song.originalKey),
                    child: const Text('Restablecer'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: document.lines.length,
              itemBuilder: (context, index) {
                final line = document.lines[index];
                if (line.sectionLabel != null && line.segments.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      line.sectionLabel!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  );
                }
                if (line.segments.isEmpty) {
                  return const SizedBox(height: 16);
                }
                return _ChordLine(segments: line.segments, semitones: semitones);
              },
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AttachmentList(
                song: _song,
                onChanged: () async {
                  final repository = ref.read(songRepositoryProvider);
                  final refreshed = await repository.getOne(_song.id);
                  setState(() => _song = refreshed);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChordLine extends StatelessWidget {
  const _ChordLine({required this.segments, required this.semitones});

  final List<ChordProSegment> segments;
  final int semitones;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: segments.map((segment) {
          final transposed = segment.chord == null
              ? null
              : transposeChord(segment.chord!, semitones: semitones);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transposed ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(segment.text.isEmpty ? ' ' : segment.text),
            ],
          );
        }).toList(),
      ),
    );
  }
}
