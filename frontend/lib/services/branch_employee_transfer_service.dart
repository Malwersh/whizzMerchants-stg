import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'branch_employee_access.dart';
import 'wallet_transfer_service.dart';

/// Device credentials remain in memory; person token storage is never consulted.
class BranchEmployeeTransferService {
  final BranchEmployeeAccess expected;
  final BranchEmployeeAccess? Function() current;
  final http.Client client;
  bool revoked = false;
  void Function()? onRevoked;
  BranchEmployeeTransferService(
      {required this.expected, required this.current, http.Client? client})
      : client = client ?? http.Client();
  void check() {
    final access = current();
    if (revoked ||
        !AppConfig.isStaging ||
        access == null ||
        access.businessId != expected.businessId ||
        access.token != expected.token ||
        access.session != expected.session ||
        access.capabilities['transferFunds'] != true) {
      throw WalletTransferException(
          'تغيرت جلسة الموظف أو صلاحية التحويل.', 'SESSION_REVOKED');
    }
  }

  Future<Map<String, dynamic>> call(String action,
      {Map<String, String>? query, Map<String, dynamic>? body}) async {
    check();
    const reads = ['context', 'recipient', 'history', 'status'];
    const writes = ['otp/send', 'otp/verify', 'request', 'cancel'];
    if (!(body == null ? reads : writes).contains(action)) {
      throw WalletTransferException(
          'العملية غير متاحة.', 'PERMISSION_REQUIRED');
    }
    const base = String.fromEnvironment('WALLET_API_URL',
        defaultValue:
            'https://z14s5f8oxh.execute-api.us-east-1.amazonaws.com/staging');
    final uri = Uri.parse('$base/wallet/branch-device/transfers/$action')
        .replace(queryParameters: query);
    final headers = {
      'Authorization': 'Bearer ${expected.token}',
      'X-Staff-Session': expected.session,
      'Content-Type': 'application/json'
    };
    final response = await (body == null
            ? client.get(uri, headers: headers)
            : client.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 20));
    check();
    if (response.statusCode == 401) {
      revoked = true;
      onRevoked?.call();
      await expected.lock();
      throw WalletTransferException('انتهت جلسة الموظف.', 'SESSION_REVOKED');
    }
    final data = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode != 200) {
      final error = data['error'];
      final code = (error is Map ? error['code'] : data['code'])?.toString();
      if (response.statusCode == 403 &&
          !['REAUTH_REQUIRED', 'PHONE_VERIFICATION_REQUIRED'].contains(code)) {
        revoked = true;
        onRevoked?.call();
        await expected.lock();
        throw WalletTransferException(
            'سُحبت صلاحية العملية أو تغيرت الجلسة.', 'SESSION_REVOKED');
      }
      throw WalletTransferException(
          (error is Map ? error['message'] : data['message'])?.toString() ??
              'تعذر تأكيد العملية.',
          (error is Map ? error['code'] : data['code'])?.toString());
    }
    return Map<String, dynamic>.from(data['data'] ?? data);
  }
}
