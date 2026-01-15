// WizzMerchant - Mock Region Data for Testing
// Use this for testing the region selector UI without API dependency

import '../models/region.dart';

class MockRegionData {
  static List<Region> getMockRegions() {
    return [
      // Baghdad Governorate
      Region(
        regionId: 'REG_BGD_000',
        regionName: 'Baghdad',
        regionNameArabic: 'بغداد',
        nameEn: 'Baghdad',
        nameAr: 'بغداد',
        governorate: 'Baghdad',
        regionType: 'PROVINCE',
        status: 'ACTIVE',
        parentId: null,
        typeLabel: 'Province',
        statusLabel: 'Active',
      ),

      // Baghdad Districts
      Region(
        regionId: 'REG_BGD_001',
        regionName: 'Al-Karkh',
        regionNameArabic: 'الكرخ',
        nameEn: 'Al-Karkh',
        nameAr: 'الكرخ',
        governorate: 'Baghdad',
        regionType: 'DISTRICT',
        status: 'ACTIVE',
        parentId: 'REG_BGD_000',
        typeLabel: 'District',
        statusLabel: 'Active',
      ),

      Region(
        regionId: 'REG_BGD_002',
        regionName: 'Al-Rusafa',
        regionNameArabic: 'الرصافة',
        nameEn: 'Al-Rusafa',
        nameAr: 'الرصافة',
        governorate: 'Baghdad',
        regionType: 'DISTRICT',
        status: 'ACTIVE',
        parentId: 'REG_BGD_000',
        typeLabel: 'District',
        statusLabel: 'Active',
      ),

      // Al-Karkh Neighborhoods WITH GPS COORDINATES
      Region(
        regionId: 'REG_BGD_001_001',
        regionName: 'Al-Mansour',
        regionNameArabic: 'المنصور',
        nameEn: 'Al-Mansour',
        nameAr: 'المنصور',
        governorate: 'Baghdad',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_BGD_001',
        gpsCoordinates: GpsCoordinates(lat: 33.3152, lng: 44.3661),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      Region(
        regionId: 'REG_BGD_001_002',
        regionName: 'Al-Kadhimiya',
        regionNameArabic: 'الكاظمية',
        nameEn: 'Al-Kadhimiya',
        nameAr: 'الكاظمية',
        governorate: 'Baghdad',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_BGD_001',
        gpsCoordinates: GpsCoordinates(lat: 33.3794, lng: 44.3403),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      Region(
        regionId: 'REG_BGD_001_003',
        regionName: 'Al-Jadriya',
        regionNameArabic: 'الجادرية',
        nameEn: 'Al-Jadriya',
        nameAr: 'الجادرية',
        governorate: 'Baghdad',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_BGD_001',
        gpsCoordinates: GpsCoordinates(lat: 33.2851, lng: 44.3801),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      // Al-Rusafa Neighborhoods WITH GPS COORDINATES
      Region(
        regionId: 'REG_BGD_002_001',
        regionName: 'Karrada',
        regionNameArabic: 'الكرادة',
        nameEn: 'Karrada',
        nameAr: 'الكرادة',
        governorate: 'Baghdad',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_BGD_002',
        gpsCoordinates: GpsCoordinates(lat: 33.3085, lng: 44.4238),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      Region(
        regionId: 'REG_BGD_002_002',
        regionName: 'Sadr City',
        regionNameArabic: 'مدينة الصدر',
        nameEn: 'Sadr City',
        nameAr: 'مدينة الصدر',
        governorate: 'Baghdad',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_BGD_002',
        gpsCoordinates: GpsCoordinates(lat: 33.3897, lng: 44.4892),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      // Basra Governorate
      Region(
        regionId: 'REG_BAS_000',
        regionName: 'Basra',
        regionNameArabic: 'البصرة',
        nameEn: 'Basra',
        nameAr: 'البصرة',
        governorate: 'Basra',
        regionType: 'PROVINCE',
        status: 'ACTIVE',
        parentId: null,
        typeLabel: 'Province',
        statusLabel: 'Active',
      ),

      // Basra Districts
      Region(
        regionId: 'REG_BAS_001',
        regionName: 'Basra Center',
        regionNameArabic: 'مركز البصرة',
        nameEn: 'Basra Center',
        nameAr: 'مركز البصرة',
        governorate: 'Basra',
        regionType: 'DISTRICT',
        status: 'ACTIVE',
        parentId: 'REG_BAS_000',
        typeLabel: 'District',
        statusLabel: 'Active',
      ),

      // Basra Neighborhoods
      Region(
        regionId: 'REG_BAS_001_001',
        regionName: 'Al-Ashar',
        regionNameArabic: 'العشار',
        nameEn: 'Al-Ashar',
        nameAr: 'العشار',
        governorate: 'Basra',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_BAS_001',
        gpsCoordinates: GpsCoordinates(lat: 30.5085, lng: 47.8133),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      Region(
        regionId: 'REG_BAS_001_002',
        regionName: 'Al-Jubailah',
        regionNameArabic: 'الجبيلة',
        nameEn: 'Al-Jubailah',
        nameAr: 'الجبيلة',
        governorate: 'Basra',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_BAS_001',
        gpsCoordinates: GpsCoordinates(lat: 30.4921, lng: 47.8009),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      // Erbil Governorate
      Region(
        regionId: 'REG_ERB_000',
        regionName: 'Erbil',
        regionNameArabic: 'أربيل',
        nameEn: 'Erbil',
        nameAr: 'أربيل',
        governorate: 'Erbil',
        regionType: 'PROVINCE',
        status: 'ACTIVE',
        parentId: null,
        typeLabel: 'Province',
        statusLabel: 'Active',
      ),

      // Erbil Districts
      Region(
        regionId: 'REG_ERB_001',
        regionName: 'Erbil Center',
        regionNameArabic: 'مركز أربيل',
        nameEn: 'Erbil Center',
        nameAr: 'مركز أربيل',
        governorate: 'Erbil',
        regionType: 'DISTRICT',
        status: 'ACTIVE',
        parentId: 'REG_ERB_000',
        typeLabel: 'District',
        statusLabel: 'Active',
      ),

      // Erbil Neighborhoods
      Region(
        regionId: 'REG_ERB_001_001',
        regionName: 'Ankawa',
        regionNameArabic: 'عنكاوا',
        nameEn: 'Ankawa',
        nameAr: 'عنكاوا',
        governorate: 'Erbil',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_ERB_001',
        gpsCoordinates: GpsCoordinates(lat: 36.2219, lng: 43.9985),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),

      // Ninawa Governorate
      Region(
        regionId: 'REG_NIN_000',
        regionName: 'Ninawa',
        regionNameArabic: 'نينوى',
        nameEn: 'Ninawa',
        nameAr: 'نينوى',
        governorate: 'Ninawa',
        regionType: 'PROVINCE',
        status: 'ACTIVE',
        parentId: null,
        typeLabel: 'Province',
        statusLabel: 'Active',
      ),

      // Ninawa Districts
      Region(
        regionId: 'REG_NIN_001',
        regionName: 'Mosul',
        regionNameArabic: 'الموصل',
        nameEn: 'Mosul',
        nameAr: 'الموصل',
        governorate: 'Ninawa',
        regionType: 'DISTRICT',
        status: 'ACTIVE',
        parentId: 'REG_NIN_000',
        typeLabel: 'District',
        statusLabel: 'Active',
      ),

      // Mosul Neighborhoods
      Region(
        regionId: 'REG_NIN_001_001',
        regionName: 'Al-Majmoua',
        regionNameArabic: 'المجموعة الثقافية',
        nameEn: 'Al-Majmoua',
        nameAr: 'المجموعة الثقافية',
        governorate: 'Ninawa',
        regionType: 'NEIGHBORHOOD',
        status: 'ACTIVE',
        parentId: 'REG_NIN_001',
        gpsCoordinates: GpsCoordinates(lat: 36.3350, lng: 43.1189),
        typeLabel: 'Neighborhood',
        statusLabel: 'Active',
      ),
    ];
  }

  /// Get mock API response format
  static Map<String, dynamic> getMockApiResponse() {
    return {
      "success": true,
      "message": "Active regions fetched successfully (MOCK DATA)",
      "data": {
        "regions": getMockRegions().map((r) => r.toJson()).toList(),
        "total": getMockRegions().length,
        "cached": false
      }
    };
  }
}
