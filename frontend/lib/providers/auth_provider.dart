import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../services/cognito_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final CognitoAuthService _authService = CognitoAuthService();
  
  AuthStatus _authStatus = AuthStatus.unknown;
  bool _isLoading = false;
  String? _errorMessage;
  AuthUser? _currentUser;

  AuthStatus get authStatus => _authStatus;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _authStatus == AuthStatus.authenticated;
  bool get isUnconfirmed => _authStatus == AuthStatus.unconfirmed;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void _setAuthStatus(AuthStatus status) {
    _authStatus = status;
    notifyListeners();
  }

  Future<void> initialize(String amplifyConfig) async {
    try {
      _setLoading(true);
      await _authService.configure(amplifyConfig);
      _authStatus = _authService.authStatus;
      
      if (_authStatus == AuthStatus.authenticated) {
        _currentUser = await _authService.getCurrentUser();
      }
      
      _setLoading(false);
    } catch (e) {
      _setError('Failed to initialize authentication: $e');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String businessName,
    required String businessType,
    required String city,
    required String neighborhood,
    required String streetName,
  }) async {
    try {
      _setLoading(true);
      clearError();

      final userAttributes = <AuthUserAttributeKey, String>{
        AuthUserAttributeKey.email: email,
        AuthUserAttributeKey.name: fullName,
        const CognitoUserAttributeKey.custom('business_name'): businessName,
        const CognitoUserAttributeKey.custom('business_type'): businessType,
        const CognitoUserAttributeKey.custom('city'): city,
        const CognitoUserAttributeKey.custom('neighborhood'): neighborhood,
        const CognitoUserAttributeKey.custom('street_name'): streetName,
      };

      final result = await _authService.signUp(
        email: email,
        password: password,
        userAttributes: userAttributes,
      );

      if (!result.isSignUpComplete) {
        _setAuthStatus(AuthStatus.unconfirmed);
        _setLoading(false);
        return true; // Success, needs confirmation
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    try {
      _setLoading(true);
      clearError();

      final result = await _authService.confirmSignUp(
        email: email,
        confirmationCode: confirmationCode,
      );

      if (result.isSignUpComplete) {
        _setAuthStatus(AuthStatus.unauthenticated);
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> resendConfirmationCode({required String email}) async {
    try {
      _setLoading(true);
      clearError();

      await _authService.resendSignUpCode(email: email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      clearError();

      final result = await _authService.signIn(
        email: email,
        password: password,
      );

      if (result.isSignedIn) {
        _setAuthStatus(AuthStatus.authenticated);
        _currentUser = await _authService.getCurrentUser();
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      clearError();

      await _authService.signOut();
      _setAuthStatus(AuthStatus.unauthenticated);
      _currentUser = null;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> resetPassword({required String email}) async {
    try {
      _setLoading(true);
      clearError();

      await _authService.resetPassword(email: email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      _setLoading(true);
      clearError();

      await _authService.confirmResetPassword(
        email: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Get user attributes including custom attributes
  Future<Map<String, String>> getUserAttributes() async {
    try {
      final attributes = await _authService.getUserAttributes();
      final attributeMap = <String, String>{};
      
      for (final attribute in attributes) {
        attributeMap[attribute.userAttributeKey.key] = attribute.value;
      }
      
      return attributeMap;
    } catch (e) {
      _setError(e.toString());
      return {};
    }
  }

  /// Get specific user attribute
  Future<String?> getUserAttribute(String key) async {
    try {
      final attributes = await getUserAttributes();
      return attributes[key];
    } catch (e) {
      return null;
    }
  }
}
