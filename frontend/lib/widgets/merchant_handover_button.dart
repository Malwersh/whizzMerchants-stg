import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../services/order_returns_service.dart';

class MerchantHandoverButton extends StatefulWidget {
  final Order order;
  final VoidCallback? onRecorded;
  const MerchantHandoverButton(
      {super.key, required this.order, this.onRecorded});
  @override
  State<MerchantHandoverButton> createState() => _MerchantHandoverButtonState();
}

class _MerchantHandoverButtonState extends State<MerchantHandoverButton> {
  final _requestId = const Uuid().v4();
  bool _busy = false, _recorded = false;
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final recorded =
        _recorded || order.merchantHandover?['state'] == 'HANDED_TO_DRIVER';
    if (recorded)
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('✓ أكّد المطعم تسليم الطلب للسائق',
              style: TextStyle(
                  color: Color(0xFF155724), fontWeight: FontWeight.w700)));
    if (order.financialAssignment == null ||
        order.driverId == null ||
        order.pickedUpAt != null ||
        ![
          OrderStatus.readyForPickup,
          OrderStatus.assigned,
          OrderStatus.headingToStore,
          OrderStatus.arrivedAtStore
        ].contains(order.status)) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00296B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14)),
              onPressed: _busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                                  title: const Text('تأكيد التسليم للسائق'),
                                  content: Text(
                                      'هل سلّمت الأصناف فعليًا إلى ${order.driverName ?? 'السائق المسند'}؟ سيُسجل خروج الطلب من عهدة المطعم.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('رجوع')),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('نعم، سلّمته للسائق'))
                                  ]));
                      if (confirmed != true || !mounted) return;
                      setState(() => _busy = true);
                      try {
                        await OrderReturnsService().call(
                            {
                              'businessId': order.businessId,
                              'orderId': order.id
                            },
                            cancel: true,
                            receipt: {
                              'handover': true,
                              'offerId': order.financialAssignment!['offerId'],
                              'attempt': order.financialAssignment!['attempt'],
                              'idempotencyKey': _requestId
                            });
                        if (!mounted) return;
                        setState(() => _recorded = true);
                        widget.onRecorded?.call();
                      } catch (_) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'لم يتأكد تسجيل التسليم. حدّث الطلب أو أعد المحاولة.')));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.handshake_outlined),
              label:
                  Text(_busy ? 'جارٍ تسجيل التسليم…' : 'تم تسليم الطلب للسائق'),
            )));
  }
}
