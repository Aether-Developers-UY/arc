/// The blocks of a service, in the order they are played.
enum SetlistSection {
  inicio('inicio', 'Inicio'),
  linea('linea', 'Línea'),
  ofrenda('ofrenda', 'Ofrenda'),
  santaCena('santa_cena', 'Santa cena');

  const SetlistSection(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SetlistSection? fromApi(String? value) =>
      values.where((s) => s.apiValue == value).firstOrNull;
}

class SetlistSong {
  SetlistSong({
    required this.id,
    required this.songId,
    required this.position,
    required this.key,
    required this.songTitle,
    required this.songArtist,
    this.section,
    this.lineName,
  });

  factory SetlistSong.fromJson(Map<String, dynamic> json) => SetlistSong(
        id: json['id'] as int,
        songId: json['song_id'] as int,
        position: json['position'] as int,
        key: json['key'] as String,
        songTitle: (json['song'] as Map<String, dynamic>?)?['title'] as String? ?? '',
        songArtist: (json['song'] as Map<String, dynamic>?)?['artist'] as String?,
        section: SetlistSection.fromApi(json['section'] as String?),
        lineName: (json['line'] as Map<String, dynamic>?)?['name'] as String?,
      );

  final int id;
  final int songId;
  final int position;
  final String key;
  final String songTitle;
  final String? songArtist;

  /// Its block in the service; null for songs added before the blocks.
  final SetlistSection? section;

  /// The line it was brought in with, if any (and the line still exists).
  final String? lineName;
}

class Setlist {
  Setlist({
    required this.id,
    required this.serviceDate,
    required this.name,
    required this.songs,
    this.annexId,
  });

  factory Setlist.fromJson(Map<String, dynamic> json) => Setlist(
        id: json['id'] as int,
        serviceDate: DateTime.parse(json['service_date'] as String),
        name: json['name'] as String?,
        songs: (json['setlist_songs'] as List<dynamic>? ?? [])
            .map((s) => SetlistSong.fromJson(s as Map<String, dynamic>))
            .toList(),
        annexId: json['annex_id'] as int?,
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

  /// The annex it belongs to. Null only in data from before annexes.
  final int? annexId;
}
