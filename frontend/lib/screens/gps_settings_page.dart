import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';

class GpsSettingsPage extends ConsumerStatefulWidget {
  final Business business;

  const GpsSettingsPage({
    super.key,
    required this.business,
  });

  @override
  ConsumerState<GpsSettingsPage> createState() => _GpsSettingsPageState();
}

class _GpsSettingsPageState extends ConsumerState<GpsSettingsPage> {
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _loading = false;
  bool _loadingCurrentLocation = false;

  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBusinessCoordinates();
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessCoordinates() async {
    setState(() {
      _loading = true;
    });

    try {
      // Load coordinates from business object
      _latitude = widget.business.latitude;
      _longitude = widget.business.longitude;

      // Update controllers
      if (_latitude != null) {
        _latitudeController.text = _latitude!.toStringAsFixed(6);
      }
      if (_longitude != null) {
        _longitudeController.text = _longitude!.toStringAsFixed(6);
      }

      // Load address if coordinates exist
      if (_latitude != null && _longitude != null) {
        try {
          _address = await LocationService.getAddressFromCoordinates(
            latitude: _latitude!,
            longitude: _longitude!,
          );
        } catch (e) {
          debugPrint('Error loading address: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading business coordinates: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _loadingCurrentLocation = true;
    });

    try {
      final currentLocationMap = await LocationService.getCurrentLocation();

      if (currentLocationMap != null) {
        final latitude = currentLocationMap['latitude']!;
        final longitude = currentLocationMap['longitude']!;

        setState(() {
          _latitude = latitude;
          _longitude = longitude;
          _latitudeController.text = _latitude!.toStringAsFixed(6);
          _longitudeController.text = _longitude!.toStringAsFixed(6);
        });

        // Get address for the new coordinates
        try {
          _address = await LocationService.getAddressFromCoordinates(
            latitude: _latitude!,
            longitude: _longitude!,
          );
          setState(() {});
        } catch (e) {
          debugPrint('Error getting address: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Location permission denied',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      setState(() {
        _loadingCurrentLocation = false;
      });
    }
  }

  Future<void> _saveGpsCoordinates() async {
    if (_latitude == null || _longitude == null) {
      showAdaptiveSnackBar(
        context: context,
        message: 'Please enter valid coordinates',
        type: AdaptiveSnackBarType.warning,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final apiService = ApiService();

      // Update business coordinates using location settings API
      await apiService.updateBusinessLocationSettings(
        widget.business.id,
        {
          'latitude': _latitude,
          'longitude': _longitude,
        },
      );

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Coordinates saved successfully',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Error saving coordinates: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onCoordinateChanged() {
    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();

    if (latText.isNotEmpty && lngText.isNotEmpty) {
      try {
        final lat = double.parse(latText);
        final lng = double.parse(lngText);

        // Validate coordinate ranges
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
            _address = null; // Clear address when coordinates change manually
          });
        }
      } catch (e) {
        // Invalid number format, ignore
      }
    }
  }

  Widget _buildCoordinateCard() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                ),
                child: Icon(
                  Icons.gps_fixed_rounded,
                  color: theme.colorScheme.primary,
                  size: AppSpacing.lg,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS Coordinates',
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: GoldenRatio.xs),
                    Text(
                      'Manage your business GPS coordinates',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xl),

          // Latitude Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latitude',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _latitudeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _onCoordinateChanged(),
                decoration: InputDecoration(
                  hintText: '33.888630',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.md),

          // Longitude Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Longitude',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _longitudeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _onCoordinateChanged(),
                decoration: InputDecoration(
                  hintText: '35.895285',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.lg),

          // Current Location Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingCurrentLocation ? null : _getCurrentLocation,
              icon: _loadingCurrentLocation
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: AdaptiveLoadingIndicator(
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    )
                  : Icon(
                      Icons.my_location_rounded,
                      color: theme.colorScheme.onPrimary,
                    ),
              label: Text(
                'Use Current Location',
                style: AppTypography.labelLarge.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                ),
              ),
            ),
          ),

          // Address Display
          if (_address != null) ...[
            SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusSM),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_city_rounded,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _address!,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
          ),
        ),
        title: Text(
          'GPS Settings',
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_latitude != null && _longitude != null)
            TextButton(
              onPressed: _loading ? null : _saveGpsCoordinates,
              child: _loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: AdaptiveLoadingIndicator(
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    )
                  : Text(
                      'Save',
                      style: AppTypography.labelLarge.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: AdaptiveLoadingIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : ListView(
              padding: EdgeInsets.all(AppSpacing.lg),
              children: [
                _buildCoordinateCard(),

                SizedBox(height: AppSpacing.xl),

                // Info Card
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.colorScheme.secondary,
                        size: AppSpacing.lg,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'GPS coordinates help customers find your business and improve delivery accuracy.',
                          style: AppTypography.bodySmall.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
