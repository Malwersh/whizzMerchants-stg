import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../lib/services/token_refresh_service.dart';
String token(int seconds, String use) => '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + seconds, 'token_use': use, 'sub': 'merchant'})))}.signature';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('valid identity is retained without requiring a new login', () async {
    final id = token(3600, 'id');
    FlutterSecureStorage.setMockInitialValues({'secure_id_token': id});
    expect(await TokenRefreshService.getValidIdToken(), id);
  });
  test('expired identity is never returned when access remains valid', () async {
    FlutterSecureStorage.setMockInitialValues({'secure_id_token': token(-60, 'id'), 'secure_access_token': token(3600, 'access')});
    expect(await TokenRefreshService.getValidIdToken(), isNull);
  });
  test('legacy access fallback requires an absent identity and a valid access token', () async {
    final access = token(3600, 'access');
    FlutterSecureStorage.setMockInitialValues({'secure_access_token': access});
    expect(await TokenRefreshService.getValidIdToken(), access);
    FlutterSecureStorage.setMockInitialValues({'secure_access_token': token(-60, 'access')});
    expect(await TokenRefreshService.getValidIdToken(), isNull);
  });
}
