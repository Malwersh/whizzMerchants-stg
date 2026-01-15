import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../l10n/app_localizations.dart';
import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';
import '../core/theme/whizz_colors.dart';

class LocationSettingsBottomDrawer extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final Function(double?, double?, String?) onLocationChanged;

  const LocationSettingsBottomDrawer({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    required this.onLocationChanged,
  });

  @override
  State<LocationSettingsBottomDrawer> createState() =>
      _LocationSettingsBottomDrawerState();

  /// Static method to show the bottom drawer
  static Future<void> show({
    required BuildContext context,
    double? initialLatitude,
    double? initialLongitude,
    String? initialAddress,
    required Function(double?, double?, String?) onLocationChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSettingsBottomDrawer(
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
        initialAddress: initialAddress,
        onLocationChanged: onLocationChanged,
      ),
    );
  }
}

class _LocationSettingsBottomDrawerState
    extends State<LocationSettingsBottomDrawer> {
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoading = false;
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _address = widget.initialAddress;
    _updateControllers();
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _updateControllers() {
    _latitudeController.text = _latitude?.toString() ?? '';
    _longitudeController.text = _longitude?.toString() ?? '';
  }

  void _onCoordinatesChanged() {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);

    if (lat != null && lng != null) {
      setState(() {
        _latitude = lat;
        _longitude = lng;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentLocationMap = await LocationService.getCurrentLocation();
      if (currentLocationMap != null && mounted) {
        final latitude = currentLocationMap['latitude']!;
        final longitude = currentLocationMap['longitude']!;

        setState(() {
          _latitude = latitude;
          _longitude = longitude;
        });
        _updateControllers();

        // Get address from coordinates
        final address = await LocationService.getAddressFromCoordinates(
          latitude: latitude,
          longitude: longitude,
        );

        final finalAddress = (address == null ||
                address == 'Address not available (stub implementation)' ||
                address == 'Address not available')
            ? null
            : address;

        setState(() {
          _address = finalAddress;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: WhizzColors.onSecondary),
                  SizedBox(width: GoldenRatio.spacing12),
                  Text(
                    'Location retrieved successfully',
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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: GoldenRatio.spacing12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.enableLocationServices,
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

  void _saveLocation() {
    widget.onLocationChanged(_latitude, _longitude, _address);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: WhizzColors.onSecondary),
            SizedBox(width: GoldenRatio.spacing12),
            Text(
              'Location settings updated successfully',
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.businessLocation,
                            style: TypographySystem.headlineSmall.copyWith(
                              color: WhizzColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Set your business location coordinates',
                            style: TypographySystem.bodyMedium.copyWith(
                              color: WhizzColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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

              // Form content
              Padding(
                padding: EdgeInsets.fromLTRB(
                  GoldenRatio.spacing24,
                  0,
                  GoldenRatio.spacing24,
                  GoldenRatio.spacing24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Description
                    Text(
                      loc.businessLocationDescription,
                      style: TypographySystem.bodyMedium.copyWith(
                        color: WhizzColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: GoldenRatio.spacing20),

                    // GPS Coordinates Input
                    Row(
                      children: [
                        Expanded(
                          child: _buildCoordinateField(
                            controller: _latitudeController,
                            label: loc.latitude,
                            hint: '33.3152',
                            icon: Icons.navigation,
                          ),
                        ),
                        SizedBox(width: GoldenRatio.spacing12),
                        Expanded(
                          child: _buildCoordinateField(
                            controller: _longitudeController,
                            label: loc.longitude,
                            hint: '44.3661',
                            icon: Icons.navigation,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: GoldenRatio.spacing20),

                    // Current Location Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            WhizzColors.secondary,
                            WhizzColors.secondary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: WhizzColors.secondary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _getCurrentLocation,
                          borderRadius:
                              BorderRadius.circular(GoldenRatio.radiusLg),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: GoldenRatio.spacing16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoading) ...[
                                  SizedBox(
                                    width: GoldenRatio.spacing20,
                                    height: GoldenRatio.spacing20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: GoldenRatio.spacing12),
                                ] else ...[
                                  Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                    size: GoldenRatio.spacing20,
                                  ),
                                  SizedBox(width: GoldenRatio.spacing12),
                                ],
                                Text(
                                  _isLoading
                                      ? 'Getting Location...'
                                      : 'Get Current Location',
                                  style: TypographySystem.titleMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: GoldenRatio.spacing24),

                    // Save Button
                    Container(
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
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusLg),
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
                          onTap: _saveLocation,
                          borderRadius:
                              BorderRadius.circular(GoldenRatio.radiusLg),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: GoldenRatio.spacing18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.save,
                                  color: WhizzColors.secondary,
                                  size: GoldenRatio.spacing20,
                                ),
                                SizedBox(width: GoldenRatio.spacing12),
                                Text(
                                  'Save Location Settings',
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
                    ),

                    SizedBox(height: GoldenRatio.spacing24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
        keyboardType: TextInputType.number,
        onChanged: (_) => _onCoordinatesChanged(),
        style: TypographySystem.bodyLarge.copyWith(
          color: WhizzColors.onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
          hintStyle: TypographySystem.bodyMedium.copyWith(
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
