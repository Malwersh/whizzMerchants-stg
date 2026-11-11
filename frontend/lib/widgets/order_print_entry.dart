import 'package:flutter/material.dart';
import '../models/order.dart';
import '../screens/order_print_screen.dart';
import '../services/order_print_service.dart';

class OrderPrintEntry extends StatelessWidget {
  final Order order;
  const OrderPrintEntry({super.key, required this.order});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: OrderPrintService.changes,
        builder: (_, revision, __) => FutureBuilder<List<Map<String, dynamic>>>(
          future: OrderPrintService.journal(order.businessId),
          builder: (_, snapshot) {
            final jobs = (snapshot.data ?? [])
                .where((j) => j['orderId'] == order.id)
                .toList();
            final attention = jobs.any((j) => [
                  'failed',
                  'uncertain',
                  'sending',
                  'queued'
                ].contains(j['status']));
            return Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: Icon(
                      attention
                          ? Icons.print_disabled_outlined
                          : Icons.receipt_long_outlined,
                      color: const Color(0xFF00296B)),
                  label: Text(
                      attention ? 'الطباعة تحتاج مراجعة' : 'الوصولات والطباعة',
                      style: const TextStyle(color: Color(0xFF00296B))),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OrderPrintScreen(order: order))),
                ));
          },
        ),
      );
}
