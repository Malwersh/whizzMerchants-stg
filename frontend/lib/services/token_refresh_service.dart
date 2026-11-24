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
      if (idToken == null || idToken.isEmpty) return accessToken;
      // An expired ID token must be refreshed, even if access is still valid.
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
      final refreshed = await AppAuthService.refreshViaAmplify();
      completer.complete(refreshed);
      return completer.future;
    } catch (e) {
      AppLogger.warning('[TokenRefreshService] Refresh failed: ${e.runtimeType}');
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
