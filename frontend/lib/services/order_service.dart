import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/app_logger.dart';
import '../models/order.dart';
import 'package:whizz_merchants/config/app_config.dart';
import 'app_auth_service.dart';
import '../core/exceptions/auth_exceptions.dart';
import 'token_refresh_service.dart'; // added

class OrderService {
  final String baseUrl = AppConfig.baseUrl;

  Future<String?> _getToken() async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<List<Order>> getMerchantOrders(String? businessId, {String? status}) async {
    AppLogger.api('OrderService.getMerchantOrders called');

    AppLogger.api('businessId: $businessId');

    AppLogger.api('status filter: $status');

    int attempt = 0;
    const maxAttempts = 2; // initial + 1 retry for transient 5xx
    while (true) {
      attempt++;
      try {
        final token = await _getToken();
        AppLogger.success(
          '🔑 DEBUG: Token retrieved: ${token != null ? " Present (${token.substring(0, token.length < 20 ? token.length : 20)}...)" : " Missing"}',
        );

        if (token == null) {
          AppLogger.error('Token not found - throwing auth exception');
          throw AuthTokenExpiredException('Auth token missing');
        }

        if (businessId == null || businessId.isEmpty) {
          AppLogger.error('Business ID not provided - throwing exception');

          throw Exception('Business ID not provided');
        }

        // Build URL with optional status parameter
        String url = '$baseUrl/merchant/orders/$businessId';
        if (status != null && status.isNotEmpty) {
          url += '?status=$status';
        }

        AppLogger.debug('🔗 DEBUG: Request URL: $url');

        AppLogger.debug('🔗 DEBUG: Base URL: $baseUrl');

        AppLogger.debug('📡 DEBUG: Making HTTP GET request...');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        // Authorization / auth-related status checks
        if (response.statusCode == 401 || response.statusCode == 403) {
          if (attempt == 1) {
            // Try refresh then retry once
            await TokenRefreshService.refreshTokens();
            continue; // retry
          }
          AppLogger.warning('[OrderService] Auth error - user needs to re-login (wizzuser approach)');
          return [];
        }

        if (response.statusCode >= 500 && response.statusCode <= 599) {
          AppLogger.error(
              'Server error ${response.statusCode} while loading orders');
          if (attempt < maxAttempts) {
            await Future.delayed(const Duration(milliseconds: 400));
            continue; // retry once
          }
          throw ServerException(
              'Server error ${response.statusCode} while loading orders');
        }

        AppLogger.debug('Response status: ${response.statusCode}');

        AppLogger.debug('Response headers: ${response.headers}');

        if (response.statusCode == 200) {
          AppLogger.success('Successful response, parsing JSON...');

          final data = jsonDecode(response.body);
          AppLogger.debug('📄 DEBUG: Response data keys: ${data.keys}');

          AppLogger.debug('📄 DEBUG: Response success: ${data['success']}');

          AppLogger.debug('📄 DEBUG: Response count: ${data['count']}');

          final List<dynamic> ordersJson = data['orders'];
          AppLogger.info('Orders JSON array length: ${ordersJson.length}');

          // Log sample orders for verification
          for (int i = 0; i < ordersJson.length && i < 3; i++) {
            final orderJson = ordersJson[i];
            AppLogger.debug(
                'Order ${i + 1} JSON keys: ${orderJson.keys.join(', ')}');

            AppLogger.debug(
                'Order ${i + 1} - id: ${orderJson['id']}, orderId: ${orderJson['orderId']}, status: ${orderJson['status']}');

            AppLogger.debug('Order ${i + 1} - Full JSON: $orderJson');
          }

          AppLogger.info('Converting JSON to Order objects...');

          final orders =
              ordersJson.map((json) => Order.fromJson(json)).toList();
          AppLogger.success('Successfully converted ${orders.length} orders');

          return orders;
        } else if (response.statusCode >= 500 && response.statusCode <= 599) {
          AppLogger.error(
            'Server error ${response.statusCode} while loading orders',
          );
          throw ServerException(
            'Server error ${response.statusCode} while loading orders',
          );
        } else {
          AppLogger.error('Unexpected error status: ${response.statusCode}');
          throw Exception(
              'Failed to load orders - HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        AppLogger.error('HTTP request failed: $e');

        AppLogger.error('Error type: ${e.runtimeType}');

        if (attempt >= maxAttempts) {
          AppLogger.warning('[OrderService] Max attempts reached, returning empty list (wizzuser approach)');
          return [];
        }
        // For network errors we can break early
        if (e is AuthTokenExpiredException) {
          await TokenRefreshService.refreshTokens();
          continue; // retry
        } else {
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }
      }
    }
  }

  Future<void> acceptMerchantOrder(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthTokenExpiredException('Auth token missing');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/merchant/order/$orderId/confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warning('[OrderService] Auth error confirming order - user needs to re-login (wizzuser approach)');
      throw Exception('Authentication required - please re-login');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to confirm order');
    }
  }

  Future<void> rejectMerchantOrder(String orderId, String businessId, {String? reason}) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthTokenExpiredException('Auth token missing');
    }

