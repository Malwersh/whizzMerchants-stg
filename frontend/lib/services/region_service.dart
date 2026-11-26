// WizzMerchant - Region Validation & Caching Service
// Integrates with WizzCentral Platform Region API (Phase 6)

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform; // Device type detection for localhost avoidance
import '../models/region.dart';
import '../config/app_config.dart';

// Simple logger for this service
class _Logger {
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('$prefix$message');
    }
  }
}

class RegionService {
  // Singleton pattern
  static final RegionService _instance = RegionService._internal();
  factory RegionService() => _instance;
  RegionService._internal();

  // Central Platform API endpoint (mutable so we can override from .env)
  static String _centralApiUrl = AppConfig.baseUrl;

  // Cache keys
  static const String _cacheKeyRegions = 'cached_active_regions_313';
  static const String _cacheKeyTimestamp = 'cached_regions_timestamp_313';
  static const String _cacheKeyLanguage = 'cached_regions_language_313';

  // Cache duration: 6 hours
  static const Duration _cacheDuration = Duration(seconds: 30);

  // In-memory cache for quick access
  List<Region>? _cachedRegions;
  DateTime? _cacheTimestamp;
  String? _cacheLanguage;

  // Loading state
  bool _isLoading = false;
  Completer<List<Region>>? _loadingCompleter;

  /// Initialize region service
  /// Call this on app startup
  Future<void> initialize() async {
    _Logger.log('🗺️ Initializing RegionService...', tag: 'RegionService');

    _centralApiUrl = AppConfig.baseUrl;

    // ⚡ CRITICAL: On physical devices, skip network initialization entirely
    if (_centralApiUrl.contains('localhost') &&
        (Platform.isIOS || Platform.isAndroid)) {
      _Logger.log(
          '🔌 Physical device detected - skipping network initialization, using cache only',
          tag: 'RegionService');
      try {
        final cached = await _loadFromCache();
        if (cached != null && cached.isNotEmpty) {
          _cachedRegions = cached;
          _Logger.log('✅ Loaded ${cached.length} regions from cache',
              tag: 'RegionService');
        } else {
          _Logger.log('ℹ️ No cache available - region features will be limited',
              tag: 'RegionService');
        }
      } catch (e) {
        _Logger.log('⚠️ Cache load failed: $e', tag: 'RegionService');
      }
      return; // Exit early - don't attempt network call
    }

    try {
      // Try to load from cache first
      final cached = await _loadFromCache();

      if (cached != null && cached.isNotEmpty) {
        _cachedRegions = cached;
        _Logger.log('✅ Loaded ${cached.length} regions from cache',
            tag: 'RegionService');
      }

      // Non-blocking background fetch
      _fetchActiveRegions(forceRefresh: false);
    } catch (e) {
      _Logger.log('⚠️ Failed to initialize RegionService: $e',
          tag: 'RegionService');
    }
  }

