import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import 'package:whizz_merchants/core/design_system/design_system.dart';

class SoundNotificationSettingsPage extends ConsumerStatefulWidget {
  const SoundNotificationSettingsPage({super.key});

  @override
  ConsumerState<SoundNotificationSettingsPage> createState() =>
      _SoundNotificationSettingsPageState();
}

class _SoundNotificationSettingsPageState
    extends ConsumerState<SoundNotificationSettingsPage> {
  bool _newOrderSound = true;
  bool _orderStatusSound = true;
  bool _systemSound = true;
  bool _vibration = true;
  double _volume = 0.8;
  String _selectedSound = 'default';

  List<Map<String, String>> _getAvailableSounds(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
      {'value': 'default', 'label': loc.defaultNotification},
      {'value': 'chime', 'label': loc.notificationChime},
      {'value': 'bell', 'label': loc.bell},
      {'value': 'ding', 'label': loc.ding},
      {'value': 'tone', 'label': loc.tone},
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _newOrderSound = prefs.getBool('sound_new_order') ?? true;
        _orderStatusSound = prefs.getBool('sound_order_status') ?? true;
        _systemSound = prefs.getBool('sound_system') ?? true;
        _vibration = prefs.getBool('sound_vibration') ?? true;
        _volume = prefs.getDouble('sound_volume') ?? 0.8;
        _selectedSound = prefs.getString('sound_type') ?? 'default';
      });
    } catch (e) {
      // Handle error silently or with proper error handling
    }
  }

  Future<void> _saveSettings() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_new_order', _newOrderSound);
      await prefs.setBool('sound_order_status', _orderStatusSound);
      await prefs.setBool('sound_system', _systemSound);
      await prefs.setBool('sound_vibration', _vibration);
      await prefs.setDouble('sound_volume', _volume);
      await prefs.setString('sound_type', _selectedSound);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: WhizzColors.secondary.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: WhizzColors.secondary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.settingsSaved,
                          style: TextStyle(
                            color: WhizzColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          loc.soundNotificationPreferencesUpdated,
                          style: TextStyle(
                            color:
                                WhizzColors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: WhizzColors.errorContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.error_rounded,
                    color: WhizzColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.saveFailed,
                          style: TextStyle(
                            color: WhizzColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          loc.failedToSaveSettings(e.toString()),
                          style: TextStyle(
                            color:
                                WhizzColors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  void _playTestSound() {
    final loc = AppLocalizations.of(context)!;
    // TODO: Implement sound playing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WhizzColors.infoContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: WhizzColors.info,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              loc.playingTestSound,
              style: TextStyle(
                color: WhizzColors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildModernSoundCard(
    String title,
    IconData icon,
    Color accentColor,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: WhizzColors.grey100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: WhizzColors.borderLight,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: WhizzColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              value ? accentColor.withValues(alpha: 0.3) : WhizzColors.grey50,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? accentColor.withValues(alpha: 0.1)
                  : WhizzColors.grey50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value ? accentColor : WhizzColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: WhizzColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
            activeTrackColor: accentColor.withValues(alpha: 0.3),
            inactiveTrackColor: WhizzColors.grey50.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: WhizzColors.secondary,
        foregroundColor: WhizzColors.white,
        elevation: 0,
        title: Text(
          loc.soundNotifications,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: WhizzColors.white,
              ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _saveSettings,
            style: FilledButton.styleFrom(
              backgroundColor: WhizzColors.textSecondary,
              foregroundColor: WhizzColors.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.save_rounded),
            label: Text(loc.save),
          ),
          const SizedBox(width: 16),
        ],
      ),
      backgroundColor: WhizzColors.backgroundPrimary,
      body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // New Order Notifications
            _buildModernSoundCard(
            loc.newOrderNotifications,
              Icons.restaurant_menu,
            WhizzColors.secondary,
              [
                _buildModernSwitchTile(
                loc.enableSound,
                loc.playSoundWhenNewOrdersArrive,
                  _newOrderSound,
                  (value) => setState(() => _newOrderSound = value),
                  Icons.volume_up,
                WhizzColors.secondary,
                ),
                _buildModernSwitchTile(
                loc.vibration,
                loc.vibrateDeviceForNewOrders,
                  _vibration,
                  (value) => setState(() => _vibration = value),
                  Icons.vibration,
                WhizzColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Order Status Notifications
            _buildModernSoundCard(
            loc.orderStatusUpdates,
              Icons.update,
            WhizzColors.info,
              [
                _buildModernSwitchTile(
                loc.enableSound,
                loc.playSoundForOrderStatusChanges,
                  _orderStatusSound,
                  (value) => setState(() => _orderStatusSound = value),
                  Icons.notifications_active,
                WhizzColors.info,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // System Notifications
            _buildModernSoundCard(
            loc.systemNotifications,
              Icons.settings,
            WhizzColors.warning,
              [
                _buildModernSwitchTile(
                loc.enableSound,
                loc.playSoundForSystemAlerts,
                  _systemSound,
                  (value) => setState(() => _systemSound = value),
                  Icons.warning,
                WhizzColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sound Settings
            _buildModernSoundCard(
            loc.soundSettings,
              Icons.volume_up,
            WhizzColors.textSecondary,
              [
                // Sound Type Dropdown
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                  color: WhizzColors.grey50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                    color: WhizzColors.textSecondary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                  value: _selectedSound,
                    decoration: InputDecoration(
                    labelText: loc.notificationSound,
                    labelStyle: TextStyle(color: WhizzColors.textSecondary),
                      prefixIcon:
                          Icon(Icons.music_note,
                        color: WhizzColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  items: _getAvailableSounds(context).map((sound) {
                      return DropdownMenuItem<String>(
                      value: sound['value'],
                        child: Text(sound['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSound = value;
                        });
                      }
                    },
                  ),
                ),

                // Volume Slider
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                  color: WhizzColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                    color: WhizzColors.textSecondary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                        Icon(Icons.volume_up, color: WhizzColors.textSecondary),
                          const SizedBox(width: 12),
                          Text(
                            'Volume: ${(_volume * 100).round()}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            color: WhizzColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.volume_down,
                            color: WhizzColors.textSecondary),
                          Expanded(
                            child: Slider(
                              value: _volume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              activeColor: WhizzColors.textSecondary,
                              inactiveColor: WhizzColors.grey50,
                              onChanged: (value) {
                                setState(() {
                                  _volume = value;
                                });
                              },
                            ),
                          ),
                          Icon(Icons.volume_up,
                              color: WhizzColors.textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),

                // Test Sound Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                  color: WhizzColors.black,
                    borderRadius: BorderRadius.circular(16),
                  boxShadow: WhizzColors.elevation(3),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _playTestSound,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                            color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                            loc.testSound,
                              style: TextStyle(
                              color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
