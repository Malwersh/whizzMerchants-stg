import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/app_logger.dart';

/// Professional secure token storage using encrypted storage
/// This replaces the insecure SharedPreferences approach for sensitive data
///
/// NOTE: This stores AUTHENTICATION TOKENS (login credentials), NOT FCM device tokens
/// - Access Token: JWT for API authentication
/// - ID Token: User identity claims from Cognito
/// - Refresh Token: Long-lived token to refresh access token
///
/// FCM device tokens are stored in FirebaseMessagingService instance, not here
class SecureTokenStorage {
  static const String _accessTokenKey = 'secure_access_token';
  static const String _idTokenKey = 'secure_id_token';
  static const String _refreshTokenKey = 'secure_refresh_token';
  static const String _businessIdKey = 'secure_business_id';
  static const String _userIdKey = 'secure_user_id';
  static const String _emailKey = 'secure_email';
  static const String _tokenExpiryKey = 'secure_token_expiry';
  static const String _lastActivityKey = 'secure_last_activity';

  // Use secure storage with proper configuration
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Migrate tokens from old SharedPreferences to secure storage
  static Future<void> migrateFromSharedPreferences() async {
    try {
      AppLogger.info(
          '🔄 Migrating tokens from SharedPreferences to SecureStorage...');

      final prefs = await SharedPreferences.getInstance();

      // Migrate access token
      final oldAccessToken = prefs.getString('access_token');
      if (oldAccessToken != null && oldAccessToken.isNotEmpty) {
        await setAccessToken(oldAccessToken);
        await prefs.remove('access_token');
        AppLogger.info('✅ Migrated access token');
      }

      // Migrate id token
      final oldIdToken = prefs.getString('id_token');
      if (oldIdToken != null && oldIdToken.isNotEmpty) {
        await setIdToken(oldIdToken);
        await prefs.remove('id_token');
        AppLogger.info('✅ Migrated id token');
      }

      // Migrate refresh token
      final oldRefreshToken = prefs.getString('refresh_token');
      if (oldRefreshToken != null && oldRefreshToken.isNotEmpty) {
        await setRefreshToken(oldRefreshToken);
        await prefs.remove('refresh_token');
        AppLogger.info('✅ Migrated refresh token');
      }

      // Migrate business ID
      final oldBusinessId = prefs.getString('business_id');
      if (oldBusinessId != null && oldBusinessId.isNotEmpty) {
        await setBusinessId(oldBusinessId);
        // Keep in SharedPreferences too for backward compatibility
        AppLogger.info('✅ Migrated business ID');
      }

      AppLogger.success('🎉 Token migration completed successfully');
    } catch (e) {
      AppLogger.error('❌ Error migrating tokens: $e');
      // Don't throw - migration failure shouldn't block app
    }
  }

  /// Store access token securely
  static Future<void> setAccessToken(String token) async {
    try {
      if (token.isEmpty) {
        AppLogger.warning('⚠️ Attempted to store empty access token');
        return;
      }
      await _secureStorage.write(key: _accessTokenKey, value: token);
      AppLogger.debug('✅ Access token stored securely');
    } catch (e) {
      AppLogger.error('❌ Error storing access token: $e');
      throw Exception('Failed to store access token securely');
    }
  }

  /// Store ID token securely
  static Future<void> setIdToken(String token) async {
    try {
      if (token.isEmpty) {
        AppLogger.warning('⚠️ Attempted to store empty ID token');
        return;
      }
      await _secureStorage.write(key: _idTokenKey, value: token);
      AppLogger.debug('✅ ID token stored securely');
    } catch (e) {
      AppLogger.error('❌ Error storing ID token: $e');
      throw Exception('Failed to store ID token securely');
    }
  }

  /// Store refresh token securely
  static Future<void> setRefreshToken(String token) async {
    try {
      if (token.isEmpty) {
        AppLogger.warning('⚠️ Attempted to store empty refresh token');
        return;
      }
      await _secureStorage.write(key: _refreshTokenKey, value: token);
      AppLogger.debug('✅ Refresh token stored securely');
    } catch (e) {
      AppLogger.error('❌ Error storing refresh token: $e');
      throw Exception('Failed to store refresh token securely');
    }
  }

