import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Main location service that delegates to platform-specific implementations
class LocationService {
  static const bool _isSupported = kIsWeb ? false : true;

  /// Check if location services are supported on this platform
  static bool get isSupported => _isSupported;

  /// Check if we're running on iOS simulator
  static bool get _isIOSSimulator {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS && (kDebugMode || kProfileMode);
  }

  /// Check if location permission is granted
  static Future<bool> hasPermission() async {
    if (!_isSupported) {
      return false;
    }
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
             permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  /// Request location permission
  static Future<bool> requestPermission() async {
    if (!_isSupported) {
      return false;
    }
    
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return false;
      }
      
      bool hasPermission = permission == LocationPermission.always ||
                          permission == LocationPermission.whileInUse;
      return hasPermission;
    } catch (e) {
      return false;
    }
  }

  /// Get current location
  static Future<Map<String, double>?> getCurrentLocation() async {
    if (!_isSupported) {
      return {
        'latitude': 24.7136,
        'longitude': 46.6753, // Riyadh, Saudi Arabia
      };
    }
    
    // Handle iOS Simulator case - it often has issues with real GPS
    if (_isIOSSimulator) {
      return {
        'latitude': 24.7136,  // Riyadh coordinates
        'longitude': 46.6753,
      };
    }
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try to open location settings
        await Geolocator.openLocationSettings();
        return null;
      }
      
      // Check and request permission
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        return null;
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      return null;
    }
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    if (!_isSupported) {
      return false;
    }
    
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }

  /// Start location updates
  static Future<void> startLocationUpdates(Function(Map<String, double>) onLocationUpdate) async {
    if (!_isSupported) {
      return;
    }
    
    try {
      // In a real implementation, you would start listening to location changes
    } catch (e) {
      // Handle error silently
    }
  }

  /// Stop location updates
  static Future<void> stopLocationUpdates() async {
    if (!_isSupported) {
      return;
    }
    
    try {
      // In a real implementation, you would stop listening to location changes
    } catch (e) {
      // Handle error silently
    }
  }

  /// Calculate distance between two points (in kilometers)
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    // Simple distance calculation using Haversine formula
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Get address from coordinates (geocoding)
  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isSupported) {
      return 'Address not available';
    }
    
    try {
      // In a real implementation, you would use geocoding service
      return null; // Placeholder
    } catch (e) {
      return null;
    }
  }

  /// Get coordinates from address (reverse geocoding)
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    if (!_isSupported) {
      return null;
    }
    
    try {
      // In a real implementation, you would use reverse geocoding service
      return null; // Placeholder
    } catch (e) {
      return null;
    }
  }
}