    AppLogger.info('🚫 Rejecting order via unified OrderService: $orderId');
    AppLogger.debug('   Business ID: $businessId');
    AppLogger.debug('   Reason: ${reason ?? "No reason provided"}');

    // Use unified OrderService /order/cancel endpoint
    // Note: No Authorization header - Order Service has no authorizer
    final response = await http.post(
      Uri.parse('${AppConfig.orderServiceUrl}/order/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'orderId': orderId,
        'canceledBy': 'restaurant',
        'reason': reason ?? 'تم رفض الطلب من قبل المطعم',
        'requestedBy': businessId,
      }),
    );

    AppLogger.debug('Response status: ${response.statusCode}');
    AppLogger.debug('Response body: ${response.body}');

    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warning('[OrderService] Auth error rejecting order - user needs to re-login');
      throw Exception('Authentication required - please re-login');
    }
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['message'] ?? 'Failed to reject order';
      AppLogger.error('❌ Failed to reject order: $errorMessage');
      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body);
    AppLogger.success('✅ Order rejected successfully: ${data['message']}');
  }

  Future<void> expireMerchantOrder(String orderId, {String? reason}) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthTokenExpiredException('Auth token missing');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/merchant/order/$orderId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'status': 'expired',
        'notes': reason ?? 'Order expired due to timeout'
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warning('[OrderService] Auth error expiring order - user needs to re-login (wizzuser approach)');
      throw Exception('Authentication required - please re-login');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to expire order');
    }
  }

  Future<void> updateMerchantOrderStatus(String orderId, String status) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthTokenExpiredException('Auth token missing');
    }

    // Convert internal status to backend format
    String backendStatus = _convertStatusToBackend(status);

    final response = await http.put(
      Uri.parse('$baseUrl/merchant/order/$orderId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': backendStatus}),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warning('[OrderService] Auth error updating order status - user needs to re-login (wizzuser approach)');
      throw Exception('Authentication required - please re-login');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to update order status');
    }
  }

  String _convertStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'pending';
      case 'confirmed':
        return 'confirmed';
      case 'preparing':
        return 'preparing';
      case 'ready':
        return 'ready';  // backward compatibility
      case 'readyforpickup':  // ✅ الحالة الجديدة من enum
        return 'ready_for_pickup';  // ✅ Backend format
      case 'ontheway':
      case 'on_the_way':
        return 'on_the_way';
      case 'delivered':
        return 'delivered';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'rejected'; // Backend expects 'rejected' for cancelled orders
      case 'canceled_by_user':
        return 'canceled_by_user';
      case 'canceled_by_store':
        return 'canceled_by_store';
      case 'canceled_by_system':
        return 'canceled_by_system';
      case 'returned':
        return 'returned';
      case 'expired':
        return 'expired';
      default:
        return status;
    }
  }

  // Cancellation methods
  Future<void> cancelOrderByUser(String orderId, {String? reason}) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthTokenExpiredException('Auth token missing');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/merchant/order/$orderId/cancel-by-user'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'reason': reason ?? 'Customer cancellation',
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warning('[OrderService] Auth error cancel by user - user needs to re-login (wizzuser approach)');
      throw Exception('Authentication required - please re-login');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel order by user');
    }
  }

  Future<void> cancelOrderByStore(String orderId, {String? reason}) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthTokenExpiredException('Auth token missing');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/merchant/order/$orderId/cancel-by-store'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'reason': reason ?? 'Store cancellation',
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warning('[OrderService] Auth error cancel by store - user needs to re-login (wizzuser approach)');
      throw Exception('Authentication required - please re-login');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel order by store');
    }
  }

  Future<void> cancelOrderBySystem(String orderId, {String? reason}) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthTokenExpiredException('Auth token missing');
    }

    final response = await http.put(
      Uri.parse('$baseUrl/merchant/order/$orderId/cancel-by-system'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'reason': reason ?? 'System timeout',
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      AppLogger.warning('[OrderService] Auth error cancel by system - user needs to re-login (wizzuser approach)');
      throw Exception('Authentication required - please re-login');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel order by system');
    }
  }
}
