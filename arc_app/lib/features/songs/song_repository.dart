import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import 'song.dart';

class SongRepository {
  SongRepository(this._apiClient);

  final ApiClient _apiClient;
  static const _cacheKey = 'arc_song_list_cache';

  Future<List<Song>> list({String? search}) async {
    try {
      final response = await _apiClient.dio.get('/songs', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      });
      final data = (response.data['data'] as List<dynamic>)
          .map((json) => Song.fromJson(json as Map<String, dynamic>))
          .toList();
      if (search == null || search.isEmpty) {
        await _cacheSongs(data);
      }
      return data;
    } catch (_) {
      if (search == null || search.isEmpty) {
        return _readCachedSongs();
      }
      rethrow;
    }
  }

  Future<Song> create(Song song) async {
    final response = await _apiClient.dio.post('/songs', data: song.toRequestJson());
    return Song.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Song> update(Song song) async {
    final response =
        await _apiClient.dio.put('/songs/${song.id}', data: song.toRequestJson());
    return Song.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int songId) => _apiClient.dio.delete('/songs/$songId');

  Future<Song> getOne(int id) async {
    final response = await _apiClient.dio.get('/songs/$id');
    return Song.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> _cacheSongs(List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = songs.map((s) => s.toRequestJson()..['id'] = s.id).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  Future<List<Song>> _readCachedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((json) => Song.fromJson({...json as Map<String, dynamic>, 'attachments': []}))
        .toList();
  }
}
