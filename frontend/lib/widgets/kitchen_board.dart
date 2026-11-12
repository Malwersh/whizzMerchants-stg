import 'package:flutter/material.dart';
import '../models/order.dart';

/// Kitchen stages deliberately stop at handover; delivery is not kitchen work.
int? kitchenStage(Order order) {
  if (order.merchantHandover?['state'] == 'HANDED_TO_DRIVER') return null;
  switch (order.status) {
    case OrderStatus.confirmed:
      return 0;
    case OrderStatus.preparing:
      return 1;
    case OrderStatus.ready:
    case OrderStatus.readyForPickup:
    case OrderStatus.reassigning:
    case OrderStatus.assigned:
    case OrderStatus.headingToStore:
    case OrderStatus.arrivedAtStore:
      return 2;
    default:
      return null;
  }
}

class KitchenBoard extends StatefulWidget {
  final List<Order> orders;
  final bool loading;
  final bool Function(OrderStatus) canUpdate;
  final Future<void> Function(String, OrderStatus) update;
  final VoidCallback close;
  final Future<void> Function() refresh;
  const KitchenBoard(
      {super.key,
      required this.orders,
      required this.loading,
      required this.canUpdate,
      required this.update,
      required this.close,
      required this.refresh});
  @override
  State<KitchenBoard> createState() => _KitchenBoardState();
}

class _KitchenBoardState extends State<KitchenBoard> {
  static const navy = Color(0xFF062B68);
  final _busy = <String>{};
  int _selected = 0;
  Future<void> _advance(Order order, OrderStatus target) async {
    if (!_busy.add(order.id)) return;
    setState(() {});
    try {
      await widget.update(order.id, target);
    } finally {
      if (mounted) setState(() => _busy.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lanes = List.generate(
        3,
        (stage) => widget.orders.where((o) => kitchenStage(o) == stage).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    const labels = ['مؤكد', 'قيد التحضير', 'جاهز للاستلام'];
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: const Color(0xFFF3F5F9),
            appBar: AppBar(
                title: const Text('شاشة التجهيز'),
                leading: IconButton(
                    tooltip: 'العودة للطلبات',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: widget.close),
                actions: [
                  IconButton(
                      tooltip: 'تحديث الطلبات',
                      onPressed: widget.loading ? null : widget.refresh,
                      icon: const Icon(Icons.refresh))
                ]),
            body: Column(children: [
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                      'الطلبات المقبولة فقط • الأقدم أولًا • تسليم السائق من شاشة الطلبات',
                      style: TextStyle(color: navy))),
              if (widget.loading) const LinearProgressIndicator(),
              Expanded(child: LayoutBuilder(builder: (context, size) {
                if (size.maxWidth >= 850) {
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(
                          3,
                          (i) =>
                              Expanded(child: _lane(labels[i], lanes[i], i))));
                }
                return Column(children: [
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          children: List.generate(
                              3,
                              (i) => Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: ChoiceChip(
                                      label: Text(
                                          '${labels[i]} (${lanes[i].length})'),
                                      selected: _selected == i,
                                      onSelected: (_) =>
                                          setState(() => _selected = i)))))),
                  Expanded(
                      child: _lane(
                          labels[_selected], lanes[_selected], _selected)),
                ]);
              })),
            ])));
  }

  Widget _lane(String title, List<Order> orders, int stage) =>
      Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text('$title · ${orders.length}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: navy, fontSize: 20))),
        Expanded(
            child: orders.isEmpty
                ? const Center(child: Text('لا توجد طلبات في هذه المرحلة'))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: orders.length,
                    itemBuilder: (context, i) => _ticket(orders[i], stage))),
      ]);
  Widget _ticket(Order order, int stage) {
    final review = order.exceptionCancellation?['state'] == 'REQUESTED';
    final target =
        stage == 0 ? OrderStatus.preparing : OrderStatus.readyForPickup;
    final elapsed = DateTime.now().difference(order.createdAt).inMinutes;
    return Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(order.id,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: navy)),
                  const SizedBox(height: 6),
                  Text(
                      'منذ ${elapsed < 0 ? 0 : elapsed} دقيقة عند تحميل الطلبات',
                      style: const TextStyle(color: Colors.blueGrey)),
                  const Divider(height: 24),
                  for (final item in order.items)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.quantity} × ${item.name}',
                                  style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                      color: navy)),
                              for (final modifier in item.modifiers)
                                Text('• $modifier',
                                    style: const TextStyle(fontSize: 17)),
                              if (item.notes?.trim().isNotEmpty == true)
                                Text(item.notes!,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        color: Color(0xFF994B00))),
                            ])),
                  if (review)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                            'طلب الزبون الإلغاء • أوقف التجهيز مؤقتًا وراجع مسؤول الفرع',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold))),
                  if (stage < 2)
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: navy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48)),
                        onPressed: review ||
                                _busy.contains(order.id) ||
                                !widget.canUpdate(target)
                            ? null
                            : () => _advance(order, target),
                        child: Text(_busy.contains(order.id)
                            ? 'جارٍ التحديث…'
                            : stage == 0
                                ? 'بدء التحضير'
                                : 'جاهز للاستلام')),
                  if (stage < 2 && !widget.canUpdate(target))
                    const Text('تحديث هذه المرحلة يتطلب صلاحية من مالك الفرع'),
                  if (stage == 2)
                    const Text('بانتظار تسليم الطلب للسائق',
                        style: TextStyle(color: navy)),
                ])));
  }
}
