import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:whizz_merchants/config/app_config.dart';
import 'app_auth_service.dart';

/// Service for checking business online status
/// Used by customer apps to determine which businesses are available
class BusinessStatusService {
  static final BusinessStatusService _instance =
      BusinessStatusService._internal();
  factory BusinessStatusService() => _instance;
  BusinessStatusService._internal();

  /// Check if a specific business is online
  Future<bool> isBusinessOnline(String businessId) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token == null) {
        debugPrint('❌ No auth token available for business status check');
        return false;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/businesses/$businessId/online-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isOnline = data['isOnline'] ?? false;
        debugPrint('📊 Business $businessId online status: $isOnline');
        return isOnline;
      } else {
        debugPrint('❌ Failed to check business status: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      debugPrint('❌ Error checking business online status: $error');
      return false;
    }
  }

  /// Check online status for multiple businesses
  Future<Map<String, bool>> getMultipleBusinessesStatus(
      List<String> businessIds) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token == null) {
        debugPrint('❌ No auth token available for businesses status check');
        return {};
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/businesses/nearby/online'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'businessIds': businessIds,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<String, bool> statusMap = {};

        for (final business in data['businesses'] ?? []) {
          statusMap[business['businessId']] = business['isOnline'] ?? false;
        }

        debugPrint(
            '📊 Multiple businesses status: ${statusMap.length} checked');
        return statusMap;
      } else {
        debugPrint(
            '❌ Failed to check multiple businesses status: ${response.statusCode}');
        return {};
      }
    } catch (error) {
      debugPrint('❌ Error checking multiple businesses status: $error');
      return {};
    }
  }

  /// Get nearby online businesses (if location-based filtering is needed)
  Future<List<String>> getNearbyOnlineBusinesses({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token == null) {
        debugPrint('❌ No auth token available for nearby businesses check');
        return [];
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/businesses/nearby/online'
            '?lat=$latitude&lng=$longitude&radius=$radiusKm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<String> onlineBusinessIds = [];

        for (final business in data['businesses'] ?? []) {
          if (business['isOnline'] == true) {
            onlineBusinessIds.add(business['businessId']);
          }
        }

        debugPrint(
            '📊 Found ${onlineBusinessIds.length} nearby online businesses');
        return onlineBusinessIds;
      } else {
        debugPrint(
            '❌ Failed to get nearby online businesses: ${response.statusCode}');
        return [];
      }
    } catch (error) {
      debugPrint('❌ Error getting nearby online businesses: $error');
      return [];
    }
  }
}
