import '../services/merchant_financial_session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_auth_service.dart';
import '../services/cognito_auth_service.dart';
import '../services/push_notifications_service.dart';
import '../core/utils/app_logger.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'session_provider.dart';

enum AuthStatus { authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final bool restorePending;
  final String? errorMessage;
  final Map<String, dynamic>? currentUser;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.isLoading = false,
    this.restorePending = false,
    this.errorMessage,
    this.currentUser,
  });

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    bool? restorePending,
    String? errorMessage,
    Map<String, dynamic>? currentUser,
  }) => AuthState(
    status: status ?? this.status,
    isLoading: isLoading ?? this.isLoading,
    restorePending: restorePending ?? this.restorePending,
    errorMessage: errorMessage ?? this.errorMessage,
    currentUser: currentUser ?? this.currentUser,
  );

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    Future<void> Function()? signOutAction,
    Future<Map<String, dynamic>?> Function()? restoreUser,
    Future<void> Function()? restoreBranch,
  })  : _signOutAction = signOutAction ?? AppAuthService.signOut,
        _restoreUser = restoreUser ?? AppAuthService.restoreCurrentUser,
        _restoreBranch = restoreBranch,
        super(const AuthState());

  final Future<void> Function() _signOutAction;
  final Future<Map<String, dynamic>?> Function() _restoreUser;
  final Future<void> Function()? _restoreBranch;
  final CognitoAuthService _cognitoService = CognitoAuthService();
  int _authRevision = 0;

  Future<void> initialize() async {
    final revision = ++_authRevision;
    MerchantFinancialSessionState.instance.clear();
    state = const AuthState(isLoading: true);
    try {
      final user = await _restoreUser();
      if (!mounted || revision != _authRevision) return;
      if (user != null) await _restoreBranch?.call();
      if (!mounted || revision != _authRevision) return;

      state = AuthState(
        status: user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
        currentUser: user,
      );
      if (user != null) {
        final businessId = user['custom:business_id'] ??
            user['custom:businessId'] ??
            user['businessId'];
        try {
          await PushNotificationsService.instance.registerTokenIfPossible(
            businessId: businessId is String ? businessId : null,
          );
        } catch (error) {
          AppLogger.warning('Push registration skipped: ${error.runtimeType}');
        }
      }
    } catch (error) {
      if (!mounted || revision != _authRevision) return;
      state = const AuthState(restorePending: true);
    }
  }

  void setAuthenticated() {
    ++_authRevision;
    state = state.copyWith(status: AuthStatus.authenticated,
        isLoading: false, restorePending: false);
  }

  Future<void> signOut() async {
    ++_authRevision;
    MerchantFinancialSessionState.instance.clear();
    // Leave protected UI before clearing the branch/session it reads.
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: true,
    );
    try {
      await _signOutAction();
    } catch (e) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Sign in user with email and password
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    ++_authRevision;
    MerchantFinancialSessionState.instance.clear();
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
  final notifier = AuthNotifier(
    restoreBranch: () => ref.read(sessionProvider.notifier).restoreBusinessId(),
  );
  // Fire minimal initialization
  notifier.initialize();
  return notifier;
});
