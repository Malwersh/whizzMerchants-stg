import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/person_onboarding_service.dart';
import '../services/branch_settlement_service.dart';
import '../widgets/merchant_financial_account.dart';
import '../widgets/merchant_settlement_corrections.dart';

class MerchantPayoutsScreen extends StatefulWidget {
  final String businessId;
  final PersonOnboardingService? service;
  final bool autoRefreshAccount;
  const MerchantPayoutsScreen(
      {super.key,
      required this.businessId,
      this.service,
      this.autoRefreshAccount = true});
  @override
  State<MerchantPayoutsScreen> createState() => _MerchantPayoutsState();
}

class _MerchantPayoutsState extends State<MerchantPayoutsScreen> {
  late final _api = widget.service ?? PersonOnboardingService();
  Map<String, dynamic>? _staffContext;
  bool get _employee => _api is BranchSettlementService;
  bool get _canRequest =>
      !_employee || _staffContext?['can']?['request'] == true;
  bool get _canReceive =>
      !_employee || _staffContext?['can']?['receive'] == true;
  final _attempts = <String, String>{};
  final _statements = <Map<String, dynamic>>[];
  final _payouts = <Map<String, dynamic>>[];
  String? _statementCursor, _payoutCursor, _error;
  bool _busy = false;
  int _epoch = 0;
  int _accountRevision = 0;
  String _periodLabel(dynamic value) {
    final period = Map<String, dynamic>.from(value as Map);
    if (period['kind'] == 'MERCHANT_OFF_CYCLE_PERIOD') {
      String baghdad(dynamic raw) {
        final parsed = DateTime.tryParse(raw?.toString() ?? '');
        if (parsed == null) return 'وقت غير متاح';
        final d = parsed.toUtc().add(const Duration(hours: 3));
        String pad(int n) => n.toString().padLeft(2, '0');
        return '${d.year}-${pad(d.month)}-${pad(d.day)} ${pad(d.hour)}:${pad(d.minute)}';
      }

      return 'كشف استثنائي خارج الدورة\nمن ${baghdad(period['fromUtc'])} حتى ${baghdad(period['untilExclusiveUtc'])} · بتوقيت العراق · النهاية غير مشمولة\nالسبب: ${period['reason'] ?? ''}';
    }
    return '${period['startLocalDate']} إلى ${period['endExclusiveLocalDate']} · النهاية غير مشمولة · توقيت العراق';
  }

  static const _labels = {
    'UNDER_REVIEW': 'بانتظار مراجعة الإدارة',
    'APPROVED': 'معتمد — لم يبدأ الصرف',
    'PROCESSING': 'قيد التنفيذ اليدوي',
    'AWAITING_RECEIPT': 'بانتظار تأكيد استلامك',
    'RECEIPT_CONFIRMED': 'أكدت الاستلام — بانتظار المطابقة',
    'RECONCILIATION_REQUIRED': 'تحتاج مراجعة ومطابقة',
    'CANCELLED': 'أُلغي قبل التنفيذ',
    'PAID': 'تم الصرف والمطابقة',
    'NON_RECEIPT_CONFIRMED': 'أكدت عدم الاستلام — بانتظار مطابقة المصدر',
    'FAILED_NOT_PAID': 'ثبت عدم الصرف — يمكنك طلب المستحق مجددًا',
  };
  String _money(dynamic v) =>
      '${((v as Map)['minorAmount'] as num) ~/ 1000} د.ع';
  List<Map<String, dynamic>> _items(Map<String, dynamic> data) =>
      (data['items'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  Future<Map<String, dynamic>> _get(String view, [String? cursor]) => _api.call(
      'settlement-schedules?view=$view&branchId=${Uri.encodeComponent(widget.businessId)}${cursor == null ? '' : '&cursor=${Uri.encodeComponent(cursor)}'}');
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MerchantPayoutsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _attempts.clear();
      _load();
    }
  }

