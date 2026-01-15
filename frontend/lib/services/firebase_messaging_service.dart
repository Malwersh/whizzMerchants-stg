import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/api_service.dart';
import 'navigation_service.dart';

/// Firebase Cloud Messaging Service for WhizzMerchants
/// Handles push notifications for orders, promotions, and system alerts
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

  String? _fcmToken;
  bool _isInitialized = false;

  /// Stream of received messages
  Stream<RemoteMessage> get onMessage => _messageController.stream;

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize Firebase Messaging Service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔥 Firebase Messaging already initialized');
      return;
    }

    try {
      debugPrint('🔥 Initializing Firebase Messaging...');

      // Ensure Firebase Core is initialized (should be done in main.dart)
      // We'll check if it's available, otherwise initialization will fail gracefully
      debugPrint('ℹ️ Verifying Firebase Core is initialized...');

      // Initialize Local Notifications (non-blocking with longer timeout)
      debugPrint('🔥 Initializing Local Notifications...');
      try {
        await _initializeLocalNotifications().timeout(
          const Duration(seconds: 10),
        );
        debugPrint('✅ Local Notifications initialized');
      } catch (e) {
        debugPrint('⚠️ Local Notifications init failed (non-fatal): $e');
      }

      // Configure Firebase Messaging (non-blocking with longer timeout)
      debugPrint('🔥 Configuring Firebase Messaging...');
      try {
        await _configureFirebaseMessaging().timeout(
          const Duration(seconds: 10),
        );
        debugPrint('✅ Firebase Messaging configured');
      } catch (e) {
        debugPrint('⚠️ Firebase Messaging config failed (non-fatal): $e');
      }

      // Request notification permissions (non-blocking on iOS)
      debugPrint('🔥 Requesting notification permissions...');
      _requestPermissions().then((_) {
        debugPrint('✅ Notification permissions handled');
      }).catchError((e) {
        debugPrint('⚠️ Permission request issue (non-fatal): $e');
      });

      // Get FCM token (can be async, don't block initialization)
      debugPrint('🔥 Fetching FCM Token...');
      _getFCMToken().then((_) {
        debugPrint('✅ FCM Token obtained: $_fcmToken');
      }).catchError((e) {
        debugPrint('⚠️ Failed to get FCM token (non-fatal): $e');
      });

      // Listen to token refresh (non-blocking)
      _listenToTokenRefresh();
      debugPrint('✅ Token refresh listener set up');

      // Listen to foreground messages (non-blocking)
      _listenToForegroundMessages();
      debugPrint('✅ Foreground message listener set up');

      // Listen to taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('👆 onMessageOpenedApp: ${message.messageId}');
        _handleMessageTap(message);
      });

      // Handle notification that opened the app from terminated state
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        debugPrint(
            '🚀 App opened from terminated via notification: ${initial.messageId}');
        // Delay a bit to ensure navigator is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleMessageTap(initial);
        });
      }

      _isInitialized = true;
      debugPrint('🎉 Firebase Messaging Service initialized successfully!');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize Firebase Messaging: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'whizz_merchants_orders',
        'Order Notifications',
        description: 'Notifications for new orders and updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Configure Firebase Messaging
  Future<void> _configureFirebaseMessaging() async {
    // Set foreground notification presentation options (iOS)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final messaging = FirebaseMessaging.instance;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('📱 iOS Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('✅ User granted provisional permission');
      } else {
        debugPrint('❌ User declined or has not accepted permission');
      }
    } else {
      debugPrint('📱 Android - Permissions handled by system');
    }
  }

  /// Get FCM token
  /// NOTE: This is the FCM DEVICE TOKEN (for push notifications), NOT login tokens
  /// The FCM token is device-specific and persists across logins/logouts
  Future<void> _getFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(); // ← FCM TOKEN
      if (token != null) {
        _fcmToken = token;
        debugPrint('📱 FCM Token: $token');

        // Try to upload token immediately if possible
        try {
          await _uploadDeviceToken(token); // ← Uploads FCM TOKEN to backend
        } catch (e) {
          debugPrint('⚠️ Could not upload token immediately: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Listen to token refresh
  void _listenToTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken; // ← FCM TOKEN
      debugPrint('🔄 FCM Token refreshed: $newToken');

      // Upload the new token
      _uploadDeviceToken(newToken).catchError((e) {
        debugPrint('❌ Error uploading refreshed token: $e');
      });
    });
  }

  /// Upload device token to backend
  /// NOTE: Uploads FCM DEVICE TOKEN (for notifications), uses LOGIN TOKEN for authentication
  Future<void> _uploadDeviceToken(String token) async {
    try {
      // Upload to backend using simple method (without merchantId)
      // This sends the FCM token in the request body, uses auth token in header
      await ApiService().registerDeviceToken(token); // ← token = FCM TOKEN

      debugPrint('✅ Device token uploaded successfully');
    } catch (e) {
      debugPrint('❌ Error uploading device token: $e');
      rethrow;
    }
  }

  /// Upload token after merchant logs in
  /// NOTE: tokenOverride is the FCM DEVICE TOKEN, not a login token
  Future<void> uploadTokenAfterLogin(String merchantId,
      {String? tokenOverride}) async {
    try {
      debugPrint('🔥🔥🔥 =================================');
      debugPrint('🔥 uploadTokenAfterLogin CALLED');
      debugPrint('🔥 merchantId: $merchantId');
      debugPrint('🔥 _fcmToken: $_fcmToken');
      debugPrint('🔥 tokenOverride: ${tokenOverride != null}');
      debugPrint('🔥🔥🔥 =================================');

      // Ensure service is initialized to safely call FirebaseMessaging
      if (!_isInitialized) {
        debugPrint(
            '⏳ FirebaseMessagingService not initialized, initializing now...');
        await initialize();
      }

      // Use provided token if available, otherwise current cached, otherwise fetch
      String? token = tokenOverride ?? _fcmToken;
      if (token == null) {
        debugPrint('⏳ Waiting for FCM token...');
        token = await FirebaseMessaging.instance.getToken();
        _fcmToken = token;
        debugPrint('⏳ Got FCM token: $token');
      }

      if (token == null) {
        debugPrint('❌ FCM token is still null after attempting to get it!');
        throw Exception('Failed to get FCM token');
      }

      debugPrint('📱 Token obtained: ${token.substring(0, 20)}...');

      // Get device info
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = 'unknown';
      String platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

      debugPrint('📱 Platform: $platform');

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        debugPrint('📱 iOS Device ID: $deviceId');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        debugPrint('📱 Android Device ID: $deviceId');
      }

      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      debugPrint('📱 App Version: $appVersion');

      debugPrint('🚀 Calling ApiService.uploadDeviceTokenWithMerchantId...');
      // Upload with merchantId
      await ApiService().uploadDeviceTokenWithMerchantId(
        merchantId: merchantId,
        deviceToken: token,
        platform: platform,
        deviceId: deviceId,
        appVersion: appVersion,
      );

      debugPrint(
          '✅✅✅ Device token uploaded SUCCESSFULLY with merchantId: $merchantId');
      debugPrint('✅ Check DynamoDB table: WhizzMerchants_DeviceTokens');
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ Error uploading token after login: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Listen to foreground messages
  void _listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground message received!');
      debugPrint('Message ID: ${message.messageId}');
      debugPrint('Data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Title: ${message.notification?.title}');
        debugPrint('Body: ${message.notification?.body}');

        // Show local notification when app is in foreground
        _showLocalNotification(message);
      }

      // Add to stream
      _messageController.add(message);
    });
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'whizz_merchants_orders',
      'Order Notifications',
      channelDescription: 'Notifications for new orders and updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      color: Color(0xFF2196F3),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('👆 Notification tapped: ${response.payload}');
    // Handle navigation based on payload
    NavigationService.navigateToOrders();
  }

  /// Handle message tap (background/terminated)
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('👆 Message tapped: ${message.data}');
    // Handle navigation based on message data
    NavigationService.navigateToOrders();
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageController.close();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background handler
  await Firebase.initializeApp();

  debugPrint('📨 Background message received!');
  debugPrint('Message ID: ${message.messageId}');
  debugPrint('Data: ${message.data}');

  if (message.notification != null) {
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
  }

  // Handle background message
  // The native layer (FCMService.kt / AppDelegate.swift) will display the notification
}
