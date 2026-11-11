import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import 'kitchen_dispatch_service.dart';

/// Device-local durable journal. A TCP write acknowledges sending, never paper output.
/// No automatic retry after sending starts: a lost connection may have printed.
class OrderPrintService {
  static final changes = ValueNotifier<int>(0);
  static Future<void> _tail = Future.value();
  static String key(String branch) => 'order_print_jobs_v1_$branch';
  static Future<T> serial<T>(Future<T> Function() action) {
    final future = _tail.then((_) => action());
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  static Future<List<Map<String, dynamic>>> journal(String branch) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key(branch));
    return raw == null
        ? []
        : (jsonDecode(raw) as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
  }

  static Future<void> _save(
      String branch, List<Map<String, dynamic>> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key(branch), jsonEncode(jobs));
    changes.value++;
  }

  static List<String> lines(Order order, String type,
      {bool reprint = false, String businessName = ''}) {
    String money(num value) =>
        '${NumberFormat('#,##0.###', 'en').format(value)} د.ع';
    return [
      if (reprint) 'إعادة طباعة',
      type == 'customer'
          ? 'وصل الزبون'
          : type == 'cancel'
              ? 'إلغاء الطلب — أوقف التجهيز'
              : 'تذكرة المطبخ',
      if (businessName.isNotEmpty) businessName,
      'طلب #${order.orderNumber ?? order.id}',
      'وقت الطلب بتوقيت بغداد: ${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt.toUtc().add(const Duration(hours: 3)))}',
      '────────────────────────',
      for (final item in order.items) ...[
        '${item.quantity} × ${item.name}',
        ...item.modifiers.map((m) => '  + $m'),
        if (item.notes?.trim().isNotEmpty == true) 'تحضير: ${item.notes}',
        if (type == 'customer') 'سعر الوحدة: ${money(item.price)}',
      ],
      if (order.notes?.trim().isNotEmpty == true)
        'ملاحظات التحضير: ${order.notes}',
      if (type == 'customer') ...[
        '────────────────────────',
        for (final e in order.receiptAmounts.entries)
          '${{
                'subtotal': 'الأصناف',
                'serviceFee_legacy': 'رسوم الخدمة',
                'discount_legacy': 'الخصم',
                'tip_legacy': 'الإكرامية',
                'packagingFee_legacy': 'التغليف',
                'tax_legacy': 'الضريبة'
              }[e.key] ?? e.key}: ${money(e.value)}',
        'التوصيل: ${money(order.deliveryFee)}',
        'الإجمالي المعتمد شامل الرسوم والخصومات: ${money(order.totalAmount)}',
        order.paymentMethod == 'cash'
            ? 'الدفع نقدًا عند الاستلام — غير محصّل'
            : 'طريقة الدفع: ${order.paymentMethod}',
      ],
    ];
  }

  static Future<void> observe(List<Order> orders, String branch) async {
    for (final order in orders.where((o) => o.businessId == branch)) {
      if (order.status == OrderStatus.confirmed) {
        await printOrder(order, automatic: true);
      } else if (order.status == OrderStatus.cancelled) {
        final jobs = await journal(branch);
        if (jobs
            .any((j) => j['orderId'] == order.id && j['type'] != 'cancel')) {
          await printOrder(order, automatic: true, cancellation: true);
        }
      }
    }
  }

  static Future<void> printOrder(Order order,
          {bool automatic = false,
          bool reprint = false,
          bool cancellation = false}) =>
      serial(() async {
        if (order.businessId.isEmpty) throw StateError('اختر الفرع أولًا');
        if (!cancellation &&
            [OrderStatus.pending, OrderStatus.cancelled, OrderStatus.expired]
                .contains(order.status)) {
          throw StateError('لا يمكن طباعة تجهيز طلب غير مقبول أو ملغى');
        }
        final settings =
            await KitchenDispatchService.load(businessId: order.businessId);
        if (automatic && !settings.autoDispatchOnAccept) return;
        if (automatic &&
            !cancellation &&
            settings.automaticFrom != null &&
            (order.updatedAt ?? order.createdAt)
                .isBefore(settings.automaticFrom!)) return;
        final printers = settings.printers.where((p) => p.enabled).toList();
        if (printers.isEmpty && settings.kdsUrl.trim().isEmpty) {
          if (automatic) return;
          throw StateError(
              'لا توجد طابعة مفعّلة لهذا الفرع. أضفها في إعدادات POS ← الطابعات.');
        }
        final jobs = await journal(order.businessId);
        if (!cancellation &&
            jobs.any((j) => j['orderId'] == order.id && j['type'] == 'cancel'))
          return;
        if (!cancellation && settings.kdsUrl.trim().isNotEmpty) {
          final id = jsonEncode([order.id, settings.kdsUrl, 'kds']);
          if (reprint || !jobs.any((j) => j['id'] == id)) {
            final job = <String, dynamic>{
              'id': id,
              'orderId': order.id,
              'type': 'kds',
              'printer': 'شاشة المطبخ',
              'status': 'sending',
              'reprint': reprint,
              'at': DateTime.now().toIso8601String()
            };
            jobs.add(job);
            await _save(order.businessId, jobs);
            try {
              await KitchenDispatchService.sendToKds(order, settings);
              job['status'] = 'sent';
            } catch (_) {
              job['status'] = 'uncertain';
            }
            await _save(order.businessId, jobs);
          }
        }
        for (final printer in printers) {
          final types = cancellation
              ? ['cancel']
              : printer.ticketType == 'both'
                  ? ['kitchen', 'customer']
                  : [printer.ticketType];
          for (final type in types) {
            final id = jsonEncode([order.id, printer.ip, printer.port, type]);
            if (!reprint && jobs.any((j) => j['id'] == id)) continue;
            final job = <String, dynamic>{
              'id': id,
              'orderId': order.id,
              'type': type,
              'printer': printer.name,
              'status': 'queued',
              'reprint': reprint,
              'at': DateTime.now().toIso8601String()
            };
            jobs.add(job);
            await _save(order.businessId, jobs);
            try {
              final bytes = await KitchenDispatchService.ticketBytes(
                  order,
                  printer.dotsWidth,
                  lines(order, type,
                      reprint: reprint, businessName: settings.businessName));
              job['status'] = 'sending';
              await _save(order.businessId, jobs);
              for (var i = 0; i < printer.copies.clamp(1, 5); i++) {
                await KitchenDispatchService.sendRaw(
                    printer.ip, printer.port, bytes);
              }
              job['status'] = 'sent';
            } catch (_) {
              job['status'] =
                  job['status'] == 'sending' ? 'uncertain' : 'failed';
            }
            await _save(order.businessId, jobs);
          }
        }
      });
}
