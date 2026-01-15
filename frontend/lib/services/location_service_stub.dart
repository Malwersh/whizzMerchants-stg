import 'dart:math' as math;

/// Stub implementation of location service for web/unsupported platforms
class LocationService {
  static const bool _isSupported = false;

  /// Check if location services are supported on this platform
  static bool get isSupported => _isSupported;

  /// Check if location permission is granted
  static Future<bool> hasPermission() async {
    return false;
  }

  /// Request location permission
  static Future<bool> requestPermission() async {
    return false;
  }

  /// Get current location
  static Future<Map<String, double>?> getCurrentLocation() async {
    // Return a default location (optional)
    return {
      'latitude': 24.7136,
      'longitude': 46.6753, // Riyadh, Saudi Arabia
    };
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return false;
  }

  /// Start location updates
  static Future<void> startLocationUpdates(Function(Map<String, double>) onLocationUpdate) async {
    // Do nothing in stub implementation
  }

  /// Stop location updates
  static Future<void> stopLocationUpdates() async {
    // Do nothing in stub implementation
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
    return degrees * (math.pi / 180);
  }

  /// Get address from coordinates (geocoding)
  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    return 'Address not available (stub implementation)';
  }

  /// Get coordinates from address (reverse geocoding)
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    return null;
  }
}
