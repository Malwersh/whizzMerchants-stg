import 'dashboards/business_dashboard.dart';
import '../services/branch_employee_access.dart';
import '../services/push_notifications_service.dart';
import '../providers/auth_provider_riverpod.dart';
import '../services/audio_notification_service.dart';
import '../services/app_auth_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/branch_device_provider.dart';
import '../services/branch_device_service.dart';
import 'branch_device_pin_setup_screen.dart';
import 'auth/auth_surface.dart';

class BranchDeviceHomeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> device;
  final BranchDeviceService? service;
  const BranchDeviceHomeScreen({super.key, required this.device, this.service});
  @override
  ConsumerState<BranchDeviceHomeScreen> createState() => _DeviceHomeState();
}

class _DeviceHomeState extends ConsumerState<BranchDeviceHomeScreen>
    with WidgetsBindingObserver {
  late final api = widget.service ?? BranchDeviceService();
  String get token => widget.device['deviceToken'];
  String? session, error;
  Map<String, dynamic>? reception, profile;
  bool loading = true, revoked = false;
  Timer? timer, expiry;
  bool refreshing = false, foreground = true, touching = false;
  DateTime? lastTouch;
  bool firstSync = true;
  List<Map<String, dynamic>> orders = [];
  DateTime? lastSync;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.service == null) {
      PushNotificationsService.instance.setOrderRefreshCallback(refresh);
      unawaited(startReception());
    } else {
      refresh();
    }
    timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.service == null)
      PushNotificationsService.instance.setOrderRefreshCallback(null);
    timer?.cancel();
    expiry?.cancel();
    session = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      lock();
    } else {
      refresh();
    }
  }

  Future<void> startReception() async {
    await AppAuthService.signOut();
    await PushNotificationsService.instance.initialize();
    await PushNotificationsService.instance.registerTokenIfPossible();
    if (mounted) await refresh();
  }

  Future<void> refresh() async {
    if (refreshing || revoked) return;
    refreshing = true;
    try {
      final r = await api.call(token, {'action': 'reception'});
      if (widget.service == null && r['pushRegistered'] != true)
        unawaited(PushNotificationsService.instance.registerTokenIfPossible());
      final list = await api.operation(
          token, 'merchant/orders/${widget.device['businessId']}');
      orders = List<Map<String, dynamic>>.from(list['orders'] ?? []);
      for (final order in orders.where((o) => o['status'] == 'pending')) {
        if (firstSync || !foreground) {
          await AudioNotificationService.markOrderSoundAnnounced(
              order['orderId']);
        } else {
          await AudioNotificationService()
              .playNewOrderSoundOnce(order['orderId']);
        }
      }
      firstSync = false;
      if (mounted)
        setState(() {
          reception = r;
          error = null;
          loading = false;
          lastSync = DateTime.now();
        });
      if (session != null) {
        final p =
            await api.call(token, {'action': 'profile'}, session: session);
        if (mounted && session != null) setState(() => profile = p);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          loading = false;
          if (e is BranchDeviceException &&
              ['DEVICE_REVOKED', 'BUSINESS_UNAVAILABLE'].contains(e.code)) {
            revoked = true;
            session = null;
            profile = null;
          }
          if (e is BranchDeviceException &&
              ['SESSION_REVOKED', 'MEMBERSHIP_REVOKED', 'ACCOUNT_CLOSING']
                  .contains(e.code)) {
            session = null;
            profile = null;
          }
        });
    } finally {
      refreshing = false;
    }
  }

  void scheduleLock(int expiresAt) {
    expiry?.cancel();
    expiry = Timer(
        Duration(
            seconds: (expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000)
                .clamp(0, 120)),
        lock);
  }

  Future<void> touch() async {
    final current = session;
    if (current == null ||
        touching ||
        lastTouch != null &&
            DateTime.now().difference(lastTouch!).inSeconds < 30) return;
    touching = true;
    try {
      final r = await api.call(token, {'action': 'touch'}, session: current);
      if (mounted && session == current) {
        lastTouch = DateTime.now();
        scheduleLock((r['expiresAt'] as num).toInt());
      }
    } catch (_) {
      if (mounted && session == current) await lock();
    } finally {
      touching = false;
    }
  }

  Future<void> lock() async {
    final old = session;
    expiry?.cancel();
    if (mounted) {
      setState(() {
        session = null;
        profile = null;
      });
      if (old != null)
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    }
    if (old != null) {
      try {
        await api.call(token, {'action': 'lock'}, session: old);
      } catch (_) {}
    }
  }

  Future<void> unlock(Map<String, dynamic> employee) async {
    final pin = TextEditingController();
    final entered = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text('فتح مهام ${employee['displayName'] ?? 'الموظف'}'),
                content: TextField(
                    controller: pin,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'PIN الشخصي')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, pin.text),
                      child: const Text('فتح المهام'))
                ]));
    // Dialog route finishes disposing its editable field after the pop animation.
    Future<void>.delayed(const Duration(seconds: 1), pin.dispose);
    if (entered == null || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final s = await api.call(token, {
        'action': 'unlock',
        'subjectId': employee['subjectId'],
        'pin': entered
      });
      if (!mounted) return;
      session = s['staffSession'];
      if (!foreground) {
        await lock();
        return;
      }
      lastTouch = DateTime.now();
      scheduleLock((s['expiresAt'] as num).toInt());
      await refresh();
    } catch (e) {
      if (mounted)
        setState(() {
          error = e.toString();
          loading = false;
        });
    }
  }

  Future<void> forget() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('الخروج من وضع جهاز الفرع؟'),
                content: const Text(
                    'يتوقف الاستقبال على هذا الجهاز. يمكن للمالك إلغاء اعتماده من أجهزة الفرع.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('فصل هذا الجهاز'))
                ]));
    if (ok != true || !mounted) return;
    await lock();
    try {
      if (!revoked) await api.call(token, {'action': 'disconnect'});
      if (mounted) {
        final device = ref.read(branchDeviceProvider.notifier);
        await ref.read(authProviderRiverpod.notifier).signOut();
        await device.forget();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AuthSurface(
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Listener(
              onPointerDown: (_) => touch(),
              child: session != null && profile != null
                  ? BusinessDashboard(
                      employeeAccess: BranchEmployeeAccess(
                          api: api,
                          token: token,
                          session: session!,
                          businessId: widget.device['businessId'],
                          profile: profile!,
                          lock: lock))
                  : Scaffold(
                      backgroundColor: const Color(0xFFF5F7FA),
                      appBar: AppBar(title: const Text('جهاز الفرع'), actions: [
                        IconButton(
                            onPressed: forget,
                            tooltip: 'فصل هذا الجهاز',
                            icon: const Icon(Icons.link_off))
                      ]),
                      body: RefreshIndicator(
                          onRefresh: refresh,
                          child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                Card(
                                    elevation: 0,
                                    color: const Color(0xFF00296B),
                                    child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.storefront,
                                                  color: Color(0xFFFDC500),
                                                  size: 32),
                                              const SizedBox(height: 12),
                                              Text(
                                                  reception?['businessName'] ??
                                                      widget.device[
                                                          'businessName'] ??
                                                      'الفرع',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Text(
                                                  reception?['device']
                                                          ?['name'] ??
                                                      'جهاز استقبال الطلبات',
                                                  style: const TextStyle(
                                                      color: Colors.white)),
                                              const SizedBox(height: 12),
                                              Text(
                                                  revoked
                                                      ? 'يلزم إعادة اعتماد الجهاز'
                                                      : error != null
                                                          ? 'تعذر التزامن — تحقق من الاتصال'
                                                          : lastSync == null
                                                              ? 'جارٍ الاتصال بالخادم…'
                                                              : 'آخر مزامنة ${TimeOfDay.fromDateTime(lastSync!).format(context)}',
                                                  style: const TextStyle(
                                                      color: Colors.white)),
                                            ]))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Text(
                                        reception?['pushRegistered'] == true
                                            ? 'تنبيهات الخلفية مرتبطة بهذا الجهاز'
                                            : 'تنبيهات الخلفية غير مربوطة بعد؛ تحقق من إذن الإشعارات.',
                                        style: const TextStyle(
                                            color: Color(0xFF00296B)))),
                                if (loading) const LinearProgressIndicator(),
                                if (error != null)
                                  Card(
                                      color: const Color(0xFFFFF0EF),
                                      child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(error!,
                                              style: const TextStyle(
                                                  color: Color(0xFF9B1C1C))))),
                                const SizedBox(height: 12),
                                Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(children: [
                                          const Icon(
                                              Icons.receipt_long_outlined,
                                              color: Color(0xFF00296B)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Text(
                                                  'طلبات جديدة: ${orders.where((o) => o['status'] == 'pending').length}')),
                                          IconButton(
                                              onPressed: refresh,
                                              tooltip: 'تحديث الاستقبال',
                                              icon: const Icon(Icons.refresh)),
                                        ]))),
                                const SizedBox(height: 20),
                                ...[
                                  const Text('من سيبدأ العمل؟',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00296B))),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'اختر اسمك وافتح مهامك بـPIN. قفل المهام لا يفصل الجهاز.'),
                                  const SizedBox(height: 12),
                                  for (final employee
                                      in List<Map<String, dynamic>>.from(
                                          reception?['staff'] ?? []))
                                    Card(
                                        child: ListTile(
                                            leading: const CircleAvatar(
                                                backgroundColor:
                                                    Color(0xFFEAF0F9),
                                                child: Icon(
                                                    Icons.person_outline,
                                                    color: Color(0xFF00296B))),
                                            title: Text(
                                                employee['displayName'] ??
                                                    'موظف'),
                                            subtitle: Text(
                                                employee['pinReady'] == true
                                                    ? 'جاهز لفتح المهام'
                                                    : 'يلزم إعداد PIN الشخصي'),
                                            trailing:
                                                const Icon(Icons.chevron_left),
                                            onTap: revoked || loading
                                                ? null
                                                : employee['pinReady'] == true
                                                    ? () => unlock(employee)
                                                    : () => setupPin())),
                                  if (!loading &&
                                      error == null &&
                                      (reception?['staff'] as List? ?? [])
                                          .isEmpty)
                                    const Card(
                                        child: Padding(
                                            padding: EdgeInsets.all(20),
                                            child: Text(
                                                'لا يوجد موظف بعضوية فعالة. يدعوه المالك ويقبل الدعوة أولًا.'))),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                      onPressed: revoked ? null : setupPin,
                                      icon: const Icon(Icons.password),
                                      label: const Text(
                                          'إعداد PIN أو استعادته بالهاتف')),
                                ],
                              ]))))));
  Future<void> setupPin() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => BranchDevicePinSetupScreen(
                businessId: widget.device['businessId'], deviceToken: token)));
    if (mounted) refresh();
  }
}
