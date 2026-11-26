import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../services/person_onboarding_service.dart';

class MerchantFinancialAccount extends StatefulWidget {
  final String businessId;
  final PersonOnboardingService service;
  final bool autoRefresh;
  final int refreshRevision;
  const MerchantFinancialAccount(
      {super.key,
      required this.businessId,
      required this.service,
      this.autoRefresh = true,
      this.refreshRevision = 0});
  @override
  State<MerchantFinancialAccount> createState() =>
      _MerchantFinancialAccountState();
}

class _MerchantFinancialAccountState extends State<MerchantFinancialAccount>
    with WidgetsBindingObserver {
  final _rows = <String, Map<String, dynamic>>{};
  Map<String, dynamic> _labels = {};
  Map<String, dynamic>? _wallet;
  late DateTime _from, _through;
  String? _cursor, _error;
  String _state = 'ALL';
  bool _busy = false, _loaded = false;
  int _epoch = 0;
  int _visibleLimit = 20;
  Timer? _timer;
  DateTime get _baghdadToday {
    final d = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(d.year, d.month, d.day);
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _money(dynamic v) {
    if (v is! Map ||
        v['currency'] != 'IQD' ||
        v['scale'] != 1000 ||
        v['moneySchemaVersion'] != 1 ||
        v['minorAmount'] is! int ||
        (v['minorAmount'] as int).abs() > 9007199254740991 ||
        (v['minorAmount'] as int) % 1000 != 0) {
      throw const FormatException('وحدة مالية غير معروفة');
    }
    return '${NumberFormat('#,##0', 'en').format((v['minorAmount'] as num) ~/ 1000)} د.ع';
  }

  String _at(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null
        ? 'غير متاح'
        : d
            .toUtc()
            .add(const Duration(hours: 3))
            .toIso8601String()
            .substring(0, 16)
            .replaceAll('T', ' ');
  }

  static const _states = {
    'POSTED': 'تم القيد',
    'ALL': 'كل الحركات',
    'PENDING_SETTLEMENT': 'بانتظار التسوية',
    'NO_PAYOUT_REQUIRED': 'صافي المستحق صفر — لا يتطلب صرفًا',
    'IN_STATEMENT': 'ضمن كشف محفوظ',
    'IN_PAYOUT': 'قيد الصرف',
    'PAID': 'تم الصرف',
    'REVIEW_REQUIRED': 'بانتظار تدقيق الإدارة'
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _through = _baghdadToday;
    _from = DateTime(_through.year, _through.month, 1);
    _load();
    if (widget.autoRefresh) {
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (mounted &&
            !_busy &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            (ModalRoute.of(context)?.isCurrent ?? false)) {
          _load(preserveDisplay: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MerchantFinancialAccount old) {
    super.didUpdateWidget(old);
    if (old.businessId != widget.businessId) {
      _epoch++;
      _busy = false;
      _load();
    } else if (old.refreshRevision != widget.refreshRevision && !_busy) {
      _load(preserveDisplay: true);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_busy &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      _load(preserveDisplay: true);
    }
  }

  Future<void> _load({bool more = false, bool preserveDisplay = false}) async {
    if (_busy) return;
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      if (!more && !preserveDisplay) {
        _rows.clear();
        _visibleLimit = 20;
        _wallet = null;
        _labels = {};
        _cursor = null;
        _loaded = false;
      }
    });
    try {
      final q = {
        'view': 'merchant-account',
        'branchId': widget.businessId,
        'fromLocalDate': _date(_from),
        'throughLocalDate': _date(_through),
        if (more && _cursor != null) 'cursor': _cursor!
      };
      final d = await widget.service
          .call('settlement-schedules?${Uri(queryParameters: q).query}');
      if (!mounted || epoch != _epoch) return;
      if (d['coverage'] != 'POSTED_MERCHANT_LEDGER_MOVEMENTS') {
        throw const FormatException('تعذر التحقق من مصدر السجل');
      }
      final candidates = more
          ? Map<String, Map<String, dynamic>>.from(_rows)
          : <String, Map<String, dynamic>>{};
      for (final raw in d['items'] as List) {
        final row = Map<String, dynamic>.from(raw);
        if (row['evidenceVerified'] == true && row['amounts'] is Map) {
          for (final value in (row['amounts'] as Map).values) {
            _money(value);
          }
        }
        if (row['evidenceVerified'] == true && row['kind'] == 'PAYOUT') {
          _money(row['amount']);
        }
        candidates[row['entryId']] = row;
      }
      setState(() {
        _rows
          ..clear()
          ..addAll(candidates);
        _labels = Map<String, dynamic>.from(d['amountLabels']);
        _wallet =
            d['wallet'] == null ? null : Map<String, dynamic>.from(d['wallet']);
        _cursor = d['nextCursor'];
        _loaded = true;
      });
    } catch (e) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = e.toString();
          _rows.clear();
          _visibleLimit = 20;
          _wallet = null;
          _loaded = false;
          _cursor = null;
        });
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  BigInt _total(String key, Iterable<Map<String, dynamic>> rows) => rows.fold(
      BigInt.zero,
      (a, r) =>
          a +
          BigInt.from(
              ((r['amounts'] as Map?)?[key]?['minorAmount'] as num?)?.toInt() ??
                  0));
  Widget _metric(String title, BigInt amount, {bool complete = true}) =>
      Container(
          width: (MediaQuery.sizeOf(context).width - 48) / 2,
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xfff5f7fb),
              borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, height: 1.5)),
            const SizedBox(height: 4),
            Text(
                complete
                    ? '${NumberFormat('#,##0', 'en').format((amount ~/ BigInt.from(1000)).toInt())} د.ع'
                    : '—',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xff00306b)))
          ]));
  Future<void> _choose() async {
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: _baghdadToday,
        initialDateRange: DateTimeRange(start: _from, end: _through),
        helpText: 'فترة الحركات · توقيت بغداد');
    if (range != null && mounted) {
      if (range.end.difference(range.start).inDays > 365) {
        setState(() => _error =
            'اختر فترة لا تتجاوز سنة؛ يمكنك مراجعة السنوات على فترات.');
        return;
      }
      setState(() {
        _from = range.start;
        _through = range.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = _rows.values.where((r) => r['evidenceVerified'] == true),
        orders = verified.where((r) =>
            ['ORDER_ACCRUAL', 'EXCEPTION_COMPENSATION'].contains(r['kind'])),
        paidFlows = verified.where((r) => r['kind'] == 'PAYOUT');
    final complete = _cursor == null &&
        !_rows.values.any((r) => r['evidenceVerified'] != true);
    final visible =
        _rows.values.where((r) => _state == 'ALL' || r['state'] == _state);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('حساب المطعم ومستحقاته',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const Text('مستحقاتك من الطلبات والتعويضات، ومتابعة ما تم صرفه.'),
      const SizedBox(height: 16),
      if (_wallet != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xff00306b),
              borderRadius: BorderRadius.circular(22)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إجمالي المستحقات غير المصروفة · كل الفترات',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),
            Text(
                '${NumberFormat('#,##0', 'en').format(_wallet!['pendingIqd'])} د.ع',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'يشمل المبالغ قيد الصرف. راجع طلبات الصرف لمتابعة الاستلام.',
                style: TextStyle(
                    color: Color(0xffdbe5f5), fontSize: 12, height: 1.5)),
          ]),
        ),
      const SizedBox(height: 18),
      const Text('ملخص المستحقات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 4, children: [
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xffe2e8f2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.date_range_outlined, size: 19),
                onPressed: _busy ? null : _choose,
                label: Text('${_date(_from)} إلى ${_date(_through)}'))),
        TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _through = _baghdadToday;
                      _from = _through;
                    });
                    _load();
                  },
            child: const Text('اليوم')),
        TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _through = _baghdadToday;
                      _from = _through.subtract(const Duration(days: 6));
                    });
                    _load();
                  },
            child: const Text('آخر ٧ أيام')),
        TextButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _through = _baghdadToday;
                      _from = DateTime(_through.year, _through.month, 1);
                    });
                    _load();
                  },
            child: const Text('هذا الشهر')),
        IconButton(
            onPressed: _busy ? null : () => _load(preserveDisplay: true),
            tooltip: 'تحديث الحساب',
            icon: const Icon(Icons.refresh))
      ]),
      const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('التواريخ بتوقيت بغداد',
              style: TextStyle(fontSize: 12, color: Color(0xff69788f)))),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Text(_error!, style: const TextStyle(color: Colors.red)),
      if (_loaded) ...[
        if (_rows.values.any((r) => r['evidenceVerified'] != true))
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  'لم يكتمل تدقيق مستحقات هذه الفترة. تظهر الإجماليات بعد اكتمال المراجعة، ولا يعني ذلك أن مستحقاتك صفر.')),
        if (_cursor != null)
          const Text(
              'المجاميع للقيود المحمّلة فقط؛ حمّل الباقي لاكتمال الفترة.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _metric('صافي مستحقات الطلبات', _total('merchantNet', orders),
              complete: complete),
          _metric('غير مصروف من هذه الطلبات',
              _total('merchantNet', orders.where((r) => r['state'] != 'PAID')),
              complete: complete),
          _metric(
              'منها قيد الصرف',
              _total('merchantNet',
                  orders.where((r) => r['state'] == 'IN_PAYOUT')),
              complete: complete),
          _metric(
              'صُرف فعليًا خلال الفترة',
              paidFlows.fold(
                  BigInt.zero,
                  (a, r) =>
                      a +
                      BigInt.from((r['amount']['minorAmount'] as num).toInt())),
              complete: complete)
        ]),
        if (complete)
          ExpansionTile(
              key: const PageStorageKey('account-breakdown'),
              title: const Text('تفصيل المنتجات والخصومات والتعويضات'),
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _metric('قيمة المنتجات', _total('goodsGross', orders)),
                  _metric('خصومات على المطعم',
                      _total('merchantFundedDiscount', orders)),
                  _metric('خصومات تمولها المنصة',
                      _total('platformFundedDiscount', orders)),
                  _metric('عمولات على المطعم',
                      _total('merchantCommission', orders)),
                  _metric('رسوم أخرى على المطعم',
                      _total('merchantOtherCharges', orders)),
                  _metric('دعم توصيل على المطعم',
                      _total('merchantDeliverySupport', orders)),
                  _metric('تعويضات طلبات مرتجعة أو متعذرة',
                      _total('merchantExceptionCompensation', orders)),
                ])
              ]),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
                'المبالغ المصروفة خلال الفترة قد تخص طلبات أقدم. صافي المستحق يحتسب الخصومات والعمولة بالفعل.')),
        DropdownButton<String>(
            isExpanded: true,
            value: _state,
            items: [
              for (final e in _states.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value))
            ],
            onChanged: (v) => setState(() {
                  _state = v!;
                  _visibleLimit = 20;
                })),
        if (visible.isEmpty)
          const Text('لا توجد حركات مطابقة في النتائج المحمّلة.'),
        for (final r in visible.take(_visibleLimit))
          Card(
              key: ValueKey(r['entryId']),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xffe2e8f2))),
              child: ExpansionTile(
                  key: PageStorageKey('account-entry-${r['entryId']}'),
                  title: Text(r['kind'] == 'EXCEPTION_COMPENSATION'
                      ? 'تعويض طلب ${r['orderNumber']}'
                      : r['kind'] == 'ORDER_ACCRUAL'
                          ? 'طلب ${r['orderNumber']}'
                          : r['kind'] == 'PAYOUT'
                              ? 'صرف مستحقات'
                              : r['kind'] == 'EXCEPTION_FUNDING'
                                  ? 'تمويل أجرة بقرار موثق'
                                  : 'مستحقات بانتظار التدقيق'),
                  subtitle: Text(
                      '${r['settlementMode'] == 'OFFSET_ONLY' ? 'تمت التسوية بالمقاصة دون نقد' : (_states[r['state']] ?? r['state'])} · ${_at(r['occurredAt'])}'),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (['ORDER_ACCRUAL', 'EXCEPTION_COMPENSATION']
                                  .contains(r['kind']))
                                for (final a in (r['amounts'] as Map).entries)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(children: [
                                        Expanded(
                                            child: Text(
                                                _labels[a.key]?.toString() ??
                                                    'تفصيل المستحق')),
                                        Text(_money(a.value))
                                      ])),
                              if (r['kind'] == 'EXCEPTION_FUNDING')
                                Text(
                                    'المخصوم من المتاح: ${-(r['amountIqd'] as num)} د.ع'),
                              if (r['kind'] == 'PAYOUT') ...[
                                if (r['correctionSettlement'] is Map)
                                  Text(
                                      'مستحق الكشف: ${_money(r['settledLiabilityAmount'])}\nمستحق تصحيح إضافي: ${r['correctionSettlement']['creditIqd']} د.ع\nخصم مديونية: ${r['correctionSettlement']['debtIqd']} د.ع'),
                                Text(
                                    'المبلغ المدفوع للمطعم: ${_money(r['amount'])}'),
                                Text(
                                    'الوسيلة: ${r['method'] == 'CASH' ? 'نقدًا' : 'زين كاش'}'),
                                Text('مرجع التنفيذ: ${r['externalReference']}'),
                                Text(
                                    'رسوم الحوالة على المنصة: ${r['executionFeeIqd']} د.ع — لم تُخصم من مستحقك')
                              ],
                              if (r['evidenceVerified'] != true)
                                const Text(
                                    'تراجع الإدارة مستندات هذه الحركة. ستظهر تفاصيلها ومبلغها بعد اكتمال التدقيق.'),
                            ]))
                  ])),
        if (visible.length > _visibleLimit)
          OutlinedButton(
              onPressed: () => setState(() => _visibleLimit += 20),
              child: const Text('عرض ٢٠ حركة إضافية')),
        if (_cursor != null)
          TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('تحميل بقية الحركات')),
      ],
      ExpansionTile(
          key: const PageStorageKey('account-help'),
          title: const Text('كيف تُحسب المستحقات؟'),
          children: [
            const Text(
                'تُسجّل مستحقات الطلبات بعد التسليم. وقد يشمل الصرف في الفترة المحددة مستحقات طلبات أقدم.'),
            const Text(
                'الرصيد غير المصروف يخص جميع الفترات، أما ملخص الفترة فيخص التواريخ المختارة فقط.'),
            const Text(
                'الخصم الذي تموله المنصة لا يُخصم من حق المطعم. رسوم الخدمة والتوصيل والإكرامية ليست دخلًا للمطعم.'),
          ]),
      const SizedBox(height: 12),
    ]);
  }
}
