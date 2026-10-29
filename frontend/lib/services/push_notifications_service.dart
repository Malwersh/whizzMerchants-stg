import 'sound_notification_settings.dart';
import 'notification_sound_policy.dart';
import 'merchant_order_alerts.dart';
import 'commercial_notice_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'branch_device_service.dart';
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
import 'merchant_notification_inbox.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore; Firebase may already be initialized.
  }
  if (message.data['action'] == 'new_order' && message.notification != null) {
    await AudioNotificationService.markOrderSoundAnnounced(
        message.data['orderId']?.toString());
  }
  await MerchantNotificationInbox.recordPush(message.data,
          title: message.notification?.title,
          body: message.notification?.body,
          messageId: message.messageId)
      .catchError((Object _) {});
  AppLogger.debug('📩 (bg) Push message received: ${message.messageId}');
}

class PushNotificationsService {
  PushNotificationsService._() {
    NotificationSoundFiles.changed.addListener(() {if(_initialized)unawaited(registerTokenIfPossible(businessId:_lastKnownBusinessId));});
    SoundNotificationSettings().addListener(() {
      if (_initialized) unawaited(registerTokenIfPossible(businessId: _lastKnownBusinessId));
    });
  }
  static final PushNotificationsService instance = PushNotificationsService._();

  final registrationStatus = ValueNotifier<String>('لم يُسجّل هذا الجهاز بعد.');
  bool _initialized = false;
  bool _isRegistering = false;
  String? _lastRegisteredToken;
  bool? _lastRegisteredSoundEnabled;
  String? _lastRegisteredBusinessId;
  String? _lastRegisteredSubjectId;
  bool _registrationPending = false;
  String? _lastKnownBusinessId;

  String? _lastReadySounds;
  // Audio service for playing notification sounds
  final AudioNotificationService _audioService = AudioNotificationService();

  // Callback for order refresh (set by app/order screen)
  void Function()? _onOrderRefreshCallback;

  Future<void>? _initialization;

  Future<void> initialize() async {
    if (_initialized) return;
    final pending = _initialization;
    if (pending != null) return pending;
    final operation = _initializeInternal();
    _initialization = operation;
    try {
      await operation;
    } finally {
      if (identical(_initialization, operation)) _initialization = null;
    }
  }

