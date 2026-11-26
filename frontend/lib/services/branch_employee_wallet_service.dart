import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'branch_employee_access.dart';
import 'branch_device_service.dart';

/// Read-only device transport. It never loads a person's tokens or wallet list.
class BranchEmployeeWalletService {
  final http.Client client;
  BranchEmployeeWalletService({http.Client? client})
      : client = client ?? http.Client();
  Future<Map<String, dynamic>> read(BranchEmployeeAccess access, String kind,
      {String? cursor,
      String? from,
      String? to,
      bool exportCsv = false}) async {
    final permission = kind == 'sales-report'
        ? 'readSalesReports'
        : kind == 'balance'
            ? 'readWalletBalance'
            : kind == 'transactions' || kind == 'statement'
                ? 'readWalletTransactions'
                : null;
    if (permission == null ||
        access.capabilities[permission] != true ||
        (exportCsv &&
            access.capabilities[kind == 'sales-report'
                    ? 'exportSalesReports'
                    : 'exportWallet'] !=
                true)) {
      throw BranchDeviceException('PERMISSION_REQUIRED');
    }
    const base = String.fromEnvironment('WALLET_API_URL',
        defaultValue:
            'https://z14s5f8oxh.execute-api.us-east-1.amazonaws.com/staging');
    final uri =
        Uri.parse('$base/wallet/branch-device/$kind').replace(queryParameters: {
      'businessId': access.businessId,
      if (cursor != null) 'cursor': cursor,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (kind == 'statement' || kind == 'sales-report')
        'format': exportCsv ? 'csv' : 'json',
    });
    if (!AppConfig.isStaging) {
      throw BranchDeviceException('PERMISSION_REQUIRED');
    }
    final response = await client.get(uri, headers: {
      'Authorization': 'Bearer ${access.token}',
      'X-Staff-Session': access.session,
    }).timeout(const Duration(seconds: 20));
    final data = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode != 200) {
      final error = data['error'];
      throw BranchDeviceException(error is Map
          ? error['code']?.toString() ?? 'UNAVAILABLE'
          : data['code']?.toString() ?? 'UNAVAILABLE');
    }
    return Map<String, dynamic>.from(data['data'] ?? data);
  }
}
