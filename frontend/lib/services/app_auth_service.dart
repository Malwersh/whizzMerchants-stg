import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_logger.dart';
import './cognito_auth_service.dart';
import './api_service.dart';
import '../providers/session_provider.dart';
import '../config/app_config.dart';
import './secure_token_storage.dart';
import './token_refresh_service.dart';
import './session_manager.dart';

class AppAuthService {
  static bool _isInitialized = false;
  static ProviderContainer? _container;
  static CognitoAuthService? _cognitoService;
  
  // Cache user data to prevent repeated API calls
  static Map<String, dynamic>? _cachedUserData;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Store authentication tokens in SecureStorage for better persistence across app restarts
  static Future<void> _storeAuthTokens(Map<String, String?> tokens) async {
    try {
      AppLogger.info('💾 Storing authentication tokens securely...');

      final accessToken = tokens['accessToken'];
      final idToken = tokens['idToken'];
      final refreshToken = tokens['refreshToken'];

      if (accessToken == null && idToken == null && refreshToken == null) {
        AppLogger.warning('⚠️ No tokens to store');
        return;
      }

      // Persist selected tokens in SharedPreferences for any remaining simple fallback reads
      final prefs = await SharedPreferences.getInstance();

      // Store in secure storage (preferred)
      if (accessToken != null) {
        await SecureTokenStorage.setAccessToken(accessToken);
        AppLogger.debug('✅ Access token stored securely');
      }

      if (idToken != null) {
        await SecureTokenStorage.setIdToken(idToken);
        AppLogger.debug('✅ ID token stored securely');
      }

      if (refreshToken != null) {
        await SecureTokenStorage.setRefreshToken(refreshToken);
        AppLogger.debug('✅ Refresh token stored securely');
        await prefs.setString('refresh_token', refreshToken);
        AppLogger.debug('✅ Refresh token persisted to SharedPreferences');
      }

      AppLogger.success('✅ All authentication tokens stored successfully');
    } catch (e) {
      AppLogger.error('❌ Error storing authentication tokens: $e');
      throw Exception('Failed to store authentication tokens');
    }
  }

  /// Clear all stored authentication tokens from SecureStorage and SharedPreferences
  static Future<void> clearStoredTokens() async {
    try {
      AppLogger.info('🧹 Clearing stored authentication tokens...');

      // Clear from secure storage
      await SecureTokenStorage.clearAll();

      // Clear additional stored data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('refresh_token');
      await prefs.remove('user');
      await prefs.remove('access_token');
      await prefs.remove('id_token');
      await prefs.remove('business_id');

      // Clear cache
      _cachedUserData = null;
      _cacheTimestamp = null;

      AppLogger.success('✅ All stored tokens cleared successfully');
    } catch (e) {
      AppLogger.error('❌ Error clearing stored tokens: $e');
    }
  }

  static void setProviderContainer(ProviderContainer container) {
    _container = container;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (AppConfig.isCognitoConfigured) {
      _cognitoService = CognitoAuthService();
      // Note: Amplify should be configured in main.dart
    }

    _isInitialized = true;
  }

  static Future<RegisterResult> registerSimple({
    required String email,
    required String password,
  }) async {
    await initialize();

    try {
      final apiService = ApiService();
      final response = await apiService.registerSimple(
        email: email,
        password: password,
      );
      return RegisterResult(
        success: response['success'] ?? false,
        message: response['message'] ?? 'Registration initiated successfully',
        userSub: response['user_sub'],
        codeDeliveryDetails: response['code_delivery_details'],
      );
    } catch (e) {
      return RegisterResult(
        success: false,
        message: e.toString(),
        userSub: null,
        codeDeliveryDetails: null,
      );
    }
  }

