import '../utils/readable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/location_settings_bottom_drawer.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';

class OtherSettingsPage extends ConsumerStatefulWidget {
  final Business business;

  const OtherSettingsPage({super.key, required this.business});

  @override
  ConsumerState<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends ConsumerState<OtherSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _countryController = TextEditingController();
  final _streetController = TextEditingController();

  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  String? _address;

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
      _latitude = business.latitude;
      _longitude = business.longitude;

      // Extract data directly from business properties - no parsing needed!
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
        _address = mainAddress.isNotEmpty ? mainAddress : null;
      });

      // Try to load additional location settings from API
      final apiService = ApiService();
      try {
        final settings =
            await apiService.getBusinessLocationSettings(business.id);
        if (mounted && settings['settings'] != null) {
          final locationData = settings['settings'];

          setState(() {
            // Update GPS coordinates from location settings
            _latitude = locationData['latitude']?.toDouble() ?? _latitude;
            _longitude = locationData['longitude']?.toDouble() ?? _longitude;

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

            // Update the address variable for LocationSettingsWidget based on API data
            if (locationData['address']?.toString().isNotEmpty == true) {
              _address = locationData['address'].toString();
            }
          });
        }
      } catch (e) {
        // If location settings don't exist, continue with business data
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Failed to load location settings: $e',
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

        // GPS coordinates
        'latitude': _latitude,
        'longitude': _longitude,

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
      settings.removeWhere(
          (key, value) => value == null || (value is String && value.isEmpty));

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
        showAdaptiveSnackBar(
          context: context,
          message: 'Location settings saved successfully',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Failed to save location settings: $e',
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

  void _onLocationChanged(
      double? latitude, double? longitude, String? address) {
    setState(() {
      _latitude = latitude;
      _longitude = longitude;
      _address = address;
    });

    // If we got a new address from GPS, try to parse it and update form fields
    if (address != null &&
        address.isNotEmpty &&
        address != 'Address not available (stub implementation)' &&
        address != 'Address not available') {
      final addressParts = _parseAddress(address);

      setState(() {
        // Only update fields that are currently empty to avoid overwriting user input
        if (_cityController.text.isEmpty && addressParts['city'] != null) {
          _cityController.text = addressParts['city']!;
        }

        if (_districtController.text.isEmpty &&
            addressParts['district'] != null) {
          _districtController.text = addressParts['district']!;
        }

        if (_streetController.text.isEmpty && addressParts['street'] != null) {
          _streetController.text = addressParts['street']!;
        }

        if (_countryController.text == 'Iraq' &&
            addressParts['country'] != null) {
          _countryController.text = addressParts['country']!;
        }
      });
    }
  }

  /// Simple address parsing to extract components
  Map<String, String?> _parseAddress(String address) {
    final Map<String, String?> components = {
      'street': null,
      'city': null,
      'district': null,
      'country': null,
    };

    if (address.isEmpty) return components;

    // Split address by common separators
    final parts = address
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isNotEmpty) {
      // First part is usually street address
      components['street'] = parts[0];

      // Look for common Iraqi city names
      for (final part in parts) {
        final lowerPart = part.toLowerCase();
        if (_isKnownCity(lowerPart)) {
          components['city'] = part;
          break;
        }
      }

      // If more than one part, use last part as country (if it looks like a country)
      if (parts.length > 1) {
        final lastPart = parts.last.toLowerCase();
        if (_isKnownCountry(lastPart)) {
          components['country'] = parts.last;
        }
      }

      // Try to identify district (usually middle parts that aren't city or country)
      for (final part in parts) {
        if (part != components['street'] &&
            part != components['city'] &&
            part != components['country']) {
          components['district'] = part;
          break;
        }
      }
    }

    return components;
  }

  /// Check if a string contains a known city name
  bool _isKnownCity(String text) {
    final knownCities = [
      'baghdad',
      'basra',
      'mosul',
      'erbil',
      'najaf',
      'karbala',
      'kirkuk',
      'sulaymaniyah',
      'ramadi',
      'fallujah',
      'tikrit',
      'amarah',
      'nasiriyah',
      'kut',
      'hilla',
      'diwaniyah',
      'samarra',
      'duhok',
      'zakho',
      'halabja'
    ];
    return knownCities.any((city) => text.contains(city));
  }

  /// Check if a string contains a known country name
  bool _isKnownCountry(String text) {
    final knownCountries = ['iraq', 'iraqi', 'kurdistan'];
    return knownCountries.any((country) => text.contains(country));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: WhizzColors.grey50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              WhizzColors.secondary.withValues(alpha: 0.05),
              WhizzColors.primary.withValues(alpha: 0.03),
              WhizzColors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern App Bar
              _buildModernAppBar(loc),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Business Address Section
                              _buildAddressSection(loc),
                              SizedBox(height: AppSpacing.xl),

                              // GPS Location Section
                              _buildGPSSection(),
                              SizedBox(height: AppSpacing.xl),

                              // Save Button
                              _buildSaveButton(loc),

                              // Bottom spacing
                              SizedBox(height: AppSpacing.xl),
                            ],
                          ),
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
              'Loading location settings...',
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

  Widget _buildModernAppBar(AppLocalizations loc) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        boxShadow: [
          BoxShadow(
            color: WhizzColors.shadow.withValues(alpha: 0.04),
            blurRadius: AppSpacing.sm,
            offset: Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: IconButton(
              icon:
                  Icon(Icons.arrow_back_rounded, color: WhizzColors.secondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '', // Empty title
                  style: AppTypography.headlineSmall.copyWith(
                    color: WhizzColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '', // Empty subtitle
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.textPrimary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [WhizzColors.secondary, WhizzColors.secondary],
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              boxShadow: [
                BoxShadow(
                  color: WhizzColors.secondary.withValues(alpha: 0.3),
                  blurRadius: AppSpacing.xs,
                  offset: Offset(0, AppSpacing.xxs),
                ),
              ],
            ),
            child: IconButton(
              icon: _isLoading
                  ? AdaptiveLoadingIndicator(
                      size: AppSpacing.lg,
                      color: WhizzColors.onPrimary,
                    )
                  : Icon(Icons.save_rounded, color: WhizzColors.onPrimary),
              onPressed: _isLoading ? null : _saveLocationSettings,
            ),
          ),
        ],
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
              size: AppSpacing.lg,
            ),
            SizedBox(width: AppSpacing.xs),
            Text(
              'Business Address',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.md),

        // Address form fields in Material 3 style
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _cityController,
                label: 'City',
                icon: Icons.location_city,
                color: Colors.grey.shade600,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'City required';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildModernTextField(
                controller: _districtController,
                label: 'District',
                icon: Icons.map,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),

        _buildModernTextField(
          controller: _countryController,
          label: 'Country',
          icon: Icons.public,
          color: Colors.grey.shade600,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter country';
            }
            return null;
          },
        ),
        SizedBox(height: AppSpacing.md),

        _buildModernTextField(
          controller: _streetController,
          label: 'Street Name',
          icon: Icons.streetview,
          color: Colors.grey.shade600,
          helperText: 'Street name used for location mapping and delivery',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Street name is required for mapping';
            }
            return null;
          },
        ),
      ],
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
    return TextFormField(
      controller: controller,
      validator: validator,
      style: AppTypography.bodyLarge.copyWith(
        fontWeight: FontWeight.w500,
        color: WhizzColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Container(
          margin: EdgeInsets.all(GoldenRatio.sm),
          padding: EdgeInsets.all(GoldenRatio.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
          ),
          child: Icon(
            icon,
            color: color,
            size: AppSpacing.xl,
          ),
        ),
        filled: true,
        fillColor: color.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          borderSide: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          borderSide: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          borderSide: BorderSide(color: color, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          borderSide: BorderSide(color: WhizzColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          borderSide: BorderSide(color: WhizzColors.error, width: 2),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
        helperStyle: AppTypography.bodySmall.copyWith(
          color: WhizzColors.textSecondary,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }

  Widget _buildGPSSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.gps_fixed,
              color: Colors.grey.shade600,
              size: AppSpacing.lg,
            ),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'GPS Location Settings',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            IconButton(
              onPressed: () => LocationSettingsBottomDrawer.show(
                context: context,
                initialLatitude: _latitude,
                initialLongitude: _longitude,
                initialAddress: _address,
                onLocationChanged: _onLocationChanged,
              ),
              style: IconButton.styleFrom(
                backgroundColor: WhizzColors.primary.withValues(alpha: 0.1),
                foregroundColor: readableForeground(
                    WhizzColors.primary.withValues(alpha: 0.1)),
              ),
              icon: Icon(Icons.edit_location),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WhizzColors.secondary,
            WhizzColors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withValues(alpha: 0.4),
            blurRadius: AppSpacing.lg,
            offset: Offset(0, GoldenRatio.sm),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _saveLocationSettings,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: GoldenRatio.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  AdaptiveLoadingIndicator(
                    size: AppSpacing.lg,
                    color: WhizzColors.onPrimary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(GoldenRatio.xs),
                    decoration: BoxDecoration(
                      color: WhizzColors.primary,
                      borderRadius: BorderRadius.circular(GoldenRatio.sm),
                    ),
                    child: Icon(
                      Icons.save,
                      color: WhizzColors.onSecondary,
                      size: GoldenRatio.lg,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  _isLoading ? 'Saving...' : 'Save Location Settings',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.onPrimary,
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
