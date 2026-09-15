import 'package:dio/dio.dart';

import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage) {
    _dio = Dio(BaseOptions(baseUrl: baseUrl));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
      ),
    );
  }

  static const baseUrl = 'http://localhost:4200/api';

  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Dio get dio => _dio;
}
