import '../services/notification_sound_policy.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/merchant_order_alerts.dart';
import '../services/audio_notification_service.dart';
import '../services/realtime_order_service.dart';
import '../services/commercial_notice_navigation.dart';

class MerchantOrderAttention extends StatefulWidget {
  final String businessId;
  final Future<List<Order>> Function() load;
  final void Function(String orderId) open;
  final Widget child;
  const MerchantOrderAttention(
      {super.key,
      required this.businessId,
      required this.load,
      required this.open,
      required this.child});
  @override
  State<MerchantOrderAttention> createState() => _MerchantOrderAttentionState();
}

class _MerchantOrderAttentionState extends State<MerchantOrderAttention>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _push;
  StreamSubscription<Order>? _socket;
  StreamSubscription<Map<String, dynamic>>? _updates;
  Timer? _timer;
  final _shown = <String>{};
  final _resolved = <String>{};
  bool _busy = false, _foreground = true, _hasSnapshot = false;
  List<Order> _pending = [];
  DateTime? _lastReminder;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _push = MerchantOrderAlerts.events.listen((d) {
      if (d['businessId'] == widget.businessId)
        _receive(d['orderId'].toString());
    });
    _socket = RealtimeOrderService().newOrderStream.listen((o) {
      if (o.businessId == widget.businessId &&
          o.status == OrderStatus.pending &&
          !o.shouldAutoReject()) _receive(o.id);
    });
    _updates = RealtimeOrderService().orderUpdateStream.listen((update) {
      final id = update['orderId']?.toString(), status = update['status']?.toString();
      if (id == null || status == null || status == 'pending') return;
      _resolved.add(id);
      _pending.removeWhere((o) => o.id == id);
      _shown.add(id);
      if (_pending.isEmpty) _lastReminder = null;
    });
    _refresh();
    _timer = Timer.periodic(
        const Duration(seconds: 15), (_) => _refresh(remind: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  Future<void> _refresh({bool remind = false}) async {
    if (_busy || !_foreground) return;
    _busy = true;
    try {
      final orders = await widget.load();
      if (!mounted || !_foreground) return;
      _resolved.addAll(orders.where((o) => o.status != OrderStatus.pending).map((o) => o.id));
      _pending = orders
          .where(
              (o) => o.status == OrderStatus.pending && !_resolved.contains(o.id) && !o.shouldAutoReject())
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _shown.addAll(orders.where((o) => o.status != OrderStatus.pending).map((o) => o.id));
      MerchantOrderAlerts.publishSnapshot(widget.businessId, orders);
      if (!_hasSnapshot) {
        _hasSnapshot = true;
        _shown.addAll(_pending.map((o) => o.id));
        _lastReminder = DateTime.now();
      } else {
        for (final order in _pending) {
          if (!_shown.contains(order.id)) _receive(order.id);
        }
      }
      if (_pending.isEmpty) {
        _lastReminder = null;
        return;
      }
      if (remind &&
          (_lastReminder == null ||
              DateTime.now().difference(_lastReminder!).inSeconds >=
                  NotificationSoundPolicy.reminderSeconds)) {
        _lastReminder = DateTime.now();
        await AudioNotificationService().playPendingOrderReminder();
      }
    } catch (_) {
      _pending = [];
    } finally {
      _busy = false;
    }
  }

  void _receive(String id) {
    if (!_foreground || !mounted || !_shown.add(id)) return;
    _lastReminder = DateTime.now();
    _show(id);
    unawaited(AudioNotificationService().playNewOrderSoundOnce(id));
    _refresh();
  }

  void _show(String orderId) {
    final context = CommercialNoticeNavigation.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(
          'طلب جديد • ${_pending.isEmpty ? 1 : _pending.length} بانتظار الرد'),
      duration: const Duration(seconds: 8),
      showCloseIcon: true,
      action: SnackBarAction(
          label: 'عرض الطلب',
          onPressed: () {
            if (mounted) widget.open(orderId);
          }),
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _push?.cancel();
    _socket?.cancel();
    _updates?.cancel();
    _timer?.cancel();
    _pending = [];
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
