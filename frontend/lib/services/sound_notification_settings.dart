import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundNotificationSettings extends ChangeNotifier {
  static final SoundNotificationSettings _instance =
      SoundNotificationSettings._internal();
  factory SoundNotificationSettings() => _instance;
  SoundNotificationSettings._internal();

  // Settings keys
  static const String _soundEnabledKey = 'sound_notifications_enabled';
  static const String _newOrderSoundKey = 'new_order_sound_enabled';
  static const String _orderUpdateSoundKey = 'order_update_sound_enabled';
  static const String _urgentOrderSoundKey = 'urgent_order_sound_enabled';
  static const String _popupSoundKey = 'popup_sound_enabled';
  static const String _volumeKey = 'notification_volume';
  static const String _soundThemeKey = 'sound_theme';

  // Default values
  bool _soundEnabled = true;
  bool _newOrderSoundEnabled = true;
  bool _orderUpdateSoundEnabled = true;
  bool _urgentOrderSoundEnabled = true;
  bool _popupSoundEnabled = true;
  double _volume = 0.8;
  String _soundTheme = 'default'; // default, professional, modern

  // Getters
  bool get soundEnabled => _soundEnabled;
  bool get newOrderSoundEnabled => _newOrderSoundEnabled;
  bool get orderUpdateSoundEnabled => _orderUpdateSoundEnabled;
  bool get urgentOrderSoundEnabled => _urgentOrderSoundEnabled;
  bool get popupSoundEnabled => _popupSoundEnabled;
  double get volume => _volume;
  String get soundTheme => _soundTheme;

  /// Initialize settings from storage
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _newOrderSoundEnabled = prefs.getBool(_newOrderSoundKey) ?? true;
      _orderUpdateSoundEnabled = prefs.getBool(_orderUpdateSoundKey) ?? true;
      _urgentOrderSoundEnabled = prefs.getBool(_urgentOrderSoundKey) ?? true;
      _popupSoundEnabled = prefs.getBool(_popupSoundKey) ?? true;
      _volume = prefs.getDouble(_volumeKey) ?? 0.8;
      _soundTheme = prefs.getString(_soundThemeKey) ?? 'default';

      debugPrint(
          '🔊 Sound settings loaded: enabled=$_soundEnabled, volume=${(_volume * 100).round()}%');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading sound settings: $e');
    }
  }

  /// Enable or disable all sound notifications
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _saveBoolSetting(_soundEnabledKey, enabled);
    debugPrint('🔊 Sound notifications ${enabled ? 'enabled' : 'disabled'}');
    notifyListeners();
  }

  /// Enable or disable new order sounds
  Future<void> setNewOrderSoundEnabled(bool enabled) async {
    _newOrderSoundEnabled = enabled;
    await _saveBoolSetting(_newOrderSoundKey, enabled);
    debugPrint('🔊 New order sounds ${enabled ? 'enabled' : 'disabled'}');
    notifyListeners();
  }

  /// Enable or disable order update sounds
  Future<void> setOrderUpdateSoundEnabled(bool enabled) async {
    _orderUpdateSoundEnabled = enabled;
    await _saveBoolSetting(_orderUpdateSoundKey, enabled);
    debugPrint('🔊 Order update sounds ${enabled ? 'enabled' : 'disabled'}');
    notifyListeners();
  }

  /// Enable or disable urgent order sounds
  Future<void> setUrgentOrderSoundEnabled(bool enabled) async {
    _urgentOrderSoundEnabled = enabled;
    await _saveBoolSetting(_urgentOrderSoundKey, enabled);
    debugPrint('🔊 Urgent order sounds ${enabled ? 'enabled' : 'disabled'}');
    notifyListeners();
  }

  /// Enable or disable popup sounds
  Future<void> setPopupSoundEnabled(bool enabled) async {
    _popupSoundEnabled = enabled;
    await _saveBoolSetting(_popupSoundKey, enabled);
    debugPrint('🔊 Popup sounds ${enabled ? 'enabled' : 'disabled'}');
    notifyListeners();
  }

  /// Set notification volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _saveDoubleSetting(_volumeKey, _volume);
    debugPrint('🔊 Volume set to: ${(_volume * 100).round()}%');
    notifyListeners();
  }

  /// Set sound theme
  Future<void> setSoundTheme(String theme) async {
    _soundTheme = theme;
    await _saveStringSetting(_soundThemeKey, theme);
    debugPrint('🔊 Sound theme set to: $theme');
    notifyListeners();
  }

  /// Check if specific notification type should play sound
  bool shouldPlaySound(String notificationType) {
    if (!_soundEnabled) return false;

    switch (notificationType.toLowerCase()) {
      case 'new_order':
        return _newOrderSoundEnabled;
      case 'order_update':
        return _orderUpdateSoundEnabled;
      case 'urgent_order':
        return _urgentOrderSoundEnabled;
      case 'popup':
        return _popupSoundEnabled;
      default:
        return true;
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _soundEnabled = true;
    _newOrderSoundEnabled = true;
    _orderUpdateSoundEnabled = true;
    _urgentOrderSoundEnabled = true;
    _popupSoundEnabled = true;
    _volume = 0.8;
    _soundTheme = 'default';

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    debugPrint('🔊 Sound settings reset to defaults');
    notifyListeners();
  }

  /// Get settings summary for display
  Map<String, dynamic> getSettingsSummary() {
    return {
      'soundEnabled': _soundEnabled,
      'newOrderSounds': _newOrderSoundEnabled,
      'orderUpdateSounds': _orderUpdateSoundEnabled,
      'urgentOrderSounds': _urgentOrderSoundEnabled,
      'popupSounds': _popupSoundEnabled,
      'volume': '${(_volume * 100).round()}%',
      'soundTheme': _soundTheme,
    };
  }

  // Helper methods for saving settings
  Future<void> _saveBoolSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('❌ Error saving bool setting $key: $e');
    }
  }

  Future<void> _saveDoubleSetting(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (e) {
      debugPrint('❌ Error saving double setting $key: $e');
    }
  }

  Future<void> _saveStringSetting(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('❌ Error saving string setting $key: $e');
    }
  }
}
