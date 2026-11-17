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

/// Songs from the library played back to back ("enganchadas").
class Line {
  const Line({required this.id, required this.name, required this.songs});

  factory Line.fromJson(Map<String, dynamic> json) => Line(
        id: json['id'] as int,
        name: json['name'] as String,
        songs: (json['line_songs'] as List<dynamic>? ?? [])
            .map((s) => LineSong.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String name;
  final List<LineSong> songs;
}
