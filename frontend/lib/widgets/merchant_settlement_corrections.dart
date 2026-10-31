import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/person_onboarding_service.dart';

/// Owner correction view and explicit payout request. Staff task sessions do not inherit owner access.
class MerchantSettlementCorrections extends StatefulWidget {
  final String businessId;
  final PersonOnboardingService service;
  final VoidCallback? onPayoutRequested;
  const MerchantSettlementCorrections(
      {super.key,
      required this.businessId,
      required this.service,
      this.onPayoutRequested});
  @override
  State<MerchantSettlementCorrections> createState() => _CorrectionsState();
}

class _CorrectionsState extends State<MerchantSettlementCorrections> {
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _position;
  bool _busy = false;
  String? _error, _cursor;
  int _epoch = 0;
  String? _requestId;
  @override
  void didUpdateWidget(covariant MerchantSettlementCorrections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId ||
        oldWidget.service != widget.service) {
      _epoch++;
      _requestId = null;
      _items.clear();
      _position = null;
      _cursor = null;
      _error = null;
      _busy = false;
    }
  }

  Future<void> _load({bool next = false}) async {
    if (_busy) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final query = Uri(queryParameters: {
        'view': 'settlement-corrections',
        'branchId': widget.businessId,
        if (next && _cursor != null) 'cursor': _cursor!
      }).query;
      final data = await widget.service.call('settlement-schedules?$query');
      if (!mounted || epoch != _epoch) return;
      final position = Map<String, dynamic>.from(data['position'] as Map);
      for (final k in ['creditIqd', 'debtIqd']) {
        if (position[k] is! int || position[k] < 0) {
          throw const FormatException();
        }
      }
      final rows = (data['items'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      setState(() {
        if (!next) _items.clear();
        for (final row in rows) {
          _items
              .removeWhere((old) => old['correctionId'] == row['correctionId']);
          _items.add(row);
        }
        _position = position;
        _cursor = data['nextCursor'] as String?;
      });
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = 'تعذر التحقق من التصحيحات. أعد المحاولة.';
          _position = null;
        });
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _requestPayout() async {
    if (_busy || _position == null) return;
    final epoch = _epoch;
    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('طلب صرف مستحق التصحيح',
                      style: TextStyle(fontSize: 20, color: Color(0xFF00296B))),
                  const SizedBox(height: 12),
                  const Text(
                      'تراجع الإدارة الطلب ثم تسلّم النقد من الصندوق وتؤكد استلامه. تُخصم المديونية المعتمدة وفق السياسة؛ وقد تُسوّى بالمقاصة دون نقد.'),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('إرسال طلب الصرف')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('تراجع')),
                ]))));
    if (!mounted || epoch != _epoch || confirmed != true) return;
    _requestId ??= const Uuid().v4();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.call('settlement-schedules', body: {
        'action': 'REQUEST_CORRECTION_PAYOUT',
        'branchId': widget.businessId,
        'requestId': _requestId,
      });
      if (!mounted || epoch != _epoch) return;
      _requestId = null;
      _position = null;
      widget.onPayoutRequested?.call();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('أُرسل طلب الصرف للمراجعة. تابعه في طلبات الصرف.')));
    } catch (e) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 16),
        child: ExpansionTile(
          title: const Text('تصحيحات التسويات',
              style: TextStyle(color: Color(0xFF00296B))),
          leading: const Icon(Icons.manage_history, color: Color(0xFF00296B)),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            const Text(
                'التصحيح مستقل عن الكشف المدفوع. القيد المعتمد لا يعني أنه صُرف أو حُصّل.'),
            TextButton.icon(
                onPressed: _busy ? null : () => _load(),
                icon: const Icon(Icons.refresh),
                label: const Text('عرض / تحديث التصحيحات')),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFF9B1C1C))),
            if (_position != null) ...[
              ListTile(
                  title: const Text('مستحق تصحيح غير مصروف'),
                  trailing: Text('${_position!['creditIqd']} د.ع')),
              ListTile(
                  title: const Text('مديونية لم تُحصّل'),
                  trailing: Text('${_position!['debtIqd']} د.ع')),
              if ((_position!['creditIqd'] as int) > 0) ...[
                FilledButton.icon(
                    onPressed: _busy ||
                            (_position!['creditReservedIqd'] ?? 0) > 0 ||
                            (_position!['debtReservedIqd'] ?? 0) > 0
                        ? null
                        : _requestPayout,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('طلب صرف المستحق الإضافي')),
                if ((_position!['creditReservedIqd'] ?? 0) > 0 ||
                    (_position!['debtReservedIqd'] ?? 0) > 0)
                  const Text(
                      'يوجد طلب تسوية جارٍ يحجز التصحيحات؛ أكمله أو ألغِه أولًا.'),
              ],
              if (_items.isEmpty) const Text('لا توجد تصحيحات مسجلة.'),
              for (final r in _items)
                ListTile(
                  isThreeLine: true,
                  title: Text(
                      '${r['direction'] == 'CREDIT' ? 'مستحق إضافي' : 'مديونية'} · ${r['amountIqd']} د.ع'),
                  subtitle: Text('${{
                        'PENDING_APPROVAL': 'بانتظار مراجعة الإدارة',
                        'POSTED': 'قيد تصحيح معتمد',
                        'REJECTED': 'مرفوض'
                      }[r['status']] ?? 'بحاجة إلى مراجعة'}\n${r['settlementProgress'] == 'SETTLED' ? 'سُوّي بالكامل' : r['settlementProgress'] == 'PARTIALLY_SETTLED' ? 'سُوّي جزئيًا' : ''}\nتمت تسويته: ${r['settledIqd'] ?? 0} د.ع · المتبقي: ${r['remainingIqd'] ?? r['amountIqd']} د.ع\nالطلب: ${r['orderId']}\nالسبب: ${r['reason']}${r['decisionReason'] == null ? '' : '\nقرار الإدارة: ${r['decisionReason']}'}'),
                ),
              if (_cursor != null)
                TextButton(
                    onPressed: _busy ? null : () => _load(next: true),
                    child: const Text('تحميل المزيد')),
            ]
          ],
        ),
      );
}
