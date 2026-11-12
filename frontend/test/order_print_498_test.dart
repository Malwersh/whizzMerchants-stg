import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/services/kitchen_dispatch_service.dart';
import 'package:whizz_merchants/services/order_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Order order(
          {String branch = 'a', OrderStatus status = OrderStatus.confirmed}) =>
      Order(
          id: 'o1',
          businessId: branch,
          customerId: 'c1',
          customerName: 'زبون',
          items: [
            OrderItem(
                id: 'p',
                name: 'بيتزا',
                price: 8000,
                quantity: 2,
                modifiers: ['حجم كبير', 'جبن إضافي'],
                notes: 'بدون بصل')
          ],
          totalAmount: 17500,
          deliveryFee: 1500,
          status: status,
          updatedAt: DateTime.now().add(const Duration(minutes: 1)),
          createdAt: DateTime(2026, 11, 10));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'branch printer settings are isolated and legacy settings are not adopted',
      () async {
    const settings = KitchenSettings(printers: [
      KitchenPrinter(name: 'A', ip: '127.0.0.1', ticketType: 'both')
    ]);
    await KitchenDispatchService.save(settings);
    expect(
        (await KitchenDispatchService.load(businessId: 'a')).printers, isEmpty);
    await KitchenDispatchService.save(settings, businessId: 'a');
    expect(
        (await KitchenDispatchService.load(businessId: 'a'))
            .printers
            .single
            .ticketType,
        'both');
    expect(
        (await KitchenDispatchService.load(businessId: 'b')).printers, isEmpty);
  });
  test('kitchen contains options and instructions but no prices', () {
    final ticket = OrderPrintService.lines(order(), 'kitchen').join('\n');
    expect(ticket, contains('حجم كبير'));
    expect(ticket, contains('بدون بصل'));
    expect(ticket, isNot(contains('د.ع')));
  });
  test('customer receipt retains authoritative total and unpaid cash wording',
      () {
    final ticket = OrderPrintService.lines(order(), 'customer').join('\n');
    expect(ticket, contains('17,500'));
    expect(ticket, contains('غير محصّل'));
    expect(OrderPrintService.lines(order(), 'customer', reprint: true).first,
        'إعادة طباعة');
  });
  test(
      'no configured printer gives actionable error, automatic observation does not fail',
      () async {
    await expectLater(OrderPrintService.printOrder(order()), throwsStateError);
    await OrderPrintService.observe([order()], 'a');
    expect(await OrderPrintService.journal('a'), isEmpty);
  });
  test('pending order cannot create a preparation job', () async {
    await expectLater(
        OrderPrintService.printOrder(order(status: OrderStatus.pending)),
        throwsStateError);
  });
  test('PNG preview and ESC/POS use Arabic ticket content without printer',
      () async {
    final o = order();
    final lines = OrderPrintService.lines(o, 'kitchen');
    final png = await KitchenDispatchService.previewBytes(o, 384, lines);
    expect(png.take(4), [137, 80, 78, 71]);
    final bytes = await KitchenDispatchService.ticketBytes(o, 384, lines);
    expect(bytes.take(2), [27, 64]);
    expect(bytes.length, greaterThan(100));
  });
  test(
      'virtual TCP printer: concurrent observations send both receipts once, reprint explicit, cancellation once',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = <Uint8List>[];
    final subscription = server.listen((socket) async {
      final b = BytesBuilder();
      await for (final chunk in socket) {
        b.add(chunk);
      }
      received.add(b.toBytes());
      await socket.close();
    });
    try {
      await KitchenDispatchService.save(
          KitchenSettings(printers: [
            KitchenPrinter(
                name: 'Virtual',
                ip: '127.0.0.1',
                port: server.port,
                ticketType: 'both')
          ]),
          businessId: 'a');
      await Future.wait([
        OrderPrintService.observe([order()], 'a'),
        OrderPrintService.observe([order()], 'a')
      ]);
      expect((await OrderPrintService.journal('a')).length, 2);
      expect(
          (await OrderPrintService.journal('a'))
              .every((j) => j['status'] == 'sent'),
          isTrue);
      await OrderPrintService.printOrder(order(), reprint: true);
      expect((await OrderPrintService.journal('a')).length, 4);
      await OrderPrintService.observe(
          [order(status: OrderStatus.cancelled)], 'a');
      await OrderPrintService.observe(
          [order(status: OrderStatus.cancelled)], 'a');
      expect((await OrderPrintService.journal('a')).length, 5);
      await OrderPrintService.observe([order()], 'a');
      expect((await OrderPrintService.journal('a')).length, 5);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received.length, 5);
    } finally {
      await subscription.cancel();
      await server.close();
    }
  });
  test(
      'receipt display uses canonical minor amounts and preserves them through copy and cache',
      () {
    final o = Order.fromJson({
      ...order().toJson(),
      'receiptAmounts': null,
      'pricing': {
        'goodsSubtotal': 16000000,
        'serviceFee': 500000,
        'discount': 1000000,
        'tip': 0
      },
      'serviceFee_legacy': 999,
    });
    expect(o.receiptAmounts['serviceFee_legacy'], 500);
    expect(o.receiptAmounts['discount_legacy'], 1000);
    expect(o.copyWith(status: OrderStatus.preparing).receiptAmounts,
        o.receiptAmounts);
    expect(Order.fromJson(o.toJson()).receiptAmounts, o.receiptAmounts);
  });
  test(
      'old accepted orders are not printed automatically when enabling a printer',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      await KitchenDispatchService.save(
          KitchenSettings(printers: [
            KitchenPrinter(name: 'Virtual', ip: '127.0.0.1', port: server.port)
          ]),
          businessId: 'a');
      final old = order().copyWith(updatedAt: DateTime(2020));
      await OrderPrintService.observe([old], 'a');
      expect(await OrderPrintService.journal('a'), isEmpty);
    } finally {
      await server.close();
    }
  });
  test('failed connection is uncertain and never silently retried on refresh',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    await KitchenDispatchService.save(
        KitchenSettings(printers: [
          KitchenPrinter(name: 'Disconnected', ip: '127.0.0.1', port: port)
        ]),
        businessId: 'a');
    await OrderPrintService.observe([order()], 'a');
    expect(
        (await OrderPrintService.journal('a')).single['status'], 'uncertain');
    await OrderPrintService.observe([order()], 'a');
    expect((await OrderPrintService.journal('a')).length, 1);
  });
  test('disabled automatic printing does not produce jobs', () async {
    await KitchenDispatchService.save(
        const KitchenSettings(
            autoDispatchOnAccept: false,
            printers: [KitchenPrinter(name: 'Disabled auto', ip: '127.0.0.1')]),
        businessId: 'a');
    await OrderPrintService.observe([order()], 'a');
    expect(await OrderPrintService.journal('a'), isEmpty);
  });
}
