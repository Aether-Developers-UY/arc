import 'package:dio/dio.dart';

import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage, {void Function()? onUnauthorized}) {
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
        onError: (error, handler) {
          // A 401 from /login is a wrong password; anywhere else it means
          // the session is no longer valid.
          if (error.response?.statusCode == 401 && error.requestOptions.path != '/login') {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static const baseUrl = 'http://localhost:4200/api';

  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Dio get dio => _dio;
}
