// WizzMerchant - Region Model
// Matches Central Platform API response structure

class Region {
  final String regionId;
  final String regionName;
  final String regionNameArabic;
  final String nameEn;
  final String nameAr;
  final String governorate;
  final String regionType; // PROVINCE, DISTRICT, NEIGHBORHOOD
  final String status; // ACTIVE, INACTIVE
  final String? parentId;
  final GpsCoordinates? gpsCoordinates;
  final String typeLabel; // Localized type label
  final String statusLabel; // Localized status label

  Region({
    required this.regionId,
    required this.regionName,
    required this.regionNameArabic,
    required this.nameEn,
    required this.nameAr,
    required this.governorate,
    required this.regionType,
    required this.status,
    this.parentId,
    this.gpsCoordinates,
    required this.typeLabel,
    required this.statusLabel,
  });

  /// Factory constructor from JSON (Central Platform API response)
  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      regionId: json['regionId'] as String,
      regionName: json['regionName'] as String,
      regionNameArabic: json['regionNameArabic'] as String,
      nameEn: json['regionName'] as String, // Use regionName as fallback
      nameAr: json['regionNameArabic']
          as String, // Use regionNameArabic as fallback
      governorate: json['governorate'] as String,
      regionType: json['regionType'] as String, // Fixed: use camelCase
      status: json['status'] as String,
      parentId: json['parentId'] as String?, // Fixed: use camelCase
      gpsCoordinates: json['gpsCoordinates'] != null
          ? GpsCoordinates.fromJson(json['gpsCoordinates'])
          : null,
      typeLabel: json['regionType'] as String, // Use regionType as fallback
      statusLabel: json['status'] as String, // Use status as fallback
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'regionId': regionId,
      'regionName': regionName,
      'regionNameArabic': regionNameArabic,
      'nameEn': nameEn,
      'nameAr': nameAr,
      'governorate': governorate,
      'regionType': regionType,
      'status': status,
      'parentId': parentId,
      'gpsCoordinates': gpsCoordinates?.toJson(),
      'typeLabel': typeLabel,
      'statusLabel': statusLabel,
    };
  }

  /// Check if region is active
  bool get isActive => status == 'ACTIVE';

  /// Get display name based on language
  String getDisplayName(String language) {
    return language == 'ar' ? nameAr : nameEn;
  }

  @override
  String toString() {
    return 'Region(id: $regionId, name: $regionName, type: $regionType, status: $status)';
  }
}

/// GPS Coordinates Model
class GpsCoordinates {
  final double lat;
  final double lng;

  GpsCoordinates({
    required this.lat,
    required this.lng,
  });

  factory GpsCoordinates.fromJson(Map<String, dynamic> json) {
    return GpsCoordinates(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }

  @override
  String toString() => 'GpsCoordinates(lat: $lat, lng: $lng)';
}
