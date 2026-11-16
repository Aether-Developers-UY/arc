import 'dart:convert';
import 'dart:typed_data';

import 'package:arc_app/core/api_client.dart';
import 'package:arc_app/core/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoToken extends TokenStorage {
  _NoToken() : super(const FlutterSecureStorage());

  @override
  Future<String?> read() async => null;
}

/// Answers every request with [status].
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(jsonEncode({'message': 'x'}), status, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a 401 logs the user out', () async {
    var calls = 0;
    final client = ApiClient(_NoToken(), onUnauthorized: () => calls++);
    client.dio.httpClientAdapter = _StatusAdapter(401);

    await expectLater(client.dio.get('/me'), throwsA(isA<DioException>()));
    expect(calls, 1);

    await expectLater(client.dio.post('/login'), throwsA(isA<DioException>()));
    expect(calls, 1, reason: 'a wrong password is not an expired session');
  });

  test('other errors do not log out', () async {
    var calls = 0;
    final client = ApiClient(_NoToken(), onUnauthorized: () => calls++);
    client.dio.httpClientAdapter = _StatusAdapter(404);

    await expectLater(client.dio.get('/setlists/1'), throwsA(isA<DioException>()));
    expect(calls, 0);
  });
}
