import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/secure_token_storage.dart';

class Session {
  final String? businessId;
  final bool isAuthenticated;
  final Map<String, dynamic>? businessData;
  final bool isExpired;
  final bool isExpiredDueToInactivity;
  final bool isReady; // ← NEW: Track session readiness

  const Session({
    this.businessId,
    this.isAuthenticated = false,
    this.businessData,
    this.isExpired = false,
    this.isExpiredDueToInactivity = false,
    this.isReady = false,
  });

  // Initial/default session (logged out, no business)
  factory Session.initial() => const Session(isReady: false);

  Session copyWith({
    String? businessId,
    bool? isAuthenticated,
    Map<String, dynamic>? businessData,
    bool? isExpired,
    bool? isExpiredDueToInactivity,
    bool? isReady,
  }) =>
      Session(
        businessId: businessId ?? this.businessId,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        businessData: businessData ?? this.businessData,
        isExpired: isExpired ?? this.isExpired,
        isExpiredDueToInactivity: isExpiredDueToInactivity ?? this.isExpiredDueToInactivity,
        isReady: isReady ?? this.isReady,
      );
}

class SessionNotifier extends StateNotifier<Session> {
  // 🔧 FIX: Add session readiness tracking
  bool _isSessionReady = false;
  Completer<void>? _sessionReadyCompleter;
  bool _isPerformingLogout = false;
  bool _isRestoringSession = false;

  SessionNotifier() : super(Session.initial()) {
    _restoreSession();
  }

