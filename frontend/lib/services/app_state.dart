import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AppState with ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal() {
    _loadPersistedStatus();
  }

  bool _isOnline = true; // Start with default, will be synced from database

  bool get isOnline => _isOnline;

  /// Load persisted online status from SharedPreferences and sync with database
  Future<void> _loadPersistedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load from local storage first for immediate UI update
      _isOnline = prefs.getBool('business_online_status') ?? true;
      notifyListeners();
      
      debugPrint('📱 AppState: Loaded persisted status: $_isOnline');
    } catch (e) {
      debugPrint('❌ AppState: Failed to load persisted status: $e');
    }
  }

  /// Initialize online status from database for a specific business
  /// This should be called after authentication to get the real database value
  Future<void> initializeOnlineStatusFromDatabase(String businessId) async {
    try {
      debugPrint('🔄 AppState: Initializing online status from database for business: $businessId');
      
      final apiService = ApiService();
      
      // Get current status from database
      debugPrint('📡 AppState: Making API call to get business status...');
      final response = await apiService.getBusinessOnlineStatus(businessId);
      debugPrint('📡 AppState: API response received: $response');
      
      if (response['success'] == true && response['data'] != null) {
        final bool actualStatus = response['data']['acceptingOrders'] ?? true;
        
        debugPrint('📊 AppState: Database status: $actualStatus, Setting as initial status');
        
        // Set the initial status from database
        _isOnline = actualStatus;
        await _savePersistedStatus(_isOnline);
        notifyListeners();
        
        debugPrint('✅ AppState: Successfully initialized status from database: $actualStatus');
      } else {
        debugPrint('⚠️ AppState: Failed to get status from database, keeping default true');
        debugPrint('⚠️ AppState: Response details: $response');
      }
    } catch (e) {
      debugPrint('❌ AppState: Failed to initialize status from database: $e');
      debugPrint('❌ AppState: Error type: ${e.runtimeType}');
      // Keep default status on error
    }
  }

  /// Sync online status with database and update local state
  /// This should be called after successful authentication
  Future<void> syncOnlineStatusFromDatabase(String businessId) async {
    try {
      debugPrint('🔄 AppState: Syncing online status from database for business: $businessId');
      
      final apiService = ApiService();
      
      // Get current status from database
      final response = await apiService.getBusinessOnlineStatus(businessId);
      
      if (response['success'] == true && response['data'] != null) {
        final bool actualStatus = response['data']['acceptingOrders'] ?? true;
        
        debugPrint('📊 AppState: Database status: $actualStatus, Local status: $_isOnline');
        
        // Update local state if different from database
        if (_isOnline != actualStatus) {
          debugPrint('🔄 AppState: Updating local status to match database: $actualStatus');
          _isOnline = actualStatus;
          await _savePersistedStatus(_isOnline);
          notifyListeners();
        } else {
          debugPrint('✅ AppState: Local status matches database');
        }
      } else {
        debugPrint('⚠️ AppState: Failed to get status from database, keeping local status');
      }
    } catch (e) {
      debugPrint('❌ AppState: Failed to sync status from database: $e');
      // Keep local status on error
    }
  }

  /// Save online status to SharedPreferences for persistence
  Future<void> _savePersistedStatus(bool isOnline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('business_online_status', isOnline);
    } catch (e) {
      debugPrint('❌ AppState: Failed to save persisted status: $e');
    }
  }

  void updateOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    _savePersistedStatus(_isOnline);
    notifyListeners();
  }
  
  bool _isToggling = false;
  bool get isToggling => _isToggling;
  
  /// Set online status and trigger backend update
  /// This is used by toggle components
  Future<void> setOnline(bool value, Future<void> Function(bool) onToggleCallback) async {
    try {
      _isToggling = true;
      notifyListeners(); // Notify about toggling state
      
      // Call the provided toggle callback (usually backend API call)
      await onToggleCallback(value);
      
      // Update local state only after successful backend call
      _isOnline = value;
      await _savePersistedStatus(_isOnline);
      
    } catch (e) {
      debugPrint('❌ AppState: Failed to set online status: $e');
      rethrow; // Let the UI handle the error
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  void logout() {
    // Reset app state on logout
    _isOnline = true;
    notifyListeners();
  }

  /// Sync online status with database on login
  /// This ensures the toggle reflects the actual database status after login
  Future<void> forceOnlineOnLogin(String businessId, String userId) async {
    try {
      debugPrint('🔄 AppState: Syncing online status from database after login');
      debugPrint('   Business ID: $businessId');
      debugPrint('   User ID: $userId');

      // Initialize status from database instead of forcing online
      await initializeOnlineStatusFromDatabase(businessId);

      debugPrint('✅ AppState: Successfully synced online status after login');
    } catch (e) {
      debugPrint('❌ AppState: Failed to sync online status after login: $e');
      // Don't throw error to prevent login failure
      
      // Fallback: keep current local status or default to true
      if (_isOnline != true) {
        debugPrint('🔄 AppState: Fallback - setting to online as default');
        _isOnline = true;
        await _savePersistedStatus(true);
        notifyListeners();
      }
    }
  }
}
