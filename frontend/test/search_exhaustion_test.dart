import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/services/order_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cache detects search failure when status and timestamps are unchanged', () async {
    SharedPreferences.setMockInitialValues({});
    final original=Order.fromJson({'id':'o','status':'ready_for_pickup'});
    await OrderCacheService.cacheOrder(original);
    final failed=Order.fromJson({...original.toJson(),'driverSearchUnavailable':true});
    expect(await OrderCacheService.hasOrderChanged(failed),isTrue);
    await OrderCacheService.cacheOrder(failed);
    expect(await OrderCacheService.hasOrderChanged(failed),isFalse);
  });
  test('search failure stays separate from order status and survives caching', () {
    final order = Order.fromJson({'id':'o','status':'ready_for_pickup','driverSearchUnavailable':true});
    expect(order.driverSearchUnavailable,isTrue);
    expect(Order.fromJson(order.toJson()).driverSearchUnavailable,isTrue);
    expect(order.copyWith().driverSearchUnavailable,isTrue);
    expect(order.status,isNot(OrderStatus.cancelled));
    expect(Order.fromJson({'id':'old'}).driverSearchUnavailable,isFalse);
  });
  test('replacement search survives cache and clears after assignment', () async {
    SharedPreferences.setMockInitialValues({});
    final original=Order.fromJson({'id':'o','status':'ready_for_pickup'});
    await OrderCacheService.cacheOrder(original);
    final replacement=Order.fromJson({...original.toJson(),'financialRelease':{'attempt':1}});
    expect(replacement.driverReplacementSearch,isTrue);
    expect(Order.fromJson(replacement.toJson()).driverReplacementSearch,isTrue);
    expect(replacement.copyWith().driverReplacementSearch,isTrue);
    expect(await OrderCacheService.hasOrderChanged(replacement),isTrue);
    expect(Order.fromJson({...replacement.toJson(),'driverId':'new','status':'assigned'}).driverReplacementSearch,isFalse);
  });
}
