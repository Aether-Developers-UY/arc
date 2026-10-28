import 'package:arc_app/features/setlists/setlist.dart';
import 'package:arc_app/features/setlists/setlist_repository.dart';
import 'package:dio/dio.dart';

/// A setlist repository backed by an in-memory map. `getOne` throws
/// whatever is in [errors] for an id, so tests can simulate 404s and
/// network failures.
class FakeSetlistRepository implements SetlistRepository {
  FakeSetlistRepository(List<Setlist> setlists)
      : setlists = {for (final s in setlists) s.id: s};

  final Map<int, Setlist> setlists;
  final Map<int, Object> errors = {};
  final Map<int, int> getOneCalls = {};

  @override
  Future<List<Setlist>> list() async => setlists.values.toList();

  @override
  Future<Setlist> getOne(int id) async {
    getOneCalls[id] = (getOneCalls[id] ?? 0) + 1;
    final error = errors[id];
    if (error != null) throw error;
    final setlist = setlists[id];
    if (setlist == null) throw httpError(404);
    return setlist;
  }

  final List<int> deleted = [];
  bool failDelete = false;

  @override
  Future<void> delete(int id) async {
    if (failDelete) throw networkError();
    deleted.add(id);
    setlists.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException httpError(int status) {
  final options = RequestOptions(path: '/setlists');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status),
    type: DioExceptionType.badResponse,
  );
}

DioException networkError() => DioException(
      requestOptions: RequestOptions(path: '/setlists'),
      type: DioExceptionType.connectionError,
    );

Setlist sampleSetlist({
  int id = 1,
  String? name = 'Culto de mañana',
  DateTime? date,
  List<(String, String)> songs = const [
    ('Sublime Gracia', 'G'),
    ('Cuán Grande Es Él', 'D'),
    ('Santo Espíritu', 'A'),
    ('Digno', 'E'),
    ('Poderoso', 'C'),
  ],
}) =>
    Setlist(
      id: id,
      serviceDate: date ?? DateTime(2026, 11, 1),
      name: name,
      songs: [
        for (var i = 0; i < songs.length; i++)
          SetlistSong(
            id: id * 100 + i,
            songId: i + 1,
            position: i,
            key: songs[i].$2,
            songTitle: songs[i].$1,
            songArtist: null,
          ),
      ],
    );
