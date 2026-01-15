import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';
import '../core/theme/whizz_colors.dart';

class GpsSettingsBottomDrawer extends ConsumerStatefulWidget {
  final Business business;

  const GpsSettingsBottomDrawer({
    super.key,
    required this.business,
  });

  @override
  ConsumerState<GpsSettingsBottomDrawer> createState() =>
      _GpsSettingsBottomDrawerState();

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
      builder: (context) => GpsSettingsBottomDrawer(
        business: business,
      ),
    );
  }
}

class _GpsSettingsBottomDrawerState
    extends ConsumerState<GpsSettingsBottomDrawer> {
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
      if (widget.business.latitude != null &&
          widget.business.longitude != null) {
        _latitude = widget.business.latitude;
        _longitude = widget.business.longitude;
        _latitudeController.text = _latitude!.toStringAsFixed(6);
        _longitudeController.text = _longitude!.toStringAsFixed(6);

        // Get address for current coordinates
        try {
          _address = await LocationService.getAddressFromCoordinates(
            latitude: _latitude!,
            longitude: _longitude!,
          );
        } catch (e) {
          debugPrint('Error getting address: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission denied'),
            backgroundColor: WhizzColors.primary,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid coordinates'),
          backgroundColor: WhizzColors.primary,
        ),
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
          'address': _address ?? 'Address not available',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS coordinates saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Close the bottom drawer
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving GPS coordinates: $e'),
            backgroundColor: WhizzColors.primary,
          ),
        );
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onCoordinateChanged() {
    try {
      final lat = double.tryParse(_latitudeController.text);
      final lng = double.tryParse(_longitudeController.text);

      if (lat != null && lng != null) {
        setState(() {
          _latitude = lat;
          _longitude = lng;
        });

        // Get address for manually entered coordinates
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          LocationService.getAddressFromCoordinates(
            latitude: lat,
            longitude: lng,
          ).then((address) {
            if (mounted) {
              setState(() {
                _address = address;
              });
            }
          }).catchError((e) {
            debugPrint('Error getting address for manual coordinates: $e');
          });
        }
      }
    } catch (e) {
      debugPrint('Error parsing coordinates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(GoldenRatio.radiusXl),
          topRight: Radius.circular(GoldenRatio.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: GoldenRatio.spacing12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(GoldenRatio.spacing20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(GoldenRatio.spacing8),
                  decoration: BoxDecoration(
                    color: WhizzColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(GoldenRatio.radiusSm),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: WhizzColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: GoldenRatio.spacing12),
                Expanded(
                  child: SizedBox.shrink(),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: GoldenRatio.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Current location section
                  if (_address != null) ...[
                    Container(
                      padding: const EdgeInsets.all(GoldenRatio.spacing16),
                      decoration: BoxDecoration(
                        color: WhizzColors.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusMd),
                        border: Border.all(
                          color: WhizzColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: WhizzColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current Location',
                                style: TypographySystem.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: WhizzColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _address!,
                            style: TypographySystem.bodySmall.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: GoldenRatio.spacing20),
                  ],

                  // Get current location button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _loadingCurrentLocation ? null : _getCurrentLocation,
                      icon: _loadingCurrentLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(_loadingCurrentLocation
                          ? 'Getting Location...'
                          : 'Get Current Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WhizzColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: GoldenRatio.spacing12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(GoldenRatio.radiusMd),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: GoldenRatio.spacing24),

                  // Manual coordinates section
                  Text(
                    'Manual Coordinates',
                    style: TypographySystem.headlineSmall.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: GoldenRatio.spacing12),

                  // Latitude field
                  TextFormField(
                    controller: _latitudeController,
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'Enter latitude (e.g., 24.7136)',
                      prefixIcon: const Icon(Icons.explore),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusMd),
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onCoordinateChanged(),
                  ),

                  const SizedBox(height: GoldenRatio.spacing16),

                  // Longitude field
                  TextFormField(
                    controller: _longitudeController,
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'Enter longitude (e.g., 46.6753)',
                      prefixIcon: const Icon(Icons.explore_off),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusMd),
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _onCoordinateChanged(),
                  ),

                  const SizedBox(height: GoldenRatio.spacing24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _saveGpsCoordinates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WhizzColors.primary,
                        foregroundColor: WhizzColors.secondary,
                        padding: const EdgeInsets.symmetric(
                            vertical: GoldenRatio.spacing16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(GoldenRatio.radiusMd),
                        ),
                      ),
                      child: _loading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Saving...'),
                              ],
                            )
                          : const Text(
                              'Save GPS Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // Bottom padding for safe area
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom +
                          GoldenRatio.spacing20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
