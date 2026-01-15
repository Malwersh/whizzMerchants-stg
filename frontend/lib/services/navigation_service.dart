// filepath: lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import '../screens/orders_page.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> navigateToOrders({String? highlightOrderId}) async {
    final ctx = navigatorKey.currentState?.context;
    if (ctx == null) return;

    // Push OrdersPage; you can extend to pass orderId via arguments/state later
    await navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const OrdersPage()),
    );
  }
}
