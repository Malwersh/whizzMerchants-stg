import '../core/utils/app_logger.dart';
import 'token_refresh_service.dart';
import 'secure_token_storage.dart';
import '../utils/token_validator.dart';

/// Central helper to construct Authorization headers using the ID token
/// API Gateway Cognito Authorizers require ID tokens, not access tokens
class AuthHeaderBuilder {
  static Future<Map<String, String>> build() async {
    // API Gateway Cognito Authorizers require ID tokens!
    // Try ID token first (required for API Gateway)
    String? token = await SecureTokenStorage.getIdToken();
    
    if (token != null && token.isNotEmpty && !TokenValidator.isTokenExpired(token)) {
      // Valid ID token found
    } else {
      // ID token expired or missing, try to refresh
      final refreshed = await TokenRefreshService.refreshTokens();
      token = refreshed?['idToken'];
      
      // Fallback to access token if ID token not available (shouldn't happen normally)
      if (token == null || token.isEmpty) {
        token = refreshed?['accessToken'];
      }
    }
    
    if (token == null || token.isEmpty) {
      throw Exception('Missing authentication token');
    }

    // Build masked token preview for logging
    final masked = token.length > 12
        ? '${token.substring(0, 6)}...${token.substring(token.length - 6)} (len=${token.length})'
        : 'len=${token.length}';
    // ignore: avoid_print
    AppLogger.info('🔐 AuthHeaderBuilder using sanitized token $masked');


    // Ensure Bearer token format is exact
    final authValue = 'Bearer $token';

    return {
      'Content-Type': 'application/json',
      'Authorization': authValue,
    };
  }

  /// Alternative header format for products API that has parsing issues
  static Future<Map<String, String>> buildAlternative() async {
    final token = await TokenRefreshService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Missing access token');
    }

    AppLogger.info('🔐 AuthHeaderBuilder using alternative format');

    return {
      'Content-Type': 'application/json',
      'Access-Token': token,
    };
  }

  /// Try multiple header formats until one works
  static Future<Map<String, String>> buildWithFallback() async {
    final token = await TokenRefreshService.getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Missing access token');
    }

    // Start with standard Bearer format
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Access-Token': token, // Include both for maximum compatibility
    };
  }
}
