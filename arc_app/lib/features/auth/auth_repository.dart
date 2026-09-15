import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';

class AuthUser {
  AuthUser({required this.id, required this.name, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final int id;
  final String name;
  final String email;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthUser> login({required String email, required String password}) async {
    try {
      final response = await _apiClient.dio.post('/login', data: {
        'email': email,
        'password': password,
      });
      final token = response.data['token'] as String;
      await _tokenStorage.write(token);
      return AuthUser.fromJson(response.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw AuthException('El email o la contraseña no son correctos.');
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