  static Future<ConfirmResult> confirmSignUp({
    required String username,
    required String code,
  }) async {
    await initialize();
    try {
      if (_cognitoService != null) {
        final result = await _cognitoService!.confirmSignUp(
          email: username,
          confirmationCode: code,
        );
        return ConfirmResult(
          success: result.isSignUpComplete,
          message: result.isSignUpComplete
              ? 'Verification successful'
              : 'Verification failed',
        );
      } else {
        // Fallback to API service
        final apiService = ApiService();
        final result = await apiService.confirmRegistration(
          email: username,
          confirmationCode: code,
        );

        if (result['success'] == true) {
          return ConfirmResult(
            success: true,
            message: result['message'] ?? 'Registration confirmed successfully',
            user: result['user'],
          );
        } else {
          return ConfirmResult(
            success: false,
            message: result['message'] ?? 'Confirmation failed',
          );
        }
      }
    } catch (e) {
      return ConfirmResult(success: false, message: e.toString());
    }
  }

  static Future<void> resendSignUpCode({required String username}) async {
    await initialize();
    if (_cognitoService != null) {
      await _cognitoService!.resendSignUpCode(email: username);
    } else {
      final apiService = ApiService();
      await apiService.resendRegistrationCode(email: username);
    }
  }

  static Future<SignInResult> signIn({
    required String email,
    required String password,
    String? recaptchaToken,
  }) async {
    await initialize();
    try {
      final apiService = ApiService();
      final apiResponse = await apiService.signIn(
        email: email,
        password: password,
        recaptchaToken: recaptchaToken,
      );
      if (apiResponse['success'] != true) {
        return SignInResult(
          success: false,
          message: apiResponse['message'] ?? 'Sign-in failed',
          user: null,
          businesses: [],
          data: null,
          accountStatus: apiResponse['accountStatus'],
        );
      }
      final authData = apiResponse['data'];
      final accessToken = authData?['AccessToken'] ??
          authData?['access_token'] ??
          apiResponse['AccessToken'] ??
          apiResponse['access_token'];
      final idToken = authData?['IdToken'] ??
          authData?['id_token'] ??
          apiResponse['IdToken'] ??
          apiResponse['id_token'];
      final refreshToken = authData?['RefreshToken'] ??
          authData?['refresh_token'] ??
          apiResponse['RefreshToken'] ??
          apiResponse['refresh_token'];
      await _storeAuthTokens({
        'accessToken': accessToken?.toString(),
        'idToken': idToken?.toString(),
        'refreshToken': refreshToken?.toString(),
      });
      if (apiResponse['businesses'] != null &&
          apiResponse['businesses'].isNotEmpty) {
        final businessData = Map<String, dynamic>.from(
          apiResponse['businesses'][0],
        );
        final businessId = businessData['businessId'];
        if (businessId != null && _container != null) {
          _container!
              .read(sessionProvider.notifier)
              .setSessionWithBusinessData(businessId, businessData);
        }
      }
      return SignInResult(
        success: true,
        message: apiResponse['message'] ?? 'Sign in successful',
        user: apiResponse['user'],
        businesses: List<Map<String, dynamic>>.from(
          apiResponse['businesses'] ?? [],
        ),
        data: authData,
        accountStatus: apiResponse['accountStatus'],
      );
    } catch (e) {
      return SignInResult(
        success: false,
        message: e.toString(),
        user: null,
        businesses: [],
        data: null,
        accountStatus: null,
      );
    }
  }