  Future<void> _initializeInternal() async {
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
          alert: false,
          badge: true,
          // Foreground orders use the deduplicated in-app audio path.
          // Background notifications retain the APNs payload sound.
          sound: false,
        );
      }

      final initial = await messaging.getInitialMessage();
      if (initial?.data['action'] == 'new_order')
        await AudioNotificationService.markOrderSoundAnnounced(
            initial?.data['orderId']?.toString());
      // Handle foreground push notifications
      FirebaseMessaging.onMessage.listen((message) async {
        CommercialNoticeNavigation.receive(message.data);
        await MerchantNotificationInbox.recordPush(message.data,
                title: message.notification?.title,
                body: message.notification?.body,
                messageId: message.messageId)
            .catchError((Object _) {});
        AppLogger.debug('📩 (fg) Push message: ${message.messageId}');
        AppLogger.debug('📩 Push data: ${message.data}');
        AppLogger.debug(
            '📩 Push notification: ${message.notification?.title} - ${message.notification?.body}');

        // Handle new_order action
        final action = message.data['action']?.toString() ?? '';
        if (action == 'new_order') {
          MerchantOrderAlerts.receive(message.data);
          AppLogger.debug('🚨 NEW ORDER PUSH RECEIVED (foreground)');

          // Play notification sound
          try {
            final orderId = message.data['orderId']?.toString();
            if (orderId != null && orderId.isNotEmpty) {
              await _audioService.playNewOrderSoundOnce(orderId);
            }
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

      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        CommercialNoticeNavigation.receive(message.data, tapped: true);
        if (message.data['action'] == 'new_order')
          await AudioNotificationService.markOrderSoundAnnounced(
              message.data['orderId']?.toString());
        await MerchantNotificationInbox.recordPush(message.data,
                title: message.notification?.title,
                body: message.notification?.body,
                messageId: message.messageId)
            .catchError((Object _) {});
        AppLogger.debug('📩 (tap) Push message opened: ${message.messageId}');
        AppLogger.debug('📩 Push data: ${message.data}');

        // Handle tap actions
        final action = message.data['action']?.toString() ?? '';
        if (action == 'new_order') {
          AppLogger.debug(
              '🚨 NEW ORDER PUSH TAPPED - Navigate to pending orders');
          // Note: Navigation will be handled by app-level handler

          // Also trigger refresh
          if (_onOrderRefreshCallback != null) {
            _onOrderRefreshCallback!();
          }
        }
      });

      // Cold start: app launched from a terminated state by tapping a notification.
      // This is critical for debugging the "tap from closed" path.
      final initialMessage = initial;
      if (initialMessage != null) {
        CommercialNoticeNavigation.receive(initialMessage.data, tapped: true);
        await MerchantNotificationInbox.recordPush(initialMessage.data,
                title: initialMessage.notification?.title,
                body: initialMessage.notification?.body,
                messageId: initialMessage.messageId)
            .catchError((Object _) {});
        AppLogger.debug(
            '📩 (coldstart) Initial push message: ${initialMessage.messageId}');
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
        await registerTokenIfPossible(
            forcedToken: token, businessId: _lastKnownBusinessId);
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
    AppLogger.debug(
        '🔔 Push notification order refresh callback ${callback != null ? "registered" : "cleared"}');
  }

  /// Remove only this account's registration before its credentials are cleared.
  Future<void> unregisterSignedOutDevice() async {
    final token = _lastRegisteredToken;
    final auth = await TokenRefreshService.getValidAccessToken();
    _registrationPending = false;
    _lastRegisteredToken = null;
    _lastRegisteredSubjectId = null;
    _lastRegisteredBusinessId = null;
    _lastKnownBusinessId = null;
    try {
      if (token != null && auth != null) {
        await http.post(Uri.parse('${AppConfig.pushNotificationsUrl}/push/tokens/unregister'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $auth'},
          body: jsonEncode({'token': token, 'app': 'merchant'}))
          .timeout(const Duration(seconds: 10));
      }
    } catch (_) { AppLogger.debug('Device unregistration unavailable'); }
    try { await FirebaseMessaging.instance.deleteToken(); } catch (_) {}
  }

  Future<void> registerTokenIfPossible(
      {String? forcedToken, String? businessId}) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (_) {
        registrationStatus.value = 'تعذر تهيئة الإشعارات. أعد المحاولة.';
        return;
      }
    }

    final requestedBusiness = businessId?.trim();
    if (requestedBusiness != null && requestedBusiness.isNotEmpty) {
      _lastKnownBusinessId = requestedBusiness;
    }
    if (_isRegistering) {
      _registrationPending = true;
      return;
    }

    try {
      _isRegistering = true;

      registrationStatus.value = 'جارٍ تسجيل هذا الجهاز…';
      if (Platform.isIOS) {
        String? apns;
        for (var attempt = 0; attempt < 10; attempt++) {
          apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (apns == null) {
          registrationStatus.value =
              'لم يكتمل اتصال الجهاز بخدمة Apple. تحقق من الإذن والإنترنت ثم أعد المحاولة.';
          return;
        }
      }
      final token =
          (forcedToken ?? await FirebaseMessaging.instance.getToken())?.trim();
      if (token == null || token.isEmpty) {
        registrationStatus.value = 'لم يكتمل تجهيز الإشعارات. أعد المحاولة.';
        AppLogger.debug('⚠️ FCM token not available yet');
        return;
      }

      final paired = await const FlutterSecureStorage()
          .read(key: 'merchant_paired_branch_device_v1');
      if (paired != null) {
        final device = Map<String, dynamic>.from(jsonDecode(paired));
        final pushResult=await BranchDeviceService().call(device['deviceToken'], {
          'action': 'register_push',
          'pushToken': token,
          'soundEnabled': SoundNotificationSettings().shouldPlaySound('new_order'),
          'soundReady': NotificationSoundPolicy.ready,
          'platform': Platform.isIOS ? 'ios' : 'android'
        });
        final beforeReady=NotificationSoundPolicy.ready.join(',');
        await NotificationSoundPolicy.adopt(pushResult['notificationPolicy']??pushResult['data']?['notificationPolicy']);
        if(beforeReady!=NotificationSoundPolicy.ready.join(',')){await BranchDeviceService().call(device['deviceToken'],{'action':'register_push','pushToken':token,'platform':Platform.isIOS?'ios':'android','soundReady':NotificationSoundPolicy.ready,'soundEnabled':SoundNotificationSettings().shouldPlaySound('new_order')});}
        registrationStatus.value = 'تم تسجيل هذا الجهاز للإشعارات.';
        return;
      }
      final authToken = await TokenRefreshService.getValidAccessToken();
      if (authToken == null || authToken.isEmpty) {
        registrationStatus.value = 'سجّل الدخول لإكمال تسجيل الإشعارات.';
        // Not logged in (or session not ready) → skip for now.
        AppLogger.debug(
            'ℹ️ No auth token yet; skipping push token registration');
        return;
      }

      final parts = authToken.split('.');
      final claims = jsonDecode(utf8.decode(base64Url.decode(
        base64Url.normalize(parts[1]),
      ))) as Map<String, dynamic>;
      final subjectId = claims['sub']?.toString();
      final registrationBusiness = _lastKnownBusinessId;
      await NotificationSoundPolicy.refresh();
      final soundEnabled=SoundNotificationSettings().shouldPlaySound('new_order');
      if (_lastReadySounds == NotificationSoundPolicy.ready.join(',') && _lastRegisteredSoundEnabled == soundEnabled && _lastRegisteredToken == token &&
          _lastRegisteredBusinessId == registrationBusiness &&
          _lastRegisteredSubjectId == subjectId) {
        registrationStatus.value = 'تم تسجيل هذا الجهاز للإشعارات.';
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

      final url =
          Uri.parse('${AppConfig.pushNotificationsUrl}/push/tokens/register');

      final body = {
        'token': token,
        'soundEnabled': soundEnabled,
        'app': 'merchant',
        'platform': platform,
          'soundReady': NotificationSoundPolicy.ready,
        'deviceId': deviceId,
        'appVersion': pkg.version,
        'buildNumber': pkg.buildNumber,
        if (registrationBusiness != null && registrationBusiness.isNotEmpty)
          'businessId': registrationBusiness,
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
        _lastReadySounds=NotificationSoundPolicy.ready.join(',');
        _lastRegisteredSoundEnabled = soundEnabled;
        _lastRegisteredToken = token;
        _lastRegisteredBusinessId = registrationBusiness;
        _lastRegisteredSubjectId = subjectId;
        registrationStatus.value = 'تم تسجيل هذا الجهاز للإشعارات.';
        AppLogger.success('✅ Push token registered (merchant)');
        return;
      }

      registrationStatus.value = 'تعذر تسجيل الجهاز في الخادم. أعد المحاولة.';
      AppLogger.error(
          '❌ Push token register failed: HTTP ${resp.statusCode} ${resp.body}');
    } catch (e) {
      registrationStatus.value =
          'تعذر تسجيل الإشعارات. تحقق من الإنترنت ثم أعد المحاولة.';
      AppLogger.error('❌ Push token registration error: $e');
    } finally {
      _isRegistering = false;
      if (_registrationPending) {
        _registrationPending = false;
        unawaited(registerTokenIfPossible(businessId: _lastKnownBusinessId));
      }
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
