import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'line.dart';

final lineRepositoryProvider = Provider((ref) => LineRepository(ref.watch(apiClientProvider)));

/// The library of lines, alphabetical.
final lineListProvider = FutureProvider<List<Line>>((ref) => ref.watch(lineRepositoryProvider).list());

class LineRepository {
  LineRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Line>> list() async {
    final response = await _apiClient.dio.get('/lines');
    return (response.data['data'] as List<dynamic>)
        .map((json) => Line.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Line> create({required String name, required List<LineSong> songs}) async {
    final response = await _apiClient.dio.post('/lines', data: _body(name, songs));
    return Line.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Line> update(int id, {required String name, required List<LineSong> songs}) async {
    final response = await _apiClient.dio.put('/lines/$id', data: _body(name, songs));
    return Line.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _apiClient.dio.delete('/lines/$id');

  Map<String, dynamic> _body(String name, List<LineSong> songs) => {
        'name': name,
        'songs': [for (final s in songs) s.toRequestJson()],
      };
}
