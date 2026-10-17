import 'dart:async';
import 'dart:convert';

import '../core/utils/app_logger.dart';
import '../utils/token_validator.dart';
import 'app_auth_service.dart';
import 'secure_token_storage.dart';

/// Handles refreshing access/ID tokens using the stored refresh token.
class TokenRefreshService {
  static Completer<Map<String, String?>?>? _refreshCompleter;

  /// Returns a valid ID token (preferred for API Gateway). Falls back to access token.
  static Future<String?> getValidIdToken() async {
    // Prefer ID token first (API Gateway authorizer requirement)
    final idToken = await SecureTokenStorage.getIdToken();
    if (idToken != null &&
        idToken.isNotEmpty &&
        !TokenValidator.isTokenExpired(idToken)) {
      return idToken;
    }
    // Try access token only if ID token missing/expired (legacy endpoints if any)
    final accessToken = await SecureTokenStorage.getAccessToken();
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !TokenValidator.isTokenExpired(accessToken)) {
      return idToken ?? accessToken; // return access if id absent
    }
    // Refresh
    final refreshed = await refreshTokens();
    return refreshed?['idToken'] ?? refreshed?['accessToken'];
  }

  /// Legacy method used in places expecting an access token; now returns ID token first.
  static Future<String?> getValidAccessToken() async {
    // Delegate to getValidIdToken to keep existing call sites working.
    return getValidIdToken();
  }

  /// Cognito GetUser requires an access token, never an ID-token fallback.
  static Future<String?> getValidUserAccessToken() async {
    bool valid(String? value) {
      if (value == null || TokenValidator.isTokenExpired(value)) return false;
      try {
        final payload = jsonDecode(utf8.decode(base64Url.decode(
            base64Url.normalize(value.split('.')[1]))));
        return payload['token_use'] == 'access';
      } catch (_) { return false; }
    }
    final stored = await SecureTokenStorage.getAccessToken();
    if (valid(stored)) return stored;
    final refreshed = (await refreshTokens())?['accessToken'];
    return valid(refreshed) ? refreshed : null;
  }

  /// Refresh tokens via backend. This call is deduped so only one refresh runs at a time.
  static Future<Map<String, String?>?> refreshTokens() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<Map<String, String?>?>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await SecureTokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.warning('[TokenRefreshService] No refresh token available');
        completer.complete(null);
        _refreshCompleter = null;
        return completer.future;
      }

      // Refresh silently via Amplify/Cognito using the 365-day refresh token.
      // Returns null only if the refresh token is revoked/expired -> real sign-out.
      final refreshed = await AppAuthService.refreshViaAmplify();
      if (refreshed == null) {
        AppLogger.warning('[TokenRefreshService] Silent refresh failed');
      } else {
        AppLogger.info('[TokenRefreshService] Tokens refreshed');
      }
      completer.complete(refreshed);
      _refreshCompleter = null;
      return completer.future;

      /* LEGACY CODE BELOW - backend /auth/refresh was never implemented
      
      AppLogger.info('[TokenRefreshService] Refreshing tokens...');
      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'refreshToken': refreshToken,
              'refresh_token': refreshToken, // support either field name
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        AppLogger.error(
            '[TokenRefreshService] Refresh failed: ${response.statusCode} ${response.body}');
        completer.complete(null); // Do not clear tokens automatically
        _refreshCompleter = null;
        return completer.future;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken =
          (data['accessToken'] ?? data['access_token']) as String?;
      final idToken = (data['idToken'] ?? data['id_token']) as String?;
      final newRefreshToken =
          (data['refreshToken'] ?? data['refresh_token']) as String? ??
              refreshToken;
      final businessId =
          (data['businessId'] ?? data['business_id']) as String?;

      if ((accessToken == null || accessToken.isEmpty) &&
          (idToken == null || idToken.isEmpty)) {
        AppLogger.error('[TokenRefreshService] Refresh response missing tokens');
        completer.complete(null);
        _refreshCompleter = null;
        return completer.future;
      }

      // Persist tokens securely
      await SecureTokenStorage.storeSessionBundle(
        accessToken: accessToken ?? '',
        idToken: idToken ?? '',
        refreshToken: newRefreshToken,
        businessId: businessId ?? '',
        tokenExpiry: TokenValidator.getExpiryDate(idToken ?? accessToken ?? ''),
      );

      final result = <String, String?>{
        'accessToken': accessToken,
        'idToken': idToken,
        'refreshToken': newRefreshToken,
      };

      completer.complete(result);
      return result;
      */ // End of commented code
    } catch (e) {
      AppLogger.error('[TokenRefreshService] Refresh error: $e');
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
