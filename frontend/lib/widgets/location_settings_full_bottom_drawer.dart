import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';

class LocationSettingsFullBottomDrawer extends ConsumerStatefulWidget {
  final Business business;

  const LocationSettingsFullBottomDrawer({
    super.key,
    required this.business,
  });

  @override
  ConsumerState<LocationSettingsFullBottomDrawer> createState() =>
      _LocationSettingsFullBottomDrawerState();

  /// Static method to show the bottom drawer
  static Future<void> show({
    required BuildContext context,
    required Business business,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => LocationSettingsFullBottomDrawer(
        business: business,
      ),
    );
  }
}

class _LocationSettingsFullBottomDrawerState
    extends ConsumerState<LocationSettingsFullBottomDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _countryController = TextEditingController();
  final _streetController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocationSettings();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _districtController.dispose();
    _countryController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load business data
      final business = widget.business;

      // Extract data directly from business properties
      String city = business.city ?? '';
      String district = business.district ?? '';
      String street = business.street ?? '';
      String country = business.country ?? 'Iraq';
      String mainAddress = business.address ?? '';

      // If we don't have a full address but have components, build it
      if (mainAddress.isEmpty &&
          (city.isNotEmpty || district.isNotEmpty || street.isNotEmpty)) {
        final addressParts = [street, district, city, country]
            .where((part) => part.isNotEmpty)
            .toList();
        mainAddress = addressParts.join(', ');
      }

      // Set the form fields with extracted data
      setState(() {
        _cityController.text = city;
        _districtController.text = district;
        _streetController.text = street;
        _countryController.text = country;
      });

      // Try to load additional location settings from API
      final apiService = ApiService();
      try {
        final settings =
            await apiService.getBusinessLocationSettings(business.id);
        if (mounted && settings['settings'] != null) {
          final locationData = settings['settings'];

          setState(() {
            // Override with API data if available and more specific
            if (locationData['city']?.toString().isNotEmpty == true) {
              _cityController.text = locationData['city'].toString();
            }
            if (locationData['district']?.toString().isNotEmpty == true) {
              _districtController.text = locationData['district'].toString();
            }
            if (locationData['street']?.toString().isNotEmpty == true) {
              _streetController.text = locationData['street'].toString();
            }
            if (locationData['country']?.toString().isNotEmpty == true) {
              _countryController.text = locationData['country'].toString();
            }
          });
        }
      } catch (e) {
        // If location settings don't exist, continue with business data
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.failedToLoadLocationSettings(e.toString())),
            backgroundColor: WhizzColors.error,
          ),
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

  Future<void> _saveLocationSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();

      // Create comprehensive location settings object
      final settings = {
        // Individual address components for mapping
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'country': _countryController.text.trim(),
        'street': _streetController.text.trim(),

        // Build address string for backward compatibility
        'address': _buildAddressString(),

        // Additional metadata
        'updated_at': DateTime.now().toIso8601String(),

        // Also include the DynamoDB format for backward compatibility
        'address_components': {
          'city': {'S': _cityController.text.trim()},
          'district': {'S': _districtController.text.trim()},
          'country': {'S': _countryController.text.trim()},
          'street': {'S': _streetController.text.trim()},
        },
      };

      // Remove empty fields to keep the data clean
      settings.removeWhere((key, value) => (value is String && value.isEmpty));

      // Also remove empty nested components
      if (settings['address_components'] != null) {
        final components =
            settings['address_components'] as Map<String, dynamic>;
        components.removeWhere((key, value) {
          if (value is Map<String, dynamic> && value['S'] is String) {
            return (value['S'] as String).isEmpty;
          }
          return false;
        });

        if (components.isEmpty) {
          settings.remove('address_components');
        }
      }

      await apiService.updateBusinessLocationSettings(
          widget.business.id, settings);

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: WhizzColors.onSecondary),
                SizedBox(width: GoldenRatio.spacing12),
                Text(
                  loc.locationSettingsSavedSuccessfully,
                  style: TypographySystem.bodyMedium.copyWith(
                    color: WhizzColors.onSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: GoldenRatio.spacing12),
                Expanded(
                  child: Text(
                    loc.failedToSaveLocationSettings(e.toString()),
                    style: TypographySystem.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
            ),
          ),
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

  /// Build a readable address string from individual components
  String _buildAddressString() {
    // Build from components
    final parts = <String>[];

    if (_streetController.text.trim().isNotEmpty) {
      parts.add(_streetController.text.trim());
    }
    if (_districtController.text.trim().isNotEmpty) {
      parts.add(_districtController.text.trim());
    }
    if (_cityController.text.trim().isNotEmpty) {
      parts.add(_cityController.text.trim());
    }
    if (_countryController.text.trim().isNotEmpty) {
      parts.add(_countryController.text.trim());
    }

    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(GoldenRatio.radiusXl),
          topRight: Radius.circular(GoldenRatio.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: GoldenRatio.spacing20,
            offset: Offset(0, -GoldenRatio.spacing8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: GoldenRatio.spacing12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WhizzColors.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(GoldenRatio.spacing24),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(GoldenRatio.spacing12),
                      decoration: BoxDecoration(
                        color: WhizzColors.secondary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusMd),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: WhizzColors.secondary,
                        size: GoldenRatio.spacing24,
                      ),
                    ),
                    SizedBox(width: GoldenRatio.spacing16),
                    Expanded(
                      child: SizedBox.shrink(),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: WhizzColors.surfaceVariant,
                        foregroundColor: WhizzColors.onSurfaceVariant,
                      ),
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              // Content
              if (_isLoading)
                _buildLoadingState()
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    GoldenRatio.spacing24,
                    0,
                    GoldenRatio.spacing24,
                    GoldenRatio.spacing24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Business Address Section
                        _buildAddressSection(loc),
                        SizedBox(height: GoldenRatio.spacing24),

                        // Save Button
                        _buildSaveButton(loc),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.all(GoldenRatio.spacing24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: WhizzColors.primary,
              strokeWidth: 3,
            ),
            SizedBox(height: GoldenRatio.spacing16),
            Text(
              loc.loadingLocationSettings,
              style: TypographySystem.bodyLarge.copyWith(
                color: WhizzColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.business,
              color: Colors.grey.shade600,
              size: GoldenRatio.spacing20,
            ),
            SizedBox(width: GoldenRatio.spacing8),
            Text(
              loc.businessAddress,
              style: TypographySystem.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: GoldenRatio.spacing16),

        // Address form fields
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _cityController,
                label: loc.city,
                icon: Icons.location_city,
                color: Colors.grey.shade600,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.cityRequired;
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: GoldenRatio.spacing16),
            Expanded(
              child: _buildModernTextField(
                controller: _districtController,
                label: loc.district,
                icon: Icons.map,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: GoldenRatio.spacing20),

        _buildModernTextField(
          controller: _countryController,
          label: loc.country,
          icon: Icons.public,
          color: Colors.grey.shade600,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return loc.pleaseEnterCountry;
            }
            return null;
          },
        ),
        SizedBox(height: GoldenRatio.spacing16),

        _buildModernTextField(
          controller: _streetController,
          label: loc.streetName,
          icon: Icons.streetview,
          color: Colors.grey.shade600,
          helperText: loc.streetNameHelper,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return loc.streetNameRequired;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WhizzColors.primary,
            WhizzColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: WhizzColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _saveLocationSettings,
          borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: GoldenRatio.spacing18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  SizedBox(
                    width: GoldenRatio.spacing20,
                    height: GoldenRatio.spacing20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WhizzColors.secondary,
                    ),
                  ),
                  SizedBox(width: GoldenRatio.spacing12),
                ] else ...[
                  Icon(
                    Icons.save,
                    color: WhizzColors.secondary,
                    size: GoldenRatio.spacing20,
                  ),
                  SizedBox(width: GoldenRatio.spacing12),
                ],
                Text(
                  _isLoading ? loc.saving : loc.saveLocationSettings,
                  style: TypographySystem.titleMedium.copyWith(
                    color: WhizzColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withValues(alpha: 0.08),
            blurRadius: GoldenRatio.spacing8,
            offset: Offset(0, GoldenRatio.spacing4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: TypographySystem.bodyLarge.copyWith(
          color: WhizzColors.onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: label,
          helperText: helperText,
          prefixIcon: Container(
            margin: EdgeInsets.all(GoldenRatio.spacing12),
            padding: EdgeInsets.all(GoldenRatio.spacing8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  WhizzColors.secondary.withValues(alpha: 0.1),
                  WhizzColors.secondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
              border: Border.all(
                color: WhizzColors.secondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: WhizzColors.secondary,
              size: GoldenRatio.spacing20,
            ),
          ),
          filled: true,
          fillColor: WhizzColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.secondary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          labelStyle: TypographySystem.bodyMedium.copyWith(
            color: WhizzColors.secondary,
            fontWeight: FontWeight.w500,
          ),
          helperStyle: TypographySystem.bodySmall.copyWith(
            color: WhizzColors.onSurfaceVariant,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.spacing20,
            vertical: GoldenRatio.spacing16,
          ),
        ),
      ),
    );
  }
}
