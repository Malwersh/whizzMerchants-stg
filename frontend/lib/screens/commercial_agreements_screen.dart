import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../services/person_onboarding_service.dart';

class CommercialAgreementsScreen extends StatefulWidget {
  final String businessId;
  final String? businessName;
  final Map<String, String> branchNames;
  final PersonOnboardingService? service;
  const CommercialAgreementsScreen(
      {super.key,
      required this.businessId,
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
      'action': 'ACCEPT_AGREEMENT',
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
        _section('تمويل الخصومات', Icons.local_offer_outlined, [
          if (policies.isEmpty)
            const Text('لا تتضمن هذه الاتفاقية مشاركة في تمويل خصومات.',
                style: TextStyle(fontSize: 14, height: 1.6)),
          for (var i = 0; i < policies.length; i++) ...[
            _line('الخصم ${i + 1}',
                'حصتك من تمويل الخصم: ${_number(policies[i]['merchantNumerator'] / policies[i]['denominator'] * 100)}%؛ والمنصة تتحمل الباقي.'),
            _line('الفترة',
                '${_date(policies[i]['effectiveFrom'])} إلى ${_date(policies[i]['effectiveTo'])}'),
            const Text('تُقرب حصتك للأسفل والباقي على المنصة.',
                style: TextStyle(fontSize: 13)),
          ],
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
                      ? 'راجع النسخة والفروع والعمولة وتمويل الخصومات قبل الموافقة. تُثبّت النسخة بعد موافقتك واستكمال التحقق.'
                      : 'راجع النسخة والفروع والعمولة وتمويل الخصومات قبل الموافقة. تبقى الشروط المعتمدة السابقة سارية حتى اعتماد المنصة للنسخة الجديدة.',
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
              for (final item in _items)
                _card(Map<String, dynamic>.from(item as Map)),
            ])),
      );
  Widget _card(Map<String, dynamic> item) {
    final draft = Map<String, dynamic>.from(item['draft'] as Map);
    final current = item['current'];
    final accepted = item['ownerAccepted'] == true;
    final published = draft['publishedVersion'] != null;
    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xffdce3ee))),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الشروط التجارية — النسخة ${draft['version']}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
                          ? (_direct
                              ? 'سُجلت موافقتك؛ تفعيل النسخة غير مكتمل. حدّث الحالة أو راجع الإدارة.'
                              : 'وافقت على هذه النسخة؛ تنتظر اعتماد المنصة.')
                          : 'بانتظار مراجعتك وموافقتك',
                  style: const TextStyle(fontSize: 14, height: 1.6)),
              _terms(
                  Map<String, dynamic>.from(draft['values'] as Map),
                  List<dynamic>.from(draft['businessIds']),
                  List<dynamic>.from(draft['fundingPolicies'] ?? [])),
              _section('مرجع الدعم', Icons.confirmation_number_outlined, [
                if (item['supportReference'] is String) ...[
                  Row(children: [
                    Expanded(child: SelectableText(item['supportReference'], textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1))),
                    IconButton(tooltip: 'نسخ مرجع الدعم', icon: const Icon(Icons.copy_outlined), onPressed: () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: '${item['supportReference']} / V${draft['version']}'));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ مرجع الدعم ورقم النسخة.')));
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر النسخ. يمكنك تحديد المرجع ونسخه يدويًا.')));
                      }
                    }),
                  ]),
                  Text('النسخة ${draft['version']} — اذكر المرجع والنسخة عند التواصل مع الدعم.', style: const TextStyle(fontSize: 13, height: 1.6)),
                ] else const Text('مرجع الدعم غير متاح؛ أعد تحديث الاتفاقية.', style: TextStyle(fontSize: 14)),
              ]),
              if (!published && !accepted) ...[
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
                        onPressed: _busy || !_confirmed.contains(draft['hash'])
                            ? null
                            : () => _accept(draft),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('تأكيد الموافقة على النسخة',
                            style: TextStyle(fontSize: 15)))),
              ],
            ])));
  }
}
