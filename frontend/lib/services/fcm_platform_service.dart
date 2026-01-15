import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'navigation_service.dart';

/// FCM Service using Platform Channels to communicate with native Firebase
/// Firebase is initialized in native code (iOS: AppDelegate.swift, Android: MainActivity.kt)
/// This service just communicates with the native side to get tokens and handle notifications
class FCMPlatformService {
  static final FCMPlatformService _instance = FCMPlatformService._internal();
  factory FCMPlatformService() => _instance;
  FCMPlatformService._internal();

  // Platform channel for FCM communication
  static const platform = MethodChannel('com.whizz.merchants/fcm');

  String? _fcmToken;
  bool _isInitialized = false;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of received messages (foreground)
  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  /// Stream of notification taps
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize FCM Platform Service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔥 FCM Platform Service already initialized');
      return;
    }

    try {
      debugPrint('🔥 Initializing FCM Platform Service...');

      // Set up method call handler to receive messages from native
      platform.setMethodCallHandler(_handleMethodCall);
      debugPrint('✅ Method call handler set up');

      // Request notification permissions
      await requestPermissions();

      // Get FCM token
      await getFCMToken();

      _isInitialized = true;
      debugPrint('🎉 FCM Platform Service initialized successfully!');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize FCM Platform Service: $e');
      debugPrint('Stack trace: $stackTrace');
      // Mark as initialized even on failure to prevent retry loops
      _isInitialized = true;
      rethrow;
    }
  }

  /// Handle method calls from native code
  Future<void> _handleMethodCall(MethodCall call) async {
    debugPrint('📞 Method call from native: ${call.method}');

    switch (call.method) {
      case 'onTokenRefresh':
        final token = call.arguments as String?;
        if (token != null) {
          _fcmToken = token;
          debugPrint('🎫 Token refreshed: $token');
        }
        break;

      case 'onMessageReceived':
        final message = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('📬 Message received: $message');
        _messageController.add(message);
        break;

      case 'onNotificationTapped':
        final notification = Map<String, dynamic>.from(call.arguments as Map);
        debugPrint('👆 Notification tapped: $notification');
        _notificationTapController.add(notification);
        // Navigate to orders for now
        NavigationService.navigateToOrders();
        break;

      default:
        debugPrint('⚠️ Unknown method call: ${call.method}');
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      debugPrint('🔔 Requesting notification permissions...');
      final bool granted =
          await platform.invokeMethod('requestNotificationPermissions');
      debugPrint('🔔 Notification permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('❌ Failed to request permissions: $e');
      return false;
    }
  }

  /// Get FCM token from native code
  Future<String?> getFCMToken() async {
    try {
      debugPrint('🎫 Fetching FCM token from native...');
      final String? token = await platform.invokeMethod('getFCMToken');
      _fcmToken = token;
      debugPrint('✅ FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _messageController.close();
    _notificationTapController.close();
  }
}
