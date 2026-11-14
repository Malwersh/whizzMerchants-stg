import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'token_refresh_service.dart';

class OrderReturnsService {
  final http.Client client;
  final Future<String?> Function() token;
  OrderReturnsService({http.Client? client, Future<String?> Function()? token})
      : client = client ?? http.Client(),
        token = token ?? TokenRefreshService.getValidUserAccessToken;
  Future<Map<String, dynamic>> call(Map<String, dynamic> selectors,
      {Map<String, dynamic>? receipt, bool cancel = false}) async {
    final credential = await token();
    if (credential == null || credential.isEmpty)
      throw Exception('أعد تسجيل الدخول');
    final uri = Uri.parse(
        '${AppConfig.baseUrl}/auth/${cancel ? 'order-cancellation' : 'order-returns'}');
    final headers = {
      'Authorization': 'Bearer $credential',
      'Content-Type': 'application/json'
    };
    final response = receipt == null
        ? await client
            .get(
                uri.replace(
                    queryParameters:
                        selectors.map((k, v) => MapEntry(k, '$v'))),
                headers: headers)
            .timeout(const Duration(seconds: 20))
        : await client
            .post(uri,
                headers: headers, body: jsonEncode({...selectors, ...receipt}))
            .timeout(const Duration(seconds: 20));
    if (await token() != credential)
      throw Exception('تغيرت الجلسة؛ أعد فتح الصفحة');
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error is Map
          ? error['code'] ?? error['error'] ?? 'RETURN_CONTINUATION_UNAVAILABLE'
          : 'RETURN_CONTINUATION_UNAVAILABLE');
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic> ||
        value['success'] != true ||
        value['orderId'] != selectors['orderId'])
      throw Exception('لم يؤكد الخادم العملية');
    return value;
  }
}