  static Future<void> signOut() async {
    try {
      // Step 1: Clear the singleton SessionManager instance.
      // This is crucial because it holds the primary copy of the tokens in memory
      // and is used by ApiService. Failure to clear this will result in the old
      // tokens being used for API calls even after "logout".
      await SessionManager.clearInstance();

      // Step 2: Clear tokens from secure storage.
      // This removes the long-term persisted tokens (access, refresh, id).
      await clearStoredTokens();

      // Step 3: Clear the session state managed by Riverpod.
      // This updates the application's UI state to reflect that the user is logged out.
      if (_container != null) {
        await _container!.read(sessionProvider.notifier).clearSession();
      }

      // Step 4: Clear SharedPreferences.
      // This removes any other session-related flags or data that might be stored,
      // such as the 'isLoggedIn' flag.
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      AppLogger.success('✅ Sign out complete - all tokens and session data cleared');
    } catch (e) {
      AppLogger.error('❌ Error during sign out: $e');
      // Even if there's an error, try to clear ALL local state
      try {
        await SessionManager.clearInstance();
        await clearStoredTokens();
        if (_container != null) {
          await _container!.read(sessionProvider.notifier).clearSession();
        }
      } catch (fallbackError) {
        AppLogger.error('❌ Fallback cleanup also failed: $fallbackError');
      }
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    await initialize();

    // Check cache first to avoid repeated API calls
    final now = DateTime.now();
    if (_cachedUserData != null && 
        _cacheTimestamp != null && 
        now.difference(_cacheTimestamp!).compareTo(_cacheTimeout) < 0) {
      AppLogger.info('Using cached user data');

      return _cachedUserData;
    }

    // Check stored tokens first - avoid API calls if possible
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final userString = prefs.getString('user');

      if (accessToken != null && accessToken.isNotEmpty) {
        // If we have user data stored, use it to avoid API calls
        if (userString != null && userString.isNotEmpty) {
          try {
            final userData = jsonDecode(userString);
            
            // Validate stored user data has essential fields
            if (userData['email'] != null && userData['userId'] != null) {
              final result = {
                'success': true,
                'email': userData['email'],
                'userId': userData['userId'] ?? userData['sub'],
                'sub': userData['sub'] ?? userData['userId'], 
                'email_verified': true,
              };
              
              // Cache the result
              _cachedUserData = result;
              _cacheTimestamp = now;
              
              return result;
            }
          } catch (e) {
            AppLogger.warning('Error parsing stored user data: $e');

          }
        }

        // Only make API call as last resort - with caching to prevent repeated calls
        final apiService = ApiService();
        
        try {
          AppLogger.info('Making API call to getUserBusinesses (cached)');

          final businessList = await apiService.getUserBusinesses();

          if (businessList.isNotEmpty) {
            final business = businessList.first;

            // Update session provider
            final businessId = business['businessId'];
            if (businessId != null) {
              _container?.read(sessionProvider.notifier).setSession(businessId);
            }

            // Cache the result to avoid repeated API calls
            final userDataToCache = {
              'email': business['email'],
              'userId': business['ownerId'] ?? business['cognitoUserId'],
              'sub': business['cognitoUserId'],
            };
            
            await prefs.setString('user', jsonEncode(userDataToCache));

            final result = {
              'success': true,
              'email': business['email'],
              'userId': business['ownerId'] ?? business['cognitoUserId'],
              'sub': business['cognitoUserId'],
              'email_verified': true,
            };
            
            // Cache the result
            _cachedUserData = result;
            _cacheTimestamp = now;

            return result;
          }
        } catch (apiError) {
          AppLogger.warning('API error in getCurrentUser: $apiError');

          if (apiError.toString().contains('401') || 
              apiError.toString().contains('Invalid or expired access token')) {
            AppLogger.info('🧹 Clearing expired tokens');

            await clearStoredTokens();
            _container?.read(sessionProvider.notifier).clearSession();
            // Clear cache on token expiration
            _cachedUserData = null;
            _cacheTimestamp = null;
          }
          // Don't throw - continue to fallback options
        }
      }
    } catch (e) {
      AppLogger.warning('Error getting user from backend: $e');

    }

    // Fallback to Cognito
    if (_cognitoService != null) {
      try {
        final result = await _cognitoService!.getCurrentUser();
        if (result != null) {
          final userData = {
            'email': result.username,
            'userId': result.userId,
            'sub': result.userId,
            'email_verified': true,
          };
          
          // Cache the result
          _cachedUserData = userData;
          _cacheTimestamp = now;
          
          return userData;
        }
      } catch (e) {
        AppLogger.warning('Cognito getCurrentUser error: $e');

      }
    }

    return null;
  }

