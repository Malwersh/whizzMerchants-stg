import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/app_logger.dart';
import '../models/user.dart';
import 'package:whizz_merchants/config/app_config.dart';
import 'app_auth_service.dart';
import '../config/merchant_auth_routes.dart';
import 'auth_header_builder.dart';
import 'secure_token_storage.dart';
import 'token_refresh_service.dart';
import '../utils/token_validator.dart';

class ApiService {
  final String baseUrl = AppConfig.baseUrl;
  String get _discountsBaseUrl =>
      AppConfig.isProduction ? MerchantAuthRoutes.productCatalogBase : baseUrl;

  static const _calendarDays = [
    'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
  ];

  Future<Map<String, dynamic>> _productionBranchSetup(
      String businessId, {Map<String, dynamic>? mutation}) async {
    final headers = await AuthHeaderBuilder.build();
    final uri = MerchantAuthRoutes.resolve(
      environment: AppConfig.environment, baseUrl: baseUrl, path: 'branch-setup',
    ).replace(queryParameters: {
      'businessId': businessId,
      if (mutation == null) 'view': 'readiness',
    });
    final response = await (mutation == null
            ? http.get(uri, headers: headers)
            : http.post(uri, headers: headers, body: jsonEncode({
                ...mutation, 'businessId': businessId, 'requestId': const Uuid().v4(),
              })))
        .timeout(const Duration(seconds: 25));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['code'] == 'MENU_CHANGED'
          ? 'تغيّرت بيانات الفرع. حدّث الصفحة وأعد المحاولة.'
          : 'تعذر حفظ أو تحميل تجهيز الفرع. أعد المحاولة.');
    }
    return data;
  }

  Future<Map<String, dynamic>> branchReadiness(String businessId,
      {bool activate = false}) async {
    if (AppConfig.isProduction) {
      final current = await _productionBranchSetup(businessId);
      final status = current['status'] as Map<String, dynamic>;
      if (!activate) {
        return {
          'alreadyActivated': status['active'] == true,
          'missing': status['missing'],
        };
      }
      return _productionBranchSetup(businessId, mutation: {
        'action': 'activate',
        'version': current['branchVersion'],
      });
    }
    final headers = await AuthHeaderBuilder.build();
    final url = Uri.parse(
        '$baseUrl/businesses/$businessId/status${activate ? '' : '?includeReadiness=true'}');
    final response = activate
        ? await http.put(url,
            headers: headers, body: jsonEncode({'action': 'complete_setup'}))
        : await http.get(url, headers: headers);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 ||
        (response.statusCode == 409 && data['missing'] is List)) return data;
    throw Exception('تعذر التحقق من تجهيز الفرع. أعد المحاولة.');
  }

  /// Helper method to get valid authentication token
  /// NOTE: This is the LOGIN TOKEN (access token from Cognito), NOT the FCM device token
  /// Used for: API authentication via Authorization header
  Future<String> _getValidToken() async {
    final token = await TokenRefreshService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Missing auth token');
    }
    return token;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Store tokens and user data in shared preferences using SecureTokenStorage
      final prefs = await SharedPreferences.getInstance();

      // Store tokens directly in SecureTokenStorage
      if (data['access_token'] != null &&
          data['access_token'].toString().isNotEmpty) {
        await SecureTokenStorage.setAccessToken(
          data['access_token'].toString(),
        );
      }
      if (data['id_token'] != null && data['id_token'].toString().isNotEmpty) {
        await SecureTokenStorage.setIdToken(data['id_token'].toString());
      }

      // Store refresh token (also sanitize it)
      if (data['refresh_token'] != null &&
          data['refresh_token'].toString().isNotEmpty) {
        final refreshToken = data['refresh_token'].toString().trim();
        await SecureTokenStorage.setRefreshToken(refreshToken);
      }

      // Persist expiry if available
      final expiry = TokenValidator.getExpiryDate(
        data['id_token']?.toString() ?? data['access_token']?.toString() ?? '',
      );
      if (expiry != null) {
        await SecureTokenStorage.setTokenExpiry(expiry);
      }

      await prefs.setString('user', jsonEncode(data['user']));
      return data;
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<User> getMerchantDetails() async {
    try {
      // Try SharedPreferences first (faster, doesn't require Amplify)
      final prefs = await SharedPreferences.getInstance();
      final String? userString = prefs.getString('user');

      if (userString != null && userString.isNotEmpty) {
        final user = User.fromJson(jsonDecode(userString));
        return user;
      }

      // Fallback: Try AppAuthService (may fail if Amplify not configured)
      try {
        final userMap = await AppAuthService.getCurrentUser();

        if (userMap != null && userMap['userId'] != null) {
          // Create a User object from the data returned by AppAuthService
          // Ensure email_verified is properly converted to boolean
          bool emailVerified = false;
          final emailVerifiedValue = userMap['email_verified'];
          if (emailVerifiedValue is bool) {
            emailVerified = emailVerifiedValue;
          } else if (emailVerifiedValue is String) {
            emailVerified = emailVerifiedValue.toLowerCase() == 'true';
          }

          final user = User(
            id: userMap['userId'],
            email: userMap['email'] ?? '',
            firstName: userMap['firstName'] ?? '',
            lastName: userMap['lastName'] ?? '',
            phoneNumber: userMap['phoneNumber'],
            profileImageUrl: userMap['profileImageUrl'],
            emailVerified: emailVerified,
            createdAt:
                DateTime.tryParse(userMap['createdAt'] ?? '') ?? DateTime.now(),
            updatedAt:
                DateTime.tryParse(userMap['updatedAt'] ?? '') ?? DateTime.now(),
          );
          return user;
        }
      } catch (authError) {
        // AppAuthService failed - this is OK, continue to final fallback
        debugPrint('⚠️ AppAuthService failed (non-critical): $authError');
      }

      // Final fallback: return a minimal User object from session data
      final businessIdString = prefs.getString('business_id');
      if (businessIdString != null) {
        return User(
          id: businessIdString,
          email: 'unknown@unknown.com',
          firstName: 'Merchant',
          lastName: 'User',
          phoneNumber: null,
          profileImageUrl: null,
          emailVerified: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      throw Exception('No user data found in any storage');
    } catch (e) {
      throw Exception('Failed to load user details: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserBusinesses() async {
    // Use refreshed token if needed
    final token = await _getValidToken();

    AppLogger.debug('📡 getUserBusinesses: calling /auth/user-businesses...');
    final response = await http.get(
      MerchantAuthRoutes.resolve(
        environment: AppConfig.environment,
        baseUrl: baseUrl,
        path: 'user-businesses',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // ← LOGIN TOKEN for API auth
      },
    );

    AppLogger.debug('📡 getUserBusinesses: status=${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        AppLogger.success('✅ getUserBusinesses: success');
        return List<Map<String, dynamic>>.from(data['businesses'] ?? []);
      } else {
        AppLogger.error(
            '❌ getUserBusinesses: API returned success=false: ${data['message']}');
        throw Exception('Failed to get user businesses: ${data['message']}');
      }
    } else {
      AppLogger.error(
          '❌ getUserBusinesses: HTTP ${response.statusCode}: ${response.body}');
      throw Exception('Failed to get user businesses: ${response.body}');
    }
  }

  Future<void> _checkDiscountSession(String token) async {
    if (await SecureTokenStorage.getIdToken() != token &&
        await SecureTokenStorage.getAccessToken() != token) {
      throw Exception('تغيرت جلسة الدخول. أعد تحميل الخصومات.');
    }
  }

  Future<List<Map<String, dynamic>>> getDiscounts(
      {required String businessId}) async {
    // ✅ Use automatic token retrieval
    final headers = await AuthHeaderBuilder.build();
    final token = headers['Authorization']!.substring(7);

    final response = await http.get(
      Uri.parse('$_discountsBaseUrl/discounts')
          .replace(queryParameters: {'businessId': businessId}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    await _checkDiscountSession(token);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['discounts'] ?? []);
      } else {
        throw Exception('Failed to get discounts: ${data['message']}');
      }
    } else {
      throw Exception('Failed to get discounts: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> registerSimple({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> registerBusiness(
      Map<String, dynamic> businessData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-with-business'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(businessData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to register business: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
    String? recaptchaToken,
  }) async {
    final body = {
      'email': email,
      'password': password,
    };
    if (recaptchaToken != null) {
      body['recaptchaToken'] = recaptchaToken;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to sign in: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> registerWithBusiness({
    required String email,
    required String password,
    required Map<String, dynamic> businessData,
  }) async {
    // Combine user data with business data for the request
    final requestData = {
      'email': email,
      'password': password,
      ...businessData,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-with-business'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to register with business: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> confirmRegistration({
    required String email,
    required String confirmationCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'verificationCode': confirmationCode,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to confirm registration: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> resendRegistrationCode({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/resend-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to resend registration code: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> checkEmailExists({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/check-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to check email: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getUserByEmail({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/get-user-by-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to get user by email: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createDiscount(Map<String, dynamic> discountData,
      {required String businessId}) async {
    final headers = await AuthHeaderBuilder.build();
    final token = headers['Authorization']!.substring(7);
    final response = await http.post(
      Uri.parse('$_discountsBaseUrl/discounts')
          .replace(queryParameters: {'businessId': businessId}),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(discountData),
    );

    await _checkDiscountSession(token);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['discount'];
      } else {
        throw Exception('Failed to create discount: ${data['message']}');
      }
    } else {
      throw Exception('Failed to create discount: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateDiscount(
      String discountId, Map<String, dynamic> discountData,
      {required String businessId, String? baseRevision}) async {
    final headers = await AuthHeaderBuilder.build();
    final token = headers['Authorization']!.substring(7);
    final response = await http.put(
      Uri.parse('$_discountsBaseUrl/discounts/$discountId').replace(queryParameters: {
        'businessId': businessId,
        if (baseRevision != null) 'baseRevision': baseRevision
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(discountData),
    );

    await _checkDiscountSession(token);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['discount'];
      } else {
        throw Exception('Failed to update discount: ${data['message']}');
      }
    } else {
      throw Exception('Failed to update discount: ${response.body}');
    }
  }

  Future<void> deleteDiscount(String discountId,
      {required String businessId, String? baseRevision}) async {
    final headers = await AuthHeaderBuilder.build();
    final token = headers['Authorization']!.substring(7);
    final response = await http.delete(
      Uri.parse('$_discountsBaseUrl/discounts/$discountId').replace(queryParameters: {
        'businessId': businessId,
        if (baseRevision != null) 'baseRevision': baseRevision
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    await _checkDiscountSession(token);

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(
          'Failed to delete discount: ${data['message'] ?? response.body}');
    }
  }

  /// Toggle a discount between active and paused.
  Future<Map<String, dynamic>> toggleDiscountStatus(String discountId,
      {required String businessId, String? baseRevision}) async {
    final headers = await AuthHeaderBuilder.build();
    final token = headers['Authorization']!.substring(7);
    final response = await http.patch(
      Uri.parse('$_discountsBaseUrl/discounts/$discountId/toggle-status').replace(
          queryParameters: {
            'businessId': businessId,
            if (baseRevision != null) 'baseRevision': baseRevision
          }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    await _checkDiscountSession(token);

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(
          'Failed to toggle discount: ${data['message'] ?? response.body}');
    }
    return data;
  }

  // POS Settings API Methods

  Uri _posUri(String businessId, [String suffix = '']) {
    if (!RegExp(r'^[\w-]{1,150}$').hasMatch(businessId)) {
      throw ArgumentError('Invalid branch identifier');
    }
    const production = String.fromEnvironment('MERCHANT_POS_PRODUCTION_URL');
    final endpoint = AppConfig.isProduction ? production : baseUrl;
    if (AppConfig.isProduction) {
      MerchantAuthRoutes.validateProductionEndpoint(endpoint);
    }
    return Uri.parse('$endpoint/businesses/$businessId/pos-settings$suffix');
  }

  Future<Map<String, String>> _posHeaders() async {
    if (AppConfig.isProduction) return AuthHeaderBuilder.build();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await _getValidToken()}',
    };
  }

  Future<Map<String, dynamic>> updatePosSettings(
      String businessId, Map<String, dynamic> settings) async {
    final uri = _posUri(businessId);
    final response = await http.put(uri,
        headers: await _posHeaders(), body: jsonEncode(settings));
    return _posResponse(response);
  }

  Future<Map<String, dynamic>> testPosConnection(
      String businessId, Map<String, dynamic> testConfig) async {
    final uri = _posUri(businessId, '/test-connection');
    final response = await http.post(uri,
        headers: await _posHeaders(), body: jsonEncode(testConfig));
    return _posResponse(response);
  }

  Future<List<dynamic>> getPosSyncLogs(String businessId) async {
    if (AppConfig.isProduction) {
      throw StateError('سجل إرسال الطلبات إلى نقطة البيع غير متاح حاليًا.');
    }
    final uri = _posUri(businessId, '/sync-logs');
    final response = await http.get(uri, headers: await _posHeaders());
    return _posResponse(response)['logs'] ?? [];
  }

  Future<Map<String, dynamic>> getPosSettings(String businessId) async {
    final uri = _posUri(businessId);
    final response = await http.get(uri, headers: await _posHeaders());
    return _posResponse(response);
  }

  Map<String, dynamic> _posResponse(http.Response response) {
    final data = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? data['code'] ?? 'POS_UNAVAILABLE');
    }
    return data;
  }

  /// Update business location settings
  Future<Map<String, dynamic>> updateBusinessLocationSettings(
      String businessId, Map<String, dynamic> locationSettings) async {
    final headers = await AuthHeaderBuilder.build();

    final response = await http.put(
      Uri.parse('$baseUrl/businesses/$businessId/location-settings'),
      headers: headers,
      body: jsonEncode(locationSettings),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final data = jsonDecode(response.body);
      if (data['error'] == 'LOCATION_OUTSIDE_REGION')
        throw Exception(
            'النقطة خارج منطقة الفرع المسجلة. اختر نقطة داخل المنطقة أو اطلب تعديل منطقة الفرع.');
      if (data['error'] == 'REGION_UNAVAILABLE')
        throw Exception('منطقة الفرع غير متاحة حاليًا.');
      if (response.statusCode == 409)
        throw Exception('تغيرت بيانات الموقع. أعد فتح الإعدادات وحاول مجددًا.');
      throw Exception(
          'Failed to update business location settings: ${data['message'] ?? response.body}');
    }
  }

  /// Get business location settings
  Future<Map<String, dynamic>> getBusinessLocationSettings(
      String businessId) async {
    final headers = await AuthHeaderBuilder.build();

    final response = await http.get(
      Uri.parse('$baseUrl/businesses/$businessId/location-settings'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(
          'Failed to get business location settings: ${data['message'] ?? response.body}');
    }
  }

  /// Get business working hours
  Future<Map<String, dynamic>> getBusinessWorkingHours(
      String businessId) async {
    if (AppConfig.isProduction) {
      final data = await _productionBranchSetup(businessId);
      final days = List<Map<String, dynamic>>.from(data['hours'] ?? []);
      return {
        'workingHours': {
          for (final day in days)
            _calendarDays[day['day'] as int]: {
              'isClosed': day['closed'] == true,
              if (day['closed'] != true && (day['periods'] as List).isNotEmpty) ...{
                'openTime': day['periods'].first['open'],
                'closeTime': day['periods'].first['close'],
              },
            },
        },
      };
    }
    final headers = await AuthHeaderBuilder.build();

    final response = await http.get(
      Uri.parse('$baseUrl/businesses/$businessId/working-hours'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(
          'Failed to get business working hours: ${data['message'] ?? response.body}');
    }
  }

  /// Update business working hours
  Future<Map<String, dynamic>> updateBusinessWorkingHours(
      String businessId, Map<String, dynamic> workingHours) async {
    if (AppConfig.isProduction) {
      final current = await _productionBranchSetup(businessId);
      final hours = workingHours['workingHours'] as Map;
      final days = _calendarDays.asMap().entries.map((entry) {
        final row = hours[entry.value] as Map;
        final closed = row['isClosed'] == true;
        return {
          'day': entry.key,
          'closed': closed,
          'periods': [
            if (!closed) {'open': row['openTime'], 'close': row['closeTime']},
          ],
        };
      }).toList();
      return _productionBranchSetup(businessId, mutation: {
        'action': 'hours',
        'version': current['branchVersion'],
        'data': days,
      });
    }
    final headers = await AuthHeaderBuilder.build();

    final response = await http.put(
      Uri.parse('$baseUrl/businesses/$businessId/working-hours'),
      headers: headers,
      body: jsonEncode(workingHours),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(
          'Failed to update business working hours: ${data['message'] ?? response.body}');
    }
  }

  /// Register device FCM/APNs token with backend
  /// NOTE: This uploads the FCM DEVICE TOKEN (for push notifications), NOT the login token
  /// Parameter deviceToken: The FCM/APNs token string from FirebaseMessaging.getToken()
  Future<void> registerDeviceToken(String deviceToken) async {
    final token = await _getValidToken(); // ← LOGIN TOKEN for auth
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/register-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // ← LOGIN TOKEN in header
      },
      body: jsonEncode({'deviceToken': deviceToken}), // ← FCM TOKEN in body
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to register device token: ${response.body}');
    }
  }

  /// Upload device token with explicit merchantId (called after login)
  /// NOTE: Uploads FCM DEVICE TOKEN, uses LOGIN TOKEN for authentication
  Future<void> uploadDeviceTokenWithMerchantId({
    required String merchantId,
    required String deviceToken, // ← FCM TOKEN (for push notifications)
    required String platform,
    required String deviceId,
    required String appVersion,
  }) async {
    debugPrint('🔥 API SERVICE: uploadDeviceTokenWithMerchantId called');
    debugPrint('🔥 merchantId: $merchantId');
    debugPrint('🔥 deviceToken length: ${deviceToken.length}');
    debugPrint('🔥 platform: $platform');
    debugPrint('🔥 deviceId: $deviceId');
    debugPrint('🔥 appVersion: $appVersion');

    final token = await _getValidToken(); // ← LOGIN TOKEN for auth
    debugPrint('🔥 Authorization token obtained: YES');

    final uri = Uri.parse('$baseUrl/merchants/$merchantId/device-token');
    debugPrint('🔥 API Endpoint: $uri');

    final requestBody = {
      'merchantId': merchantId,
      'deviceToken': deviceToken,
      'platform': platform,
      'deviceId': deviceId,
      'appVersion': appVersion,
      'isActive': true,
    };

    debugPrint('🔥 Request body: ${jsonEncode(requestBody)}');

    debugPrint('🚀 Making HTTP POST request...');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint('📡 Response status code: ${response.statusCode}');
    debugPrint('📡 Response body: ${response.body}');

    if (response.statusCode != 200) {
      debugPrint(
        '❌ Failed to upload device token: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to upload device token: ${response.body}');
    }

    debugPrint('✅✅✅ Device token uploaded via API successfully!');
  }

  /// Update business online/offline status
  Future<void> updateBusinessOnlineStatus(
    String businessId,
    String userId,
    bool isOnline,
  ) async {
    // Use _getValidToken to get valid token
    final token = await _getValidToken();
    final response = await http.put(
      Uri.parse('$baseUrl/businesses/$businessId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userId': userId,
        'status': isOnline ? 'online' : 'offline',
        'source': 'flutter_app'
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(
          'Failed to update business status: ${errorData['message'] ?? errorData['error'] ?? response.body}');
    }
  }

  /// Get business online status
  Future<Map<String, dynamic>> getBusinessOnlineStatus(
      String businessId) async {
    final token = await _getValidToken();
    final response = await http.get(
      Uri.parse('$baseUrl/businesses/$businessId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
          'Failed to get business status: ${errorData['error'] ?? response.body}');
    }
  }

  // Business Profile Management Methods

  /// Get business profile information
  Future<Map<String, dynamic>> getBusinessProfile(String businessId) async {
    final token = await _getValidToken();
    final response = await http.get(
      Uri.parse('$baseUrl/businesses/$businessId/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
          'Failed to get business profile: ${errorData['message'] ?? response.body}');
    }
  }

  /// Get complete business details including all fields from DynamoDB
  Future<Map<String, dynamic>> getBusinessDetails() async {
    final token = await _getValidToken();
    final response = await http.get(
      Uri.parse('$baseUrl/business/details'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
          'Failed to get business details: ${errorData['message'] ?? response.body}');
    }
  }

  /// Update business profile information
  Future<Map<String, dynamic>> updateBusinessProfile(
      String businessId, Map<String, dynamic> profileData) async {
    final token = await _getValidToken();
    final response = await http.put(
      Uri.parse('$baseUrl/businesses/$businessId/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(profileData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(
          'Failed to update business profile: ${errorData['message'] ?? response.body}');
    }
  }

  /// Update business photo
  Future<Map<String, dynamic>> updateBusinessPhoto(
      String businessId, String photoUrl) async {
    return await updateBusinessProfile(businessId, {
      'businessPhotoUrl': photoUrl,
    });
  }

  /// Update business basic information
  Future<Map<String, dynamic>> updateBusinessBasicInfo(
    String businessId, {
    String? businessName,
    String? ownerName,
    String? description,
    String? website,
    String? phoneNumber,
  }) async {
    final updateData = <String, dynamic>{};

    if (businessName != null) updateData['businessName'] = businessName;
    if (ownerName != null) updateData['ownerName'] = ownerName;
    if (description != null) updateData['description'] = description;
    if (website != null) updateData['website'] = website;
    if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;

    return await updateBusinessProfile(businessId, updateData);
  }

  /// Update business address information
  Future<Map<String, dynamic>> updateBusinessAddress(
    String businessId, {
    String? address,
    String? city,
    String? district,
    String? country,
    String? street,
    double? latitude,
    double? longitude,
  }) async {
    final updateData = <String, dynamic>{};

    if (address != null) updateData['address'] = address;
    if (city != null) updateData['city'] = city;
    if (district != null) updateData['district'] = district;
    if (country != null) updateData['country'] = country;
    if (street != null) updateData['street'] = street;
    if (latitude != null) updateData['latitude'] = latitude;
    if (longitude != null) updateData['longitude'] = longitude;

    return await updateBusinessProfile(businessId, updateData);
  }

  /// Delete business account permanently
  /// This will delete all business data and the associated user account
  Future<void> deleteBusinessAccount(String businessId) async {
    final token = await _getValidToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/businesses/$businessId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = jsonDecode(response.body);
      throw Exception(
          'Failed to delete business account: ${data['message'] ?? response.body}');
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Unified access token retrieval
    final accessToken = await _getValidToken();

    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to change password: ${response.body}');
    }
  }

  /// Create virtual WebSocket connection for tracking business user login
  Future<Map<String, dynamic>> createVirtualWebSocketConnection(
      Map<String, dynamic> connectionData) async {
    final token = await _getValidToken();
    final response = await http.post(
      Uri.parse('$baseUrl/websocket/virtual-connection'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(connectionData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception(
          'Failed to create virtual WebSocket connection: ${response.body}');
    }
  }

  /// Remove business WebSocket connections on logout
  Future<Map<String, dynamic>> removeBusinessWebSocketConnections(
      Map<String, dynamic> removalData) async {
    final token = await _getValidToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/websocket/business-connections'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(removalData),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception(
          'Failed to remove WebSocket connections: ${response.body}');
    }
  }

  /// Track business user login
  Future<Map<String, dynamic>> trackBusinessLogin({
    required String businessId,
    required String userId,
    required String email,
  }) async {
    final token = await _getValidToken();
    final requestUrl = '$baseUrl/auth/track-login';
    final requestBody = jsonEncode({
      'businessId': businessId,
      'userId': userId,
      'email': email,
    });

    AppLogger.info('API_SERVICE: Making POST request...');
    AppLogger.api('URL: $requestUrl');
    AppLogger.api('Body: $requestBody');

    final response = await http.post(
      Uri.parse(requestUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: requestBody,
    );

    AppLogger.api('📡 API_SERVICE: Response received');
    AppLogger.api('Status: ${response.statusCode}');
    AppLogger.api('Headers: ${response.headers}');
    AppLogger.api('Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      AppLogger.success('API_SERVICE: trackBusinessLogin successful');
      return data;
    } else {
      AppLogger.error('API_SERVICE: trackBusinessLogin failed');
      throw Exception('Failed to track business login: ${response.body}');
    }
  }

  /// Remove business user login tracking
  Future<Map<String, dynamic>> trackBusinessLogout({
    required String businessId,
    required String userId,
  }) async {
    final token = await _getValidToken();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/track-logout'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'businessId': businessId,
        'userId': userId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to track business logout: ${response.body}');
    }
  }

  /// Delete merchant account
  Future<void> deleteAccount({
    required String userId,
    required String password,
  }) async {
    final token = await _getValidToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/merchants/account'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'userId': userId, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete account: ${response.body}');
    }
  }
}
