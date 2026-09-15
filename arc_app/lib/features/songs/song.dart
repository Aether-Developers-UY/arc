class Attachment {
  Attachment({
    required this.id,
    required this.type,
    required this.originalName,
    required this.filePath,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as int,
        type: json['type'] as String,
        originalName: json['original_name'] as String,
        filePath: json['file_path'] as String,
      );

  final int id;
  final String type; // audio | pdf | other
  final String originalName;
  final String filePath;
}

class Song {
  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.originalKey,
    required this.tempo,
    required this.timeSignature,
    required this.content,
    required this.notes,
    required this.attachments,
  });

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as int,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        originalKey: json['original_key'] as String,
        tempo: json['tempo'] as int?,
        timeSignature: json['time_signature'] as String?,
        content: json['content'] as String,
        notes: json['notes'] as String?,
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toRequestJson() => {
        'title': title,
        'artist': artist,
        'original_key': originalKey,
        'tempo': tempo,
        'time_signature': timeSignature,
        'content': content,
        'notes': notes,
      };

  final int id;
  final String title;
  final String? artist;
  final String originalKey;
  final int? tempo;
  final String? timeSignature;
  final String content;
  final String? notes;
  final List<Attachment> attachments;
}
