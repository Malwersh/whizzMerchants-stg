import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../core/utils/app_logger.dart';

/// 💾 خدمة التخزين المؤقت للطلبات - Cache-based smart polling
/// يحفظ الطلبات في الذاكرة ويُحدّث UI فقط عند التغيير الفعلي
class OrderCacheService {
  static const String _cachePrefix = 'order_cache_';
  static const int _cacheExpirationSeconds = 30; // صلاحية الكاش 30 ثانية

  /// حفظ الطلب في الذاكرة المؤقتة
  static Future<bool> cacheOrder(Order order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cachedData = {
        'orderId': order.id,
        'status': order.status.name,
        'driverId': order.driverId,
        'driverName': order.driverName,
        'driverPhone': order.driverPhone,
        'vehicleType': order.vehicleType,
        'vehiclePlate': order.vehiclePlate,
        'driverAssignedAt': order.driverAssignedAt?.toIso8601String(),
        'pickedUpAt': order.pickedUpAt?.toIso8601String(),
        'updatedAt': order.updatedAt?.toIso8601String(),
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now()
            .add(Duration(seconds: _cacheExpirationSeconds))
            .millisecondsSinceEpoch,
      };

      final cacheKey = '$_cachePrefix${order.id}';
      final jsonString = json.encode(cachedData);
      
      await prefs.setString(cacheKey, jsonString);
      AppLogger.debug('💾 Order cached: ${order.id} - status: ${order.status.name}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error caching order: $e');
      return false;
    }
  }

  /// الحصول على الطلب من الذاكرة المؤقتة
  static Future<Map<String, dynamic>?> getCachedOrder(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$orderId';
      
      final jsonString = prefs.getString(cacheKey);
      if (jsonString == null) {
        AppLogger.debug('🔍 No cache found for order: $orderId');
        return null;
      }

      final cachedData = json.decode(jsonString) as Map<String, dynamic>;
      final expiresAt = cachedData['expiresAt'] as int?;

      // فحص الصلاحية
      if (expiresAt == null || DateTime.now().millisecondsSinceEpoch > expiresAt) {
        AppLogger.debug('⏰ Cache expired for order: $orderId');
        await clearCachedOrder(orderId);
        return null;
      }

      AppLogger.debug('✅ Valid cache found for order: $orderId');
      return cachedData;
    } catch (e) {
      AppLogger.error('❌ Error reading cached order: $e');
      return null;
    }
  }

  /// مقارنة الطلب الجديد مع الكاش للكشف عن التغييرات
  static Future<bool> hasOrderChanged(Order newOrder) async {
    AppLogger.info('🔍 Checking order for changes: ${newOrder.id}');
    AppLogger.info('   New order status: ${newOrder.status.name}');
    AppLogger.info('   New order driver: ${newOrder.driverId}');
    AppLogger.info('   New order updatedAt: ${newOrder.updatedAt}');
    
    final cached = await getCachedOrder(newOrder.id);
    if (cached == null) {
      // لا يوجد كاش - هذا تغيير (أول مرة نرى هذا الطلب)
      AppLogger.info('✅ No cache found - treating as NEW order (will cache now)');
      return true;
    }

    AppLogger.info('🔍 Cache found:');
    AppLogger.info('   Cached status: ${cached['status']}');
    AppLogger.info('   Cached driver: ${cached['driverId']}');
    AppLogger.info('   Cached updatedAt: ${cached['updatedAt']}');

    // مقارنة الحقول المهمة
    final statusChanged = cached['status'] != newOrder.status.name;
    final driverChanged = cached['driverId'] != newOrder.driverId;
    final driverNameChanged = cached['driverName'] != newOrder.driverName;
    final vehicleChanged = cached['vehicleType'] != newOrder.vehicleType;
    final updatedAtChanged = cached['updatedAt'] != newOrder.updatedAt?.toIso8601String();

    final hasChanged = statusChanged || driverChanged || driverNameChanged || vehicleChanged || updatedAtChanged;

    AppLogger.info('🔍 Comparison results:');
    AppLogger.info('   Status changed? $statusChanged');
    AppLogger.info('   Driver changed? $driverChanged');
    AppLogger.info('   Driver name changed? $driverNameChanged');
    AppLogger.info('   Vehicle changed? $vehicleChanged');
    AppLogger.info('   UpdatedAt changed? $updatedAtChanged');
    AppLogger.info('   === OVERALL: ${hasChanged ? "CHANGED ✅" : "UNCHANGED ⏭️"} ===');

    if (hasChanged) {
      AppLogger.info('🔄 Order ${newOrder.id} HAS CHANGES:');
      if (statusChanged) AppLogger.info('  - Status: ${cached['status']} → ${newOrder.status.name}');
      if (driverChanged) AppLogger.info('  - Driver: ${cached['driverId']} → ${newOrder.driverId}');
      if (driverNameChanged) AppLogger.info('  - Driver name: ${cached['driverName']} → ${newOrder.driverName}');
      if (vehicleChanged) AppLogger.info('  - Vehicle: ${cached['vehicleType']} → ${newOrder.vehicleType}');
      if (updatedAtChanged) AppLogger.info('  - UpdatedAt: ${cached['updatedAt']} → ${newOrder.updatedAt?.toIso8601String()}');
    }

    return hasChanged;
  }

  /// حذف الطلب من الذاكرة المؤقتة
  static Future<void> clearCachedOrder(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$orderId';
      await prefs.remove(cacheKey);
      AppLogger.debug('🗑️ Cache cleared for order: $orderId');
    } catch (e) {
      AppLogger.error('❌ Error clearing cached order: $e');
    }
  }

  /// حذف جميع الطلبات من الذاكرة المؤقتة
  static Future<void> clearAllOrdersCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final orderCacheKeys = keys.where((key) => key.startsWith(_cachePrefix)).toList();
      
      for (final key in orderCacheKeys) {
        await prefs.remove(key);
      }
      
      AppLogger.info('🧹 All order cache cleared');
    } catch (e) {
      AppLogger.error('❌ Error clearing all order cache: $e');
    }
  }
}
