import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../core/utils/app_logger.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  unconfirmed,
}

class CognitoAuthService {
  static final CognitoAuthService _instance = CognitoAuthService._internal();
  factory CognitoAuthService() => _instance;
  CognitoAuthService._internal();

  bool _isConfigured = false;
  AuthStatus _authStatus = AuthStatus.unknown;

  AuthStatus get authStatus => _authStatus;
  bool get isConfigured => _isConfigured;

  Future<void> configure(String amplifyConfig) async {
    if (_isConfigured) return;

    // If Amplify has already been configured globally, use that instead of reconfiguring
    try {
      if (Amplify.isConfigured) {
        AppLogger.info(
            'CognitoAuthService: Amplify already configured globally. Skipping configuration.');
        _isConfigured = true;
        await _checkAuthStatus();
        return;
      }
    } catch (e) {
      // If Amplify.isConfigured access fails, continue and try to configure
      AppLogger.debug(
          'CognitoAuthService: Amplify.isConfigured check failed: $e');
    }

    try {
      AppLogger.info('CognitoAuthService: Starting configure()');
      AppLogger.debug('CognitoAuthService: Adding AmplifyAuthCognito plugin');
      try {
        await Amplify.addPlugin(AmplifyAuthCognito());
        AppLogger.debug('CognitoAuthService: AmplifyAuthCognito plugin added');
      } catch (e) {
        AppLogger.warning(
            'CognitoAuthService: addPlugin may have failed or already configured: $e');
      }

      AppLogger.debug('CognitoAuthService: Calling Amplify.configure()');
      // Increased timeout to 5s and don't throw on timeout - just mark as configured
      try {
        await Amplify.configure(amplifyConfig).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            AppLogger.warning(
                'CognitoAuthService: Amplify.configure timed out after 5s - continuing anyway');
            // Don't throw - mark as configured and continue
          },
        );
        AppLogger.debug('CognitoAuthService: Amplify.configure finished');
      } catch (e) {
        AppLogger.warning(
            'CognitoAuthService: Amplify.configure error (may still work): $e');
        // Don't rethrow - continue with initialization
      }

      _isConfigured = true;
      
      // Check initial auth state
      await _checkAuthStatus();
      AppLogger.info('CognitoAuthService: configure() completed');
    } on AmplifyAlreadyConfiguredException {
      _isConfigured = true;
      await _checkAuthStatus();
      AppLogger.warning('CognitoAuthService: Amplify already configured');
    } catch (e) {
      AppLogger.error('CognitoAuthService: configure failed: $e');
      throw Exception('Failed to configure Amplify: $e');
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Add timeout to prevent hanging
      final session = await Amplify.Auth.fetchAuthSession().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          AppLogger.warning('CognitoAuthService: fetchAuthSession timed out');
          // Return a mock unauthenticated session
          throw TimeoutException('Auth session check timed out');
        },
      );
      _authStatus = session.isSignedIn
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } catch (e) {
      AppLogger.debug('CognitoAuthService: _checkAuthStatus error: $e');
      _authStatus = AuthStatus.unauthenticated;
    }
  }

  /// Sign up a new user with email verification
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required Map<AuthUserAttributeKey, String> userAttributes,
  }) async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: userAttributes,
        ),
      );

      if (!result.isSignUpComplete) {
        _authStatus = AuthStatus.unconfirmed;
      }

      return result;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Confirm sign up with verification code
  Future<SignUpResult> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );

      if (result.isSignUpComplete) {
        _authStatus = AuthStatus.unauthenticated;
      }

      return result;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Resend confirmation code
  Future<ResendSignUpCodeResult> resendSignUpCode({
    required String email,
  }) async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      final result = await Amplify.Auth.resendSignUpCode(username: email);
      return result;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in user
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        _authStatus = AuthStatus.authenticated;
      }

      return result;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      await Amplify.Auth.signOut();
      _authStatus = AuthStatus.unauthenticated;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Reset password
  Future<ResetPasswordResult> resetPassword({required String email}) async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      final result = await Amplify.Auth.resetPassword(username: email);
      return result;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Confirm reset password
  Future<void> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Change user password
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.updatePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return {
        'success': true,
        'message': 'Password changed successfully',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to change password: $e',
      };
    }
  }

  /// Initiate forgot password flow
  static Future<Map<String, dynamic>> forgotPassword({
    required String username,
  }) async {
    try {
      final result = await Amplify.Auth.resetPassword(username: username);
      return {
        'success': true,
        'message': 'Password reset code sent',
        'codeDeliveryDetails': {
          'deliveryMedium':
              result.nextStep.codeDeliveryDetails?.deliveryMedium.name,
          'destination': result.nextStep.codeDeliveryDetails?.destination,
        },
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to initiate password reset: $e',
      };
    }
  }

  /// Confirm forgot password with verification code
  static Future<Map<String, dynamic>> confirmForgotPassword({
    required String username,
    required String confirmationCode,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: username,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      return {
        'success': true,
        'message': 'Password reset successfully',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reset password: $e',
      };
    }
  }

  /// Get current user
  Future<AuthUser?> getCurrentUser() async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } on AuthException {
      return null;
    }
  }

  /// Get user attributes
  Future<List<AuthUserAttribute>> getUserAttributes() async {
    if (!_isConfigured) {
      throw Exception('Amplify is not configured');
    }

    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      return attributes;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleAuthException(AuthException e) {
    switch (e.runtimeType) {
      case const (UsernameExistsException):
        return 'An account with this email already exists';
      case const (InvalidParameterException):
        return 'Invalid parameters provided';
      case const (InvalidPasswordException):
        return 'Password does not meet requirements';
      case const (CodeMismatchException):
        return 'Invalid verification code';
      case const (UserNotConfirmedException):
        return 'Please verify your email address';
      case const (UserNotFoundException):
        return 'User not found';
      case const (LimitExceededException):
        return 'Too many attempts. Please try again later';
      default:
        // Handle specific error messages for common scenarios
        if (e.message.contains('code') && e.message.contains('expired')) {
          return 'Verification code has expired';
        }
        if (e.message.contains('Incorrect') || e.message.contains('password')) {
          return 'Incorrect email or password';
        }
        return e.message;
    }
  }
}
