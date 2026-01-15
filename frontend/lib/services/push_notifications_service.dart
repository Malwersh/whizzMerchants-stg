import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/utils/app_logger.dart';
import 'token_refresh_service.dart';
import 'audio_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore; Firebase may already be initialized.
  }
  AppLogger.debug('📩 (bg) Push message received: ${message.messageId}');
}

class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance = PushNotificationsService._();

  bool _initialized = false;
  bool _isRegistering = false;
  String? _lastRegisteredToken;
  DateTime? _lastRegisterAttemptAt;
  String? _lastKnownBusinessId;
  
  // Audio service for playing notification sounds
  final AudioNotificationService _audioService = AudioNotificationService();
  
  // Callback for order refresh (set by app/order screen)
  void Function()? _onOrderRefreshCallback;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Initialize audio service
      await _audioService.initialize();
      AppLogger.success('🔊 Audio service initialized for push notifications');

      final messaging = FirebaseMessaging.instance;

      // iOS: request permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Handle foreground push notifications
      FirebaseMessaging.onMessage.listen((message) async {
        AppLogger.debug('📩 (fg) Push message: ${message.messageId}');
        AppLogger.debug('📩 Push data: ${message.data}');
        AppLogger.debug('📩 Push notification: ${message.notification?.title} - ${message.notification?.body}');
        
        // Handle new_order action
        final action = message.data['action']?.toString() ?? '';
        if (action == 'new_order') {
          AppLogger.debug('🚨 NEW ORDER PUSH RECEIVED (foreground)');
          
          // Play notification sound
          try {
            await _audioService.playNotificationSound('new_order');
            AppLogger.debug('🔊 New order sound played successfully');
          } catch (e) {
            AppLogger.debug('⚠️ Failed to play sound: $e');
          }
          
          // Trigger order refresh
          if (_onOrderRefreshCallback != null) {
            AppLogger.debug('🔄 Triggering order refresh after push...');
            _onOrderRefreshCallback!();
          } else {
            AppLogger.warning('⚠️ No order refresh callback registered!');
          }
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        AppLogger.debug('📩 (tap) Push message opened: ${message.messageId}');
        AppLogger.debug('📩 Push data: ${message.data}');
        
        // Handle tap actions
        final action = message.data['action']?.toString() ?? '';
        if (action == 'new_order') {
          AppLogger.debug('🚨 NEW ORDER PUSH TAPPED - Navigate to pending orders');
          // Note: Navigation will be handled by app-level handler
          
          // Also trigger refresh
          if (_onOrderRefreshCallback != null) {
            _onOrderRefreshCallback!();
          }
        }
      });

      // Cold start: app launched from a terminated state by tapping a notification.
      // This is critical for debugging the "tap from closed" path.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.debug('📩 (coldstart) Initial push message: ${initialMessage.messageId}');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'debug_last_initial_push',
            jsonEncode({
              'messageId': initialMessage.messageId,
              'sentTime': initialMessage.sentTime?.toIso8601String(),
              'data': initialMessage.data,
              'notification': {
                'title': initialMessage.notification?.title,
                'body': initialMessage.notification?.body,
              },
              'recordedAt': DateTime.now().toIso8601String(),
            }),
          );
        } catch (e) {
          AppLogger.debug('⚠️ Failed to persist initial push debug info: $e');
        }
      }

      // Token refresh → re-register
      messaging.onTokenRefresh.listen((token) async {
        AppLogger.debug('🔁 FCM token refreshed');
        await registerTokenIfPossible(forcedToken: token, businessId: _lastKnownBusinessId);
      });

      _initialized = true;
      AppLogger.success('✅ PushNotificationsService initialized');
    } catch (e) {
      AppLogger.error('❌ PushNotificationsService init failed: $e');
      rethrow;
    }
  }

  /// Set callback for order refresh (called when new order push arrives)
  void setOrderRefreshCallback(void Function()? callback) {
    _onOrderRefreshCallback = callback;
    AppLogger.debug('🔔 Push notification order refresh callback ${callback != null ? "registered" : "cleared"}');
  }

  Future<void> registerTokenIfPossible({String? forcedToken, String? businessId}) async {
    if (!_initialized) {
      await initialize();
    }

    // Avoid spam: if called repeatedly in a short burst, back off.
    final now = DateTime.now();
    if (_isRegistering) return;
    if (_lastRegisterAttemptAt != null && now.difference(_lastRegisterAttemptAt!) < const Duration(seconds: 3)) {
      return;
    }

    try {
      _isRegistering = true;
      _lastRegisterAttemptAt = now;

      final token = (forcedToken ?? await FirebaseMessaging.instance.getToken())?.trim();
      if (token == null || token.isEmpty) {
        AppLogger.debug('⚠️ FCM token not available yet');
        return;
      }

      if (_lastRegisteredToken == token) {
        return;
      }

      final authToken = await TokenRefreshService.getValidAccessToken();
      if (authToken == null || authToken.isEmpty) {
        // Not logged in (or session not ready) → skip for now.
        AppLogger.debug('ℹ️ No auth token yet; skipping push token registration');
        return;
      }

      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : 'unknown';

      if (platform == 'unknown') {
        AppLogger.debug('⚠️ Unsupported platform for push registration');
        return;
      }

      final deviceId = await _getDeviceIdSafe();
      final pkg = await PackageInfo.fromPlatform();

      final safeBusinessId = (businessId ?? '').trim();
      if (safeBusinessId.isNotEmpty) {
        _lastKnownBusinessId = safeBusinessId;
      }

      final url = Uri.parse('${AppConfig.pushNotificationsUrl}/push/tokens/register');

      final body = {
        'token': token,
        'app': 'merchant',
        'platform': platform,
        'deviceId': deviceId,
        'appVersion': pkg.version,
        'buildNumber': pkg.buildNumber,
        if (_lastKnownBusinessId != null && _lastKnownBusinessId!.isNotEmpty) 'businessId': _lastKnownBusinessId,
      };

      AppLogger.debug('📡 Registering push token to Central Notifications...');

      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _lastRegisteredToken = token;
        AppLogger.success('✅ Push token registered (merchant)');
        return;
      }

      AppLogger.error('❌ Push token register failed: HTTP ${resp.statusCode} ${resp.body}');
    } catch (e) {
      AppLogger.error('❌ Push token registration error: $e');
    } finally {
      _isRegistering = false;
    }
  }

  Future<String?> _getDeviceIdSafe() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.identifierForVendor;
      }
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        // `androidId` is not available in all device_info_plus versions.
        // `id` is widely available and stable enough for best-effort identification.
        return info.id;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
