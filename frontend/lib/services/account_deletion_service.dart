import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'token_refresh_service.dart';
import 'secure_token_storage.dart';
import '../utils/token_validator.dart';
import '../config/app_config.dart';
import '../config/merchant_auth_routes.dart';

class AccountDeletionService {
  AccountDeletionService(
      {required this.scope, this.businessId, http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;
  void close() => _client.close();
  final String scope;
  final String? businessId;
  static const _stagingBase =
      'https://77j15qyukg.execute-api.us-east-1.amazonaws.com/staging';

  static Uri endpoint({
    required String environment,
    required String productionBase,
    required String operation,
  }) {
    if (!const {'status', 'eligibility', 'send', 'request', 'receipt'}
        .contains(operation)) {
      throw ArgumentError.value(operation, 'operation');
    }
    if (environment == 'staging') {
      return Uri.parse('$_stagingBase/deletion/$operation');
    }
    if (environment != 'production' || productionBase.isEmpty) {
      throw StateError('خدمة حذف الحساب غير متاحة في هذه البيئة حاليًا.');
    }
    MerchantAuthRoutes.validateProductionEndpoint(productionBase);
    final uri = Uri.parse(productionBase);
    if (uri.path != '/production' ||
        uri.hasPort ||
        !RegExp(r'^[a-z0-9]+\.execute-api\.us-east-1\.amazonaws\.com$')
            .hasMatch(uri.host)) {
      throw StateError('عنوان خدمة حذف الحساب في الإنتاج غير صالح.');
    }
    return uri.replace(path: '/production/deletion/$operation');
  }

  Uri _endpoint(String operation) => endpoint(
        environment: AppConfig.environment,
        productionBase: AppConfig.accountDeletionProductionUrl,
        operation: operation,
      );
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accountName: 'merchant_account_deletion'),
    aOptions:
        AndroidOptions(sharedPreferencesName: 'merchant_account_deletion'),
  );
  static String _storageKey(String scope, String id) =>
      AppConfig.isProduction ? 'production:$scope:$id' : '$scope:$id';

  static Future<bool> hasSavedAccountReceipt() async =>
      await _storage.read(key: _storageKey('ACCOUNT', 'account')) != null;

  String get _receiptKey => _storageKey(scope, businessId ?? 'account');
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool followReceipt = false}) async {
    final uri = _endpoint(path).replace(queryParameters: {
      'scope': scope,
      if (businessId != null) 'businessId': businessId!,
    });
    var token = await SecureTokenStorage.getAccessToken();
    if (token != null && TokenValidator.isTokenExpired(token)) {
      final refreshed = await TokenRefreshService.refreshTokens();
      token = refreshed?['accessToken'];
    }
    String? owner;
    if (token != null) {
      owner = (jsonDecode(utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.')[1]))))
          as Map)['sub'] as String?;
    }
    http.Response response;
    if (body == null) {
      response = await _client.get(uri, headers: {
        if (token != null) 'Authorization': 'Bearer $token'
      }).timeout(const Duration(seconds: 30));
    } else {
      if (token == null) throw Exception('يرجى تسجيل الدخول');
      response = await _client
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token'
              },
              body: jsonEncode({
                ...body,
                'scope': {
                  'kind': scope,
                  if (businessId != null) 'businessId': businessId
                }
              }))
          .timeout(const Duration(seconds: 30));
    }
    if (path == 'status' &&
        (response.statusCode == 401 ||
            (followReceipt &&
                response.statusCode == 200 &&
                (jsonDecode(utf8.decode(response.bodyBytes))
                        as Map)['request'] ==
                    null))) {
      final saved = await _storage.read(key: _receiptKey);
      if (saved == null) throw Exception('يرجى تسجيل الدخول');
      final receipt = jsonDecode(saved) as Map;
      if (owner != null && receipt['ownerId'] != owner) {
        throw Exception('يرجى تسجيل الدخول');
      }
      response = await _client
          .post(_endpoint('receipt'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'receiptToken': receipt['token']}))
          .timeout(const Duration(seconds: 30));
    }
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'تعذر إكمال العملية؛ حدّث حالة الطلب');
    }
    if (data['receiptToken'] is String) {
      await _storage.write(
          key: _receiptKey,
          value: jsonEncode({'ownerId': owner, 'token': data['receiptToken']}));
    }
    return data;
  }
}
