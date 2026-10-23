import 'return_continuation_screen.dart';
import 'dart:async';
import 'return_item_receipt_editor.dart';
import 'package:flutter/material.dart';
import '../services/order_returns_service.dart';

class OrderReturnScreen extends StatefulWidget {
  final Map<String, dynamic> selectors;
  final OrderReturnsService? service;
  const OrderReturnScreen({super.key, required this.selectors, this.service});
  @override
  State<OrderReturnScreen> createState() => _OrderReturnScreenState();
}

class _OrderReturnScreenState extends State<OrderReturnScreen>
    with WidgetsBindingObserver {
  Timer? poll;
  Map<String, dynamic>? data;
  bool busy = false, noCash = false, canReceiveReturn = false;
  final readinessNote = TextEditingController();
  @override
  void dispose() {
    poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    readinessNote.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>>? itemReceipts;
  bool? received;
  String? condition, responsibility, error;
  int generation = 0;
  late final service = widget.service ?? OrderReturnsService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!busy &&
          received == null &&
          !canReceiveReturn &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) load(silent: true);
    });
    load();
  }

  @override
  void didUpdateWidget(covariant OrderReturnScreen old) {
    super.didUpdateWidget(old);
    if (old.selectors.toString() != widget.selectors.toString()) load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load(silent: true);
  }

  Future<void> load({bool silent = false}) async {
    final turn = ++generation,
        scope = Map<String, dynamic>.from(widget.selectors);
    setState(() {
      busy = true;
      if (!silent) data = null;
      error = null;
      if (!silent) {
        itemReceipts = null;
        received = null;
        condition = null;
        responsibility = null;
        noCash = false;
        canReceiveReturn = false;
      }
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

  Future<void> setAutomaticAcceptance(bool enabled) async {
    if (busy) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(enabled
                    ? 'استقبال المرتجعات تلقائيًا'
                    : 'إيقاف الاستقبال التلقائي'),
                content: Text(enabled
                    ? 'أوافق بصفتي مالك الفرع على استقبال المرتجعات أثناء العمل. يتحقق الخادم من الفتح ووقت العودة والهامش المعتمد قبل الإغلاق. لا يعني هذا تأكيد استلام أي أصناف أو اعتماد تعويض مالي.'
                    : 'ستحتاج الحالات الجديدة إلى المراجعة اليدوية. التصاريح السابقة لا تُلغى بهذا التغيير.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد'))
                ]));
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      await service.call(widget.selectors,
          receipt: {'automaticReturnAcceptance': enabled});
      if (mounted) await load();
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error = 'لم يتأكد حفظ الإعداد. حدّث الحالة قبل إعادة المحاولة.';
        });
    }
  }

  Future<void> recordReadiness() async {
    if (busy ||
        !canReceiveReturn ||
        readinessNote.text.trim().length < 5 ||
        data?['status'] != 'REQUESTED') return;
    setState(() => busy = true);
    try {
      await service.call(widget.selectors, receipt: {
        'returnId': data!['returnId'],
        'expectedVersion': data!['version'],
        'branchCanReceive': true,
        'note': readinessNote.text.trim()
      });
      if (mounted) await load();
    } catch (_) {
      if (mounted)
        setState(() {
          data = null;
          busy = false;
          error =
              'لم يتأكد تسجيل استعداد الفرع. حدّث الحالة قبل إعادة المحاولة.';
        });
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
      'cashCollected': false,
      if (record['itemManifest'] != null) 'itemReceipts': itemReceipts,
    };
    final clean =
        received == true && condition == 'INTACT' && responsibility == 'NONE';
    final agree = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('تأكيد استلام المرتجع'),
                content: Text(clean
                    ? 'سيُحرر الحجز بعد تأكيد استلام جميع الأصناف سليمة وبلا مسؤولية على السائق. لا يُنفذ صرف أو رد للزبون.'
                    : received == true
                        ? 'تأكيد استلام جميع الأصناف ينهي مهمة إرجاع السائق. مراجعة التلف والمسؤولية والضمان والتعويض مستقلة. لا يعني التلف أن السائق مسؤول عنه.'
                        : 'سيسجل الاستلام الجزئي وتبقى العهدة والضمان للمراجعة. أبلغ الدعم بالكميات المستلمة والناقصة؛ لا تُحمّل المسؤولية تلقائيًا.'),
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
                if (data!['continuation'] != null)
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ReturnContinuationScreen(
                                      orderId: widget.selectors['orderId'],
                                      caseKey:
                                          'RETURN#${widget.selectors['attempt']}',
                                      driver: false,
                                      call: (body) {
                                        final payload =
                                            Map<String, dynamic>.from(body);
                                        final action = payload.remove('action');
                                        return service.call(widget.selectors,
                                            receipt: {
                                              ...payload,
                                              'custodyAction': action
                                            });
                                      }))),
                      child: const Text('متابعة الكميات الإضافية والاعتراضات')),
                SwitchListTile(
                    value:
                        data!['automaticReturnAcceptance']?['enabled'] == true,
                    onChanged: busy ? null : setAutomaticAcceptance,
                    title: const Text('استقبال المرتجعات تلقائيًا أثناء العمل'),
                    subtitle: const Text(
                        'موافقة دائمة للفرع؛ تأكيد الاستلام الفعلي يبقى مطلوبًا.')),
                if (data!['handoverIssue']?['state'] == 'AWAITING_SUPPORT')
                  Text(
                      'بلاغ من السائق عند الفرع: ${data!['handoverIssue']['note']} — يحتاج مراجعة وتواصلًا عاجلًا.'),
                Text(switch (data!['status']) {
                  'REQUESTED' => 'تعذر التسليم؛ بانتظار تعليمات الإدارة',
                  'RETURNING' => 'السائق يعيد الأصناف إلى الفرع',
                  'ARRIVED_AT_BRANCH' => 'وصل السائق؛ سجّل ما استلمته فعليًا',
                  'CONFIRMED' => 'تم تأكيد الاستلام وانتهت العودة',
                  'REVIEW_REQUIRED' => data!['taskCompleted'] == true
                      ? (data!['continuation']?['plan'] != null
                          ? 'انتهت عهدة السائق؛ متابعة الأصناف والضمان والحقوق مستقلة'
                          : (data!['holdStatus'] == 'RELEASED'
                              ? 'انتهت مهمة الإرجاع وحُرر الضمان؛ مراجعة الحقوق مستمرة'
                              : 'استلمت الأصناف وانتهت مهمة الإرجاع؛ الحالة والضمان والحقوق قيد المراجعة'))
                      : 'الاستلام الجزئي أو العهدة قيد المراجعة؛ تواصل مع الدعم',
                  _ => 'حالة غير متاحة'
                }),
                if (data!['status'] == 'REQUESTED' &&
                    data!['continuation']?['plan'] == null) ...[
                  if (data!['branchReadiness'] != null)
                    const Text(
                        'سُجل استعداد الفرع للاستقبال؛ لم يصدر تصريح العودة بعد.'),
                  const Text(
                      'أبلغ الإدارة إذا كان الفرع مفتوحًا وقادرًا على استقبال الأصناف. هذا لا يعني استلامها فعليًا أو السماح بإعادة تقديمها.'),
                  TextField(
                      controller: readinessNote,
                      maxLength: 1000,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'توضيح استعداد الفرع للاستقبال')),
                  CheckboxListTile(
                      value: canReceiveReturn,
                      onChanged: busy
                          ? null
                          : (v) =>
                              setState(() => canReceiveReturn = v ?? false),
                      title: const Text(
                          'الفرع مفتوح ويمكنه استقبال الأصناف العائدة')),
                  FilledButton(
                      onPressed: busy ||
                              !canReceiveReturn ||
                              readinessNote.text.trim().length < 5
                          ? null
                          : recordReadiness,
                      child: const Text('تسجيل استعداد الفرع للإدارة')),
                ],
                if (data!['resolution'] is Map) ...[
                  const SizedBox(height: 12),
                  const Text('قضية الاستثناء والمستحقات',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('مرجع القضية: ${data!['resolution']['caseId']}'),
                  const Text(
                      'تأكيد استلام الأصناف ينهي العهدة ولا يعني اعتماد تعويض المطعم أو صرفه.'),
                  Text(data!['resolution']['nextStep'] ??
                      'مراجعة المستحقات وفق الاتفاقية والأدلة'),
                  const SizedBox(height: 12),
                ],
                const Text(
                    'تأكيد المالك إقرار باستلام فعلي. أجرة العودة تُراجع وفق السياسة؛ لا ينشأ رد لزبون لم يدفع.'),
                if (data!['itemReceipt'] is Map)
                  ReturnItemReceiptSummary(
                      receipt: Map<String, dynamic>.from(data!['itemReceipt'])),
                if (data!['status'] == 'ARRIVED_AT_BRANCH' &&
                    data!['continuation']?['plan'] == null) ...[
                  if (data!['itemManifest'] is Map)
                    ReturnItemReceiptEditor(
                        key: ValueKey(data!['itemManifest']['digest']),
                        manifest:
                            Map<String, dynamic>.from(data!['itemManifest']),
                        enabled: !busy,
                        onChanged: (lines) => setState(() {
                              itemReceipts = lines;
                              received = lines == null
                                  ? null
                                  : lines.every((line) {
                                      final expected = (data!['itemManifest']
                                              ['lines'] as List)
                                          .firstWhere((e) =>
                                              e['lineId'] == line['lineId']);
                                      return line['receivedQty'] ==
                                          expected['expectedQty'];
                                    });
                              condition = lines == null
                                  ? null
                                  : received == false
                                      ? 'MISSING'
                                      : lines.any((line) => [
                                                'DAMAGED',
                                                'SPOILED',
                                                'UNKNOWN'
                                              ].contains(line['condition']))
                                          ? 'DAMAGED'
                                          : 'INTACT';
                            })),
                  if (data!['itemManifest'] == null) ...[
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
                          DropdownMenuItem(
                              value: 'INTACT', child: Text('سليمة')),
                          DropdownMenuItem(
                              value: 'DAMAGED', child: Text('تالفة'))
                        ],
                        onChanged:
                            busy ? null : (v) => setState(() => condition = v)),
                  ],
                  DropdownButtonFormField<String>(
                      initialValue: responsibility,
                      decoration: const InputDecoration(
                          labelText: 'هل توجد ملاحظة تحتاج مراجعة؟'),
                      items: const [
                        DropdownMenuItem(
                            value: 'NONE',
                            child: Text('لا توجد ملاحظة على السائق')),
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
