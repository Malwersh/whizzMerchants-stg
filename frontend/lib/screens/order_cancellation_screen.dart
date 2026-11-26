import 'package:flutter/material.dart';
import '../services/order_returns_service.dart';

class OrderCancellationScreen extends StatefulWidget {
  final Map<String, dynamic> selectors;
  final OrderReturnsService? service;
  const OrderCancellationScreen(
      {super.key, required this.selectors, this.service});
  @override
  State<OrderCancellationScreen> createState() =>
      _OrderCancellationScreenState();
}

class _OrderCancellationScreenState extends State<OrderCancellationScreen> {
  bool retained = false,
      noCash = false,
      busy = false,
      done = false,
      uncertain = false;
  int generation = 0;
  @override
  void didUpdateWidget(covariant OrderCancellationScreen old) {
    super.didUpdateWidget(old);
    if (old.selectors.toString() != widget.selectors.toString()) {
      generation++;
      retained = false;
      noCash = false;
      busy = false;
      done = false;
      uncertain = false;
    }
  }

  Future<void> cancel() async {
    if (busy || !retained || !noCash || uncertain) return;
    final turn = generation,
        scope = Map<String, dynamic>.from(widget.selectors);
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('إلغاء الطلب قبل استلام السائق'),
                content: const Text(
                    'يُلغى الطلب كاملًا ويُحرر حجز هذه المحاولة وتمويل الخصم. أي أجرة أو تعويض يبقى للمراجعة وفق السياسة. بعد الاستلام استخدم مسار العودة.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد الإلغاء'))
                ]));
    if (!mounted || turn != generation || yes != true) return;
    setState(() => busy = true);
    try {
      await (widget.service ?? OrderReturnsService()).call(scope,
          cancel: true,
          receipt: {'goodsRetainedByBranch': true, 'cashCollected': false});
      if (mounted && turn == generation) setState(() => done = true);
    } catch (_) {
      if (mounted && turn == generation) setState(() => uncertain = true);
    } finally {
      if (mounted && turn == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('إلغاء الطلب قبل الاستلام')),
      body: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(
                'الطلب ${widget.selectors['orderId']} — الفرع ${widget.selectors['businessId']}'),
            if (busy) const LinearProgressIndicator(),
            if (done)
              const Text('أكد الخادم إلغاء الطلب وتحرير الحجز')
            else if (uncertain)
              const Text(
                  'النتيجة غير مؤكدة. عد إلى الطلبات وحدّث حالتها قبل أي إعادة إرسال.')
            else ...[
              const Text(
                  'هذا الإجراء يلغي الطلب كاملًا. فك إسناد السائق مع إبقاء الطلب إجراء مختلف. الخادم يرفض الإلغاء إذا سبق استلام الأصناف.'),
              CheckboxListTile(
                  value: retained,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => retained = v ?? false),
                  title:
                      const Text('الأصناف باقية في الفرع ولم يستلمها السائق')),
              CheckboxListTile(
                  value: noCash,
                  onChanged:
                      busy ? null : (v) => setState(() => noCash = v ?? false),
                  title: const Text('لم يحصل تحصيل نقدي من الزبون')),
              FilledButton(
                  onPressed: busy || !retained || !noCash ? null : cancel,
                  child: const Text('مراجعة الإلغاء')),
            ]
          ])));
}
