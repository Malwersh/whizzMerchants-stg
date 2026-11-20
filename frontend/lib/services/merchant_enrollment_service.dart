import 'dart:convert';
import 'package:http/http.dart' as http;

/// Public enrollment bootstrap. Never falls back to a staging endpoint.
class MerchantEnrollmentService {
  final http.Client client;
  final Uri base;
  MerchantEnrollmentService({required this.client, required String baseUrl})
      : base = Uri.parse(baseUrl) {
    if (base.scheme != 'https' ||
        base.host.isEmpty ||
        base.path != '/production' ||
        base.hasQuery ||
        base.hasFragment) {
      throw ArgumentError('Invalid production enrollment endpoint');
    }
  }

  Future<Map<String, dynamic>> _request(String action,
      [Map<String, dynamic>? body]) async {
    final uri =
        base.replace(path: '${base.path}/auth/merchant-enrollment/$action');
    final response = await (body == null
            ? client.get(uri)
            : client.post(uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body)))
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid enrollment response');
    }
    if (response.statusCode != 200) {
      // Retain the structured code, never response contents or credentials.
      throw MerchantEnrollmentException(decoded['code'] is String
          ? decoded['code'] as String
          : 'UNAVAILABLE');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> legal() => _request('legal');
  Future<Map<String, dynamic>> send(String phone) =>
      _request('send', {'phone': phone});
  Future<Map<String, dynamic>> verify(
          {required String phone,
          required String sessionId,
          required String code,
          required String name,
          required Map<String, dynamic> legalAcceptance}) =>
      _request('verify', {
        'phone': phone,
        'sessionId': sessionId,
        'code': code,
        'name': name,
        'legalAccepted': true,
        'legalAcceptance': legalAcceptance,
      });
}

class MerchantEnrollmentException implements Exception {
  final String code;
  const MerchantEnrollmentException(this.code);
  @override
  String toString() => 'Merchant enrollment unavailable ($code)';
}
