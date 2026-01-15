import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../l10n/app_localizations.dart';
import '../core/theme/whizz_colors.dart';

class LocationSettingsWidget extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final Function(double?, double?, String?) onLocationChanged;
  final bool isLoading;

  const LocationSettingsWidget({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    required this.onLocationChanged,
    this.isLoading = false,
  });

  @override
  _LocationSettingsWidgetState createState() => _LocationSettingsWidgetState();
}

class _LocationSettingsWidgetState extends State<LocationSettingsWidget> {
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

  @override
  void didUpdateWidget(LocationSettingsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLatitude != oldWidget.initialLatitude ||
        widget.initialLongitude != oldWidget.initialLongitude ||
        widget.initialAddress != oldWidget.initialAddress) {
      setState(() {
        _latitude = widget.initialLatitude;
        _longitude = widget.initialLongitude;
        _address = widget.initialAddress;
      });
      _updateControllers();
    }
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
      widget.onLocationChanged(_latitude, _longitude, _address);
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

        // Notify parent widget
        widget.onLocationChanged(_latitude, _longitude, finalAddress);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location retrieved successfully',
                  style: TextStyle(color: WhizzColors.secondary)),
              backgroundColor: WhizzColors.primary,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.enableLocationServices,
                style: TextStyle(color: WhizzColors.secondary)),
            backgroundColor: WhizzColors.primary,
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: WhizzColors.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.businessLocation,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: WhizzColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              localizations.businessLocationDescription,
              style: TextStyle(
                fontSize: 14,
                color: WhizzColors.secondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            // GPS Coordinates Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    decoration: InputDecoration(
                      labelText: localizations.latitude,
                      labelStyle: TextStyle(color: WhizzColors.secondary),
                      hintText: '33.3152',
                      hintStyle: TextStyle(
                          color: WhizzColors.secondary.withValues(alpha: 0.6)),
                      prefixIcon:
                          Icon(Icons.navigation, color: WhizzColors.secondary),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: WhizzColors.secondary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: WhizzColors.secondary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: WhizzColors.secondary.withValues(alpha: 0.5)),
                      ),
                    ),
                    style: TextStyle(color: WhizzColors.secondary),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onCoordinatesChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    decoration: InputDecoration(
                      labelText: localizations.longitude,
                      labelStyle: TextStyle(color: WhizzColors.secondary),
                      hintText: '44.3661',
                      hintStyle: TextStyle(
                          color: WhizzColors.secondary.withValues(alpha: 0.6)),
                      prefixIcon:
                          Icon(Icons.navigation, color: WhizzColors.secondary),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: WhizzColors.secondary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: WhizzColors.secondary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: WhizzColors.secondary.withValues(alpha: 0.5)),
                      ),
                    ),
                    style: TextStyle(color: WhizzColors.secondary),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onCoordinatesChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current Location Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isLoading || widget.isLoading) 
                    ? null 
                    : _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhizzColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: (_isLoading || widget.isLoading)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text('Get Current Location',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            
            // Location Status
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WhizzColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: WhizzColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: WhizzColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localizations.locationSet,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: WhizzColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    if (_address != null && _address!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _address!,
                        style: TextStyle(
                          fontSize: 13,
                          color: WhizzColors.secondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Coordinates: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: WhizzColors.secondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WhizzColors.secondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: WhizzColors.secondary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_off,
                      color: WhizzColors.secondary.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizations.noLocationSet,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: WhizzColors.secondary.withValues(alpha: 0.7),
                        ),
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
}
