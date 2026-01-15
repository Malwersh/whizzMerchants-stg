/// Advanced Session Provider with Riverpod
/// Professional state management for session lifecycle

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_state.dart';
import '../services/advanced_session_service.dart';

/// Global session service instance
final advancedSessionServiceProvider = Provider<AdvancedSessionService>((ref) {
  return AdvancedSessionService.instance;
});

/// Session state provider - listens to session service
final advancedSessionStateProvider = ChangeNotifierProvider<AdvancedSessionService>((ref) {
  return AdvancedSessionService.instance;
});

/// Convenience provider - current session state
final currentSessionStateProvider = Provider<SessionState>((ref) {
  final service = ref.watch(advancedSessionStateProvider);
  return service.currentState;
});

/// Convenience provider - is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final state = ref.watch(currentSessionStateProvider);
  return state is SessionActive;
});

/// Convenience provider - business ID
final businessIdProvider = Provider<String?>((ref) {
  final service = ref.watch(advancedSessionStateProvider);
  return service.businessId;
});

/// Convenience provider - business data
final businessDataProvider = Provider<Map<String, dynamic>?>((ref) {
  final service = ref.watch(advancedSessionStateProvider);
  return service.businessData;
});

/// Convenience provider - session expires at
final sessionExpiresAtProvider = Provider<DateTime?>((ref) {
  final service = ref.watch(advancedSessionStateProvider);
  return service.sessionExpiresAt;
});

/// Convenience provider - is session expired
final isSessionExpiredProvider = Provider<bool>((ref) {
  final state = ref.watch(currentSessionStateProvider);
  return state is SessionExpired;
});

/// Convenience provider - session error
final sessionErrorProvider = Provider<SessionError?>((ref) {
  final state = ref.watch(currentSessionStateProvider);
  return state is SessionError ? state : null;
});
