import 'notification_sound_files.dart';
import 'order_alert_cadence.dart';
import 'dart:async';
import 'notification_sound_policy.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sound_notification_settings.dart';

class AudioNotificationService {
  static final AudioNotificationService _instance =
      AudioNotificationService._internal();
  factory AudioNotificationService() => _instance;
  AudioNotificationService._internal();

  late final AudioPlayer _audioPlayer = AudioPlayer();
  final SoundNotificationSettings _settings = SoundNotificationSettings();

  // Sound configuration - Use available sound files
  static const String _newOrderSound =
      'sounds/first_nitification_sound.wav'; // Main new order sound
  static const String _notificationChime =
      'sounds/notification_chime.aiff'; // Fallback sound
  static const String _gentleReminderSound =
      'sounds/first_nitification_sound.wav'; // Use new sound
  static const String _urgentAlertSound =
      'sounds/first_nitification_sound.wav'; // Use new sound
  static const String _autoRejectSound =
      'sounds/notification_chime.aiff'; // Use chime as fallback

  /// Initialize the audio service
  Future<void> initialize() async {
    try {
      await _settings.initialize();
      unawaited(NotificationSoundPolicy.refresh());
      await _audioPlayer.setVolume(_settings.volume);
      debugPrint('🔊 AudioNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing audio service: $e');
    }
  }

  final Map<String, DateTime> _announcedOrders = {};
  final _orderCadence = OrderAlertCadence();
  final Map<String,Future<void>> _newOrderInFlight={};
  Future<void> _newOrderTail=Future<void>.value();

