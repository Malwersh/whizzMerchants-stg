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
    String arabicDigits(String value) => value.replaceAllMapped(
        RegExp(r'[0-9]'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);
    String money(num value) =>
        '${arabicDigits(NumberFormat('#,##0.###', 'en').format(value).replaceAll(',', '٬').replaceAll('.', '٫'))} د.ع';
    final address = order.deliveryAddress;
    final addressText = address == null
        ? order.customerAddress?.trim() ?? ''
        : <String>[
            address.city,
            address.district,
            address.street,
            if (address.building?.trim().isNotEmpty == true)
              'البناية ${address.building}',
            if (address.floor?.trim().isNotEmpty == true)
              'الطابق ${address.floor}',
            if (address.apartment?.trim().isNotEmpty == true)
              'الشقة ${address.apartment}',
            if (address.landmark?.trim().isNotEmpty == true)
              'قرب ${address.landmark}',
          ].where((v) => v.trim().isNotEmpty).toSet().join('، ');
    if (type == 'customer') {
      final amounts = order.receiptAmounts;
      final subtotal = amounts['subtotal'] ??
          order.items.fold<num>(0, (sum, item) => sum + item.totalPrice);
      final discount = (amounts['discount_legacy'] ?? 0).abs();
      final computed = subtotal +
          order.deliveryFee +
          (amounts['serviceFee_legacy'] ?? 0) +
          (amounts['tip_legacy'] ?? 0) +
          (amounts['packagingFee_legacy'] ?? 0) +
          (amounts['tax_legacy'] ?? 0) -
          discount;
      if ((computed - order.totalAmount).abs() > .001) {
        throw StateError(
            'تفاصيل مبالغ الطلب غير مكتملة أو لا تطابق الإجمالي. حدّث الطلب قبل طباعة وصل الزبون.');
      }
      return [
        'وصل الزبون', // Rendering marker; the printed header starts with the logo.
        'شركة الانطلاق الخاطف',
        'توصيل',
        order.customerName,
        if (reprint) 'إعادة طباعة',
        'تاريخ الطلب: ${arabicDigits(DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt.toUtc().add(const Duration(hours: 3))))} · بغداد',
        if (addressText.isNotEmpty) addressText,
        'طلب #${order.orderNumber ?? order.id}',
        if (businessName.trim().isNotEmpty) businessName.trim(),
        '────────────────────────',
        for (final item in order.items) ...[
          '${arabicDigits(item.quantity.toString())} × ${item.name.replaceAll('\t', ' ')}\t${money(item.totalPrice)}',
          ...item.modifiers.map((m) => '  + $m'),
          if (item.notes?.trim().isNotEmpty == true)
            'ملاحظة الصنف: ${item.notes}',
          if (item.quantity > 1) 'سعر الوحدة: ${money(item.price)}',
          '────────────────────────',
        ],
        if (order.notes?.trim().isNotEmpty == true)
          'ملاحظات للمطعم: ${order.notes}',
        if (order.deliveryInstructions?.trim().isNotEmpty == true)
          'ملاحظات للسائق: ${order.deliveryInstructions}',
        'المجموع الفرعي\t${money(subtotal)}',
        if (discount > 0) 'الخصم\t−${money(discount)}',
        if ((amounts['serviceFee_legacy'] ?? 0) != 0)
          'رسوم الخدمة\t${money(amounts['serviceFee_legacy']!)}',
        if ((amounts['tip_legacy'] ?? 0) != 0)
          'إكرامية السائق\t${money(amounts['tip_legacy']!)}',
        if ((amounts['packagingFee_legacy'] ?? 0) != 0)
          'رسوم التغليف\t${money(amounts['packagingFee_legacy']!)}',
        if ((amounts['tax_legacy'] ?? 0) != 0)
          'الضريبة\t${money(amounts['tax_legacy']!)}',
        'رسوم التوصيل\t${money(order.deliveryFee)}',
        order.paymentMethod == 'cash'
            ? 'الدفع نقدًا عند الاستلام — غير محصّل'
            : 'طريقة الدفع: ${order.paymentMethod}',
        '────────────────────────',
        'الإجمالي\t${money(order.totalAmount)}',
      ];
    }
    return [
      if (reprint) 'إعادة طباعة',
      type == 'cancel' ? 'إلغاء الطلب — أوقف التجهيز' : 'تذكرة المطبخ',
      if (businessName.isNotEmpty) businessName,
      'طلب #${order.orderNumber ?? order.id}',
      'وقت الطلب بتوقيت بغداد: ${arabicDigits(DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt.toUtc().add(const Duration(hours: 3))))}',
      '────────────────────────',
      for (final item in order.items) ...[
        '${arabicDigits(item.quantity.toString())} × ${item.name}',
        ...item.modifiers.map((m) => '  + $m'),
        if (item.notes?.trim().isNotEmpty == true) 'تحضير: ${item.notes}',
      ],
      if (order.notes?.trim().isNotEmpty == true)
        'ملاحظات التحضير: ${order.notes}',
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
