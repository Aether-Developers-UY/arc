import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_provider.dart';

final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(apiClientProvider)));

class AdminUser {
  AdminUser({required this.id, required this.name, required this.username, required this.role});

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as int,
        name: json['name'] as String,
        username: json['username'] as String,
        role: json['role'] as String,
      );

  final int id;
  final String name;
  final String username;
  final String role;

  bool get isAdmin => role == 'admin';
}

/// A request the server refused, with its message ready to show.
class AdminException implements Exception {
  AdminException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Users and annexes management. Only admins can call these endpoints.
class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Future<List<AdminUser>> users() => _guard(() async {
        final response = await _dio.get('/users');
        return (response.data['data'] as List<dynamic>)
            .map((json) => AdminUser.fromJson(json as Map<String, dynamic>))
            .toList();
      });

  Future<void> createUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) =>
      _guard(() => _dio.post('/users', data: {
            'name': name,
            'username': username,
            'password': password,
            'role': role,
          }));

  /// Only the given fields change. Sending [password] ends that user's
  /// sessions.
  Future<void> updateUser(int id, {String? name, String? username, String? role, String? password}) =>
      _guard(() => _dio.put('/users/$id', data: {
            'name': ?name,
            'username': ?username,
            'role': ?role,
            'password': ?password,
          }));

  Future<void> deleteUser(int id) => _guard(() => _dio.delete('/users/$id'));

  Future<void> createAnnex(String name) => _guard(() => _dio.post('/annexes', data: {'name': name}));

  Future<void> renameAnnex(int id, String name) =>
      _guard(() => _dio.put('/annexes/$id', data: {'name': name}));

  Future<void> deleteAnnex(int id) => _guard(() => _dio.delete('/annexes/$id'));

  /// Turns a refused request into an [AdminException] with the server's
  /// own message (the first validation error, or `message`).
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) throw AdminException(first.first.toString());
        }
        if (e.response?.statusCode == 422 && data['message'] is String) {
          throw AdminException(data['message'] as String);
        }
      }
      throw AdminException('No se pudo completar. Verificá tu conexión e intentá de nuevo.');
    }
  }
}
