import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../services/person_onboarding_service.dart';

class CommercialAgreementsScreen extends StatefulWidget {
  final String businessId;
  final String? focusSharingId;
  final String? focusRequestKind;
  final String? businessName;
  final Map<String, String> branchNames;
  final PersonOnboardingService? service;
  const CommercialAgreementsScreen(
      {super.key,
      required this.businessId,
      this.focusSharingId,
      this.focusRequestKind,
      this.businessName,
      this.branchNames = const {},
      this.service});
  @override
  State<CommercialAgreementsScreen> createState() => _AgreementsState();
}

class _AgreementsState extends State<CommercialAgreementsScreen> {
  late final _api = widget.service ?? PersonOnboardingService();
  List<dynamic> _items = [];
  final Set<String> _confirmed = {};
  final Map<String, String> _attempts = {};
  bool _busy = false;
  bool _direct = false;
  String? _error;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CommercialAgreementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _confirmed.clear();
      _attempts.clear();
      _load();
    }
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      _items = [];
      _direct = false;
      _confirmed.clear();
    });
    try {
      final data = await _api.call(
          'commercial-agreements?businessId=${Uri.encodeComponent(widget.businessId)}');
      if (mounted && epoch == _epoch)
        setState(() {
          _items = data['items'] as List<dynamic>? ?? [];
          _direct = data['can']?['direct'] == true;
        });
    } catch (e) {
      if (mounted && epoch == _epoch) setState(() => _error = e.toString());
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> draft) async {
    if (_busy || !_confirmed.contains(draft['hash'])) return;
    final epoch = _epoch, businessId = widget.businessId;
    final body = <String, dynamic>{
      'businessId': businessId,
      'action':
          draft['kind'] == 'DELIVERY' ? 'ACCEPT_DELIVERY' : draft['kind'] == 'FUNDING' ? 'ACCEPT_FUNDING' : 'ACCEPT_AGREEMENT',
      'id': draft['id'],
      'draftVersion': draft['version'],
      'baseVersion': draft['baseVersion'],
      'hash': draft['hash']
    };
    final signature = jsonEncode(body);
    body['requestId'] =
        _attempts.putIfAbsent(signature, () => const Uuid().v4());
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.call('commercial-agreements', body: body);
      if (!mounted || epoch != _epoch || businessId != widget.businessId)
        return;
      _attempts.remove(signature);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['publishedVersion'] != null
              ? 'سُجلت موافقتك وثُبتت النسخة الجديدة.'
              : _direct
                  ? 'سُجلت موافقتك. جارٍ تحديث حالة الاتفاقية.'
                  : 'سُجلت موافقتك على هذه النسخة. تنتظر اعتماد المنصة.')));
      await _load();
    } catch (e) {
      if (mounted && epoch == _epoch)
        setState(() {
          _error = e.toString();
          _busy = false;
        });
    }
  }

  String _number(num value) => NumberFormat('#,##0.###', 'en').format(value);
  String _charge(dynamic value) {
    final c = Map<String, dynamic>.from(value as Map);
    if (c['kind'] == 'NONE') return 'دون رسوم';
    if (c['kind'] == 'FIXED')
      return '${_number(c['fixed']['minorAmount'] / 1000)} دينار';
    const bases = {
      'GOODS_GROSS': 'قيمة السلع قبل الخصومات',
      'AFTER_MERCHANT_DISCOUNT': 'قيمة السلع بعد خصم التاجر',
      'CUSTOMER_GOODS_PAYMENT': 'ما يدفعه العميل للسلع'
    };
    return '${_number(c['rate']['numerator'] / c['rate']['denominator'] * 100)}% من ${bases[c['basis']]}';
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toUtc();
    if (date == null) return 'غير محدد';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} • ${two(date.hour)}:${two(date.minute)} (UTC)';
  }

  String _branch(dynamic id) =>
      widget.branchNames[id] ??
      (id == widget.businessId
          ? widget.businessName ?? 'الفرع المحدد'
          : 'فرع إضافي — الاسم غير متاح');
  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xfff5f7fb),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)))
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
  Widget _line(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 13, color: Color(0xff596579))),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 16, height: 1.5, fontWeight: FontWeight.w600))
      ]));
  Widget _terms(Map<String, dynamic> values, List<dynamic> branches,
          List<dynamic> policies) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('العمولة ورسوم الخدمة', Icons.payments_outlined, [
          _line('عمولة المنصة على مبيعاتك', _charge(values['commission'])),
          const Divider(height: 20),
          _line('رسم الخدمة على طلب الزبون', _charge(values['serviceFee'])),
          const SizedBox(height: 8),
          const Text(
              'رسوم التوصيل والإكرامية ورسم الخدمة لا تدخل في المبلغ الذي تُحسب منه عمولة السلع.',
              style: TextStyle(fontSize: 13, height: 1.6)),
        ]),
        _section('الفروع المشمولة', Icons.storefront_outlined,
            [for (final id in branches) _line('الفرع', _branch(id))]),
        _section('مدة الاتفاقية', Icons.event_outlined, [
          _line('بداية السريان', _date(values['effectiveFrom'])),
          _line(
              'نهاية السريان',
              values['effectiveTo'] == null
                  ? 'دون تاريخ انتهاء محدد'
                  : _date(values['effectiveTo'])),
          const Text('الأوقات معروضة بالتوقيت العالمي UTC.',
              style: TextStyle(fontSize: 12)),
        ]),
        if (policies.isNotEmpty)
          _section('إفصاح تاريخي عن مشاركة الخصومات', Icons.history, [
            for (final policy in policies)
              _line('حصة المتجر في النسخة التاريخية',
                  '${_number(policy['merchantNumerator'] / policy['denominator'] * 100)}%'),
            const Text(
                'طلبات المشاركة الجديدة مستقلة عن اتفاقية العمولة والخدمة.'),
          ]),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('تفاصيل تقريب المبالغ',
                style: TextStyle(fontSize: 14)),
            children: [
              _line(
                  'العمولة', _rounding(values['commission']['finalRounding'])),
              _line('رسم الخدمة',
                  _rounding(values['serviceFee']['finalRounding'])),
            ]),
      ]);
  Widget _sharingTerms(Map<String, dynamic> values, String? name) =>
      _section('شروط المشاركة', Icons.local_offer_outlined, [
        _line(
            'الخصم', name ?? 'اسم الخصم غير متاح؛ أعد التحميل أو راجع المنصة'),
        _line('الفرع', _branch(widget.businessId)),
        _line('حصتك من مبلغ الخصم',
            '${_number(values['merchantNumerator'] / values['denominator'] * 100)}%'),
        _line('حصة المنصة',
            '${_number((1 - values['merchantNumerator'] / values['denominator']) * 100)}%'),
        _line('مدة الخصم والمشاركة',
            '${_date(values['effectiveFrom'])} إلى ${_date(values['effectiveTo'])}'),
        const Text(
            'هذه مشاركة في مبلغ الخصم وليست عمولة مبيعات. لا تسري قبل موافقتك. عند تغيير شروط الخصم تحتاج المشاركة إلى موافقة جديدة؛ وحتى ذلك يتحمل صاحب الخصم تكلفته كاملة.',
            style: TextStyle(fontSize: 13, height: 1.6)),
      ]);
  String _rounding(dynamic r) => r == null
      ? 'غير محدد'
      : 'كل ${r['incrementIqd']} دينار؛ ${{
            'HALF_AWAY_FROM_ZERO': 'الأقرب والنصف للأعلى',
            'TOWARD_ZERO': 'حذف الكسر',
            'EXACT': 'دقة تامة دون تقريب'
          }[r['mode']] ?? r['mode']}';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('الاتفاقية التجارية',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh))
            ]),
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(widget.businessName ?? 'مراجعة الاتفاقية',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                  _direct
                      ? 'راجع الشروط قبل الموافقة. تُثبّت النسخة بعد موافقتك واستكمال التحقق.'
                      : 'راجع شروط كل طلب قبل الموافقة. عرض التوصيل يتفعّل بموافقتك وفق تاريخ بدايته؛ وتظهر حالة كل اتفاقية أدناه.',
                  style: const TextStyle(fontSize: 14, height: 1.7)),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!, key: const Key('commercial-error')),
                TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('إعادة التحميل'))
              ],
              if (!_busy && _error == null && _items.isEmpty)
                const Text('لا توجد اتفاقيات تجارية مقدمة لهذا الفرع.'),
              for (final item in _items.where((x) =>
                  widget.focusSharingId == null ||
                  (x['draft']['id'] == widget.focusSharingId && (widget.focusRequestKind == null || x['draft']['kind'] == widget.focusRequestKind))))
                _card(Map<String, dynamic>.from(item as Map)),
            ])),
      );
  bool _readableDeliveryTerms(dynamic values) {
    if (values is! Map) return false;
    final version = values['schemaVersion'];
    if (version == 2) return values['commission'] is Map && values['limits'] == null;
    return (version == null || version == 1) && values['limits'] is Map;
  }

  Widget _deliveryTerms(Map<String, dynamic> v) {
    if (!_readableDeliveryTerms(v)) {
      return _section('تعذر عرض شروط الاتفاقية', Icons.error_outline, [
        const Text('حدّث الصفحة للحصول على الشروط الكاملة قبل الموافقة. إذا استمرت المشكلة، راجع المنصة.'),
      ]);
    }
    String cash(dynamic x) => '${_number(x['minorAmount'] / 1000)} دينار';
    final c = v['customerRule'], f = v['funding'], e = v['eligibility'], l = v['limits'];
    final customer = switch (c['kind']) {
      'FREE' => 'التوصيل مجاني للزبون',
      'FIXED_TARIFF' => 'توصيل ثابت للزبون: ${cash(c['amount'])}',
      'CAPPED_PRICE' => 'يدفع الزبون حتى ${cash(c['amount'])} للتوصيل',
      'AMOUNT_OFF' => 'خصم ${cash(c['amount'])} من التوصيل',
      'PERCENT_OFF' => 'خصم ${_number(c['numerator'] / c['denominator'] * 100)}% حتى ${cash(c['maximumDiscount'])}',
      _ => 'التوصيل حسب التعرفة المعتادة',
    };
    if(v['schemaVersion']==2){
      final rate=v['commission']['rate'];
      final payer=f['kind']=='MERCHANT'?'المتجر يتحمل الفرق بالكامل':f['kind']=='PLATFORM'?'المنصة تتحمل الفرق بالكامل':'المتجر ${_number(f['merchantNumerator']/f['denominator']*100)}% والمنصة ${_number((f['denominator']-f['merchantNumerator'])/f['denominator']*100)}% من الفرق';
      return _section('اتفاقية أسعار وتوصيل', Icons.handshake_outlined, [
        Text(customer), Text(payer),
        Text('عمولة المنصة خلال الاتفاقية: ${_number(rate['numerator']/rate['denominator']*100)}% من قيمة الأصناف قبل الخصم.'),
        Text('الحد الأدنى للطلب: ${cash(e['minimumGoods'])} قبل خصم الأصناف.'),
        Text('تسري في ${e['regionIds'].length} منطقة، من ${_date(v['effectiveFrom'])} إلى ${_date(v['effectiveTo'])}.'),
        const Text('دون ميزانية حملة أو حد استخدام للزبون. يُحجز تمويل الفرق لكل طلب، وأجرة السائق مستقلة.'),
        const Text('تعود العمولة والحد الأدنى الأصليان والتوصيل المحسوب بعد انتهاء الاتفاقية. الطلبات المؤكدة تحتفظ بشروطها.'),
        const Text('موافقتك تفعّل هذه النسخة وفق مدتها دون اعتماد إضافي.'),
      ]);
    }
    final funding = switch (f['kind']) {
      'MERCHANT' => 'المتجر يتحمل دعم التوصيل بالكامل',
      'PLATFORM' => 'المنصة تتحمل دعم التوصيل بالكامل',
      'SHARED_RATIO' => 'المتجر ${_number(f['merchantNumerator'] / f['denominator'] * 100)}%، والمنصة ${_number((f['denominator'] - f['merchantNumerator']) / f['denominator'] * 100)}% من الدعم. سقف المتجر ${cash(f['merchantCap'])}، والمنصة ${cash(f['platformCap'])}',
      _ => '${f['contributor'] == 'MERCHANT' ? 'المتجر' : 'المنصة'} يساهم حتى ${cash(f['contribution'])}، والطرف الآخر يتحمل الباقي حتى ${cash(f['remainderCap'])}',
    };
    return _section('شروط عرض التوصيل', Icons.delivery_dining, [
      Text(customer), Text(funding),
      Text('أجرة السائق مستقلة عن رسوم التوصيل على الزبون.'),
      Text('دعم المتجر لكل طلب حتى ${cash(l['merchantPerOrder'])}؛ وميزانيته ${cash(l['merchantBudget'])}'),
      Text('دعم المنصة لكل طلب حتى ${cash(l['platformPerOrder'])}؛ وميزانيتها ${cash(l['platformBudget'])}'),
      Text('الحد الأدنى للطلب ${cash(e['minimumGoods'])} ${e['minimumGoodsBasis'] == 'GOODS_GROSS' ? 'قبل خصم الأصناف' : 'بعد خصم الأصناف'}'),
      Text('ضمن ${_number(e['maximumRoadMeters'] / 1000)} كم، في ${e['regionIds'].length} منطقة محددة بالعرض'),
      Text('${e['audience'] == 'NEW_CUSTOMER' ? 'للزبائن الجدد' : 'لجميع الزبائن'}؛ حتى ${l['perCustomerUses']} استخدام لكل زبون'),
      Text(e['goodsDiscountStacking'] == 'ALLOW' ? 'يمكن جمعه مع خصم الأصناف' : 'لا يجمع مع خصم الأصناف'),
      Text('من ${_date(v['effectiveFrom'])} إلى ${_date(v['effectiveTo'])}'),
      const Text('عند عدم تحقق الشروط أو تجاوز سقف الدعم، تطبق التعرفة المعتادة قبل تأكيد الطلب.'),
      const Text('موافقتك تفعّل هذه النسخة وفق مدتها دون اعتماد إضافي من موظف آخر.'),
    ]);
  }

  Widget _card(Map<String, dynamic> item) {
    final draft = Map<String, dynamic>.from(item['draft'] as Map);
    final current = item['current'];
    final delivery = draft['kind'] == 'DELIVERY';
    final sharing = draft['kind'] == 'FUNDING';
    final accepted = item['ownerAccepted'] == true;
    final published = draft['publishedVersion'] != null;
    return Card(
        key: ValueKey(
            'card-${widget.businessId}-${draft["id"]}-${draft["version"]}-${draft["hash"]}'),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xffdce3ee))),
        child: ExpansionTile(
            key: ValueKey(
                'request-${widget.businessId}-${draft['id']}-${draft['version']}-${draft['hash']}'),
            initiallyExpanded: (sharing || delivery) && widget.focusSharingId == draft['id'],
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
                delivery ? 'عرض توصيل' : sharing
                    ? (item['campaignLabel'] as String? ?? 'مشاركة تمويل خصم')
                    : 'الشروط التجارية',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${delivery ? 'عرض توصيل' : sharing ? 'مشاركة خصم' : 'اتفاقية تجارية'} • النسخة ${draft['version']}\n${published ? 'معتمدة' : accepted ? 'سُجلت موافقتك؛ جارٍ استكمال التفعيل' : 'بانتظار مراجعتك وموافقتك'}',
                style: const TextStyle(fontSize: 13, height: 1.6)),
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (current?['terms'] != null)
                  ExpansionTile(
                      title:
                          Text('الشروط المعتمدة — إصدار ${current['version']}'),
                      children: [
                        if (current['disclosure'] != null)
                          _terms(
                              Map<String, dynamic>.from(
                                  current['disclosure']['values'] as Map),
                              List<dynamic>.from(
                                  current['disclosure']['businessIds']),
                              List<dynamic>.from(
                                  current['disclosure']['fundingPolicies']))
                        else
                          const Text(
                              'تفاصيل الإفصاح التاريخية غير متاحة. راجع المنصة للحصول على النسخة الكاملة.'),
                      ]),
                Text(
                    published
                        ? 'تم اعتماد هذه النسخة.'
                        : accepted
                            ? ((delivery || _direct)
                                ? 'سُجلت موافقتك؛ تفعيل النسخة غير مكتمل. حدّث الحالة أو راجع الإدارة.'
                                : 'وافقت على هذه النسخة؛ تنتظر اعتماد المنصة.')
                            : 'بانتظار مراجعتك وموافقتك',
                    style: const TextStyle(fontSize: 14, height: 1.6)),
                if (delivery)
                  _deliveryTerms(Map<String, dynamic>.from(draft['values'] as Map))
                else if (sharing)
                  _sharingTerms(
                      Map<String, dynamic>.from(draft['values'] as Map),
                      item['campaignLabel'] as String?)
                else
                  _terms(
                      Map<String, dynamic>.from(draft['values'] as Map),
                      List<dynamic>.from(draft['businessIds']),
                      List<dynamic>.from(draft['fundingPolicies'] ?? [])),
                if (!sharing && !delivery)
                  _section('مرجع الدعم', Icons.confirmation_number_outlined, [
                    if (item['supportReference'] is String) ...[
                      Row(children: [
                        Expanded(
                            child: SelectableText(item['supportReference'],
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1))),
                        IconButton(
                            tooltip: 'نسخ مرجع الدعم',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () async {
                              try {
                                await Clipboard.setData(ClipboardData(
                                    text:
                                        '${item['supportReference']} / V${draft['version']}'));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'نُسخ مرجع الدعم ورقم النسخة.')));
                              } catch (_) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'تعذر النسخ. يمكنك تحديد المرجع ونسخه يدويًا.')));
                              }
                            }),
                      ]),
                      Text(
                          'النسخة ${draft['version']} — اذكر المرجع والنسخة عند التواصل مع الدعم.',
                          style: const TextStyle(fontSize: 13, height: 1.6)),
                    ] else
                      const Text('مرجع الدعم غير متاح؛ أعد تحديث الاتفاقية.',
                          style: TextStyle(fontSize: 14)),
                  ]),
                if (!published && !accepted && (!delivery || _readableDeliveryTerms(draft['values']))) ...[
                  const Divider(height: 28),
                  CheckboxListTile(
                      value: _confirmed.contains(draft['hash']),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _confirmed.add(draft['hash']);
                                } else {
                                  _confirmed.remove(draft['hash']);
                                }
                              }),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                          'قرأت شروط هذه النسخة ونطاقها وأوافق عليها',
                          style: TextStyle(fontSize: 14, height: 1.6))),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed:
                              _busy || !_confirmed.contains(draft['hash'])
                                  ? null
                                  : () => _accept(draft),
                          style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('تأكيد الموافقة على النسخة',
                              style: TextStyle(fontSize: 15)))),
                ],
              ])
            ]));
  }
}
