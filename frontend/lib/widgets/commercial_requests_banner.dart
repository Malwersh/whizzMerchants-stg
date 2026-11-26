import 'dart:async';
import 'package:flutter/material.dart';
import '../services/person_onboarding_service.dart';
import '../services/commercial_notice_navigation.dart';
import '../screens/commercial_agreements_screen.dart';

class CommercialRequestsBanner extends StatefulWidget {
  final String businessId;
  final String? businessName;
  final PersonOnboardingService? service;
  const CommercialRequestsBanner({super.key, required this.businessId, this.businessName, this.service});
  @override State<CommercialRequestsBanner> createState() => _BannerState();
}
class _BannerState extends State<CommercialRequestsBanner> with WidgetsBindingObserver {
  int _count = 0, _epoch = 0;
  bool _loading = false, _active = true;
  Timer? _timer;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); CommercialNoticeNavigation.changes.addListener(_load); _load(); _timer = Timer.periodic(const Duration(minutes: 1), (_) { if (_active) _load(); }); }
  @override void didUpdateWidget(covariant CommercialRequestsBanner oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.businessId != widget.businessId) { _epoch++; _loading = false; _count = 0; _load(); } }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { _active = state == AppLifecycleState.resumed; if (_active) { _load(); CommercialNoticeNavigation.tryOpen(); } }
  Future<void> _load() async {
    if (_loading) return;
    final epoch = ++_epoch, business = widget.businessId; _loading = true;
    try {
      final result = await (widget.service ?? PersonOnboardingService()).call('commercial-agreements?businessId=${Uri.encodeComponent(business)}&view=pending-sharing');
      if (mounted && epoch == _epoch) setState(() => _count = List<dynamic>.from(result['items'] ?? []).length);
    } catch (_) { if (mounted && epoch == _epoch) setState(() => _count = 0); }
    finally { if (epoch == _epoch) _loading = false; }
  }
  @override void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); CommercialNoticeNavigation.changes.removeListener(_load); super.dispose(); }
  @override Widget build(BuildContext context) => _count == 0 ? const SizedBox.shrink() : MaterialBanner(
    leading: const Icon(Icons.local_offer_outlined),
    content: Text('لديك $_count طلب عرض أو مشاركة بانتظار موافقتك'),
    actions: [TextButton(onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommercialAgreementsScreen(businessId: widget.businessId, businessName: widget.businessName))); _load(); }, child: const Text('مراجعة الطلبات'))]);
}
