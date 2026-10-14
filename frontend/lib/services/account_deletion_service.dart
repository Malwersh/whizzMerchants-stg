import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'token_refresh_service.dart';
import 'secure_token_storage.dart';
import '../utils/token_validator.dart';

class AccountDeletionService {
  AccountDeletionService({required this.scope, this.businessId, http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void close() => _client.close();
  final String scope;
  final String? businessId;
  static const _base = 'https://77j15qyukg.execute-api.us-east-1.amazonaws.com/staging';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accountName: 'merchant_account_deletion'),
    aOptions: AndroidOptions(sharedPreferencesName: 'merchant_account_deletion'),
  );
  static Future<bool> hasSavedAccountReceipt() async =>
      await _storage.read(key: 'ACCOUNT:account') != null;

  String get _receiptKey => '$scope:${businessId ?? 'account'}';
  Future<Map<String, dynamic>> call(String path, {Map<String, dynamic>? body, bool followReceipt = false}) async {
    var token = await SecureTokenStorage.getAccessToken();
    if (token != null && TokenValidator.isTokenExpired(token)) {
      final refreshed = await TokenRefreshService.refreshTokens();
      token = refreshed?['accessToken'];
    }
    String? owner;
    if (token != null) {
      owner = (jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1])))) as Map)['sub'] as String?;
    }
    final uri = Uri.parse('$_base/deletion/$path').replace(queryParameters: {
      'scope': scope, if (businessId != null) 'businessId': businessId!,
    });
    http.Response response;
    if (body == null) {
      response = await _client.get(uri, headers: {if (token != null) 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
    } else {
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      response = await _client.post(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({...body, 'scope': {'kind': scope, if (businessId != null) 'businessId': businessId}})).timeout(const Duration(seconds: 30));
    }
    if (path == 'status' && (response.statusCode == 401 ||
        (followReceipt && response.statusCode == 200 && (jsonDecode(response.body) as Map)['request'] == null))) {
      final saved = await _storage.read(key: _receiptKey);
      if (saved == null) throw Exception('يرجى تسجيل الدخول');
      final receipt = jsonDecode(saved) as Map;
      if (owner != null && receipt['ownerId'] != owner) throw Exception('يرجى تسجيل الدخول');
      response = await _client.post(Uri.parse('$_base/deletion/receipt'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'receiptToken': receipt['token']})).timeout(const Duration(seconds: 30));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) throw Exception(data['message'] ?? 'تعذر إكمال العملية؛ حدّث حالة الطلب');
    if (data['receiptToken'] is String) await _storage.write(key: _receiptKey, value: jsonEncode({'ownerId': owner, 'token': data['receiptToken']}));
    return data;
  }
}
