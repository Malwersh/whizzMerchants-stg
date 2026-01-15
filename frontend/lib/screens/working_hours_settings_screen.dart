import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';

class WorkingHoursSettingsScreen extends ConsumerStatefulWidget {
  final Business business;

  const WorkingHoursSettingsScreen({super.key, required this.business});

  @override
  ConsumerState<WorkingHoursSettingsScreen> createState() =>
      _WorkingHoursSettingsScreenState();
}

class _WorkingHoursSettingsScreenState
    extends ConsumerState<WorkingHoursSettingsScreen> {
  bool _isLoading = false;

  final Map<String, Map<String, dynamic>> _workingHours = {
    'monday': {'isOpen': true, 'isClosed': false, 'openTime': '09:00', 'closeTime': '21:00'},
    'tuesday': {'isOpen': true, 'isClosed': false, 'openTime': '09:00', 'closeTime': '21:00'},
    'wednesday': {'isOpen': true, 'isClosed': false, 'openTime': '09:00', 'closeTime': '21:00'},
    'thursday': {'isOpen': true, 'isClosed': false, 'openTime': '09:00', 'closeTime': '21:00'},
    'friday': {'isOpen': true, 'isClosed': false, 'openTime': '09:00', 'closeTime': '21:00'},
    'saturday': {'isOpen': true, 'isClosed': false, 'openTime': '09:00', 'closeTime': '21:00'},
    'sunday': {'isOpen': false, 'isClosed': true, 'openTime': '09:00', 'closeTime': '21:00'},
  };

  final List<String> _daysOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];


  @override
  void initState() {
    super.initState();
    _loadWorkingHours();
  }

  Future<void> _loadWorkingHours() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      final hours =
          await apiService.getBusinessWorkingHours(widget.business.id);

      if (mounted && hours['workingHours'] != null) {
        setState(() {
          final loadedHours = hours['workingHours'];

          for (String day in _daysOrder) {
            if (loadedHours[day] != null) {
              final dayData = Map<String, dynamic>.from(loadedHours[day]);
              
              // Handle both backend formats (isOpen/isClosed)
              bool isOpen = false;
              if (dayData.containsKey('isClosed')) {
                isOpen = dayData['isClosed'] != true;
              } else if (dayData.containsKey('isOpen')) {
                isOpen = dayData['isOpen'] == true;
              }
              
              // Get opening and closing times from various possible fields
              String openTime = dayData['openTime'] ?? dayData['opening'] ?? '09:00';
              String closeTime = dayData['closeTime'] ?? dayData['closing'] ?? '21:00';
              
              // 🔥 If times are "closed", "none" or empty, it means the day is closed
              if (openTime == 'closed' || openTime == 'none' || openTime.isEmpty || 
                  closeTime == 'closed' || closeTime == 'none' || closeTime.isEmpty) {
                isOpen = false;
                openTime = 'closed';
                closeTime = 'closed';
              }
              
              _workingHours[day] = {
                'isOpen': isOpen,
                'openTime': isOpen ? openTime : 'closed',
                'closeTime': isOpen ? closeTime : 'closed',
              };
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: AppLocalizations.of(context)!
              .failedToLoadWorkingHours(e.toString()),
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveWorkingHours() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      
      // Transform the working hours data to include isClosed field
      final transformedWorkingHours = <String, Map<String, dynamic>>{};
      
      for (String day in _daysOrder) {
        final dayData = _workingHours[day]!;
        final isOpen = dayData['isOpen'] as bool;
        
        transformedWorkingHours[day] = {
          'isOpen': isOpen,
          'isClosed': !isOpen, // Add isClosed field based on isOpen
          // 🔥 عندما يكون اليوم مغلق، ارسل "closed" بدلاً من الأوقات الفعلية
          'openTime': isOpen ? dayData['openTime'] : 'closed',
          'closeTime': isOpen ? dayData['closeTime'] : 'closed',
        };
      }
      
      final data = {
        'workingHours': transformedWorkingHours,
      };

      await apiService.updateBusinessWorkingHours(widget.business.id, data);
      
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: AppLocalizations.of(context)!.workingHoursSaved,
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: AppLocalizations.of(context)!
              .failedToSaveWorkingHours(e.toString()),
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectTime(String day, bool isOpenTime) async {
    final dayData = _workingHours[day]!;
    
    // Don't allow time selection if the day is closed
    if (!dayData['isOpen']) {
      return;
    }
    
    final currentTime = isOpenTime
        ? dayData['openTime']
        : dayData['closeTime'];

    // Handle "closed" and "none" values by using defaults
    final timeToUse = (currentTime == 'closed' || currentTime == 'none' || currentTime == null) 
        ? (isOpenTime ? '09:00' : '21:00') 
        : currentTime;

    final timeParts = timeToUse.split(':');
    final initialTime = TimeOfDay(
        hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    
    if (picked != null) {
      final timeString =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpenTime) {
          _workingHours[day]!['openTime'] = timeString;
        } else {
          _workingHours[day]!['closeTime'] = timeString;
        }
      });
    }
  }

  void _copyToAllDays(String sourceDay) {
    final sourceHours = _workingHours[sourceDay]!;
    setState(() {
      for (String day in _daysOrder) {
        if (day != sourceDay) {
          _workingHours[day] = Map<String, dynamic>.from(sourceHours);
        }
      }
    });

    showAdaptiveSnackBar(
      context: context,
      message: AppLocalizations.of(context)!
          .appliedDayHoursToAll(_getLocalizedDayName(sourceDay, context)),
      type: AdaptiveSnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void _setCommonSchedule(String schedule) {
    Map<String, dynamic> hours;

    switch (schedule) {
      case 'regular':
        hours = {'isOpen': true, 'isClosed': false, 'openTime': '09:00', 'closeTime': '17:00'};
        break;
      case 'restaurant':
        hours = {'isOpen': true, 'isClosed': false, 'openTime': '11:00', 'closeTime': '23:00'};
        break;
      case 'retail':
        hours = {'isOpen': true, 'isClosed': false, 'openTime': '10:00', 'closeTime': '22:00'};
        break;
      default:
        return;
    }

    setState(() {
      for (String day in _daysOrder) {
        _workingHours[day] = Map<String, dynamic>.from(hours);
      }
    });

    showAdaptiveSnackBar(
      context: context,
      message: AppLocalizations.of(context)!.appliedHoursToAllDays(schedule),
      type: AdaptiveSnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  String _getLocalizedDayName(String day, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (day) {
      case 'monday':
        return loc.monday;
      case 'tuesday':
        return loc.tuesday;
      case 'wednesday':
        return loc.wednesday;
      case 'thursday':
        return loc.thursday;
      case 'friday':
        return loc.friday;
      case 'saturday':
        return loc.saturday;
      case 'sunday':
        return loc.sunday;
      default:
        return day;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            _buildModernAppBar(loc),

              // Content
              Expanded(
                child: _isLoading
                  ? _buildLoadingState(loc)
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            // Quick Presets Section
                          _buildQuickPresetsSection(loc),

                            // Working Hours Cards
                          _buildWorkingHoursSection(loc),

                            // Save Button
                          _buildSaveButton(loc),

                            // Bottom spacing
                            SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildModernAppBar(AppLocalizations loc) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow.withValues(alpha: 0.04),
            blurRadius: AppSpacing.xs,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back_rounded,
                  color: WhizzColors.secondary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.workingHoursSettings,
                  style: AppTypography.titleLarge.copyWith(
                    color: WhizzColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  loc.setBusinessHours,
                  style: AppTypography.bodySmall.copyWith(
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WhizzColors.textSecondary,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: _isLoading
                  ? const AdaptiveLoadingIndicator(
                      size: 16,
                      color: Colors.white,
                    )
                  : Icon(Icons.save_rounded, color: Colors.white, size: 20),
              onPressed: _isLoading ? null : _saveWorkingHours,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(AppLocalizations loc) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(AppSpacing.xl + AppSpacing.xs),
        decoration: BoxDecoration(
          color: WhizzColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
          boxShadow: [
            BoxShadow(
              color: WhizzColors.shadow.withValues(alpha: 0.1),
              blurRadius: AppSpacing.lg,
              offset: Offset(0, AppSpacing.xs),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AdaptiveLoadingIndicator(),
            SizedBox(height: AppSpacing.md),
            Text(
              loc.loadingWorkingHours,
              style: AppTypography.bodyLarge.copyWith(
                color: WhizzColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPresetsSection(AppLocalizations loc) {
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow.withValues(alpha: 0.06),
            blurRadius: AppSpacing.sm,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: WhizzColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: WhizzColors.secondary,
                  size: 18,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.quickPresets,
                      style: AppTypography.titleMedium.copyWith(
                        color: WhizzColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      loc.applySchedulesToAllDays,
                      style: AppTypography.bodySmall.copyWith(
                        color: WhizzColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _buildPresetButton(loc.regularHours, 'regular')),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: _buildPresetButton(loc.restaurantHours, 'restaurant')),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: _buildPresetButton(loc.retailHours, 'retail')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, String schedule) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.4),
          width: 1,
        ),
        gradient: LinearGradient(
          colors: [
            WhizzColors.secondary.withValues(alpha: 0.05),
            WhizzColors.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _setCommonSchedule(schedule),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: WhizzColors.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkingHoursSection(AppLocalizations loc) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children:
            _daysOrder.map((day) => _buildModernDayCard(day, loc)).toList(),
      ),
    );
  }

  Widget _buildModernDayCard(String day, AppLocalizations loc) {
    final dayData = _workingHours[day]!;
    
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: dayData['isOpen'] 
              ? WhizzColors.secondary.withValues(alpha: 0.3)
              : WhizzColors.textPrimary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow.withValues(alpha: 0.06),
            blurRadius: AppSpacing.sm,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: dayData['isOpen']
                        ? WhizzColors.secondary.withValues(alpha: 0.1)
                        : WhizzColors.textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
                  ),
                  child: Icon(
                    dayData['isOpen'] ? Icons.access_time_rounded : Icons.block_rounded,
                    color: dayData['isOpen']
                        ? WhizzColors.secondary
                        : WhizzColors.textPrimary.withValues(alpha: 0.4),
                    size: 18,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getLocalizedDayName(day, context),
                        style: AppTypography.titleMedium.copyWith(
                          color: WhizzColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                          dayData['isOpen']
                            ? '${dayData['openTime'] == 'closed' || dayData['openTime'] == 'none' ? loc.closed : dayData['openTime']} - ${dayData['closeTime'] == 'closed' || dayData['closeTime'] == 'none' ? loc.closed : dayData['closeTime']}'
                            : loc.closed,
                        style: AppTypography.bodySmall.copyWith(
                            color: dayData['isOpen']
                              ? WhizzColors.textSecondary
                              : WhizzColors.textPrimary.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Switch
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: dayData['isOpen'],
                    onChanged: (value) {
                      setState(() {
                        _workingHours[day]!['isOpen'] = value;
                        _workingHours[day]!['isClosed'] = !value;
                        
                        if (!value) {
                          // 🔥 When closing the day, set hours to "closed"
                          _workingHours[day]!['openTime'] = 'closed';
                          _workingHours[day]!['closeTime'] = 'closed';
                        } else {
                          // 🔥 When opening the day, set default hours if they are "closed" or "none"
                          if (_workingHours[day]!['openTime'] == 'closed' || 
                              _workingHours[day]!['openTime'] == 'none' || 
                              _workingHours[day]!['openTime'] == null) {
                            _workingHours[day]!['openTime'] = '09:00';
                          }
                          if (_workingHours[day]!['closeTime'] == 'closed' || 
                              _workingHours[day]!['closeTime'] == 'none' || 
                              _workingHours[day]!['closeTime'] == null) {
                            _workingHours[day]!['closeTime'] = '21:00';
                          }
                        }
                      });
                    },
                    activeColor: WhizzColors.secondary,
                    activeTrackColor:
                        WhizzColors.secondary.withValues(alpha: 0.3),
                    inactiveTrackColor:
                        WhizzColors.textPrimary.withValues(alpha: 0.1),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                SizedBox(width: AppSpacing.xxs),
                // Menu Button
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: WhizzColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
                  ),
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: WhizzColors.textSecondary,
                      size: 16,
                    ),
                    onSelected: (value) {
                      if (value == 'copy') {
                        _copyToAllDays(day);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 16, color: WhizzColors.textSecondary),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              loc.copyToAllDays,
                              style: AppTypography.bodySmall.copyWith(
                                color: WhizzColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Time Selection Section (only if open)
            if (dayData['isOpen']) ...[
              SizedBox(height: AppSpacing.sm),
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      WhizzColors.secondary.withValues(alpha: 0.03),
                      WhizzColors.textSecondary.withValues(alpha: 0.03),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
                  border: Border.all(
                    color: WhizzColors.secondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Open Time
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(day, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: WhizzColors.white,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.borderRadiusMD),
                            border: Border.all(
                              color:
                                  WhizzColors.secondary.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: WhizzColors.secondary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.login_rounded,
                                  size: 14,
                                  color: WhizzColors.secondary,
                                ),
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      loc.opens,
                                      style:
                                          AppTypography.bodySmall.copyWith(
                                        color: WhizzColors.textPrimary
                                            .withValues(alpha: 0.6),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      dayData['openTime'] == 'closed' || dayData['openTime'] == 'none' ? '00:00' : dayData['openTime'],
                                      style:
                                          AppTypography.titleSmall.copyWith(
                                        color: WhizzColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    // Close Time
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(day, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: WhizzColors.white,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.borderRadiusMD),
                            border: Border.all(
                              color: WhizzColors.textSecondary
                                  .withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: WhizzColors.textSecondary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.logout_rounded,
                                  size: 14,
                                  color: WhizzColors.textSecondary,
                                ),
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      loc.closes,
                                      style:
                                          AppTypography.bodySmall.copyWith(
                                        color: WhizzColors.textPrimary
                                            .withValues(alpha: 0.6),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      dayData['closeTime'] == 'closed' || dayData['closeTime'] == 'none' ? '00:00' : dayData['closeTime'],
                                      style:
                                          AppTypography.titleSmall.copyWith(
                                        color: WhizzColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: WhizzColors.textPrimary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
                  border: Border.all(
                    color: WhizzColors.textPrimary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block_rounded,
                      color: WhizzColors.textPrimary.withValues(alpha: 0.4),
                      size: 16,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      loc.closed,
                      style: AppTypography.bodySmall.copyWith(
                        color: WhizzColors.textPrimary.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(AppLocalizations loc) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: WhizzColors.secondary,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withValues(alpha: 0.3),
            blurRadius: AppSpacing.sm,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _saveWorkingHours,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  AdaptiveLoadingIndicator(
                    size: 18,
                    color: WhizzColors.textSecondary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                ] else ...[
                  Icon(
                    Icons.save_rounded,
                    color: WhizzColors.textSecondary,
                    size: 18,
                  ),
                  SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  _isLoading ? loc.saving : loc.saveWorkingHours,
                  style: AppTypography.titleMedium.copyWith(
                    color: WhizzColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