  static Future<RegisterResult> registerWithBusiness({
    required String email,
    required String password,
    required Map<String, dynamic> businessData,
  }) async {
    AppLogger.info('AppAuthService.registerWithBusiness called');

    AppLogger.info('📧 Email: $email');

    AppLogger.info('🏢 Business data keys: ${businessData.keys.toList()}');

    
    await initialize();

    try {
      final apiService = ApiService();
      final response = await apiService.registerWithBusiness(
        email: email,
        password: password,
        businessData: businessData,
      );
      AppLogger.success('API response received: $response');

      final bool isSuccess = response['success'] == true;
      if (!isSuccess) {
        return RegisterResult(
          success: false,
          message: response['message'] ?? 'Registration failed.',
          userSub: null,
          codeDeliveryDetails: response['code_delivery_details'],
          businessId: null,
        );
      }

      return RegisterResult(
        success: true,
        message: response['message'] ?? 'Registration initiated successfully.',
        userSub: response['user_sub'],
        codeDeliveryDetails: response['code_delivery_details'],
        businessId: response['business_id'],
      );
    } catch (e) {
      AppLogger.error('AppAuthService.registerWithBusiness error: $e');

      return RegisterResult(
        success: false,
        message: e.toString(),
        userSub: null,
        codeDeliveryDetails: null,
        businessId: null,
      );
    }
  }

  static Future<String?> getAccessToken() async {
    await initialize();
    AppLogger.debug('getAccessToken() called');

    // Prefer a valid (refreshed) ID token via TokenRefreshService
    try {
      final validToken = await TokenRefreshService.getValidAccessToken();
      if (validToken != null && validToken.isNotEmpty) {
        AppLogger.debug(
            'Returning valid token (ID preferred). len=${validToken.length}');
        return validToken;
      }
    } catch (e) {
      AppLogger.warning(
          'getAccessToken: refresh path failed, falling back to stored tokens. e=$e');
    }

    // Fallback: read from secure storage directly (ID token first)
    try {
      final idToken = await SecureTokenStorage.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        AppLogger.debug(
            'Fallback returning stored ID token. len=${idToken.length}');
        return idToken;
      }

      final accessToken = await SecureTokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        AppLogger.debug(
            'Fallback returning stored access token. len=${accessToken.length}');
        return accessToken;
      }

