/// Advanced Session Management Service
/// Professional-grade session handling with automatic token refresh,
/// session validation, and lifecycle management

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_state.dart';
import 'secure_token_storage.dart';

class AdvancedSessionService extends ChangeNotifier {
  static final AdvancedSessionService _instance = AdvancedSessionService._internal();
  factory AdvancedSessionService() => _instance;
  static AdvancedSessionService get instance => _instance;
  
  AdvancedSessionService._internal();

  // State management
  SessionState _currentState = const SessionInitial();
  SessionState get currentState => _currentState;

  // Session data
  String? _businessId;
  Map<String, dynamic>? _businessData;
  DateTime? _sessionExpiresAt;
  DateTime _lastActivity = DateTime.now();

  // Timers
  Timer? _refreshTimer;
  Timer? _validationTimer;
  Timer? _activityTimer;

  // Flags
  bool _isRefreshing = false;
  bool _isValidating = false;
  final bool _autoRefresh = true;
  final bool _autoExtend = true;

  // Configuration
  static const Duration _refreshBeforeExpiry = Duration(minutes: 5);
  static const Duration _validationInterval = Duration(minutes: 10);
  static const Duration _activityCheckInterval = Duration(minutes: 1);
  static const Duration _maxInactivityDuration = Duration(hours: 2);

  // Storage keys
  static const String _keyBusinessId = 'session_business_id';
  static const String _keyBusinessData = 'session_business_data';
  static const String _keyExpiresAt = 'session_expires_at';
  static const String _keyLastActivity = 'session_last_activity';

  // Getters
  String? get businessId => _businessId;
  Map<String, dynamic>? get businessData => _businessData;
  DateTime? get sessionExpiresAt => _sessionExpiresAt;
  DateTime get lastActivity => _lastActivity;
  bool get isAuthenticated => _currentState is SessionActive;
  bool get isExpired => _currentState is SessionExpired;

  /// Initialize session service - call on app start
  Future<void> initialize() async {
    debugPrint('🚀 AdvancedSessionService: Initializing...');
    
    try {
      _emitState(const SessionLoading(message: 'Checking session...'));
      
      // Load persisted session data
      await _loadPersistedSession();
      
      // Validate loaded session
      if (_businessId != null) {
        await _validateSession();
      } else {
        debugPrint('❌ AdvancedSessionService: No persisted session found');
        _emitState(const SessionTerminated(reason: 'No session found'));
      }
      
      // Start background timers
      _startBackgroundTimers();
      
      debugPrint('✅ AdvancedSessionService: Initialization complete');
    } catch (e) {
      debugPrint('❌ AdvancedSessionService: Initialization failed: $e');
      _emitState(SessionError(
        message: 'Failed to initialize session',
        requiresLogin: true,
      ));
    }
  }

  /// Load persisted session from storage
  Future<void> _loadPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _businessId = prefs.getString(_keyBusinessId);
      final businessDataJson = prefs.getString(_keyBusinessData);
      final expiresAtString = prefs.getString(_keyExpiresAt);
      final lastActivityString = prefs.getString(_keyLastActivity);
      
      if (businessDataJson != null) {
        _businessData = jsonDecode(businessDataJson);
      }
      
      if (expiresAtString != null) {
        _sessionExpiresAt = DateTime.parse(expiresAtString);
      }
      
      if (lastActivityString != null) {
        _lastActivity = DateTime.parse(lastActivityString);
      }
      
