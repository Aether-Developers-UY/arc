class SetlistSong {
  SetlistSong({
    required this.id,
    required this.songId,
    required this.position,
    required this.key,
    required this.songTitle,
    required this.songArtist,
  });

  factory SetlistSong.fromJson(Map<String, dynamic> json) => SetlistSong(
        id: json['id'] as int,
        songId: json['song_id'] as int,
        position: json['position'] as int,
        key: json['key'] as String,
        songTitle: (json['song'] as Map<String, dynamic>?)?['title'] as String? ?? '',
        songArtist: (json['song'] as Map<String, dynamic>?)?['artist'] as String?,
      );

  final int id;
  final int songId;
  final int position;
  final String key;
  final String songTitle;
  final String? songArtist;
}

class Setlist {
  Setlist({
    required this.id,
    required this.serviceDate,
    required this.name,
    required this.songs,
  });

  factory Setlist.fromJson(Map<String, dynamic> json) => Setlist(
        id: json['id'] as int,
        serviceDate: DateTime.parse(json['service_date'] as String),
        name: json['name'] as String?,
        songs: (json['setlist_songs'] as List<dynamic>? ?? [])
            .map((s) => SetlistSong.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toRequestJson() => {
        'service_date':
            '${serviceDate.year.toString().padLeft(4, '0')}-${serviceDate.month.toString().padLeft(2, '0')}-${serviceDate.day.toString().padLeft(2, '0')}',
        'name': name,
      };

  final int id;
  final DateTime serviceDate;
  final String? name;
  final List<SetlistSong> songs;
}
