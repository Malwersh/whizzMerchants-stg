import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/kitchen_dispatch_service.dart';
import '../services/order_print_service.dart';

class OrderPrintScreen extends StatefulWidget {
  final Order order;
  const OrderPrintScreen({super.key, required this.order});
  @override
  State<OrderPrintScreen> createState() => _OrderPrintScreenState();
}

class _OrderPrintScreenState extends State<OrderPrintScreen> {
  String type = 'kitchen';
  int width = 576;
  bool busy = false;
  late Future<Uint8List> preview;
  late Future<List<Map<String, dynamic>>> jobs;
  void refresh() {
    preview = KitchenDispatchService.load(businessId: widget.order.businessId)
        .then((settings) => KitchenDispatchService.previewBytes(
            widget.order,
            width,
            OrderPrintService.lines(widget.order, type,
                businessName: settings.businessName)));
    jobs = OrderPrintService.journal(widget.order.businessId);
  }

  @override
  void initState() {
    super.initState();
    if (widget.order.status == OrderStatus.cancelled) type = 'cancel';
    refresh();
  }

  Future<void> printReceipt() async {
    final prior = await OrderPrintService.journal(widget.order.businessId);
    final reprint = prior.any((j) => j['orderId'] == widget.order.id);
    if (!mounted) return;
    final yes = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(reprint
                      ? 'إعادة طباعة الوصولات؟'
                      : 'إرسال الوصولات للطابعات؟'),
                  const SizedBox(height: 12),
                  const Text(
                      'تحقق من الورق أولًا. نجاح الإرسال لا يثبت خروج الورقة. ستُرسل النسخ وفق إعدادات طابعات الفرع.'),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد الإرسال')),
                ]))));
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await OrderPrintService.printOrder(widget.order,
          reprint: reprint,
          cancellation: widget.order.status == OrderStatus.cancelled);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          refresh();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(title: const Text('الوصولات والطباعة')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('معاينة فقط — لا تحتاج إلى طابعة',
              style: TextStyle(color: Color(0xFF00296B))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final value in [
              'kitchen',
              'customer',
              if (widget.order.status == OrderStatus.cancelled) 'cancel'
            ])
              ChoiceChip(
                  label: Text(value == 'kitchen'
                      ? 'المطبخ'
                      : value == 'customer'
                          ? 'الزبون'
                          : 'الإلغاء'),
                  selected: type == value,
                  onSelected: (_) => setState(() {
                        type = value;
                        refresh();
                      })),
            ChoiceChip(
                label: const Text('58 مم'),
                selected: width == 384,
                onSelected: (_) => setState(() {
                      width = 384;
                      refresh();
                    })),
            ChoiceChip(
                label: const Text('80 مم'),
                selected: width == 576,
                onSelected: (_) => setState(() {
                      width = 576;
                      refresh();
                    })),
          ]),
          const SizedBox(height: 16),
          FutureBuilder<Uint8List>(
              future: preview,
              builder: (_, s) => s.hasData
                  ? Image.memory(s.data!, fit: BoxFit.contain)
                  : Text(s.hasError
                      ? 'تعذر تجهيز المعاينة'
                      : 'جارٍ تجهيز المعاينة…')),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: busy ? null : printReceipt,
              icon: const Icon(Icons.print_outlined),
              label: Text(busy ? 'جارٍ الإرسال…' : 'إرسال للطابعات')),
          const SizedBox(height: 20),
          const Text('سجل هذا الطلب',
              style: TextStyle(fontWeight: FontWeight.bold)),
          FutureBuilder<List<Map<String, dynamic>>>(
              future: jobs,
              builder: (_, s) => Column(children: [
                    for (final job in (s.data ?? [])
                        .where((j) => j['orderId'] == widget.order.id))
                      ListTile(
                          title: Text(
                              '${job['printer']} · ${job['type'] == 'customer' ? 'الزبون' : job['type'] == 'cancel' ? 'الإلغاء' : 'المطبخ'}'),
                          subtitle: Text('${{
                                'queued': 'بانتظار الإرسال',
                                'sending': 'الإرسال لم يُحسم؛ تحقق قبل الإعادة',
                                'sent': 'أُرسلت للطابعة؛ تحقق من الورق',
                                'uncertain':
                                    'تعذر تأكيد الإرسال؛ قد تكون طُبعت',
                                'failed': 'فشل تجهيز التذكرة'
                              }[job['status']] ?? job['status']}\n${job['at']}')),
                  ])),
        ]),
      );
}