  static const _soundHistoryKey = 'merchant_order_sound_history_v1';
  static Future<bool> markOrderSoundAnnounced(String? orderId) async {
    if (orderId == null || orderId.isEmpty) return false;
    _instance._announcedOrders[orderId] = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    Map<String, dynamic> history = {};
    try {
      history = Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_soundHistoryKey) ?? '{}'));
    } catch (_) {}
    final now = DateTime.now().millisecondsSinceEpoch;
    history.removeWhere((k, v) => v is! int || now - v > 3600000);
    final seen = history.containsKey(orderId);
    history[orderId] = now;
    while (history.length > 200) {
      history.remove(history.keys.first);
    }
    await prefs.setString(_soundHistoryKey, jsonEncode(history));
    return seen;
  }

  Future<void> playNewOrderSoundOnce(String orderId) {
    if(orderId.isEmpty||!_settings.shouldPlaySound('new_order'))return Future.value();
    return _newOrderInFlight.putIfAbsent(orderId,(){
      final task=_newOrderTail.then((_)async{
        final now=DateTime.now();
        _announcedOrders.removeWhere((_,time)=>now.difference(time).inHours>=1);
        if(_announcedOrders.containsKey(orderId))return;
        final prefs=await SharedPreferences.getInstance();await prefs.reload();
        Map<String,dynamic> history={};
        try{history=Map<String,dynamic>.from(jsonDecode(prefs.getString(_soundHistoryKey)??'{}'));}catch(_){}
        if(history[orderId] is int&&now.millisecondsSinceEpoch-(history[orderId] as int)<3600000){_announcedOrders[orderId]=now;return;}
        if(await _playNewOrderCue(respectCadence:false)){_orderCadence.reserve(Duration.zero);await markOrderSoundAnnounced(orderId);}
      });
      _newOrderTail=task.catchError((Object _){});
      return task.whenComplete(() { _newOrderInFlight.remove(orderId); });
    });
  }

  Future<void> playPendingOrderReminder() async {
    final seconds = NotificationSoundPolicy.reminderSeconds.clamp(30, 300);
    if (!_orderCadence.ready(Duration(seconds: seconds))) return;
    await playNewOrderSound();
  }

  /// Play new order notification sound with IMMEDIATE priority
  Future<void> playNewOrderSound() async { await _playNewOrderCue(); }

  Future<bool> _playNewOrderCue({bool respectCadence=true})async{
    if(!_settings.shouldPlaySound('new_order'))return true;
    if(respectCadence&&!_orderCadence.reserve(const Duration(seconds:3)))return false;
    try{
      unawaited(NotificationSoundPolicy.refresh());
      final file=NotificationSoundPolicy.file('merchantNewOrder');
      if(file==null)return true; // Intentional central silence is handled.
      if(!kIsWeb&&defaultTargetPlatform==TargetPlatform.iOS){
        final result=await NotificationSoundFiles.bridge.invokeMapMethod<String,dynamic>('playOrderCue',{'file':file,'volume':_settings.volume});
        return result?['playing']==true;
      }
      await _audioPlayer.setAudioContext(AudioContext(android:const AudioContextAndroid(contentType:AndroidContentType.sonification,usageType:AndroidUsageType.notification,audioFocus:AndroidAudioFocus.gainTransientMayDuck)));
      await _audioPlayer.stop();await _audioPlayer.setVolume(_settings.volume);
      await _audioPlayer.play(NotificationSoundFiles.source(file));
      unawaited(HapticFeedback.heavyImpact());return true;
    }catch(error){
      debugPrint('Merchant order cue failed: ${error.runtimeType}');
      try{await _audioPlayer.play(AssetSource(_notificationChime));return true;}catch(_){return false;}
    }
  }

  /// Play general notification chime
  Future<void> playNotificationChime() async {
    if (!_settings.shouldPlaySound('popup')) return;

    try {
      debugPrint('🔊 Playing notification chime');
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_settings.volume);
      await _audioPlayer.play(AssetSource(_notificationChime));

      // Light haptic feedback for general notifications
      await HapticFeedback.lightImpact();

      debugPrint('✅ Notification chime played successfully');
    } catch (e) {
      debugPrint('❌ Error playing notification chime: $e');
    }
  }

  /// Play urgent order sound (single play - fixed repetition issue)
  Future<void> playUrgentOrderSound() async {
    if (!_settings.shouldPlaySound('urgent_order')) return;

    try {
      debugPrint('🔊 Playing urgent order sound (single play)');

      // 🔧 FIX: Play sound only once instead of 3 times to avoid repetition
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_settings.volume);
      unawaited(NotificationSoundPolicy.refresh());
      final file=NotificationSoundPolicy.file('merchantNewOrder');
      if(file==null)return;
      await _audioPlayer.play(NotificationSoundFiles.source(file));

      // Enhanced haptic feedback for urgent orders (double impact)
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();

      debugPrint('✅ Urgent order sound played successfully (single play)');
    } catch (e) {
      debugPrint('❌ Error playing urgent order sound: $e');
    }
  }

  /// Play sound based on notification type
  Future<void> playNotificationSound(String type,
      {bool isUrgent = false}) async {
    if (!_settings.soundEnabled) return;

    switch (type.toLowerCase()) {
      case 'new_order':
      case 'order':
        if (isUrgent) {
          await playUrgentOrderSound();
        } else {
          await playNewOrderSound();
        }
        break;
      // ⭐ DISABLED: Don't play sound for order_update - only for new orders
      // This prevents sound playing when merchant changes order status
      // case 'order_update':
      // case 'order_confirmed':
      // case 'order_ready':
      //   await playNotificationChime();
      //   break;
      case 'payment_received':
        await playNotificationChime();
        break;
      default:
        // Don't play sound for unspecified types
        break;
    }
  }

  /// Play gentle reminder sound for first timeout alert (2 minutes)
  Future<void> playGentleReminder() async {
    if (!_settings.shouldPlaySound('timeout_alert')) return;

    try {
      debugPrint('🔊 Playing gentle reminder sound');
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_settings.volume * 0.7); // Slightly quieter
      await _audioPlayer.play(AssetSource(_gentleReminderSound));

      // Light haptic feedback
      await HapticFeedback.lightImpact();

      debugPrint('✅ Gentle reminder sound played successfully');
    } catch (e) {
      debugPrint('❌ Error playing gentle reminder sound: $e');
      // Fallback to notification chime
      await playNotificationChime();
    }
  }

  /// Play urgent alert sound for second timeout alert (5 minutes)
  Future<void> playUrgentAlert() async {
    if (!_settings.shouldPlaySound('timeout_alert')) return;

    try {
      debugPrint('🔊 Playing urgent alert sound');
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_settings.volume); // Full volume
      await _audioPlayer.play(AssetSource(_urgentAlertSound));

      // Strong haptic feedback
      await HapticFeedback.heavyImpact();

      debugPrint('✅ Urgent alert sound played successfully');
    } catch (e) {
      debugPrint('❌ Error playing urgent alert sound: $e');
      // Fallback to new order sound with repeat
      await playNewOrderSound();
      await Future.delayed(const Duration(milliseconds: 500));
      await playNewOrderSound();
    }
  }

  /// Play auto-reject sound when order is automatically rejected (8 minutes)
  Future<void> playOrderAutoRejected() async {
    if (!_settings.shouldPlaySound('timeout_alert')) return;

    try {
      debugPrint('🔊 Playing order auto-rejected sound');
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_settings.volume);
      await _audioPlayer.play(AssetSource(_autoRejectSound));

      // Strong haptic pattern
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();

      debugPrint('✅ Order auto-rejected sound played successfully');
    } catch (e) {
      debugPrint('❌ Error playing auto-reject sound: $e');
      // Fallback to urgent order sound with triple repeat
      for (int i = 0; i < 3; i++) {
        await playUrgentOrderSound();
        if (i < 2) await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// Test all timeout notification sounds
  Future<void> testTimeoutSounds() async {
    debugPrint('Testing timeout notification sounds...');

    await playGentleReminder();
    await Future.delayed(const Duration(seconds: 2));

    await playUrgentAlert();
    await Future.delayed(const Duration(seconds: 2));

    await playOrderAutoRejected();

    debugPrint('✅ Timeout sound test completed');
  }

  /// Test all notification sounds
  Future<void> testAllSounds() async {
    debugPrint('Testing all notification sounds...');

    await playNewOrderSound();
    await Future.delayed(const Duration(seconds: 2));

    await playNotificationChime();
    await Future.delayed(const Duration(seconds: 2));

    await playUrgentOrderSound();
    await Future.delayed(const Duration(seconds: 2));

    await testTimeoutSounds();

    debugPrint('✅ Sound test completed');
  }

  /// Enable or disable sound notifications
  Future<void> setSoundEnabled(bool enabled) async {
    await _settings.setSoundEnabled(enabled);
  }

  /// Set volume level (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _settings.setVolume(volume);
    await _audioPlayer.setVolume(_settings.volume);
  }

  /// Get current sound settings
  bool get isSoundEnabled => _settings.soundEnabled;
  double get volume => _settings.volume;
  SoundNotificationSettings get settings => _settings;

  /// Stop any currently playing sound
  Future<void> stopSound() async {
    try {
      await _audioPlayer.stop();
      debugPrint('⏹️ Audio playback stopped');
    } catch (e) {
      debugPrint('❌ Error stopping audio: $e');
    }
  }

  /// Dispose of the audio player
  void dispose() {
    _audioPlayer.dispose();
    debugPrint('🗑️ AudioNotificationService disposed');
  }
}
