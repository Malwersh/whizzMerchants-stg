import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/secure_token_storage.dart';
import '../services/branch_session_store.dart';
import '../services/merchant_branch_scope.dart';
import '../services/app_state.dart';
import '../services/realtime_order_service.dart';

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
        isExpiredDueToInactivity:
            isExpiredDueToInactivity ?? this.isExpiredDueToInactivity,
        isReady: isReady ?? this.isReady,
      );
}

class SessionNotifier extends StateNotifier<Session> {
  // 🔧 FIX: Add session readiness tracking
  bool _isSessionReady = false;
  Completer<void>? _sessionReadyCompleter;
  bool _isPerformingLogout = false;

  final BranchSessionStore _store;
  int _generation = 0;
  Future<void> _persistence = Future<void>.value();
  SessionNotifier({BranchSessionStore? store, bool restoreOnStart = true})
      : _store = store ?? BranchSessionStore(),
        super(Session.initial()) {
    if (restoreOnStart) {
      _restoreSession();
    } else {
      _isSessionReady = true;
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _persistence.then((_) => action());
    _persistence = next.catchError((Object _) {});
    return next;
  }

  void _ready() {
    _isSessionReady = true;
    if (_sessionReadyCompleter?.isCompleted == false)
      _sessionReadyCompleter!.complete();
    _sessionReadyCompleter = null;
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
        debugPrint(
            '⚠️ SessionProvider: No token found - user needs to re-login');
        // Don't auto-logout - like wizzuser approach
        return;
      }

      // Check JWT expiry locally (like wizzuser) - NO auto-logout!
      try {
        if (JwtDecoder.isExpired(token)) {
          debugPrint(
              '⚠️ SessionProvider: Token expired - user will need to re-login');
          // Log only - don't clear session (wizzuser approach)
          return;
        }

        final remainingTime = JwtDecoder.getRemainingTime(token);
        debugPrint(
            '✅ SessionProvider: Session valid, remaining: ${remainingTime.inMinutes} min');
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
    await restoreBusinessId();
  }

  Future<void> setSessionWithBusinessData(
      String businessId, Map<String, dynamic> businessData) async {
    if (_isPerformingLogout || !mounted) return;
    if (businessId.trim().isEmpty ||
        ((businessData['businessId'] ?? businessData['id']) != null &&
            (businessData['businessId'] ?? businessData['id']) != businessId)) {
      throw ArgumentError('بيانات الفرع لا تطابق الفرع المختار.');
    }
    final generation = ++_generation;
    final data = Map<String, dynamic>.from(businessData);
    // Publish the selection synchronously. Old readers are invalid immediately.
    MerchantBranchScope.selectionChanged(businessId);
    AppState().selectBranch(businessId);
    RealtimeOrderService().selectBranch(businessId);
    state = Session(
        isAuthenticated: true,
        businessId: businessId,
        businessData: data,
        isReady: true);
    _ready();
    await _enqueue(() async {
      if (generation != _generation || !mounted) return;
      await _store.save(businessId, data);
    });
  }

  Future<void> restoreBusinessId() async {
    final generation = _generation;
    try {
      final restored = await _store.read();
      if (!mounted || generation != _generation || _isPerformingLogout) return;
      MerchantBranchScope.selectionChanged(restored.businessId);
      AppState().selectBranch(restored.businessId);
      RealtimeOrderService().selectBranch(restored.businessId);
      state = Session(
          isAuthenticated: restored.authenticated,
          businessId: restored.businessId,
          businessData: restored.businessData,
          isReady: true);
      if (restored.businessId == null)
        await _enqueue(() async {
          if (generation == _generation) await _store.clear();
        });
    } catch (_) {
      if (mounted && generation == _generation)
        state = const Session(isReady: true);
    } finally {
      _ready();
    }
  }

  /// Only the reader that observed this exact session may clear its selection.
  Future<void> clearBusinessSelection({Session? expected}) async {
    if (!mounted || (expected != null && !identical(state, expected))) return;
    ++_generation;
    MerchantBranchScope.selectionChanged(null);
    AppState().selectBranch(null);
    RealtimeOrderService().selectBranch(null);
    state = Session(isAuthenticated: state.isAuthenticated, isReady: true);
    _ready();
    await _enqueue(_store.clear);
  }

  Future<void> clearSession() async {
    if (!mounted) return;
    ++_generation;
    _isPerformingLogout = true;
    MerchantBranchScope.selectionChanged(null);
    AppState().selectBranch(null);
    RealtimeOrderService().selectBranch(null);
    state = const Session(isReady: true);
    _ready();
    try {
      await _enqueue(_store.clear);
    } finally {
      _isPerformingLogout = false;
    }
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, Session>((ref) {
  return SessionNotifier();
});