  /// Wait for session to be fully ready before making API calls
  Future<void> waitForSessionReady() async {
    if (!_isSessionReady) {
      _sessionReadyCompleter ??= Completer<void>();
      await _sessionReadyCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ SessionProvider: Session readiness timeout');
          _isSessionReady = true;
        },
      );
    }
  }

  /// Safe state update - prevents updates during logout or restoration
  void _safeStateUpdate(Session newState) {
    // Prevent updates during critical operations
    if (_isPerformingLogout && newState.isAuthenticated) {
      debugPrint('⚠️ SessionProvider: Blocking state update during logout');
      return;
    }
    
    if (_isRestoringSession && mounted) {
      // Allow updates during restoration
      state = newState;
      return;
    }
    
    if (mounted) {
      state = newState;
    }
  }

  /// Safe emit - prevents duplicate state emissions
  void _safeEmit(Session newState) {
    // Ignore updates during logout (except initial state)
    if (_isPerformingLogout && newState.isAuthenticated) {
      debugPrint('⚠️ SessionProvider: Blocking state emission during logout');
      return;
    }
    
    // Prevent duplicate states
    if (state.isAuthenticated == newState.isAuthenticated &&
        state.businessId == newState.businessId &&
        state.isExpired == newState.isExpired) {
      debugPrint('⚠️ SessionProvider: Preventing duplicate state emission');
      return;
    }
    
    if (mounted) {
      state = newState;
      debugPrint('✅ SessionProvider: State emitted - auth: ${newState.isAuthenticated}, expired: ${newState.isExpired}');
    }
  }

  /// Validate current session (check token expiry)
  /// Following wizzuser's approach: JWT validation only, no auto-logout
  Future<void> _validateCurrentSession() async {
    if (!state.isAuthenticated) {
      debugPrint('ℹ️ SessionProvider: Not authenticated, skipping validation');
      return;
    }
    
    // Prevent validation during logout
    if (_isPerformingLogout) {
      debugPrint('⏸️ SessionProvider: Skipping validation during logout');
      return;
    }
    
    debugPrint('🔍 SessionProvider: Validating current session...');
    
    try {
      final token = await SecureTokenStorage.getAccessToken();
      
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ SessionProvider: No token found - user needs to re-login');
        // Don't auto-logout - like wizzuser approach
        return;
      }
      
      // Check JWT expiry locally (like wizzuser) - NO auto-logout!
      try {
        if (JwtDecoder.isExpired(token)) {
          debugPrint('⚠️ SessionProvider: Token expired - user will need to re-login');
          // Log only - don't clear session (wizzuser approach)
          return;
        }
        
        final remainingTime = JwtDecoder.getRemainingTime(token);
        debugPrint('✅ SessionProvider: Session valid, remaining: ${remainingTime.inMinutes} min');
        
      } catch (jwtError) {
        debugPrint('⚠️ SessionProvider: Could not validate token: $jwtError');
        // Don't clear session on JWT errors (wizzuser approach)
      }
      
    } catch (e) {
      debugPrint('❌ SessionProvider: Error validating session: $e');
      // Don't clear session on validation errors - just log
    }
  }

  /// Called when app resumes from background
  Future<void> onAppResumed() async {
    debugPrint('🔄 SessionProvider: App resumed, validating session...');
    await _validateCurrentSession();
  }

  /// Backwards-compatible helper: sets session with only businessId
  /// Used by older code paths like AppAuthService.getCurrentUser and login_page
  Future<void> setSession(String businessId) async {
    // Delegate to the full method with empty businessData
    await setSessionWithBusinessData(businessId, <String, dynamic>{});
  }

  Future<void> _restoreSession() async {
    debugPrint('🔄 SessionProvider: _restoreSession started');
    _isRestoringSession = true;
    _isSessionReady = false;
    
    try {
      await restoreBusinessId();
      
      // Mark session as ready
      _isSessionReady = true;
      _sessionReadyCompleter?.complete();
      debugPrint('✅ SessionProvider: Session restoration complete and ready');
    } catch (e) {
      debugPrint('❌ SessionProvider: Error during session restoration: $e');
      _isSessionReady = true;
      _sessionReadyCompleter?.complete();
    } finally {
      _isRestoringSession = false;
    }
  }

  Future<void> setSessionWithBusinessData(
    String businessId,
    Map<String, dynamic> businessData,
  ) async {
    debugPrint(
        '📝 SessionProvider: setSessionWithBusinessData called with businessId=$businessId');

    // Prevent updates during logout
    if (_isPerformingLogout) {
      debugPrint('⏸️ SessionProvider: Ignoring session update during logout');
      return;
    }

    // 🔧 Following wizzuser: Mark session as not ready during update
    _isSessionReady = false;
    _sessionReadyCompleter = Completer<void>();

    try {
      // 🔧 Following wizzuser: Update in-memory state IMMEDIATELY before persistence
      final newSession = state.copyWith(
        isAuthenticated: true,
        businessId: businessId,
        businessData: businessData,
        isExpired: false,
        isExpiredDueToInactivity: false,
      );
      
      _safeStateUpdate(newSession);
      debugPrint('✅ SessionProvider: In-memory state updated immediately (wizzuser pattern)');

      // Persist to disk (async, but memory already updated)
      await _persistBusinessId(businessId);
      await _persistBusinessData(businessData);
      
      debugPrint('✅ SessionProvider: Session persisted to disk');
    } finally {
      // 🔧 Following wizzuser: Mark session as ready
      _isSessionReady = true;
      _sessionReadyCompleter?.complete();
      _sessionReadyCompleter = null;
      debugPrint('✅ SessionProvider: Session is now ready');
    }
  }

  Future<void> _persistBusinessId(String businessId) async {
    debugPrint(
        '💾 SessionProvider: _persistBusinessId called with businessId=$businessId');
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString('business_id', businessId);
    debugPrint('✅ SessionProvider: business_id persisted: $ok');

    // Also persist securely for cold-start restore
    try {
      await SecureTokenStorage.setBusinessId(businessId);
    } catch (e) {
      debugPrint('⚠️ SessionProvider: failed to store businessId securely: $e');
    }
  }

  Future<void> _persistBusinessData(Map<String, dynamic> businessData) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(businessData);
    final ok = await prefs.setString('business_data', jsonString);
    debugPrint(
        '✅ SessionProvider: business_data persisted: $ok, length=${jsonString.length}');
  }

  Future<void> restoreBusinessId() async {
    debugPrint('🔍 🔄 SessionProvider: restoreBusinessId called');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedId = prefs.getString('business_id');

      // Fallback to secure storage if SharedPreferences is empty
      storedId ??= await SecureTokenStorage.getBusinessId();
      debugPrint('🔍 🔄 SessionProvider: stored business_id=$storedId');

      if (storedId == null || storedId.isEmpty) {
        debugPrint('🔍 🔄 SessionProvider: no stored business_id found');
        return;
      }

      // 🔧 FIX: Don't check token expiry during cold start - just restore session
      // Following wizzbussiness pattern: restore businessId immediately, let API calls handle expired tokens
      final token = await SecureTokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ SessionProvider: no access token found - restoring businessId without token');
        // Still restore businessId - user will be prompted to login when making API calls
      } else {
        // Just log token info without blocking session restoration
        try {
          if (JwtDecoder.isExpired(token)) {
            debugPrint('⚠️ SessionProvider: Token expired - user will be prompted to re-login on first API call');
          } else {
            final remainingTime = JwtDecoder.getRemainingTime(token);
            debugPrint('✅ SessionProvider: Token valid, remaining time: ${remainingTime.inMinutes} minutes');
          }
        } catch (jwtError) {
          debugPrint('⚠️ SessionProvider: Token validation failed: $jwtError');
        }
      }

      // ✅ Always restore businessId - don't block on token expiry
      // This matches wizzbussiness approach: restore session, let UI handle expired tokens
      final restoredSession = state.copyWith(
        isAuthenticated: true,
        businessId: storedId,
        isExpired: false,
        isExpiredDueToInactivity: false,
      );
      
      _safeStateUpdate(restoredSession);

      // Try to restore cached business data
      final jsonString = prefs.getString('business_data');
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final map = jsonDecode(jsonString) as Map<String, dynamic>;
          final sessionWithData = state.copyWith(businessData: map);
          _safeStateUpdate(sessionWithData);
          debugPrint('✅ SessionProvider: restored cached business_data');
        } catch (e) {
          debugPrint('⚠️ SessionProvider: failed to decode business_data: $e');
        }
      }
      
      debugPrint('✅ SessionProvider: Business session restored successfully');
    } catch (e) {
      debugPrint('❌ SessionProvider: Error restoring business session: $e');
    }
  }

  Future<void> clearBusinessSelection() async {
    await SecureTokenStorage.clearBusinessId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('business_data');
    state = Session(isAuthenticated: state.isAuthenticated, isReady: true);
  }

  Future<void> clearSession() async {
    debugPrint('🧹 SessionProvider: clearSession called');
    
    // 🔧 Following wizzuser: Set logout flag to prevent race conditions
    _isPerformingLogout = true;
    _isSessionReady = false;
    
    try {
      // 🔧 Following wizzuser: Clear in-memory state first
      _safeStateUpdate(Session.initial());
      debugPrint('✅ SessionProvider: In-memory state cleared');

      // Clear persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('business_id');
      await prefs.remove('business_data');
      
      // Also clear from secure storage
      try {
        await SecureTokenStorage.clearBusinessId(); // Clear business ID from secure storage
      } catch (e) {
        debugPrint('⚠️ SessionProvider: failed to clear businessId from secure storage: $e');
      }
      
      debugPrint(
          '✅ SessionProvider: cleared persisted business_id and business_data from all storage');
    } finally {
      // 🔧 Following wizzuser: Reset flags after delay
      await Future.delayed(const Duration(milliseconds: 500));
      _isPerformingLogout = false;
      _isSessionReady = true;
      _sessionReadyCompleter?.complete();
      _sessionReadyCompleter = null;
      debugPrint('✅ SessionProvider: Session clear complete, flags reset');
    }
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session>((ref) {
  return SessionNotifier();
});
