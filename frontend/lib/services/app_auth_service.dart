import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:amplify_flutter/amplify_flutter.dart' as amplify;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_api/amplify_api.dart';
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
import './push_notifications_service.dart';

class AppAuthService {
  static bool _isInitialized = false;
  static ProviderContainer? _container;
  static CognitoAuthService? _cognitoService;

  // Cache user data to prevent repeated API calls

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
      await _configureAmplify();
    }

    _isInitialized = true;
  }

  /// Configures Amplify (Auth + API) exactly once. Uses CUSTOM_AUTH flow so the
  /// phone-based passwordless (OTP) sign-in returns the custom challenge step.
  static Future<void> _configureAmplify() async {
    if (amplify.Amplify.isConfigured) return;
    try {
      await amplify.Amplify.addPlugins([AmplifyAuthCognito(), AmplifyAPI()]);

      final amplifyconfig = '''{
        "UserAgent": "aws-amplify-cli/2.0",
        "Version": "1.0",
        "auth": {
          "plugins": {
            "awsCognitoAuthPlugin": {
              "UserAgent": "aws-amplify-cli/0.1.0",
              "Version": "0.1.0",
              "CognitoUserPool": {
                "Default": {
                  "PoolId": "${AppConfig.cognitoUserPoolId}",
                  "AppClientId": "${AppConfig.appClientId}",
                  "Region": "${AppConfig.cognitoRegion}"
                }
              },
              "Auth": {
                "Default": {
                  "authenticationFlowType": "CUSTOM_AUTH"
                }
              }
            }
          }
        },
        "api": {
          "plugins": {
            "awsAPIPlugin": {
              "haddir-api": {
                "endpointType": "REST",
                "endpoint": "${AppConfig.baseUrl}",
                "region": "${AppConfig.cognitoRegion}",
                "authorizationType": "AMAZON_COGNITO_USER_POOLS"
              }
            }
          }
        }
      }''';

      await amplify.Amplify.configure(amplifyconfig);
      AppLogger.success('✅ Amplify configured (CUSTOM_AUTH)');
    } catch (e) {
      // "already configured" is safe to ignore; anything else is logged.
      AppLogger.error('Amplify configuration failed: $e');
    }
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

  // ===================== Phone OTP (passwordless) =====================

  /// Normalizes Iraqi mobile input (07XXXXXXXXX, 7XXXXXXXXX, 9647..., +9647...,
  /// Arabic-Indic digits) to E.164 (+9647XXXXXXXXX). Returns null if invalid.
  static String? normalizeIraqiPhone(String input) {
    var p = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < arabic.length; i++) {
      p = p.replaceAll(arabic[i], '$i');
    }
    if (p.startsWith('+964')) {
      p = p.substring(4);
    } else if (p.startsWith('00964')) {
      p = p.substring(5);
    } else if (p.startsWith('964')) {
      p = p.substring(3);
    }
    if (p.startsWith('0')) p = p.substring(1);
    if (!RegExp(r'^7\d{9}$').hasMatch(p)) return null;
    return '+964$p';
  }

  /// Step 1: start sign-in. Cognito's CreateAuthChallenge trigger sends the code via OTPIQ.
  static String? lastSignInStep;
  static Future<bool> startPhoneSignIn(String phoneE164) async {
    await initialize();
    try {
      try {
        await amplify.Amplify.Auth.signOut();
      } catch (_) {}
      final result = await amplify.Amplify.Auth.signIn(
        username: phoneE164,
        options: const amplify.SignInOptions(
          pluginOptions: CognitoSignInPluginOptions(
            authFlowType: amplify.AuthenticationFlowType.customAuthWithoutSrp,
          ),
        ),
      );
      lastSignInStep = result.nextStep.signInStep.name;
      return result.nextStep.signInStep ==
          amplify.AuthSignInStep.confirmSignInWithCustomChallenge;
    } on amplify.AuthException catch (e) {
      AppLogger.error('startPhoneSignIn failed: ${e.message}');
      final msg = e.message.toLowerCase();
      // PreventUserExistenceErrors makes unknown users surface as a generic failure.
      if (msg.contains('incorrect username') ||
          msg.contains('user does not exist')) {
        throw PhoneAuthException(PhoneAuthError.notRegistered);
      }
      throw PhoneAuthException(PhoneAuthError.sendFailed, e.message);
    }
  }

  /// Step 2: submit the code. On success stores tokens and loads the merchant's business.
  static Future<SignInResult> confirmPhoneCode(String code) async {
    await initialize();
    try {
      final result = await amplify.Amplify.Auth.confirmSignIn(
        confirmationValue: code,
      );
      if (!result.isSignedIn) {
        // Wrong code; Cognito re-issues the same challenge (no new SMS).
        return SignInResult(
          success: false,
          message: 'INVALID_CODE',
          businesses: [],
        );
      }
      if (!await _syncTokensFromAmplify()) {
        return SignInResult(
            success: false, message: 'TOKEN_SYNC_FAILED', businesses: []);
      }

      final businesses = <Map<String, dynamic>>[];
      // Authentication belongs to the person; branch selection happens explicitly.
      await SecureTokenStorage.clearBusinessId();
      await _container?.read(sessionProvider.notifier).clearBusinessSelection();
      return SignInResult(
        success: true,
        message: 'Sign in successful',
        businesses: businesses,
      );
    } on amplify.AuthException catch (e) {
      AppLogger.error('confirmPhoneCode failed: ${e.message}');
      // After 3 wrong attempts or 3 minutes Cognito ends the session.
      return SignInResult(
        success: false,
        message: 'CODE_EXPIRED_OR_TOO_MANY_ATTEMPTS',
        businesses: [],
      );
    }
  }

  /// Copies Amplify (Cognito) tokens into the app's secure storage used by API calls.
  static Future<bool> _syncTokensFromAmplify({
    bool forceRefresh = false,
  }) async {
    try {
      final session = await amplify.Amplify.Auth.fetchAuthSession(
        options: amplify.FetchAuthSessionOptions(forceRefresh: forceRefresh),
      ) as CognitoAuthSession;
      final tokens = session.userPoolTokensResult.valueOrNull;
      if (tokens == null) return false;
      await _storeAuthTokens({
        'accessToken': tokens.accessToken.raw,
        'idToken': tokens.idToken.raw,
        'refreshToken': tokens.refreshToken,
      });
      return true;
    } catch (e) {
      AppLogger.warning('Token sync from Amplify failed: $e');
      return false;
    }
  }

  /// Used by TokenRefreshService: silent refresh with the 365-day refresh token.
  static Future<Map<String, String?>?> refreshViaAmplify() async {
    final ok = await _syncTokensFromAmplify(forceRefresh: true);
    if (!ok) return null;
    return {
      'accessToken': await SecureTokenStorage.getAccessToken(),
      'idToken': await SecureTokenStorage.getIdToken(),
      'refreshToken': await SecureTokenStorage.getRefreshToken(),
    };
  }

  static Future<void> signOut() async {
    try {
      await PushNotificationsService.instance.unregisterSignedOutDevice();
      // Revoke the Cognito refresh token (EnableTokenRevocation) and clear Amplify's store.
      try {
        await amplify.Amplify.Auth.signOut();
      } catch (_) {}

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

      AppLogger.success(
        '✅ Sign out complete - all tokens and session data cleared',
      );
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

  static Future<Map<String, dynamic>?> getCurrentUser(
      {bool allowRefresh = true}) async {
    await initialize();
    final token = await SecureTokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await http
          .post(
            Uri.https(
                'cognito-idp.${AppConfig.cognitoRegion}.amazonaws.com', '/'),
            headers: {
              'Content-Type': 'application/x-amz-json-1.1',
              'X-Amz-Target': 'AWSCognitoIdentityProviderService.GetUser'
            },
            body: jsonEncode({'AccessToken': token}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map;
      if (response.statusCode != 200) {
        final code = '${data['__type']}'.split('#').last;
        if (code == 'NotAuthorizedException' ||
            code == 'UserNotFoundException') {
          if (allowRefresh &&
              await _syncTokensFromAmplify(forceRefresh: true)) {
            return getCurrentUser(allowRefresh: false);
          }
          await signOut();
        }
        return null;
      }
      final attributes = <String, dynamic>{
        for (final a in data['UserAttributes'] as List)
          a['Name'] as String: a['Value']
      };
      final sub = attributes['sub'];
      if (sub is! String || sub.isEmpty) return null;
      final user = <String, dynamic>{
        ...attributes,
        'userId': sub,
        'sub': sub,
        'email': attributes['email'] ?? ''
      };
      return user;
    } catch (_) {
      return null;
    }
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
          'Returning valid token (ID preferred). len=${validToken.length}',
        );
        return validToken;
      }
    } catch (e) {
      AppLogger.warning(
        'getAccessToken: refresh path failed, falling back to stored tokens. e=$e',
      );
    }

    // Fallback: read from secure storage directly (ID token first)
    try {
      final idToken = await SecureTokenStorage.getIdToken();
      if (idToken != null && idToken.isNotEmpty) {
        AppLogger.debug(
          'Fallback returning stored ID token. len=${idToken.length}',
        );
        return idToken;
      }

      final accessToken = await SecureTokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        AppLogger.debug(
          'Fallback returning stored access token. len=${accessToken.length}',
        );
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
    // Account existence is checked separately by getCurrentUser against Cognito.
    try {
      final token = await TokenRefreshService.getValidAccessToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
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

  static Future<EmailCheckResult> checkEmailExists({
    required String email,
  }) async {
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
        final response = await CognitoAuthService.forgotPassword(
          username: email,
        );
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

  EmailCheckResult({required this.exists, required this.message});
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

  ConfirmForgotPasswordResult({required this.success, required this.message});
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

enum PhoneAuthError { notRegistered, sendFailed }

class PhoneAuthException implements Exception {
  final PhoneAuthError error;
  final String? detail;
  PhoneAuthException(this.error, [this.detail]);

  @override
  String toString() =>
      'PhoneAuthException($error${detail != null ? ': $detail' : ''})';
}
