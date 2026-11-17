import '../songs/song.dart';

/// A song inside a line, in the key the line plays it.
class LineSong {
  const LineSong({
    required this.songId,
    required this.key,
    required this.title,
    this.artist,
    required this.originalKey,
  });

  factory LineSong.fromJson(Map<String, dynamic> json) {
    final song = json['song'] as Map<String, dynamic>? ?? const {};
    return LineSong(
      songId: json['song_id'] as int,
      key: json['key'] as String,
      title: song['title'] as String? ?? '',
      artist: song['artist'] as String?,
      originalKey: song['original_key'] as String? ?? json['key'] as String,
    );
  }

  final int songId;
  final String key;
  final String title;
  final String? artist;
  final String originalKey;

  LineSong withKey(String key) =>
      LineSong(songId: songId, key: key, title: title, artist: artist, originalKey: originalKey);

  Map<String, dynamic> toRequestJson() => {'song_id': songId, 'key': key};
}

/// Songs from the library played back to back ("enganchadas"), in one
/// key; a song keeps a key of its own where the line goes up a step.
class Line {
  const Line({
    required this.id,
    required this.name,
    required this.key,
    required this.songs,
    this.attachments = const [],
  });

  factory Line.fromJson(Map<String, dynamic> json) => Line(
        id: json['id'] as int,
        name: json['name'] as String,
        key: json['key'] as String? ?? 'C',
        songs: (json['line_songs'] as List<dynamic>? ?? [])
            .map((s) => LineSong.fromJson(s as Map<String, dynamic>))
            .toList(),
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String name;
  final String key;
  final List<LineSong> songs;

  /// Files for the whole line (a rehearsal track, the charts).
  final List<Attachment> attachments;

  /// True when some song is not in the line key.
  bool get changesKey => songs.any((s) => s.key != key);
}
