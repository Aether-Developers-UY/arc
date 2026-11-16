/// A congregation of the church. Each setlist belongs to one.
class Annex {
  Annex({required this.id, required this.name, this.isMember = true});

  /// `is_member` only comes from `GET /annexes`; the annexes listed in the
  /// profile (`/me`) are the user's own.
  factory Annex.fromJson(Map<String, dynamic> json) => Annex(
        id: json['id'] as int,
        name: json['name'] as String,
        isMember: json['is_member'] as bool? ?? true,
      );

  final int id;
  final String name;
  final bool isMember;

  @override
  bool operator ==(Object other) => other is Annex && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