      AppLogger.debug('No token available');
      return null;
    } catch (e) {
      AppLogger.error('Error retrieving tokens from storage: $e');
      return null;
    }
  }

  static Future<bool> isSignedIn() async {
    await initialize();
    
    AppLogger.info('🔍 Checking if user is signed in...');
    
    try {
      // STEP 1: Check if we have a valid access token (or ID token)
      // Use TokenRefreshService which will auto-refresh if needed
      final validToken = await TokenRefreshService.getValidAccessToken();
      
      AppLogger.debug('🔍 Step 1: Valid token check - ${validToken != null && validToken.isNotEmpty ? "FOUND" : "NOT FOUND"}');
      
      if (validToken == null || validToken.isEmpty) {
        AppLogger.info('❌ No valid token found, user is not signed in');
        return false;
      }
      
      // STEP 2: Check if session has businessId persisted
      // This avoids unnecessary API calls on cold start
      if (_container != null) {
        final session = _container!.read(sessionProvider);
        AppLogger.debug('🔍 Step 2: Session check - isAuthenticated: ${session.isAuthenticated}, businessId: ${session.businessId}');
        
        if (session.isAuthenticated && session.businessId != null && session.businessId!.isNotEmpty) {
          AppLogger.info('✅ Valid token + session found, user is signed in');
          return true;
        }
      }
      
      // STEP 3: Fallback - Try to restore session from storage
      // SessionProvider should have already done this, but double-check
      final prefs = await SharedPreferences.getInstance();
      final storedBusinessId = prefs.getString('business_id');
      
      AppLogger.debug('🔍 Step 3: Storage check - storedBusinessId: $storedBusinessId');
      
      if (storedBusinessId != null && storedBusinessId.isNotEmpty) {
        AppLogger.info('✅ Valid token + stored businessId found, user is signed in');
        return true;
      }
      
      // STEP 4: ⚠️ DISABLED - Following wizzuser approach
      // wizzuser DOES NOT call API to validate session - only local JWT check
      // This was causing unwanted logout on tab switches when API returns 401
      AppLogger.debug('🔍 Step 4: API validation SKIPPED (wizzuser pattern)');
      AppLogger.info('✅ Token found - treating as signed in (wizzuser approach)');
      return true;
      
    } catch (outer) {
      AppLogger.warning('❌ Unexpected error in isSignedIn: $outer');
      return false;
    }
  }

  // Add debug method that doesn't conflict with undefined method
  static Map<String, dynamic> debugAuthState() {
    return {
      'isInitialized': _isInitialized,
      'hasCognitoService': _cognitoService != null,
      'hasContainer': _container != null,
    };
  }

  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Use API service for password change
      final apiService = ApiService();
      final response = await apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return response['success'] ?? false;
    } catch (e) {
      AppLogger.error('Error changing password: $e');

      return false;
    }
  }

  static Future<EmailCheckResult> checkEmailExists(
      {required String email}) async {
    await initialize();

    try {
      final apiService = ApiService();
      final response = await apiService.checkEmailExists(email: email);
      return EmailCheckResult(
        exists: response['exists'] ?? false,
        message: response['message'] ?? 'Email check completed',
      );
    } catch (e) {
      AppLogger.error('Error checking email existence: $e');

      return EmailCheckResult(
        exists: false,
        message: 'Error checking email: $e',
      );
    }
  }

  static Future<ConfirmResult> confirmRegistration({
    required String email,
    required String confirmationCode,
  }) async {
    await initialize();

    try {
      final apiService = ApiService();
      final response = await apiService.confirmRegistration(
        email: email,
        confirmationCode: confirmationCode,
      );

      return ConfirmResult(
        success: response['success'] ?? false,
        message: response['message'],
        business: response['business'],
        user: response['user'],
      );
    } catch (e) {
      AppLogger.error('Error confirming registration: $e');

      return ConfirmResult(
        success: false,
        message: 'Registration confirmation failed: $e',
      );
    }
  }

  static Future<bool> resendRegistrationCode({required String email}) async {
    await initialize();

    try {
      final apiService = ApiService();
      final response = await apiService.resendRegistrationCode(email: email);
      return response['success'] ?? false;
    } catch (e) {
      AppLogger.error('Error resending registration code: $e');

      return false;
    }
  }

  /// Check user status before password reset
  static Future<UserStatusResult> checkUserStatus({
    required String email,
  }) async {
    await initialize();

    try {
      final apiService = ApiService();
      // Try to get user info to see if account exists
      final response = await apiService.getUserByEmail(email: email);

      if (response['success'] == true && response['user'] != null) {
        final user = response['user'];
        final userStatus = user['status']?.toLowerCase();

        if (userStatus == 'unconfirmed' ||
            userStatus == 'pending_confirmation') {
          return UserStatusResult(
            exists: true,
            isConfirmed: false,
            status: 'unconfirmed',
            message:
                'Your account exists but is not confirmed. Please verify your email first.',
          );
        } else if (userStatus == 'confirmed' || userStatus == 'active') {
          return UserStatusResult(
            exists: true,
            isConfirmed: true,
            status: 'confirmed',
            message: 'Account confirmed and ready for password reset.',
          );
        } else {
          return UserStatusResult(
            exists: true,
            isConfirmed: false,
            status: userStatus ?? 'unknown',
            message: 'Account found but has an unknown status: $userStatus',
          );
        }
      } else {
        // User doesn't exist based on API response
        return UserStatusResult(
          exists: false,
          isConfirmed: false,
          status: 'not_found',
          message: 'No account found with this email address.',
        );
      }
    } catch (e) {
      AppLogger.error('Error checking user status: $e');


      // Return error status instead of falling back to email-sending methods
      return UserStatusResult(
        exists: false,
        isConfirmed: false,
        status: 'error',
        message: 'Unable to check account status. Please try again later.',
      );
    }
  }

  /// Initiate forgot password flow
  static Future<ForgotPasswordResult> forgotPassword({
    required String email,
  }) async {
    await initialize();

    try {
      if (_cognitoService != null) {
        final response =
            await CognitoAuthService.forgotPassword(username: email);
        return ForgotPasswordResult(
          success: response['success'] ?? false,
          message: response['message'] ?? '',
          codeDeliveryDetails: response['codeDeliveryDetails'],
        );
      } else {
        // If no Cognito service, return error
        return ForgotPasswordResult(
          success: false,
          message: 'Password reset service not available',
        );
      }
    } catch (e) {
      AppLogger.error('Error initiating password reset: $e');

      return ForgotPasswordResult(
        success: false,
        message: 'Failed to initiate password reset: $e',
      );
    }
  }

  /// Confirm forgot password with verification code
  static Future<ConfirmForgotPasswordResult> confirmForgotPassword({
    required String email,
    required String confirmationCode,
    required String newPassword,
  }) async {
    await initialize();

    try {
      if (_cognitoService != null) {
        final response = await CognitoAuthService.confirmForgotPassword(
          username: email,
          confirmationCode: confirmationCode,
          newPassword: newPassword,
        );
        return ConfirmForgotPasswordResult(
          success: response['success'] ?? false,
          message: response['message'] ?? '',
        );
      } else {
        // If no Cognito service, return error
        return ConfirmForgotPasswordResult(
          success: false,
          message: 'Password reset service not available',
        );
      }
    } catch (e) {
      AppLogger.error('Error confirming password reset: $e');

      return ConfirmForgotPasswordResult(
        success: false,
        message: 'Failed to confirm password reset: $e',
      );
    }
  }
}

