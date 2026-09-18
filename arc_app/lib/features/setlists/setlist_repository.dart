import '../../core/api_client.dart';
import 'setlist.dart';

class SetlistRepository {
  SetlistRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Setlist>> list() async {
    final response = await _apiClient.dio.get('/setlists');
    return (response.data['data'] as List<dynamic>)
        .map((json) => Setlist.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Setlist> getOne(int id) async {
    final response = await _apiClient.dio.get('/setlists/$id');
    return Setlist.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Setlist> create(Setlist setlist) async {
    final response = await _apiClient.dio.post('/setlists', data: setlist.toRequestJson());
    return Setlist.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Setlist> update(Setlist setlist) async {
    final response =
        await _apiClient.dio.put('/setlists/${setlist.id}', data: setlist.toRequestJson());
    return Setlist.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _apiClient.dio.delete('/setlists/$id');

  Future<SetlistSong> addSong({required int setlistId, required int songId, String? key}) async {
    final response = await _apiClient.dio.post('/setlists/$setlistId/songs', data: {
      'song_id': songId,
      if (key != null) 'key': key,
    });
    return SetlistSong.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> updateSongKey({
    required int setlistId,
    required int setlistSongId,
    required String key,
  }) async {
    await _apiClient.dio.put('/setlists/$setlistId/songs/$setlistSongId', data: {'key': key});
  }

  Future<void> removeSong({required int setlistId, required int setlistSongId}) =>
      _apiClient.dio.delete('/setlists/$setlistId/songs/$setlistSongId');

  Future<void> reorder({required int setlistId, required List<int> setlistSongIds}) =>
      _apiClient.dio.put('/setlists/$setlistId/reorder', data: {
        'setlist_song_ids': setlistSongIds,
      });
}
