import 'dart:async';

import '../core/utils/app_logger.dart';
import '../utils/token_validator.dart';
import 'secure_token_storage.dart';

/// Handles refreshing access/ID tokens using the stored refresh token.
class TokenRefreshService {
  static Completer<Map<String, String?>?>? _refreshCompleter;

  /// Returns a valid ID token (preferred for API Gateway). Falls back to access token.
  static Future<String?> getValidIdToken() async {
    // Prefer ID token first (API Gateway authorizer requirement)
    final idToken = await SecureTokenStorage.getIdToken();
    if (idToken != null && idToken.isNotEmpty && !TokenValidator.isTokenExpired(idToken)) {
      return idToken;
    }
    // Try access token only if ID token missing/expired (legacy endpoints if any)
    final accessToken = await SecureTokenStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty && !TokenValidator.isTokenExpired(accessToken)) {
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

      // ⚠️ DISABLED: Backend /auth/refresh endpoint not implemented (returns 501)
      // Following wizzuser approach: no TokenRefreshService, JWT validation only
      AppLogger.warning('[TokenRefreshService] Token refresh disabled - backend endpoint not implemented');
      AppLogger.warning('[TokenRefreshService] User will need to re-login when token expires');
      
      // Return null without calling backend
      completer.complete(null);
      _refreshCompleter = null;
      return completer.future;
      
      /* ORIGINAL CODE BELOW - COMMENTED OUT UNTIL BACKEND IMPLEMENTS /auth/refresh
      
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