// Result classes
class RegisterResult {
  final bool success;
  final String message;
  final String? userSub;
  final Map<String, dynamic>? codeDeliveryDetails;
  final String? businessId;

  RegisterResult({
    required this.success,
    required this.message,
    this.userSub,
    this.codeDeliveryDetails,
    this.businessId,
  });
}

class ConfirmResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? business;
  final Map<String, dynamic>? user;

  ConfirmResult({
    required this.success,
    this.message,
    this.business,
    this.user,
  });
}

class SignInResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> businesses;
  final Map<String, dynamic>? data;
  final String? accountStatus;

  SignInResult({
    required this.success,
    required this.message,
    this.user,
    required this.businesses,
    this.data,
    this.accountStatus,
  });
}

class EmailCheckResult {
  final bool exists;
  final String message;

  EmailCheckResult({
    required this.exists,
    required this.message,
  });
}

class ForgotPasswordResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? codeDeliveryDetails;

  ForgotPasswordResult({
    required this.success,
    required this.message,
    this.codeDeliveryDetails,
  });
}

class ConfirmForgotPasswordResult {
  final bool success;
  final String message;

  ConfirmForgotPasswordResult({
    required this.success,
    required this.message,
  });
}

class UserStatusResult {
  final bool exists;
  final bool isConfirmed;
  final String status;
  final String message;

  UserStatusResult({
    required this.exists,
    required this.isConfirmed,
    required this.status,
    required this.message,
  });
}
