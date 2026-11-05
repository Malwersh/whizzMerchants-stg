import 'dart:convert';

import '../core/utils/app_logger.dart';
import '../utils/token_validator.dart';
import 'app_auth_service.dart';
import 'secure_token_storage.dart';

/// Handles refreshing access/ID tokens using the stored refresh token.
class TokenRefreshService {
  static Future<Map<String, String?>?>? _refreshFuture;

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
      if (idToken == null || idToken.isEmpty) return accessToken;
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
        final payload = jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(value.split('.')[1])),
          ),
        );
        return payload['token_use'] == 'access';
      } catch (_) {
        return false;
      }
    }

    final stored = await SecureTokenStorage.getAccessToken();
    if (valid(stored)) return stored;
    final refreshed = (await refreshTokens())?['accessToken'];
    return valid(refreshed) ? refreshed : null;
  }

  /// Refresh the durable Cognito session once for all concurrent callers.
  static Future<Map<String, String?>?> refreshTokens() async {
    final active = _refreshFuture;
    if (active != null) return active;
    final pending = AppAuthService.refreshViaAmplify();
    _refreshFuture = pending;
    try {
      final result = await pending;
      AppLogger.info(result == null
          ? '[TokenRefreshService] No active Cognito session'
          : '[TokenRefreshService] Tokens refreshed');
      return result;
    } catch (_) {
      AppLogger.warning('[TokenRefreshService] Refresh unavailable');
      rethrow;
    } finally {
      if (identical(_refreshFuture, pending)) _refreshFuture = null;
    }
  }
}