  /// Store business ID securely
  static Future<void> clearBusinessId() async {
    await _secureStorage.delete(key: _businessIdKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('business_id');
  }

  static Future<void> setBusinessId(String businessId) async {
    try {
      if (businessId.isEmpty) {
        AppLogger.warning('⚠️ Attempted to store empty business ID');
        return;
      }
      await _secureStorage.write(key: _businessIdKey, value: businessId);

      // Also store in SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('business_id', businessId);

      AppLogger.debug('✅ Business ID stored securely');
    } catch (e) {
      AppLogger.error('❌ Error storing business ID: $e');
      throw Exception('Failed to store business ID securely');
    }
  }

  /// Store user ID securely
  static Future<void> setUserId(String userId) async {
    try {
      if (userId.isEmpty) {
        AppLogger.warning('⚠️ Attempted to store empty user ID');
        return;
      }
      await _secureStorage.write(key: _userIdKey, value: userId);
      AppLogger.debug('✅ User ID stored securely');
    } catch (e) {
      AppLogger.error('❌ Error storing user ID: $e');
    }
  }

  /// Store email securely
  static Future<void> setEmail(String email) async {
    try {
      if (email.isEmpty) {
        AppLogger.warning('⚠️ Attempted to store empty email');
        return;
      }
      await _secureStorage.write(key: _emailKey, value: email);
      AppLogger.debug('✅ Email stored securely');
    } catch (e) {
      AppLogger.error('❌ Error storing email: $e');
    }
  }

  /// Store token expiry timestamp
  static Future<void> setTokenExpiry(DateTime expiry) async {
    try {
      await _secureStorage.write(
        key: _tokenExpiryKey,
        value: expiry.millisecondsSinceEpoch.toString(),
      );
      AppLogger.debug('✅ Token expiry stored: ${expiry.toIso8601String()}');
    } catch (e) {
      AppLogger.error('❌ Error storing token expiry: $e');
    }
  }

  /// Update last activity timestamp
  static Future<void> updateLastActivity() async {
    try {
      await _secureStorage.write(
        key: _lastActivityKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      AppLogger.error('❌ Error updating last activity: $e');
    }
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: _accessTokenKey);
      if (token != null && token.isNotEmpty) {
        await updateLastActivity();
      }
      return token;
    } catch (e) {
      AppLogger.error('❌ Error reading access token: $e');
      return null;
    }
  }

