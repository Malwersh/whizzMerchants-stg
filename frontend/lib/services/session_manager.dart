import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'app_auth_service.dart';
import 'secure_token_storage.dart';

/// Professional session management service for handling user authentication state
/// and preventing sign-in conflicts when users are already authenticated
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // Session state
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  String? _accessToken;
  DateTime? _lastSessionCheck;
  Timer? _sessionValidationTimer;

  // Session validation interval (5 minutes)
  static const Duration _sessionCheckInterval = Duration(minutes: 5);

  // Session timeout (30 minutes of inactivity)
  static const Duration _sessionTimeout = Duration(minutes: 30);

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get accessToken => _accessToken;

  /// Initialize session manager and check for existing session
  Future<void> initialize() async {
    try {
      await _loadStoredSession();
      await _validateCurrentSession();
      _startSessionValidationTimer();
    } catch (e) {
      debugPrint('SessionManager initialization error: $e');
      await _clearSession();
    }
  }

  /// Load stored session from persistent storage
  Future<void> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');

      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        // In a real app, you'd parse JSON here
        // For now, we'll validate through the auth service
      }

      final lastActivityString = prefs.getString('last_activity');
      if (lastActivityString != null) {
        final lastActivity = DateTime.parse(lastActivityString);
        final now = DateTime.now();

        // Check if session has expired due to inactivity
        if (now.difference(lastActivity) > _sessionTimeout) {
          debugPrint('Session expired due to inactivity');
          await _clearSession();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading stored session: $e');
    }
  }

  /// Validate current session by checking with auth service
  Future<bool> _validateCurrentSession() async {
    try {
      if (_accessToken == null) {
        _isAuthenticated = false;
        return false;
      }

      final response = await AppAuthService.getCurrentUser();

      if (response != null &&
          response['success'] == true &&
          response['user'] != null) {
        _currentUser = response['user'];
        _isAuthenticated = true;
        _lastSessionCheck = DateTime.now();
        await _updateLastActivity();
        notifyListeners();
        return true;
      } else {
        // Session is invalid
        await _clearSession();
        return false;
      }
    } catch (e) {
      debugPrint('Session validation error: $e');
      await _clearSession();
      return false;
    }
  }

  /// Start periodic session validation timer
  void _startSessionValidationTimer() {
    _sessionValidationTimer?.cancel();
    _sessionValidationTimer = Timer.periodic(_sessionCheckInterval, (timer) {
      _validateCurrentSession();
    });
  }

  /// Update last activity timestamp
  Future<void> _updateLastActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_activity', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error updating last activity: $e');
    }
  }

  /// Handle successful sign-in
  Future<void> onSignInSuccess({
    required Map<String, dynamic> user,
    required String accessToken,
  }) async {
    try {
      _currentUser = user;
      _accessToken = accessToken;
      _isAuthenticated = true;
      _lastSessionCheck = DateTime.now();

      // Store session data using SecureTokenStorage
      await SecureTokenStorage.setAccessToken(accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'user_data', user.toString()); // In real app, use JSON
      await _updateLastActivity();

      notifyListeners();
    } catch (e) {
      debugPrint('Error storing session data: $e');
    }
  }

  /// Create a new session directly from a Cognito AuthenticationResult map.
  /// This is useful for handling login after registration confirmation.
  Future<void> createSessionFromCognitoAuthResult(
      Map<String, dynamic> authResult) async {
    try {
      _accessToken = authResult['AccessToken'];
      final idToken = authResult['IdToken'];
      final refreshToken = authResult['RefreshToken'];

      if (_accessToken == null || idToken == null || refreshToken == null) {
        throw Exception("Incomplete authentication tokens received.");
      }

      _isAuthenticated = true;
      _lastSessionCheck = DateTime.now();

      // Store tokens in SharedPreferences using SecureTokenStorage
      await SecureTokenStorage.setAccessToken(_accessToken!);
      final prefs = await SharedPreferences.getInstance();
      await SecureTokenStorage.setRefreshToken(refreshToken);
      await prefs.setString('id_token', idToken);
      await prefs.setString('refresh_token', refreshToken);

      // After storing tokens, fetch the user details using the new session.
      // This relies on AppAuthService.getAccessToken() picking up the new token.
      final userResponse = await AppAuthService.getCurrentUser();
      if (userResponse != null &&
          userResponse['success'] == true &&
          userResponse['user'] != null) {
        _currentUser = userResponse['user'];
        await prefs.setString('user_data', jsonEncode(_currentUser));
      } else {
        _currentUser = null;
        debugPrint('Session created, but failed to fetch user data.');
      }

      await _updateLastActivity();
      _startSessionValidationTimer(); // Ensure the timer is running for the new session

      notifyListeners();
      debugPrint('Session successfully created from registration flow.');
    } catch (e) {
      debugPrint('Error creating session from Cognito auth result: $e');
      await _clearSession(); // If session creation fails, clear everything.
    }
  }

  /// Static method to clear session manager instance (avoids circular dependency)
  static Future<void> clearInstance() async {
    try {
      final instance = SessionManager._instance;
      await instance._clearSession();
    } catch (e) {
      debugPrint('Error clearing SessionManager instance: $e');
    }
  }

  /// Handle sign-out
  Future<void> onSignOut() async {
    try {
      // Clear session data - don't call AppAuthService.signOut() to avoid circular dependency
      await _clearSession();
    } catch (e) {
      debugPrint('Error during SessionManager sign out: $e');
      // Force clear anyway
      await _clearSession();
    }
  }

  /// Clear session data
  Future<void> _clearSession() async {
    try {
      _isAuthenticated = false;
      _currentUser = null;
      _accessToken = null;
      _lastSessionCheck = null;
      
      // Cancel session validation timer
      _sessionValidationTimer?.cancel();

      // Clear stored data - comprehensive cleanup using SecureTokenStorage
      await SecureTokenStorage.clearAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('id_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_data');
      await prefs.remove('last_activity');
      await prefs.remove('current_business_id');

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  /// Check if user is already signed in before attempting sign-in
  Future<Map<String, dynamic>> checkSignInPermission() async {
    try {
      // First validate current session
      final isValid = await _validateCurrentSession();

      if (isValid && _isAuthenticated) {
        return {
          'canSignIn': false,
          'reason': 'already_signed_in',
          'message':
              'You are already signed in. Please sign out first if you want to sign in with a different account.',
          'currentUser': _currentUser,
          'suggestedActions': ['continue_current_session', 'sign_out_and_retry']
        };
      }

      return {'canSignIn': true, 'message': 'Ready to sign in'};
    } catch (e) {
      debugPrint('Error checking sign-in permission: $e');
      // If there's an error, allow sign-in (fail-safe)
      return {'canSignIn': true, 'message': 'Ready to sign in'};
    }
  }

  /// Professional sign-in with session conflict handling
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
    bool forceSignIn = false,
  }) async {
    try {
      // Check if already signed in (unless forcing)
      if (!forceSignIn) {
        final signInCheck = await checkSignInPermission();
        if (signInCheck['canSignIn'] != true) {
          return {
            'success': false,
            'errorType': 'session_conflict',
            'message': signInCheck['message'],
            'currentUser': signInCheck['currentUser'],
            'suggestedActions': signInCheck['suggestedActions'],
            'canForceSignIn': true
          };
        }
      }

      // If forcing sign-in, clear current session first
      if (forceSignIn && _isAuthenticated) {
        await _clearSession();
      }

      // Attempt sign-in
      final response = await AppAuthService.signIn(
        email: email,
        password: password,
      );

      if (response.success) {
        // Get current user data
        final userResponse = await AppAuthService.getCurrentUser();

        if (userResponse != null && userResponse['success'] == true) {
          await onSignInSuccess(
            user: userResponse['user'],
            accessToken: '', // Access token is managed internally
          );

          return {
            'success': true,
            'message': 'Sign in successful',
            'user': _currentUser,
            'accessToken': _accessToken,
          };
        }
      }

      return {
        'success': false,
        'errorType': 'authentication_failed',
        'message': response.message,
      };
    } catch (e) {
      debugPrint('Sign-in error: $e');
      return {
        'success': false,
        'errorType': 'system_error',
        'message': 'An unexpected error occurred during sign-in',
      };
    }
  }

  /// Refresh session data
  Future<bool> refreshSession() async {
    return await _validateCurrentSession();
  }

  /// Check if session is still valid
  Future<bool> isSessionValid() async {
    if (!_isAuthenticated || _accessToken == null) {
      return false;
    }

    final now = DateTime.now();

    // If we haven't checked in a while, validate
    if (_lastSessionCheck == null ||
        now.difference(_lastSessionCheck!) > _sessionCheckInterval) {
      return await _validateCurrentSession();
    }

    return _isAuthenticated;
  }

  /// Update user activity (call this on user interactions)
  Future<void> updateActivity() async {
    if (_isAuthenticated) {
      await _updateLastActivity();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _sessionValidationTimer?.cancel();
    super.dispose();
  }
}
