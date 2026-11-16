import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_provider.dart';
import 'annex.dart';

final annexRepositoryProvider = Provider((ref) => AnnexRepository(ref.watch(apiClientProvider)));

class AnnexRepository {
  AnnexRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Every annex of the church, each with whether the user belongs to it.
  Future<List<Annex>> list() async {
    final response = await _apiClient.dio.get('/annexes');
    return (response.data['data'] as List<dynamic>)
        .map((json) => Annex.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> join(int id) => _apiClient.dio.post('/annexes/$id/join');

  Future<void> leave(int id) => _apiClient.dio.delete('/annexes/$id/join');
}
