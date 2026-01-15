import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_auth_service.dart';
import '../services/cognito_auth_service.dart';
import '../services/push_notifications_service.dart';
import '../core/utils/app_logger.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

enum AuthStatus { authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? currentUser;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.isLoading = false,
    this.errorMessage,
    this.currentUser,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? currentUser,
  }) => AuthState(
    status: status ?? this.status,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: errorMessage ?? this.errorMessage,
    currentUser: currentUser ?? this.currentUser,
  );

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());
  
  final CognitoAuthService _cognitoService = CognitoAuthService();

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final signedIn = await AppAuthService.isSignedIn();
      
      // Get current user data if authenticated
      Map<String, dynamic>? userData;
      if (signedIn) {
        userData = await AppAuthService.getCurrentUser();
        
        // Register push token if already signed in
        try {
          final businessId = userData?['custom:business_id'] ?? 
                            userData?['custom:businessId'] ?? 
                            userData?['businessId'];
          await PushNotificationsService.instance.registerTokenIfPossible(
            businessId: businessId is String ? businessId : null,
          );
          AppLogger.success('✅ Push token registration triggered on init (existing session)');
        } catch (e) {
          AppLogger.warning('⚠️ Push token registration failed on init (non-critical): $e');
        }
      }
      
      state = state.copyWith(
        status: signedIn
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        isLoading: false,
        currentUser: userData,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setAuthenticated() {
    state = state.copyWith(status: AuthStatus.authenticated);
  }
  
  Future<void> signOut() async {
    try {
      await AppAuthService.signOut();
    } catch (e) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Sign in user with email and password
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final result = await _cognitoService.signIn(
        email: email,
        password: password,
      );
      
      if (result.isSignedIn) {
        // Get user data after successful sign in
        final userData = await AppAuthService.getCurrentUser();
        
        state = state.copyWith(
          status: AuthStatus.authenticated,
          isLoading: false,
          currentUser: userData,
        );
        
        // Register push token after successful sign in
        try {
          final businessId = userData?['custom:business_id'] ?? 
                            userData?['custom:businessId'] ?? 
                            userData?['businessId'];
          await PushNotificationsService.instance.registerTokenIfPossible(
            businessId: businessId is String ? businessId : null,
          );
          AppLogger.success('✅ Push token registration triggered after sign in');
        } catch (e) {
          AppLogger.warning('⚠️ Push token registration failed (non-critical): $e');
        }
        
        return {
          'success': true,
          'message': 'Sign in successful',
          'isSignedIn': true,
        };
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign in incomplete',
        );
        
        return {
          'success': false,
          'message': 'Sign in incomplete',
          'isSignedIn': false,
        };
      }
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      
      return {
        'success': false,
        'message': e.message,
        'error': e.toString(),
      };
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get user attributes from Cognito
  Future<Map<String, dynamic>?> getUserAttributes() async {
    try {
      final authUser = await Amplify.Auth.getCurrentUser();
      final attributes = await Amplify.Auth.fetchUserAttributes();
      
      final Map<String, dynamic> userAttributes = {
        'userId': authUser.userId,
        'username': authUser.username,
      };
      
      for (final attribute in attributes) {
        userAttributes[attribute.userAttributeKey.key] = attribute.value;
      }
      
      return userAttributes;
    } on AuthException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return null;
    } catch (e) {
      return null;
    }
  }
}

final authProviderRiverpod = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier();
  // Fire minimal initialization
  notifier.initialize();
  return notifier;
});
