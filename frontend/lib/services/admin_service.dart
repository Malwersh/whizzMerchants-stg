import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/business.dart';
import 'package:whizz_merchants/config/app_config.dart';

class AdminService {
  final String _apiUrl = AppConfig.baseUrl;

  Future<List<Business>> getPendingBusinesses(String token) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/admin/businesses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((json) => Business.fromJson(json))
          .where((business) => business.status == 'pending')
          .toList();
    } else {
      throw Exception('Failed to load pending businesses');
    }
  }

  Future<void> approveMerchant(String token, String businessId) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/admin/businesses/$businessId/approve'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to approve merchant');
    }
  }

  Future<void> rejectMerchant(String token, String businessId) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/admin/businesses/$businessId/reject'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reject merchant');
    }
  }
}
