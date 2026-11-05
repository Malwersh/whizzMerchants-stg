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
  AuthNotifier({
    Future<void> Function()? signOutAction,
    Future<bool> Function()? isSignedInAction,
    Future<Map<String, dynamic>?> Function()? currentUserAction,
    Future<void> Function(Map<String, dynamic>)? onRestored,
  }) : _signOutAction = signOutAction ?? AppAuthService.signOut,
       _isSignedInAction = isSignedInAction ?? AppAuthService.isSignedIn,
       _currentUserAction = currentUserAction ?? AppAuthService.getCurrentUser,
       _onRestored = onRestored ?? _registerRestoredPush,
       super(const AuthState());

  final Future<void> Function() _signOutAction;
  final Future<bool> Function() _isSignedInAction;
  final Future<Map<String, dynamic>?> Function() _currentUserAction;
  final Future<void> Function(Map<String, dynamic>) _onRestored;
  int _generation = 0;
  final CognitoAuthService _cognitoService = CognitoAuthService();

  static Future<void> _registerRestoredPush(Map<String, dynamic> user) async {
    final businessId =
        user['custom:business_id'] ??
        user['custom:businessId'] ??
        user['businessId'];
    await PushNotificationsService.instance.registerTokenIfPossible(
      businessId: businessId is String ? businessId : null,
    );
  }

  Future<void> initialize() async {
    final generation = ++_generation;
    state = AuthState(
      status: state.status,
      currentUser: state.currentUser,
      isLoading: true,
    );
    try {
      final signedIn = await _isSignedInAction();
      if (!mounted || generation != _generation) return;
      final user = signedIn ? await _currentUserAction() : null;
      if (!mounted || generation != _generation) return;
      state = AuthState(
        status: signedIn && user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        currentUser: user,
      );
      if (user != null) {
        try {
          await _onRestored(user);
        } catch (_) {
          /* Push availability does not determine authentication. */
        }
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = AuthState(
        status: state.status,
        currentUser: state.currentUser,
        errorMessage:
            'تعذر استعادة الجلسة الآن. تحقق من الاتصال وأعد المحاولة.',
      );
    }
  }

  void setAuthenticated() {
    ++_generation;
    state = state.copyWith(status: AuthStatus.authenticated);
  }

  Future<void> signOut() async {
    ++_generation;
    // Leave protected UI before clearing the branch/session it reads.
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isLoading: true,
    );
    try {
      await _signOutAction();
    } catch (_) {
      // Keep local navigation logged out even if remote cleanup fails.
    }
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
          final businessId =
              userData?['custom:business_id'] ??
              userData?['custom:businessId'] ??
              userData?['businessId'];
          await PushNotificationsService.instance.registerTokenIfPossible(
            businessId: businessId is String ? businessId : null,
          );
          AppLogger.success(
            '✅ Push token registration triggered after sign in',
          );
        } catch (e) {
          AppLogger.warning(
            '⚠️ Push token registration failed (non-critical): $e',
          );
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
      state = state.copyWith(isLoading: false, errorMessage: e.message);

      return {'success': false, 'message': e.message, 'error': e.toString()};
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());

      return {'success': false, 'message': e.toString()};
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

final authProviderRiverpod = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final notifier = AuthNotifier();
  // Fire minimal initialization
  notifier.initialize();
  return notifier;
});