  /// Get ID token
  static Future<String?> getIdToken() async {
    try {
      final token = await _secureStorage.read(key: _idTokenKey);
      if (token != null && token.isNotEmpty) {
        await updateLastActivity();
      }
      return token;
    } catch (e) {
      AppLogger.error('❌ Error reading ID token: $e');
      return null;
    }
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      AppLogger.error('❌ Error reading refresh token: $e');
      return null;
    }
  }

  /// Get business ID
  static Future<String?> getBusinessId() async {
    try {
      // Try secure storage first
      String? businessId = await _secureStorage.read(key: _businessIdKey);

      // Fallback to SharedPreferences for backward compatibility
      if (businessId == null || businessId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        businessId = prefs.getString('business_id');

        // If found in SharedPreferences, migrate to secure storage
        if (businessId != null && businessId.isNotEmpty) {
          await setBusinessId(businessId);
        }
      }

      return businessId;
    } catch (e) {
      AppLogger.error('❌ Error reading business ID: $e');
      return null;
    }
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e) {
      AppLogger.error('❌ Error reading user ID: $e');
      return null;
    }
  }

  /// Get email
  static Future<String?> getEmail() async {
    try {
      return await _secureStorage.read(key: _emailKey);
    } catch (e) {
      AppLogger.error('❌ Error reading email: $e');
      return null;
    }
  }

  /// Get token expiry
  static Future<DateTime?> getTokenExpiry() async {
    try {
      final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryStr != null && expiryStr.isNotEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error reading token expiry: $e');
      return null;
    }
  }

  /// Get last activity timestamp
  static Future<DateTime?> getLastActivity() async {
    try {
      final activityStr = await _secureStorage.read(key: _lastActivityKey);
      if (activityStr != null && activityStr.isNotEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(activityStr));
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error reading last activity: $e');
      return null;
    }
  }

  /// Check if tokens are expired
  static Future<bool> areTokensExpired() async {
    try {
      final expiry = await getTokenExpiry();
      if (expiry == null) {
        return true; // Assume expired if no expiry found
      }
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      AppLogger.error('❌ Error checking token expiry: $e');
      return true;
    }
  }

  /// Check if session is valid (has tokens and not expired)
  static Future<bool> hasValidSession() async {
    try {
      final accessToken = await getAccessToken();
      final idToken = await getIdToken();
      final businessId = await getBusinessId();
      final expired = await areTokensExpired();

      final isValid = accessToken != null &&
          accessToken.isNotEmpty &&
          idToken != null &&
          idToken.isNotEmpty &&
          businessId != null &&
          businessId.isNotEmpty &&
          !expired;

      AppLogger.info('🔍 Session validation: ${isValid ? "VALID" : "INVALID"}');
      if (!isValid) {
        AppLogger.info(
            '   - Has access token: ${accessToken != null && accessToken.isNotEmpty}');
        AppLogger.info(
            '   - Has id token: ${idToken != null && idToken.isNotEmpty}');
        AppLogger.info(
            '   - Has business ID: ${businessId != null && businessId.isNotEmpty}');
        AppLogger.info('   - Tokens expired: $expired');
      }

      return isValid;
    } catch (e) {
      AppLogger.error('❌ Error validating session: $e');
      return false;
    }
  }

  /// Get the best token for API authorization (prefers ID token)
  static Future<String?> getAuthorizationToken() async {
    try {
      // Prefer ID token (has audience field for API Gateway)
      final idToken = await getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        AppLogger.debug('🎫 Using ID token for authorization');
        return idToken;
      }

      // Fallback to access token
      final accessToken = await getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        AppLogger.debug('🎫 Using access token for authorization (fallback)');
        return accessToken;
      }

      AppLogger.warning('⚠️ No authorization token available');
      return null;
    } catch (e) {
      AppLogger.error('❌ Error getting authorization token: $e');
      return null;
    }
  }

  /// Store complete session bundle atomically
  static Future<void> storeSessionBundle({
    required String accessToken,
    required String idToken,
    required String refreshToken,
    required String businessId,
    String? userId,
    String? email,
    DateTime? tokenExpiry,
  }) async {
    try {
      AppLogger.info('💾 Storing complete session bundle...');

      // Store all tokens
      await Future.wait([
        setAccessToken(accessToken),
        setIdToken(idToken),
        setRefreshToken(refreshToken),
        setBusinessId(businessId),
        if (userId != null) setUserId(userId),
        if (email != null) setEmail(email),
        if (tokenExpiry != null) setTokenExpiry(tokenExpiry),
        updateLastActivity(),
      ]);

      AppLogger.success('✅ Session bundle stored successfully');
    } catch (e) {
      AppLogger.error('❌ Error storing session bundle: $e');
      throw Exception('Failed to store session bundle');
    }
  }

  /// Clear all stored tokens and session data
  static Future<void> clearAll() async {
    try {
      AppLogger.info('🧹 Clearing all secure tokens...');

      await _secureStorage.deleteAll();

      // Also clear SharedPreferences for complete cleanup
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('business_id');
      await prefs.remove('access_token');
      await prefs.remove('id_token');
      await prefs.remove('refresh_token');

      AppLogger.success('✅ All tokens cleared successfully');
    } catch (e) {
      AppLogger.error('❌ Error clearing tokens: $e');
      throw Exception('Failed to clear tokens');
    }
  }

  /// Get complete session info for debugging
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      return {
        'hasAccessToken': (await getAccessToken()) != null,
        'hasIdToken': (await getIdToken()) != null,
        'hasRefreshToken': (await getRefreshToken()) != null,
        'businessId': await getBusinessId(),
        'userId': await getUserId(),
        'email': await getEmail(),
        'tokenExpiry': (await getTokenExpiry())?.toIso8601String(),
        'lastActivity': (await getLastActivity())?.toIso8601String(),
        'isExpired': await areTokensExpired(),
        'hasValidSession': await hasValidSession(),
      };
    } catch (e) {
      AppLogger.error('❌ Error getting session info: $e');
      return {};
    }
  }
}
