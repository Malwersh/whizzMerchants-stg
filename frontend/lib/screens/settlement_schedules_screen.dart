import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../services/person_onboarding_service.dart';

class SettlementSchedulesScreen extends StatefulWidget {
  final String businessId;
  final PersonOnboardingService? service;
  const SettlementSchedulesScreen(
      {super.key, required this.businessId, this.service});
  @override
  State<SettlementSchedulesScreen> createState() => _SettlementSchedulesState();
}

class _SettlementSchedulesState extends State<SettlementSchedulesScreen> {
  late final _api = widget.service ?? PersonOnboardingService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SettlementSchedulesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) _load();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await _api.call(
          'settlement-schedules?branchId=${Uri.encodeComponent(widget.businessId)}');
      if (mounted && epoch == _epoch) setState(() => _data = data);
    } catch (e) {
      if (mounted && epoch == _epoch) setState(() => _error = e.toString());
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'غير محدد'
        : DateFormat('yyyy/MM/dd')
            .format(parsed.toUtc().add(const Duration(hours: 3)));
  }

  String _frequency(dynamic value) =>
      const {
        'WEEKLY': 'أسبوعيًا',
        'FORTNIGHTLY': 'كل أسبوعين',
        'MONTHLY': 'شهريًا'
      }[value] ??
      'غير محدد';
  Future<void> _consent(Map<String, dynamic> proposal) async {
    if (_busy) return;
    final branchId = widget.businessId;
    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('مراجعة جدول التسوية',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Text(
                          '${_frequency(proposal['schedule']?['frequency'])}، ابتداءً من ${_date(proposal['effectiveFrom'])} بتوقيت بغداد.'),
                      const SizedBox(height: 12),
                      const Text(
                          'أوافق على فترة تجميع مستحقات المتجر. بعد موافقتي يحتاج الجدول إلى اعتماد المنصة. هذه الموافقة لا تعني صرف المستحقات.'),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('أوافق على هذا الجدول')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('رجوع')),
                    ]))));
    if (confirmed != true ||
        !mounted ||
        branchId != widget.businessId ||
        _busy) {
      return;
    }
    final epoch = ++_epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.call('settlement-schedules', body: {
        'action': 'CONSENT',
        'branchId': branchId,
        'proposalId': proposal['proposalId'],
        'proposalDigest': proposal['proposalDigest']
      });
      if (mounted && epoch == _epoch) await _load();
    } catch (e) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  Widget _card(Map<String, dynamic> row, {bool current = false}) {
    final pending = row['status'] == 'AWAITING_OWNER';
    final title = current
        ? 'الجدول المعتمد'
        : pending
            ? 'طلب موافقتك على جدول التسوية'
            : row['status'] == 'AWAITING_APPROVAL'
                ? 'بانتظار اعتماد المنصة'
                : 'اقتراح معتمد';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                      '${_frequency(row['schedule']?['frequency'])} · النسخة ${row['schedule']?['version']}'),
                  Text('من ${_date(row['effectiveFrom'])} بتوقيت بغداد'),
                  if (row['effectiveTo'] != null)
                    Text('حتى ${_date(row['effectiveTo'])}'),
                  if (pending)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton(
                            onPressed: _busy ? null : () => _consent(row),
                            child: const Text('مراجعة الجدول والموافقة'))),
                ])));
  }

  @override
  Widget build(BuildContext context) {
    final proposals = (_data?['proposals'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r));
    final current = _data?['current'];
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('جدول تسوية المستحقات'), actions: [
            IconButton(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث')
          ]),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const Text(
                'يحدد الجدول فترة تجميع مستحقات متجرك لإعداد الكشف المالي. صرف المستحقات إجراء منفصل.'),
            const SizedBox(height: 16),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Semantics(
                  liveRegion: true,
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            if (current is Map)
              _card(Map<String, dynamic>.from(current), current: true),
            if (_data != null && current == null)
              const Text('لا يوجد جدول معتمد حتى الآن.'),
            ...proposals.map((p) => _card(p)),
          ]),
        ));
  }
}
