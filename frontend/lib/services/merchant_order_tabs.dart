import '../models/order.dart';

bool merchantOrderMatchesFilter(OrderStatus status, String filterValue) {
    final filter = filterValue.toLowerCase();

    switch (filter) {
      case 'all':
        return true; // Show all orders

      case 'pending':
        return status == OrderStatus.pending;

      case 'confirmed':
        return status == OrderStatus.confirmed;

      case 'preparing':
        return status == OrderStatus.preparing;

      case 'ready': // ✅ تبويب "جاهز" يشمل جميع حالات السائق قبل التسليم
        return status == OrderStatus.ready || status == OrderStatus.readyForPickup ||
            status ==
                OrderStatus.reassigning || // 🔄 Task 6: البحث عن سائق بديل
            status == OrderStatus.assigned ||
            status == OrderStatus.headingToStore ||
            status == OrderStatus.arrivedAtStore ||
            status == OrderStatus.pickedUp ||
            status == OrderStatus.headingToCustomer ||
            status == OrderStatus.arrivedAtCustomer ||
            status == OrderStatus.returning ||
            status == OrderStatus.returnArrived;

      case 'delivered': // تبويب "تم التوصيل" في الأرشيف
        return status == OrderStatus.delivered ||
            status == OrderStatus.completed;

      case 'cancelled':
        return status == OrderStatus.cancelled;

      case 'returned':
        return status == OrderStatus.returned;

      case 'expired':
        return status == OrderStatus.expired;

      default:
        return false;
    }
  }