      debugPrint('📦 AdvancedSessionService: Loaded persisted session for businessId=$_businessId');
    } catch (e) {
      debugPrint('⚠️ AdvancedSessionService: Failed to load persisted session: $e');
    }
  }

  /// Persist session data to storage
  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_businessId != null) {
        await prefs.setString(_keyBusinessId, _businessId!);
      }
      
      if (_businessData != null) {
        await prefs.setString(_keyBusinessData, jsonEncode(_businessData));
      }
      
      if (_sessionExpiresAt != null) {
        await prefs.setString(_keyExpiresAt, _sessionExpiresAt!.toIso8601String());
      }
      
      await prefs.setString(_keyLastActivity, _lastActivity.toIso8601String());
      
      debugPrint('💾 AdvancedSessionService: Session persisted');
    } catch (e) {
      debugPrint('⚠️ AdvancedSessionService: Failed to persist session: $e');
    }
  }

  /// Create new session after login
  Future<void> createSession({
    required String businessId,
    required Map<String, dynamic> businessData,
    required String accessToken,
    required String idToken,
    required String refreshToken,
  }) async {
    debugPrint('🔐 AdvancedSessionService: Creating new session for businessId=$businessId');
    
    try {
      // Store tokens securely
      await SecureTokenStorage.setAccessToken(accessToken);
      await SecureTokenStorage.setIdToken(idToken);
      await SecureTokenStorage.setRefreshToken(refreshToken);
      
      // Calculate expiry from JWT
      DateTime? expiresAt;
      try {
        final decodedToken = JwtDecoder.decode(accessToken);
        if (decodedToken['exp'] != null) {
          expiresAt = DateTime.fromMillisecondsSinceEpoch(decodedToken['exp'] * 1000);
        }
      } catch (e) {
        debugPrint('⚠️ AdvancedSessionService: Failed to decode token expiry: $e');
      }
      
      // Update session data
      _businessId = businessId;
      _businessData = businessData;
      _sessionExpiresAt = expiresAt;
      _lastActivity = DateTime.now();
      
      // Persist to storage
      await _persistSession();
      
      // Emit active state
      _emitState(SessionActive(
        businessId: businessId,
        businessName: businessData['businessName'] ?? businessData['name'] ?? 'Unknown',
        email: businessData['email'] ?? 'unknown@email.com',
        businessData: businessData,
        expiresAt: expiresAt,
        lastActivity: _lastActivity,
      ));
      
      // Start background timers
      _startBackgroundTimers();
      
      debugPrint('✅ AdvancedSessionService: Session created successfully');
    } catch (e) {
      debugPrint('❌ AdvancedSessionService: Failed to create session: $e');
      _emitState(SessionError(
        message: 'Failed to create session: $e',
        requiresLogin: true,
      ));
    }
  }

  /// Validate current session
  Future<bool> _validateSession() async {
    if (_isValidating) {
      debugPrint('⏳ AdvancedSessionService: Validation already in progress');
      return false;
    }
    
    _isValidating = true;
    
    try {
      debugPrint('🔍 AdvancedSessionService: Validating session...');
      
      // Check if we have businessId
      if (_businessId == null) {
        debugPrint('❌ AdvancedSessionService: No businessId found');
        _emitState(const SessionExpired(reason: 'No businessId', canRefresh: false));
        return false;
      }
      
      // Get access token
      final accessToken = await SecureTokenStorage.getAccessToken();
      if (accessToken == null) {
        debugPrint('❌ AdvancedSessionService: No access token found');
        _emitState(const SessionExpired(reason: 'No access token', canRefresh: true));
        return false;
      }
      
      // Check JWT expiry locally first
      try {
        if (JwtDecoder.isExpired(accessToken)) {
          debugPrint('⚠️ AdvancedSessionService: Token expired locally');
          // Try to refresh
          if (_autoRefresh) {
            return await _refreshToken();
          } else {
            _emitState(const SessionExpired(reason: 'Token expired', canRefresh: true));
            return false;
          }
        }
      } catch (e) {
        debugPrint('⚠️ AdvancedSessionService: JWT decode error: $e');
      }
      
      // Validate with backend (optional - uncomment when API is ready)
      /*
      try {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/auth/validate-session'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'businessId': _businessId}),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.bodyBytes);
          if (data['valid'] == true) {
            debugPrint('✅ AdvancedSessionService: Session valid');
            _updateActivity();
            return true;
          }
        } else if (response.statusCode == 401) {
          debugPrint('❌ AdvancedSessionService: Session invalid (401)');
          if (_autoRefresh) {
            return await _refreshToken();
          } else {
            _emitState(const SessionExpired(reason: 'Session invalid', canRefresh: true));
            return false;
          }
        }
      } catch (e) {
        debugPrint('⚠️ AdvancedSessionService: Validation request failed: $e');
        // If validation fails, assume session is still valid (offline mode)
        return true;
      }
      */
      
      // If we reach here, session is valid
      debugPrint('✅ AdvancedSessionService: Session valid');
      _updateActivity();
      return true;
      
    } finally {
      _isValidating = false;
    }
  }

  /// Refresh access token using refresh token
  Future<bool> _refreshToken() async {
    if (_isRefreshing) {
      debugPrint('⏳ AdvancedSessionService: Refresh already in progress');
      return false;
    }
    
    _isRefreshing = true;
    
    try {
      debugPrint('🔄 AdvancedSessionService: Refreshing token...');
      
      if (_businessId != null) {
        _emitState(SessionRefreshing(businessId: _businessId!));
      }
      
      // Get refresh token
      final refreshToken = await SecureTokenStorage.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('❌ AdvancedSessionService: No refresh token found');
        _emitState(const SessionExpired(reason: 'No refresh token', canRefresh: false));
        return false;
      }
      
      // Call refresh API (uncomment when backend is ready)
      /*
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {
          'Authorization': 'Bearer $refreshToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.bodyBytes);
        
        // Store new tokens
        await SecureTokenStorage.storeAccessToken(data['accessToken']);
        await SecureTokenStorage.storeIdToken(data['idToken']);
        
        // Update expiry
        if (data['expiresIn'] != null) {
          _sessionExpiresAt = DateTime.now().add(Duration(seconds: data['expiresIn']));
          await _persistSession();
        }
        
        debugPrint('✅ AdvancedSessionService: Token refreshed successfully');
        _updateActivity();
        
        // Re-emit active state
        if (_businessId != null && _businessData != null) {
          _emitState(SessionActive(
            businessId: _businessId!,
            businessName: _businessData!['businessName'] ?? _businessData!['name'] ?? 'Unknown',
            email: _businessData!['email'] ?? 'unknown@email.com',
            businessData: _businessData!,
            expiresAt: _sessionExpiresAt,
            lastActivity: _lastActivity,
          ));
        }
        
        return true;
      } else if (response.statusCode == 401) {
        debugPrint('❌ AdvancedSessionService: Refresh token expired');
        _emitState(const SessionExpired(reason: 'Refresh token expired', canRefresh: false));
        return false;
      } else {
        debugPrint('❌ AdvancedSessionService: Refresh failed: ${response.statusCode}');
        _emitState(SessionError(message: 'Token refresh failed: ${response.statusCode}'));
        return false;
      }
      */
      
      // Temporary: Since API not ready, just log and return false
      debugPrint('⚠️ AdvancedSessionService: Refresh API not implemented yet');
      _emitState(const SessionExpired(reason: 'Token refresh not available', canRefresh: false));
      return false;
      
    } catch (e) {
      debugPrint('❌ AdvancedSessionService: Refresh failed: $e');
      _emitState(SessionError(message: 'Token refresh failed: $e'));
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Update last activity timestamp
  void _updateActivity() {
    _lastActivity = DateTime.now();
    _persistSession();
  }

  /// Record user activity (call this on user interactions)
  void recordActivity() {
    _updateActivity();
    debugPrint('👆 AdvancedSessionService: Activity recorded');
  }

  /// Start background timers for automatic session management
  void _startBackgroundTimers() {
    // Stop existing timers
    _stopBackgroundTimers();
    
    // Auto-refresh timer: checks if token needs refresh
    if (_autoRefresh && _sessionExpiresAt != null) {
      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _checkAndRefreshIfNeeded();
      });
      debugPrint('⏰ AdvancedSessionService: Refresh timer started');
    }
    
    // Validation timer: periodically validates session
    _validationTimer = Timer.periodic(_validationInterval, (timer) {
      _validateSession();
    });
    debugPrint('⏰ AdvancedSessionService: Validation timer started');
    
    // Activity timer: checks for inactivity
    _activityTimer = Timer.periodic(_activityCheckInterval, (timer) {
      _checkInactivity();
    });
    debugPrint('⏰ AdvancedSessionService: Activity timer started');
  }

  /// Stop all background timers
  void _stopBackgroundTimers() {
    _refreshTimer?.cancel();
    _validationTimer?.cancel();
    _activityTimer?.cancel();
    debugPrint('⏹️ AdvancedSessionService: Background timers stopped');
  }

  /// Check if token needs refresh and refresh if necessary
  Future<void> _checkAndRefreshIfNeeded() async {
    if (_sessionExpiresAt == null) return;
    
    final now = DateTime.now();
    final timeUntilExpiry = _sessionExpiresAt!.difference(now);
    
    if (timeUntilExpiry < _refreshBeforeExpiry && !_isRefreshing) {
      debugPrint('⚠️ AdvancedSessionService: Token expiring soon, refreshing...');
      await _refreshToken();
    }
  }

  /// Check for user inactivity
  void _checkInactivity() {
    final now = DateTime.now();
    final inactiveDuration = now.difference(_lastActivity);
    
    if (inactiveDuration > _maxInactivityDuration) {
      debugPrint('⚠️ AdvancedSessionService: User inactive for ${inactiveDuration.inMinutes} minutes');
      if (_autoExtend) {
        // Could extend session or show warning
        debugPrint('💡 AdvancedSessionService: Consider showing inactivity warning');
      }
    }
  }

  /// Logout and clear session
  Future<void> logout({bool callBackend = true}) async {
    debugPrint('🚪 AdvancedSessionService: Logging out...');
    
    try {
      // Call logout API (uncomment when backend is ready)
      if (callBackend && _businessId != null) {
        /*
        try {
          final accessToken = await SecureTokenStorage.getAccessToken();
          if (accessToken != null) {
            await http.post(
              Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'businessId': _businessId}),
            ).timeout(const Duration(seconds: 5));
          }
        } catch (e) {
          debugPrint('⚠️ AdvancedSessionService: Logout API call failed: $e');
        }
        */
      }
      
      // Clear all data
      await _clearSession();
      
      // Emit terminated state
      _emitState(const SessionTerminated(reason: 'User logged out'));
      
      debugPrint('✅ AdvancedSessionService: Logged out successfully');
    } catch (e) {
      debugPrint('❌ AdvancedSessionService: Logout failed: $e');
      _emitState(SessionError(message: 'Logout failed: $e'));
    }
  }

  /// Clear all session data
  Future<void> _clearSession() async {
    // Stop timers
    _stopBackgroundTimers();
    
    // Clear memory
    _businessId = null;
    _businessData = null;
    _sessionExpiresAt = null;
    
    // Clear secure storage
    await SecureTokenStorage.clearAll();
    
    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBusinessId);
    await prefs.remove(_keyBusinessData);
    await prefs.remove(_keyExpiresAt);
    await prefs.remove(_keyLastActivity);
    
    debugPrint('🧹 AdvancedSessionService: Session cleared');
  }

  /// Emit new state
  void _emitState(SessionState newState) {
    if (_currentState.runtimeType != newState.runtimeType) {
      _currentState = newState;
      notifyListeners();
      debugPrint('📢 AdvancedSessionService: State changed to ${newState.runtimeType}');
    }
  }

  /// Dispose and cleanup
  @override
  void dispose() {
    _stopBackgroundTimers();
    super.dispose();
  }
}