  /// Fetch active regions from Central Platform API
  /// Called on app startup and periodically
  Future<List<Region>> _fetchActiveRegions({bool forceRefresh = false}) async {
    // If already loading, wait for completion
    if (_isLoading && _loadingCompleter != null) {
      return _loadingCompleter!.future;
    }

    // Check cache validity
    if (!forceRefresh && _isCacheValid()) {
      _Logger.log('✅ Cache is valid, using cached regions',
          tag: 'RegionService');
      return _cachedRegions ?? [];
    }

    _isLoading = true;
    _loadingCompleter = Completer<List<Region>>();

    try {
      // Avoid localhost calls on physical devices – they will always fail
      if (_centralApiUrl.contains('localhost') &&
          (Platform.isIOS || Platform.isAndroid)) {
        _Logger.log(
            '🔌 Skipping localhost fetch on physical device; using cache if available',
            tag: 'RegionService');
        final result = _cachedRegions ?? [];
        _loadingCompleter!.complete(result);
        return result;
      }

      _Logger.log('🌐 Fetching active regions from Central API...',
          tag: 'RegionService');

      // Get user's preferred language
      final language = await _getUserLanguage();

      // Build API URL with language parameter
      final url = Uri.parse('$_centralApiUrl/auth/onboarding-regions');

      _Logger.log('📡 API Request: GET $url', tag: 'RegionService');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Accept-Language': language,
          'User-Agent': 'WizzMerchant/1.0',
        },
      ).timeout(
        const Duration(
            seconds: 10), // ⚡ Reduced from 10s to 2s for faster failure
        onTimeout: () {
          throw TimeoutException('Region API request timed out after 2s');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse response
        final rows = List<Map<String, dynamic>>.from(data['items'] as List);
        final byId = {for (final row in rows) row['id']: row};
        String governorate(Map<String, dynamic> row) {
          final seen = <String>{};
          while (row['level'] != 1) {
            if (!seen.add(row['id'] as String) ||
                !byId.containsKey(row['parentId'])) return '';
            row = byId[row['parentId']]!;
          }
          return row['labelAr'] as String;
        }

        final regions = rows
            .map((r) => Region.fromJson({
                  'regionId': r['id'],
                  'regionName': r['labelEn'] ?? r['labelAr'],
                  'regionNameArabic': r['labelAr'],
                  'parentId': r['parentId'],
                  'governorate': governorate(r),
                  'regionType': {
                    0: 'COUNTRY',
                    1: 'PROVINCE',
                    2: 'DISTRICT',
                    3: 'NEIGHBORHOOD'
                  }[r['level']],
                  'status': 'ACTIVE',
                }))
            .toList();
        _Logger.log('✅ Fetched ${regions.length} active regions',
            tag: 'RegionService');

        // Update cache
        _cachedRegions = regions;
        _cacheTimestamp = DateTime.now();
        _cacheLanguage = language;

        // Save to persistent storage
        await _saveToCache(regions, language);

        _loadingCompleter!.complete(regions);
        return regions;
      } else {
        throw Exception(
            'API returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _Logger.log('❌ Failed to fetch active regions: $e', tag: 'RegionService');

      // Graceful fallback: cache or empty list – DO NOT rethrow (prevents white screen)
      final fallback = <Region>[];
      _cachedRegions = null;
      _cacheTimestamp = null;
      if (fallback.isNotEmpty) {
        _Logger.log('⚠️ Using stale cache as fallback', tag: 'RegionService');
      } else {
        _Logger.log('⚠️ No cache available – returning empty list',
            tag: 'RegionService');
      }
      if (!_loadingCompleter!.isCompleted) {
        _loadingCompleter!.complete(fallback);
      }
      return fallback;
    } finally {
      _isLoading = false;
      _loadingCompleter = null;
    }
  }

  /// Check if a specific region is active
  /// This is the main validation function used throughout the app
  Future<bool> isRegionActive(String regionId) async {
    try {
      // Ensure regions are loaded
      final regions = await getActiveRegions(forceRefresh: true);

      // Check if region exists in active regions
      final isActive = regions.any((r) => r.regionId == regionId);

      if (!isActive) {
        _Logger.log('⚠️ Region $regionId is INACTIVE or not found',
            tag: 'RegionService');
      }

      return isActive;
    } catch (e) {
      _Logger.log('❌ Error checking region status: $e', tag: 'RegionService');
      // Conservative: assume inactive on error
      return false;
    }
  }

  /// Get all active regions (with caching)
  Future<List<Region>> getActiveRegions({bool forceRefresh = false}) async {
    // Return cached if valid
    if (!forceRefresh && _isCacheValid() && _cachedRegions != null) {
      return _cachedRegions!;
    }

    // Fetch fresh data
    return _fetchActiveRegions(forceRefresh: forceRefresh);
  }

  /// Get active regions by type
  Future<List<Region>> getActiveRegionsByType(String regionType) async {
    final regions = await getActiveRegions();
    return regions.where((r) => r.regionType == regionType).toList();
  }

  /// Get active regions by governorate
  Future<List<Region>> getActiveRegionsByGovernorate(String governorate) async {
    final regions = await getActiveRegions();
    return regions.where((r) => r.governorate == governorate).toList();
  }

  /// Get region details by ID
  Future<Region?> getRegionById(String regionId) async {
    final regions = await getActiveRegions();
    try {
      return regions.firstWhere((r) => r.regionId == regionId);
    } catch (e) {
      return null;
    }
  }

  /// Get localized region name
  Future<String> getRegionName(String regionId, {String? language}) async {
    final region = await getRegionById(regionId);
    if (region == null) return regionId;

    final userLang = language ?? await _getUserLanguage();
    return userLang == 'ar' ? region.nameAr : region.nameEn;
  }

  /// Refresh cache manually
  /// Call this after webhook notification or on user action
  Future<void> refreshCache() async {
    _Logger.log('🔄 Manually refreshing region cache...', tag: 'RegionService');
    await _fetchActiveRegions(forceRefresh: true);
  }

  /// Get localized error message for inactive region
  Future<String> getInactiveRegionMessage({String? language}) async {
    final userLang = language ?? await _getUserLanguage();

    if (userLang == 'ar') {
      return 'الخدمة غير متوفرة حالياً في منطقتك';
    } else {
      return 'Service is currently unavailable in your area';
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_cachedRegions == null || _cacheTimestamp == null) {
      return false;
    }

    final age = DateTime.now().difference(_cacheTimestamp!);
    return age < _cacheDuration;
  }

  /// Load regions from persistent cache
  Future<List<Region>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if cache exists
      final regionsJson = prefs.getString(_cacheKeyRegions);
      final timestampStr = prefs.getString(_cacheKeyTimestamp);
      final cachedLang = prefs.getString(_cacheKeyLanguage);

      if (regionsJson == null || timestampStr == null) {
        return null;
      }

      // Parse timestamp
      final timestamp = DateTime.tryParse(timestampStr);
      if (timestamp == null) return null;

      // Check if cache is expired
      final age = DateTime.now().difference(timestamp);
      if (age > _cacheDuration) {
        _Logger.log('⏰ Cache expired (age: ${age.inHours}h)',
            tag: 'RegionService');
        return null;
      }

      // Parse regions
      final regionsData = jsonDecode(regionsJson) as List;
      final regions = regionsData.map((r) => Region.fromJson(r)).toList();

      // Update in-memory cache
      _cacheTimestamp = timestamp;
      _cacheLanguage = cachedLang ?? 'en';

      return regions;
    } catch (e) {
      _Logger.log('❌ Error loading cache: $e', tag: 'RegionService');
      return null;
    }
  }

  /// Save regions to persistent cache
  Future<void> _saveToCache(List<Region> regions, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Serialize regions
      final regionsJson = jsonEncode(regions.map((r) => r.toJson()).toList());

      // Save to SharedPreferences
      await prefs.setString(_cacheKeyRegions, regionsJson);
      await prefs.setString(
          _cacheKeyTimestamp, DateTime.now().toIso8601String());
      await prefs.setString(_cacheKeyLanguage, language);

      _Logger.log('💾 Saved ${regions.length} regions to cache',
          tag: 'RegionService');
    } catch (e) {
      _Logger.log('❌ Error saving cache: $e', tag: 'RegionService');
    }
  }

  /// Get user's preferred language
  Future<String> _getUserLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('app_language') ?? 'ar'; // Default to Arabic
      return lang == 'ar' ? 'ar' : 'en';
    } catch (e) {
      return 'ar'; // Default to Arabic
    }
  }

  /// Clear cache (for testing/debugging)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyRegions);
    await prefs.remove(_cacheKeyTimestamp);
    await prefs.remove(_cacheKeyLanguage);

    _cachedRegions = null;
    _cacheTimestamp = null;
    _cacheLanguage = null;

    _Logger.log('🗑️ Region cache cleared', tag: 'RegionService');
  }

  /// Get cache info (for debugging)
  Future<Map<String, dynamic>> getCacheInfo() async {
    final regions = _cachedRegions;
    final timestamp = _cacheTimestamp;
    final language = _cacheLanguage;

    return {
      'cached': regions != null,
      'count': regions?.length ?? 0,
      'timestamp': timestamp?.toIso8601String(),
      'age_hours': timestamp != null
          ? DateTime.now().difference(timestamp).inHours
          : null,
      'language': language,
      'valid': _isCacheValid(),
    };
  }

  /// Handle webhook notification from Central Platform
  /// Call this when receiving push notification about region status change
  Future<void> handleWebhookNotification(
      Map<String, dynamic> notification) async {
    _Logger.log('📢 Received region update webhook: $notification',
        tag: 'RegionService');

    try {
      final event = notification['event'];

      if (event == 'REGION_STATUS_CHANGED') {
        // Refresh cache immediately
        await refreshCache();

        _Logger.log('✅ Cache refreshed after webhook', tag: 'RegionService');
      }
    } catch (e) {
      _Logger.log('❌ Error handling webhook: $e', tag: 'RegionService');
    }
  }
}
