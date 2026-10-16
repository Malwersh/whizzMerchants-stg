import 'package:flutter/material.dart';
import '../services/order_returns_service.dart';

class OrderReturnScreen extends StatefulWidget {
  final Map<String, dynamic> selectors;
  final OrderReturnsService? service;
  const OrderReturnScreen({super.key, required this.selectors, this.service});
  @override
  State<OrderReturnScreen> createState() => _OrderReturnScreenState();
}

class _OrderReturnScreenState extends State<OrderReturnScreen> {
  Map<String, dynamic>? data;
  bool busy = false, noCash = false;
  bool? received;
  String? condition, responsibility, error;
  int generation = 0;
  late final service = widget.service ?? OrderReturnsService();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant OrderReturnScreen old) {
    super.didUpdateWidget(old);
    if (old.selectors.toString() != widget.selectors.toString()) load();
  }

  Future<void> load() async {
    final turn = ++generation,
        scope = Map<String, dynamic>.from(widget.selectors);
    setState(() {
      busy = true;
      data = null;
      error = null;
      received = null;
      condition = null;
      responsibility = null;
      noCash = false;
    });
    try {
      final v = await service.call(scope);
      if (mounted && turn == generation) setState(() => data = v);
    } catch (_) {
      if (mounted && turn == generation)
        setState(() => error = 'تعذر تحميل حالة العودة. أعد المحاولة');
    } finally {
      if (mounted && turn == generation) setState(() => busy = false);
    }
  }

  Future<void> confirm() async {
    final record = data;
    if (busy ||
        record == null ||
        received == null ||
        condition == null ||
        responsibility == null ||
        !noCash) return;
    final turn = generation,
        scope = Map<String, dynamic>.from(widget.selectors);
    final body = {
      'returnId': record['returnId'],
      'expectedVersion': record['version'],
      'allItemsReceived': received,
      'condition': condition,
      'driverResponsibility': responsibility,
      'cashCollected': false
    };
    final clean =
        received == true && condition == 'INTACT' && responsibility == 'NONE';
    final agree = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('تأكيد استلام المرتجع'),
                content: Text(clean
                    ? 'سيُحرر الحجز بعد تأكيد استلام جميع الأصناف سليمة وبلا مسؤولية على السائق. لا يُنفذ صرف أو رد للزبون.'
                    : 'ستُحال العودة للمراجعة مع بقاء الحجز قائمًا. لن يمكن استبدال هذا الإقرار بإقرار مختلف من هذه الشاشة.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد الإقرار'))
                ]));
    if (!mounted || turn != generation || agree != true) return;
    setState(() => busy = true);
    try {
      await service.call(scope, receipt: body);
      if (!mounted || turn != generation) return;
      await load();
    } catch (_) {
      if (mounted && turn == generation)
        setState(() {
          data = null;
          busy = false;
          error = 'لم تتأكد النتيجة. أعد تحميل الحالة قبل إعادة الإرسال';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('استلام الطلب المعاد'), actions: [
          IconButton(
              onPressed: busy ? null : load, icon: const Icon(Icons.refresh))
        ]),
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('الطلب ${widget.selectors['orderId']}'),
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(
                    onPressed: busy ? null : load,
                    child: const Text('إعادة التحميل'))
              ],
              if (data != null) ...[
                Text(switch (data!['status']) {
                  'RETURNING' => 'السائق يعيد الأصناف إلى الفرع',
                  'ARRIVED_AT_BRANCH' => 'وصل السائق؛ سجّل ما استلمته فعليًا',
                  'CONFIRMED' => 'تم تأكيد الاستلام وانتهت العودة',
                  'REVIEW_REQUIRED' => 'الاستلام قيد المراجعة والحجز قائم',
                  _ => 'حالة غير متاحة'
                }),
                const Text(
                    'تأكيد المالك إقرار باستلام فعلي. أجرة العودة تُراجع وفق السياسة؛ لا ينشأ رد لزبون لم يدفع.'),
                if (data!['status'] == 'ARRIVED_AT_BRANCH') ...[
                  DropdownButtonFormField<bool>(
                      initialValue: received,
                      decoration: const InputDecoration(
                          labelText: 'هل استلمت جميع الأصناف؟'),
                      items: const [
                        DropdownMenuItem(
                            value: true, child: Text('نعم، جميع الأصناف')),
                        DropdownMenuItem(
                            value: false, child: Text('لا، يوجد نقص'))
                      ],
                      onChanged:
                          busy ? null : (v) => setState(() => received = v)),
                  DropdownButtonFormField<String>(
                      initialValue: condition,
                      decoration: const InputDecoration(
                          labelText: 'حالة الأصناف المستلمة'),
                      items: const [
                        DropdownMenuItem(value: 'INTACT', child: Text('سليمة')),
                        DropdownMenuItem(value: 'DAMAGED', child: Text('تلف')),
                        DropdownMenuItem(value: 'MISSING', child: Text('نقص'))
                      ],
                      onChanged:
                          busy ? null : (v) => setState(() => condition = v)),
                  DropdownButtonFormField<String>(
                      initialValue: responsibility,
                      decoration:
                          const InputDecoration(labelText: 'مسؤولية السائق'),
                      items: const [
                        DropdownMenuItem(
                            value: 'NONE',
                            child: Text('لا توجد مسؤولية مسجلة')),
                        DropdownMenuItem(
                            value: 'REVIEW', child: Text('تحتاج مراجعة'))
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => responsibility = v)),
                  CheckboxListTile(
                      value: noCash,
                      onChanged: busy
                          ? null
                          : (v) => setState(() => noCash = v ?? false),
                      title: const Text(
                          'أؤكد أن هذه عودة بلا مبلغ محصل من الزبون')),
                  FilledButton(
                      onPressed: busy ||
                              received == null ||
                              condition == null ||
                              responsibility == null ||
                              !noCash
                          ? null
                          : confirm,
                      child: const Text('مراجعة وتأكيد الاستلام')),
                ]
              ]
            ])),
      );
}
