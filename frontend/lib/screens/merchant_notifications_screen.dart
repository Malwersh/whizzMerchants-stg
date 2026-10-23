import 'notification_settings_page.dart';
import 'commercial_agreements_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../core/theme/whizz_colors.dart';
import '../models/notification.dart';
import '../services/merchant_notification_inbox.dart';
import 'orders_page.dart';
import 'merchant_wallet_accounts_screen.dart';

class MerchantNotificationsScreen extends StatefulWidget {
  final String businessId;
  final MerchantNotificationInbox? service;
  const MerchantNotificationsScreen(
      {super.key, required this.businessId, this.service});
  @override
  State<MerchantNotificationsScreen> createState() =>
      _MerchantNotificationsScreenState();
}

class _MerchantNotificationsScreenState
    extends State<MerchantNotificationsScreen> with WidgetsBindingObserver {
  late final inbox = widget.service ?? MerchantNotificationInbox.instance;
  bool unreadOnly = false, loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    inbox.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await inbox.load(widget.businessId);
    if (mounted) setState(() => loading = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    inbox.removeListener(_changed);
    super.dispose();
  }

  Future<void> _open(NotificationModel item) async {
    await inbox.markRead(id: item.id);
    if (!mounted) return;
    if (item.type == 'commercial_sharing_requested') {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CommercialAgreementsScreen(
                  businessId: widget.businessId,
                  focusSharingId: item.data['sharingId']?.toString(),
                  focusRequestKind: item.data['requestKind']?.toString() ?? 'FUNDING')));
    } else if (item.orderId != null) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(item.title)),
                  body: OrdersPage(
                      businessId: widget.businessId,
                      focusOrderId: item.orderId))));
    } else if (item.type.contains('wallet') || item.type.contains('transfer')) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const MerchantWalletAccountsScreen()));
    } else {
      await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(item.body)
                      ]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = inbox.items.where((x) => !unreadOnly || !x.isRead).toList();
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: WhizzColors.grey50,
            appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: WhizzColors.secondary,
                title: const Text('الإشعارات'),
                centerTitle: true,
                actions: [
                  IconButton(
                      tooltip: 'إعدادات الإشعارات',
                      icon: const Icon(Icons.notifications_active_outlined),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsPage()))),
                  TextButton(
                      onPressed: inbox.items.any((x) => !x.isRead)
                          ? () => inbox.markRead()
                          : null,
                      child: const Text('قراءة الكل'))
                ]),
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Wrap(spacing: 10, children: [
                            for (final entry in {
                              false: 'الكل',
                              true: 'غير المقروءة'
                            }.entries)
                              ChoiceChip(
                                  label: Text(entry.value),
                                  selected: unreadOnly == entry.key,
                                  selectedColor: WhizzColors.secondary,
                                  labelStyle: TextStyle(
                                      color: unreadOnly == entry.key
                                          ? Colors.white
                                          : WhizzColors.secondary),
                                  onSelected: (_) =>
                                      setState(() => unreadOnly = entry.key))
                          ]),
                          if (inbox.error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(inbox.error!,
                                    style: const TextStyle(
                                        color: WhizzColors.secondary))),
                          const SizedBox(height: 18),
                          if (rows.isEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 100),
                                child: Column(children: [
                                  const Icon(Icons.notifications_none_rounded,
                                      size: 62, color: WhizzColors.secondary),
                                  const SizedBox(height: 20),
                                  Text(
                                      unreadOnly
                                          ? 'أنت مطّلع على كل جديد'
                                          : 'لا توجد إشعارات بعد',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: WhizzColors.secondary))
                                ])),
                          for (final item in rows)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () => _open(item),
                                        child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                    color: item.isRead
                                                        ? Colors.black
                                                            .withValues(
                                                                alpha: .06)
                                                        : WhizzColors.primary
                                                            .withValues(
                                                                alpha: .45))),
                                            child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                      item.orderId != null
                                                          ? Icons
                                                              .receipt_long_outlined
                                                          : Icons
                                                              .notifications_none_rounded,
                                                      color: WhizzColors
                                                          .secondary),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                        Text(item.title,
                                                            style: TextStyle(
                                                                color: WhizzColors
                                                                    .secondary,
                                                                fontSize: 16,
                                                                fontWeight: item
                                                                        .isRead
                                                                    ? FontWeight
                                                                        .w500
                                                                    : FontWeight
                                                                        .w700)),
                                                        if (item.body
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 6),
                                                          Text(item.body,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .black87,
                                                                  height: 1.5))
                                                        ],
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                            intl.DateFormat(
                                                                    'dd/MM/yyyy • HH:mm')
                                                                .format(item
                                                                    .createdAt
                                                                    .toLocal()),
                                                            style:
                                                                const TextStyle(
                                                                    color: Colors
                                                                        .grey,
                                                                    fontSize:
                                                                        12))
                                                      ])),
                                                  if (!item.isRead)
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                top: 6),
                                                        child: Icon(
                                                            Icons.circle,
                                                            size: 8,
                                                            color: WhizzColors
                                                                .primary))
                                                ])))))
                        ]))));
  }
}
