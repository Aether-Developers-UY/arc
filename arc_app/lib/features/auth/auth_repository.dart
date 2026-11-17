import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';
import '../annexes/annex.dart';

class AuthUser {
  AuthUser({
    required this.id,
    required this.name,
    required this.username,
    this.role = 'standard',
    this.annexes = const [],
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        name: json['name'] as String,
        username: json['username'] as String,
        role: json['role'] as String? ?? 'standard',
        annexes: (json['annexes'] as List<dynamic>? ?? [])
            .map((a) => Annex.fromJson(a as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String name;
  final String username;
  final String role;

  /// The annexes the user belongs to, by id.
  final List<Annex> annexes;

  bool get isAdmin => role == 'admin';
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthUser> login({required String username, required String password}) async {
    try {
      final response = await _apiClient.dio.post('/login', data: {
        'username': username,
        'password': password,
      });
      final token = response.data['token'] as String;
      await _tokenStorage.write(token);
      return AuthUser.fromJson(response.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw AuthException('Usuario o contraseña incorrectos.');
      }
      throw AuthException('No se pudo conectar con el servidor.');
    } on TypeError {
      throw AuthException('Respuesta inesperada del servidor.');
    }
  }

  /// Validates the stored token against the backend and returns the current
  /// user, or throws [AuthException] if the token is missing/invalid/expired.
  Future<AuthUser> currentUser() async {
    try {
      final response = await _apiClient.dio.get('/me');
      return AuthUser.fromJson(response.data['user'] as Map<String, dynamic>);
    } on DioException {
      throw AuthException('La sesión no es válida.');
    } on TypeError {
      throw AuthException('Respuesta inesperada del servidor.');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/logout');
    } on DioException {
      // Ignore network errors on logout — clear the local token regardless.
    }
    await _tokenStorage.clear();
  }

  Future<bool> hasStoredToken() async => (await _tokenStorage.read()) != null;
}
