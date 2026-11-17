import 'package:arc_app/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('without API_URL the app talks to the local backend', () {
    // A published build passes --dart-define=API_URL=https://.../api.
    expect(ApiClient.baseUrl, 'http://localhost:4200/api');
    expect(const String.fromEnvironment('API_URL'), isEmpty);
  });
}