  Future<void> _load({String? more}) async {
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      if (more == null) _accountRevision++;
    });
    try {
      if (_employee) {
        final c = await _get('payout-context');
        if (!mounted || epoch != _epoch) return;
        _staffContext = c;
      }
      if (more == null || more == 'statements') {
        final d = await _get(
            'payout-statements', more == null ? null : _statementCursor);
        if (!mounted || epoch != _epoch) return;
        if (more == null) _statements.clear();
        for (final r in _items(d)) {
          _statements.removeWhere((x) => x['batchId'] == r['batchId']);
          _statements.add(r);
        }
        _statementCursor = d['nextCursor'];
      }
      if (more == null || more == 'payouts') {
        final d = await _get('payouts', more == null ? null : _payoutCursor);
        if (!mounted || epoch != _epoch) return;
        if (more == null) _payouts.clear();
        for (final r in _items(d)) {
          _payouts.removeWhere((x) => x['payoutId'] == r['payoutId']);
          _payouts.add(r);
        }
        _payoutCursor = d['nextCursor'];
      }
    } catch (e) {
      if (mounted && epoch == _epoch) _error = e.toString();
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final v = {'branchId': widget.businessId, ...body},
        fingerprint = jsonEncode(v);
    final requestId =
        _attempts.putIfAbsent(fingerprint, () => const Uuid().v4());
    final result = await _api
        .call('settlement-schedules', body: {...v, 'requestId': requestId});
    _attempts.remove(fingerprint);
    return result;
  }

  Future<void> _showStatement(Map<String, dynamic> batch) async {
    if (_busy) return;
    final epoch = _epoch, branchId = widget.businessId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _api.call(
          'settlement-schedules?view=payout-statement&branchId=${Uri.encodeComponent(branchId)}&batchId=${Uri.encodeComponent(batch['batchId'])}');
      if (!mounted || epoch != _epoch || branchId != widget.businessId) return;
      final lines = (data['lines'] as List).cast<Map>();
      if (data['coverage'] != 'COMPLETE_SAVED_STATEMENT' ||
          lines.isEmpty ||
          lines.length > 10 ||
          lines.length != data['summary']['accrualCount']) {
        throw Exception('تعذر التحقق من اكتمال الكشف. أعد تحميله.');
      }
      const fields = {
        'goodsGross': 'قيمة المنتجات',
        'merchantFundedDiscount': 'خصم يموله المطعم',
        'platformFundedDiscount': 'خصم تموله المنصة',
        'merchantGoodsEntitlement': 'حق المنتجات بعد خصم المطعم',
        'merchantCommission': 'عمولة المنصة',
        'merchantOtherCharges': 'رسوم المطعم الأخرى',
        'merchantDeliverySupport': 'دعم التوصيل من المطعم',
        'merchantNet': 'صافي مستحق المطعم',
      };
      Widget amounts(Map values) => Column(children: [
            for (final field in fields.entries)
              if (values[field.key] != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(field.value)),
                      Text(_money(values[field.key]),
                          style: TextStyle(
                              fontWeight: field.key == 'merchantNet'
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ])),
          ]);
      setState(() => _busy = false);
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('تفاصيل كشف المستحقات'),
                content: SizedBox(
                    width: 560,
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_periodLabel(data['period'])),
                          const SizedBox(height: 8),
                          Text(data['paymentStatus'] == 'PAID'
                              ? 'تمت التسوية والمطابقة'
                              : 'لم يُصرف — اعتماد الكشف وحده لا يعني الدفع'),
                          const Divider(),
                          if (data['correctionSettlement'] is Map)
                            Text(
                                'مستحق تصحيح إضافي: ${data['correctionSettlement']['creditIqd']} د.ع · خصم مديونية: ${data['correctionSettlement']['debtIqd']} د.ع · النقد المدفوع فعليًا: ${_money(data['paidCashAmount'])}'),
                          const Text('إجمالي الكشف',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          amounts(data['summary']['amounts']),
                          for (final line in lines) ...[
                            const Divider(),
                            SelectionArea(
                                child: Text('الطلب: ${line['orderId']}')),
                            Text(
                                'التسليم بتوقيت العراق: ${DateTime.parse(line['deliveredAt']).toUtc().add(const Duration(hours: 3)).toIso8601String().substring(0, 16).replaceAll('T', ' ')}'),
                            amounts(line['amounts']),
                          ],
                          const Divider(),
                          const Text(
                              'يشمل هذا الكشف طلباته المثبتة فقط، ولا يمثل إجمالي حساب المطعم.'),
                          SelectionArea(
                              child: Text('مرجع الكشف: ${data['batchId']}')),
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إغلاق'))
                ],
              ));
    } catch (e) {
      if (mounted && epoch == _epoch) setState(() => _error = e.toString());
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _request(Map<String, dynamic> batch) async {
    String method = 'CASH', notice = '';
    String? proofId;
    bool verified = false, working = false;
    String phoneValue = '', codeValue = '';
    bool submitted = false;
    submitted = await showDialog<bool>(
            context: context,
            builder: (dialogContext) =>
                StatefulBuilder(builder: (context, update) {
                  Future<void> operation(Future<void> Function() run) async {
                    update(() {
                      working = true;
                      notice = '';
                    });
                    try {
                      await run();
                    } catch (e) {
                      if (context.mounted) {
                        update(() => notice = e.toString());
                      }
                    } finally {
                      if (context.mounted) update(() => working = false);
                    }
                  }

                  return PopScope(
                      canPop: !working,
                      child: AlertDialog(
                        title: const Text('طلب صرف مستحقات الكشف'),
                        content: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  'صافي المستحق: ${_money(batch['summary']['amounts']['merchantNet'])}'),
                              Text(_employee
                                  ? 'تُحفظ هويتك وصفتك كمفوّض عن المطعم. تتولى إدارة المنصة الصرف والمطابقة؛ لا تؤكد الاستلام قبل وصول كامل المبلغ.'
                                  : 'الطلب للمالك نفسه. تتولى الإدارة الصرف الفعلي؛ لا تؤكد الاستلام قبل وصول المبلغ كاملًا.'),
                              DropdownButton<String>(
                                  isExpanded: true,
                                  value: method,
                                  items: [
                                    const DropdownMenuItem(
                                        value: 'CASH', child: Text('نقدًا')),
                                    DropdownMenuItem(
                                        value: 'ZAIN_CASH',
                                        enabled: !_employee ||
                                            (_staffContext?['methods']
                                                        as List? ??
                                                    [])
                                                .contains('ZAIN_CASH'),
                                        child: const Text('حوالة زين كاش')),
                                    DropdownMenuItem(
                                        value: 'BANK',
                                        enabled: false,
                                        child: Text('حوالة مصرفية — قريبًا')),
                                  ],
                                  onChanged: working
                                      ? null
                                      : (v) => update(() {
                                            method = v!;
                                            phoneValue = '';
                                            codeValue = '';
                                            proofId = _employee
                                                ? _staffContext?['destination']
                                                    ?['proofId'] as String?
                                                : null;
                                            verified =
                                                _employee && proofId != null;
                                            notice = '';
                                          })),
                              if (method == 'ZAIN_CASH' && _employee)
                                Text(
                                    'جهة زين كاش المعتمدة من المالك: ${_staffContext?['destination']?['maskedPhone'] ?? ''}. تغيير الجهة يحتاج تحقق المالك.'),
                              if (method == 'ZAIN_CASH' && !_employee) ...[
                                TextField(
                                    onChanged: (v) => phoneValue = v,
                                    enabled: !working && proofId == null,
                                    keyboardType: TextInputType.phone,
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'رقم محفظة زين كاش لهذا الطلب')),
                                if (proofId == null)
                                  TextButton(
                                      onPressed: working
                                          ? null
                                          : () => operation(() async {
                                                final d = await _post({
                                                  'action':
                                                      'START_PAYOUT_DESTINATION',
                                                  'phone': phoneValue
                                                });
                                                if (context.mounted) {
                                                  update(() {
                                                    proofId = d['proofId'];
                                                    verified = d['status'] ==
                                                        'VERIFIED';
                                                    notice =
                                                        'أدخل الرمز المرسل إلى رقم الوجهة. هذا لا يغيّر رقم تسجيل الدخول.';
                                                  });
                                                }
                                              }),
                                      child:
                                          const Text('إرسال رمز تحقق للوجهة')),
                                if (proofId != null && !verified) ...[
                                  TextField(
                                      onChanged: (v) => codeValue = v,
                                      enabled: !working,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      decoration: const InputDecoration(
                                          labelText: 'رمز التحقق')),
                                  TextButton(
                                      onPressed: working
                                          ? null
                                          : () => operation(() async {
                                                await _post({
                                                  'action':
                                                      'VERIFY_PAYOUT_DESTINATION',
                                                  'proofId': proofId,
                                                  'code': codeValue
                                                });
                                                if (context.mounted) {
                                                  update(() {
                                                    verified = true;
                                                    notice =
                                                        'تم التحقق من رقم الوجهة لهذا الطلب.';
                                                  });
                                                }
                                              }),
                                      child: const Text('تأكيد الرقم')),
                                ],
                                if (proofId != null)
                                  TextButton(
                                      onPressed: working
                                          ? null
                                          : () => update(() {
                                                proofId = null;
                                                verified = false;
                                                codeValue = '';
                                              }),
                                      child: const Text(
                                          'تغيير الرقم / بدء تحقق جديد')),
                              ],
                              if (notice.isNotEmpty) Text(notice),
                              if (working) const LinearProgressIndicator(),
                            ])),
                        actions: [
                          TextButton(
                              onPressed: working
                                  ? null
                                  : () => Navigator.pop(dialogContext, false),
                              child: const Text('رجوع')),
                          FilledButton(
                              onPressed: working ||
                                      method == 'ZAIN_CASH' && !verified
                                  ? null
                                  : () => operation(() async {
                                        await _post({
                                          'action': 'REQUEST_PAYOUT',
                                          'batchId': batch['batchId'],
                                          'batchDigest': batch['batchDigest'],
                                          'method': method,
                                          if (method == 'ZAIN_CASH')
                                            'destinationProofId': proofId
                                        });
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext, true);
                                        }
                                      }),
                              child: const Text('إرسال طلب الصرف'))
                        ],
                      ));
                })) ??
        false;
    if (submitted && mounted) {
      setState(() => _section = 2);
      await _load();
    }
  }

  Future<void> _act(Map<String, dynamic> row, String action) async {
    String? reason;
    final receipt = action == 'ACK_PAYOUT_RECEIPT';
    final noReceipt = action == 'ACK_PAYOUT_NOT_RECEIVED';
    String reasonValue = '';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(receipt
                    ? 'تأكيد الاستلام الفعلي'
                    : action == 'CANCEL_PAYOUT'
                        ? 'إلغاء طلب الصرف'
                        : noReceipt
                            ? 'تأكيد عدم استلام أي مبلغ'
                            : 'طلب مراجعة الصرف'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(receipt
                      ? 'هل استلمت كامل مبلغ ${_money(row['amount'])} بالفعل؟ لا تؤكد بناءً على وعد أو صورة حوالة فقط.'
                      : action == 'CANCEL_PAYOUT'
                          ? 'يمكن إلغاء الطلب قبل بدء التنفيذ فقط.'
                          : noReceipt
                              ? 'هل تؤكد أنك لم تستلم أي جزء من هذا المبلغ؟ ستراجع الإدارة نتيجة المصدر قبل السماح بطلب جديد.'
                              : 'سيبقى المستحق مرتبطًا بهذا الطلب إلى حين المطابقة، دون إعادة دفع تلقائية.'),
                  if (action == 'REPORT_PAYOUT_PROBLEM')
                    TextField(
                        onChanged: (v) => reasonValue = v,
                        maxLength: 300,
                        decoration: const InputDecoration(
                            labelText: 'سبب المراجعة — خمسة أحرف على الأقل'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () {
                        reason = reasonValue.trim();
                        if (action != 'REPORT_PAYOUT_PROBLEM' ||
                            reason!.length >= 5) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      child:
                          Text(receipt ? 'نعم، استلمت كامل المبلغ' : 'تأكيد'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _post({
        'action': action,
        'payoutId': row['payoutId'],
        'version': row['version'],
        if (action == 'ACK_PAYOUT_NOT_RECEIVED') ...{
          'accepted': true,
          'receivedAmount': 0
        },
        if (receipt) ...{
          'accepted': true,
          'receivedAmount': (row['amount']['minorAmount'] as num) ~/ 1000
        },
        if (reason != null && action == 'REPORT_PAYOUT_PROBLEM')
          'reason': reason
      });
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  Widget _statementCard(Map<String, dynamic> b) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_money(b['summary']['amounts']['merchantNet']),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(
                '${b['summary']['accrualCount']} طلب · ${b['period']['kind'] == 'MERCHANT_OFF_CYCLE_PERIOD' ? 'تسوية استثنائية' : 'تسوية دورية'}'),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                key: PageStorageKey('statement-period-${b['batchId']}'),
                title: const Text('الفترة وسبب التسوية'),
                children: [
                  Text(_periodLabel(b['period'])),
                  SelectionArea(child: Text('مرجع الكشف: ${b['batchId']}'))
                ]),
            Text((b['summary']['amounts']['merchantNet']['minorAmount']
                        as num) ==
                    0
                ? 'صافي المستحق صفر — لا يتطلب صرفًا'
                : b['payoutStatus'] == 'PAID'
                    ? 'تمت التسوية'
                    : b['payoutStatus'] == 'ACTIVE'
                        ? 'مرتبط بطلب صرف قائم'
                        : b['approved'] == true
                            ? 'معتمد — لم يُصرف'
                            : 'بانتظار اعتماد الإدارة'),
            OutlinedButton(
                onPressed: _busy ? null : () => _showStatement(b),
                child: const Text('تفاصيل الكشف والطلبات')),
            if (_canRequest &&
                (b['summary']['amounts']['merchantNet']['minorAmount'] as num) >
                    0 &&
                b['approved'] == true &&
                !['ACTIVE', 'PAID'].contains(b['payoutStatus']))
              FilledButton(
                  onPressed: _busy ? null : () => _request(b),
                  child: const Text('طلب صرف المستحقات'))
          ])));
  Widget _payoutCard(Map<String, dynamic> p) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${_money(p['amount'])} · ${p['method'] == 'CASH' ? 'نقدًا' : 'زين كاش'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(p['settlementMode'] == 'OFFSET_ONLY'
                ? 'تمت التسوية بالمقاصة — دون تسليم نقدي'
                : (_labels[p['status']] ?? p['status'])),
            if (p['correctionSettlement'] is Map)
              Text(
                  '${p['sourceKind'] == 'CORRECTIONS_ONLY' ? 'صرف تصحيح مستقل' : 'مستحق الكشف: ${_money(p['baseAmount'])}'}\nمستحق تصحيح إضافي: ${p['correctionSettlement']['creditIqd']} د.ع\nخصم مديونية: ${p['correctionSettlement']['debtIqd']} د.ع\nالنقد للتسليم: ${_money(p['amount'])}'),
            Text('المستفيد: ${p['recipientName'] ?? p['destination']}'),
            if (p['recipientRoleLabel'] != null)
              Text(
                  '${p['recipientRoleLabel']}${p['recipientBusinessName'] == null ? '' : ' — ${p['recipientBusinessName']}'}'),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                key: PageStorageKey('payout-reference-${p['payoutId']}'),
                title: const Text('مرجع طلب الصرف'),
                children: [SelectionArea(child: Text(p['payoutId']))]),
            if (p['externalReference'] != null)
              Text('مرجع التنفيذ: ${p['externalReference']}'),
            if (_canReceive && p['status'] == 'RECONCILIATION_REQUIRED')
              TextButton(
                  onPressed:
                      _busy ? null : () => _act(p, 'ACK_PAYOUT_NOT_RECEIVED'),
                  child: const Text('تأكيد أنني لم أستلم أي مبلغ')),
            if (_canReceive && p['status'] == 'AWAITING_RECEIPT')
              FilledButton(
                  onPressed: _busy ? null : () => _act(p, 'ACK_PAYOUT_RECEIPT'),
                  child: const Text('تأكيد استلام كامل المبلغ')),
            if (_canRequest &&
                ['UNDER_REVIEW', 'APPROVED'].contains(p['status']))
              TextButton(
                  onPressed: _busy ? null : () => _act(p, 'CANCEL_PAYOUT'),
                  child: const Text('إلغاء قبل التنفيذ')),
            if (_canReceive &&
                ['PROCESSING', 'AWAITING_RECEIPT', 'RECEIPT_CONFIRMED']
                    .contains(p['status']))
              TextButton(
                  onPressed:
                      _busy ? null : () => _act(p, 'REPORT_PAYOUT_PROBLEM'),
                  child: const Text('لم أستلم / طلب مراجعة'))
          ])));

  int _section = 0;
  Widget _pagedList(bool statements) {
    final rows = statements ? _statements : _payouts;
    final cursor = statements ? _statementCursor : _payoutCursor;
    return ListView.builder(
        key: PageStorageKey(
            statements ? 'merchant-statements' : 'merchant-payouts'),
        padding: const EdgeInsets.all(16),
        itemCount: rows.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(statements
                    ? 'اعتماد الكشف لا يعني دفعه. افتح تفاصيل الكشف لمراجعة طلباته، ثم اطلب صرفه.'
                    : 'تابع طلب الصرف هنا. أكّد الاستلام فقط بعد وصول كامل المبلغ إليك.'));
          }
          if (index <= rows.length) {
            return statements
                ? _statementCard(rows[index - 1])
                : _payoutCard(rows[index - 1]);
          }
          if (cursor != null) {
            return OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _load(more: statements ? 'statements' : 'payouts'),
                child: Text(statements
                    ? 'تحميل كشوف إضافية'
                    : 'تحميل طلبات صرف إضافية'));
          }
          return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  rows.isEmpty
                      ? (statements
                          ? 'لا توجد كشوف محفوظة حتى الآن.'
                          : 'لا توجد طلبات صرف حتى الآن.')
                      : 'نهاية النتائج المحمّلة',
                  textAlign: TextAlign.center));
        });
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مستحقاتي والتسويات'), actions: [
          IconButton(
              tooltip: 'تحديث',
              onPressed: _busy ? null : () => _load(),
              icon: const Icon(Icons.refresh))
        ]),
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                for (final item in [
                  (0, 'الحساب', Icons.account_balance_outlined),
                  (1, 'الكشوف', Icons.receipt_long_outlined),
                  (2, 'طلبات الصرف', Icons.payments_outlined)
                ])
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                              showCheckmark: false,
                              label: SizedBox(
                                  width: double.infinity,
                                  child: Text(item.$2,
                                      textAlign: TextAlign.center)),
                              selected: _section == item.$1,
                              onSelected: (_) =>
                                  setState(() => _section = item.$1))))
              ])),
          if (_employee && _staffContext != null)
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                    '${_staffContext?['actor']?['name']} — ${_staffContext?['actor']?['roleLabel']} · ${_staffContext?['actor']?['businessName']}')),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(
              child: IndexedStack(index: _section, children: [
            Offstage(
                offstage: _section != 0,
                child: ListView(
                    key: const PageStorageKey('merchant-account'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      MerchantFinancialAccount(
                          businessId: widget.businessId,
                          service: _api,
                          autoRefresh: widget.autoRefreshAccount,
                          refreshRevision: _accountRevision),
                      if (!_employee)
                        MerchantSettlementCorrections(
                            businessId: widget.businessId,
                            service: _api,
                            onPayoutRequested: () {
                              setState(() {
                                _section = 2;
                              });
                              _load();
                            })
                    ])),
            Offstage(offstage: _section != 1, child: _pagedList(true)),
            Offstage(offstage: _section != 2, child: _pagedList(false))
          ]))
        ])),
      ));
}
