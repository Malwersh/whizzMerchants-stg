import 'notification_settings_page.dart';
import '../widgets/commercial_requests_banner.dart';
import '../services/commercial_notice_navigation.dart';
import 'auth/auth_surface.dart';
import 'branch_staff_screen.dart';
import 'person_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/person_onboarding_service.dart';
import 'merchant_branch_draft_screen.dart';
import '../providers/auth_provider_riverpod.dart';
import '../providers/session_provider.dart';
import 'dashboards/business_dashboard.dart';
import 'merchant_wallet_accounts_screen.dart';
import 'delete_account_screen.dart';

class MerchantBusinessesScreen extends ConsumerStatefulWidget {
  const MerchantBusinessesScreen({super.key});
  @override
  ConsumerState<MerchantBusinessesScreen> createState() =>
      _MerchantBusinessesScreenState();
}

class _MerchantBusinessesScreenState
    extends ConsumerState<MerchantBusinessesScreen> {
  List<Map<String, dynamic>>? _businesses;
  String? _error, _draftError;
  List<Map<String, dynamic>> _drafts = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    CommercialNoticeNavigation.ownerReady = false;
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadBusinesses(), _loadDrafts()]);
  }

  Future<void> _loadBusinesses() async {
    try {
      final rows = await ApiService().getUserBusinesses();
      if (mounted)
        setState(() {
          _businesses = rows;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              CommercialNoticeNavigation.ownerReady = true;
              CommercialNoticeNavigation.tryOpen();
            }
          });
          _error = null;
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل أنشطتك. أعد المحاولة.');
    }
  }

  Future<void> _loadDrafts() async {
    try {
      final data = await PersonOnboardingService().call('branch-drafts');
      if (mounted)
        setState(() {
          _drafts = List<Map<String, dynamic>>.from(data['items'] ?? []);
          _draftError = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _draftError = 'تعذر تحميل المسودات. أعد المحاولة.');
    }
  }

  Future<void> _draft([Map<String, dynamic>? draft]) async {
    try {
      final api = PersonOnboardingService();
      final response = await api.call('person-profile');
      if (response['profile'] == null) {
        final ack = await api.call('person-registration', authenticated: false);
        if (!mounted) return;
        final accepted = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    title: const Text('حسابك الشخصي'),
                    content: Text(ack['acknowledgementText'] as String),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('موافق'))
                    ]));
        if (accepted != true) return;
        await api.call('person-profile',
            body: {'acknowledgementVersion': ack['acknowledgementVersion']});
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MerchantBranchDraftScreen(draft: draft)));
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح المسودة. أعد المحاولة.');
    }
  }

  Future<void> _readiness(Map<String, dynamic> business) async {
    const names = {
      'APPROVAL': 'اعتماد الفرع وعدم وجود حظر من المنصة',
      'ONBOARDING_VERSION': 'ربط الفرع بمسار التسجيل الجديد',
      'DETAILS': 'الاسم وهاتف الفرع والعنوان التفصيلي',
      'LOCATION': 'منطقة خدمة فعالة ونقطة صحيحة داخلها',
      'AGREEMENT': 'اتفاقية الشراكة وطلب معتمد',
      'HOURS': 'ساعات عمل صالحة',
      'PRODUCT': 'منتج متاح باسم وسعر صحيح'
    };
    try {
      final id = (business['businessId'] ?? business['id']) as String;
      final result = await ApiService().branchReadiness(id);
      if (!mounted) return;
      final missing = List<String>.from(result['missing'] ?? []);
      final approved = result['alreadyActivated'] == true;
      final confirm = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: const Text('جاهزية الفرع'),
                content: Text(approved
                    ? 'الفرع مفعّل للعرض. استقبال الطلبات يتحكم به زر التشغيل وساعات العمل.'
                    : missing.isEmpty
                        ? 'متطلبات التجهيز الأساسية مكتملة. سيظهر الفرع للعملاء بعد التفعيل، ويبقى استقبال الطلبات متوقفًا حتى تختار التشغيل.'
                        : missing
                            .map((code) => '• ${names[code] ?? code}')
                            .join('\n')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('إغلاق')),
                  if (!approved && missing.isEmpty)
                    FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('إكمال التجهيز وتفعيل الظهور'))
                ],
              ));
      if (confirm != true) return;
      final activated = await ApiService().branchReadiness(id, activate: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(activated['activated'] == true
              ? 'تم تفعيل ظهور الفرع. افتح لوحة الفرع لتشغيل استقبال الطلبات.'
              : 'تغيرت المتطلبات. أعد فحص جاهزية الفرع.')));
      await _loadBusinesses();
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذر فحص جاهزية الفرع. أعد المحاولة.');
    }
  }

  Future<void> _open(Map<String, dynamic> b) async {
    final status = b['status']?.toString().toLowerCase();
    if (status != 'approved' && status != 'active') {
      showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                  title: const Text('حالة مراجعة النشاط'),
                  content: Text(
                      'الحالة: ${b['status'] ?? 'قيد المراجعة'}\nيمكنك العودة واختيار نشاط آخر.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('حسنًا'))
                  ]));
      return;
    }
    await ref
        .read(sessionProvider.notifier)
        .setSessionWithBusinessData(b['businessId'].toString(), b);
    if (mounted)
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const BusinessDashboard()));
  }

  @override
  Widget build(BuildContext context) => AuthSurface(
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              appBar: AppBar(title: const Text('مطاعمي وأنشطتي'), actions: [
                IconButton(
                    tooltip: 'إعدادات الإشعارات',
                    icon: const Icon(Icons.notifications_active_outlined),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationSettingsPage()))),
                IconButton(
                    tooltip: 'دعواتي وعضوياتي',
                    icon: const Icon(Icons.groups_outlined),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BranchStaffScreen()))),
                IconButton(
                    tooltip: 'بياناتي الشخصية',
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PersonProfileScreen()))),
                IconButton(
                    tooltip: 'تسجيل الخروج',
                    onPressed: () async {
                      await ref.read(authProviderRiverpod.notifier).signOut();
                      if (context.mounted)
                        Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    icon: const Icon(Icons.logout))
              ]),
              body: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    const Text('اختر النشاط أو الفرع الذي تريد إدارته.'),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(_error!),
                      TextButton(
                          onPressed: _load, child: const Text('إعادة المحاولة'))
                    ] else if (_businesses == null)
                      const Center(child: CircularProgressIndicator())
                    else if (_businesses!.isEmpty)
                      const Card(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                  'حسابك الشخصي جاهز. لا توجد أنشطة مرتبطة به بعد.'))),
                    for (final b
                        in _businesses ?? <Map<String, dynamic>>[]) ...[
                      CommercialRequestsBanner(
                          key: ValueKey('sharing-${b['businessId']}'),
                          businessId: b['businessId'].toString(),
                          businessName:
                              (b['businessName'] ?? b['name'])?.toString()),
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.storefront),
                              title: Text(
                                  (b['businessName'] ?? b['name'] ?? 'نشاط')
                                      .toString()),
                              subtitle: Text(
                                  (b['status'] ?? 'قيد المراجعة').toString()),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (b['status'] == 'approved')
                                      IconButton(
                                          tooltip: 'تجهيز وتفعيل الفرع',
                                          icon: const Icon(
                                              Icons.fact_check_outlined),
                                          onPressed: () => _readiness(b)),
                                    const Icon(Icons.chevron_left)
                                  ]),
                              onTap: () => _open(b))),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: () => _draft(),
                        icon: const Icon(Icons.add_business),
                        label: const Text('إضافة نشاط أو فرع')),
                    if (_draftError != null) Text(_draftError!),
                    for (final draft in _drafts
                        .where((d) => d['reviewStatus'] != 'APPROVED'))
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.edit_note),
                              title: Text(draft['name'] as String),
                              subtitle: Text(const {
                                    'DRAFT': 'مسودة — غير مقدمة للمراجعة',
                                    'SUBMITTED': 'مقدمة للمراجعة',
                                    'NEEDS_INFORMATION': 'يحتاج استكمالًا',
                                    'REJECTED': 'مرفوضة — راجع السبب'
                                  }[draft['reviewStatus']] ??
                                  'مسودة'),
                              onTap: () => _draft(draft))),
                    OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const MerchantWalletAccountsScreen())),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('المحافظ والصلاحيات المالية')),
                    TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const DeleteAccountScreen(
                                    scope: 'ACCOUNT'))),
                        child: const Text('إدارة حذف حسابي الشخصي')),
                  ])))));
}
