import '../models/order.dart';
import 'branch_device_service.dart';

/// In-memory employee transport. Never supplies owner credentials or shared caches.
class BranchEmployeeAccess {
  final BranchDeviceService api;
  final String token, session, businessId;
  final Map<String, dynamic> profile;
  final Future<void> Function() lock;
  BranchEmployeeAccess(
      {required this.api,
      required this.token,
      required this.session,
      required this.businessId,
      required this.profile,
      required this.lock});
  bool get canOrders => profile['staff']?['permissionSchema'] == 2
      ? capabilities['readOrders'] == true
      : ['MANAGER', 'RECEPTION'].contains(profile['staff']?['role']);
  Map<String, dynamic> get capabilities =>
      Map<String, dynamic>.from(profile['capabilities'] ?? {});
  bool canUpdate(OrderStatus status) {
    if (profile['staff']?['permissionSchema'] != 2) return true;
    final permission = {
      OrderStatus.confirmed: 'orders.accept',
      OrderStatus.cancelled: 'orders.reject',
      OrderStatus.preparing: 'orders.prepare',
      OrderStatus.ready: 'orders.ready',
      OrderStatus.readyForPickup: 'orders.ready'
    }[status];
    return permission != null &&
        (profile['staff']?['permissions'] as List? ?? []).contains(permission);
  }

  Future<List<Order>> orders() async {
    final r = await api.operation(token, 'merchant/orders/$businessId',
        session: session);
    return (r['orders'] as List? ?? [])
        .map((v) => Order.fromJson(
            {...Map<String, dynamic>.from(v), 'businessId': businessId}))
        .toList();
  }

  Future<void> update(String id, OrderStatus status, {String? reason}) async {
    if (!canUpdate(status)) throw BranchDeviceException('PERMISSION_REQUIRED');
    final action = status == OrderStatus.confirmed
        ? 'confirm'
        : status == OrderStatus.cancelled
            ? 'reject'
            : 'status';
    final value = status == OrderStatus.preparing
        ? 'preparing'
        : [OrderStatus.ready, OrderStatus.readyForPickup].contains(status)
            ? 'ready'
            : null;
    if (action == 'status' && value == null)
      throw BranchDeviceException('PERMISSION_REQUIRED');
    await api.operation(token, 'merchant/order/$id/$action',
        session: session,
        body: {
          'businessId': businessId,
          if (action == 'confirm') 'estimatedPreparationTime': 20,
          if (action == 'reject') 'reason': reason ?? 'رفض موظف الفرع',
          if (value != null) 'status': value,
        });
  }
}
