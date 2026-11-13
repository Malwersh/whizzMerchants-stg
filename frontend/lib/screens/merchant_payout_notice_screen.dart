import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../services/person_onboarding_service.dart';
import '../widgets/merchant_financial_gate.dart';
import 'merchant_payouts_screen.dart';

class MerchantPayoutNoticeScreen extends StatelessWidget {
  final String businessId, payoutId;
  final PersonOnboardingService? service;
  const MerchantPayoutNoticeScreen(
      {super.key,
      required this.businessId,
      required this.payoutId,
      this.service});
  @override
  Widget build(BuildContext context) => MerchantFinancialGate(
      branchId: businessId,
      child: _Details(
          key: ValueKey("$businessId/$payoutId"),
          businessId: businessId,
          payoutId: payoutId,
          service: service));
}

class _Details extends StatefulWidget {
  final String businessId, payoutId;
  final PersonOnboardingService? service;
  const _Details(
      {super.key,
      required this.businessId,
      required this.payoutId,
      this.service});
  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  late final Future<
      Map<String,
          dynamic>> _result = (widget.service ?? PersonOnboardingService()).call(
      'settlement-schedules?view=payout&branchId=${Uri.encodeComponent(widget.businessId)}&payoutId=${Uri.encodeComponent(widget.payoutId)}');
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: const Text('تحديث عملية الصرف')),
          body: FutureBuilder<Map<String, dynamic>>(
              future: _result,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) {
                  return const Center(
                      child: Text(
                          'تعذر فتح العملية. تحقق من صلاحيتك ثم أعد فتح التنبيه.'));
                }
                // The reference is a hint only. Never display the push's amount or status.
                final result = s.data!, raw = result['payout'] ?? result;
                if (raw is! Map ||
                    raw['payoutId'] != widget.payoutId ||
                    raw['branchId'] != widget.businessId) {
                  return const Center(
                      child: Text('هذه العملية غير متاحة لهذا الفرع.'));
                }
                final status = const {
                      'AWAITING_RECEIPT': 'بانتظار تأكيد الاستلام',
                      'PAID': 'تمت المطابقة والصرف',
                      'RECONCILIATION_REQUIRED': 'قيد المراجعة والمطابقة',
                      'CANCELLED': 'أُلغيت عملية الصرف',
                      'FAILED_NOT_PAID': 'لم يُنفذ الصرف',
                      'RECEIPT_CONFIRMED': 'تم تأكيد الاستلام'
                    }[raw['status']] ??
                    'راجع حالة العملية في مستحقاتك';
                return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 40),
                          const SizedBox(height: 20),
                          Text(status,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          const Text(
                              'فتح التنبيه لا يؤكد الاستلام ولا يغيّر حالة الصرف.'),
                          const SizedBox(height: 12),
                          if (raw['amount'] is Map &&
                              raw['amount']['currency'] == 'IQD' &&
                              raw['amount']['scale'] == 1000 &&
                              raw['amount']['moneySchemaVersion'] == 1 &&
                              raw['amount']['minorAmount'] is int &&
                              raw['amount']['minorAmount'] >= 0 &&
                              raw['amount']['minorAmount'] <=
                                  9007199254740991 &&
                              raw['amount']['minorAmount'] % 1000 == 0)
                            Text(
                                '${NumberFormat('#,##0', 'en').format(raw['amount']['minorAmount'] ~/ 1000)} د.ع',
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff00306b))),
                          const SizedBox(height: 24),
                          FilledButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => MerchantPayoutsScreen(
                                          businessId: widget.businessId))),
                              child:
                                  const Text('مراجعة المستحقات وطلبات الصرف'))
                        ]));
              })));
}
