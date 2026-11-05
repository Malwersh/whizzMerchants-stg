import '../widgets/merchant_workspace_widgets.dart';
import '../providers/business_provider.dart';
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

final merchantDraftsLoaderProvider =
    Provider<Future<List<Map<String, dynamic>>> Function()>(
  (ref) => () async {
    final data = await PersonOnboardingService().call('branch-drafts');
    return List<Map<String, dynamic>>.from(data['items'] ?? []);
  },
);

class MerchantBusinessesScreen extends StatelessWidget {
  const MerchantBusinessesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthSurface(child: _MerchantBusinessesContent());
}

class _MerchantBusinessesContent extends ConsumerStatefulWidget {
  const _MerchantBusinessesContent();
  @override
  ConsumerState<_MerchantBusinessesContent> createState() =>
      _MerchantBusinessesScreenState();
}

class _MerchantBusinessesScreenState
    extends ConsumerState<_MerchantBusinessesContent> {
  List<Map<String, dynamic>>? _businesses;
  String? _error, _draftError;
  bool _opening = false;
  String? _openingId;
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
      final rows = await ref.read(businessListLoaderProvider)();
      if (mounted) {
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
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل أنشطتك. أعد المحاولة.');
    }
  }

  Future<void> _loadDrafts() async {
    try {
      final drafts = await ref.read(merchantDraftsLoaderProvider)();
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _draftError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _draftError = 'تعذر تحميل المسودات. أعد المحاولة.');
      }
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
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
        await api.call(
          'person-profile',
          body: {'acknowledgementVersion': ack['acknowledgementVersion']},
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MerchantBranchDraftScreen(draft: draft),
        ),
      );
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
      'PRODUCT': 'منتج متاح باسم وسعر صحيح',
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
          content: Text(
            approved
                ? 'الفرع مفعّل للعرض. استقبال الطلبات يتحكم به زر التشغيل وساعات العمل.'
                : missing.isEmpty
                    ? 'متطلبات التجهيز الأساسية مكتملة. سيظهر الفرع للعملاء بعد التفعيل، ويبقى استقبال الطلبات متوقفًا حتى تختار التشغيل.'
                    : missing
                        .map((code) => '• ${names[code] ?? code}')
                        .join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('إغلاق'),
            ),
            if (!approved && missing.isEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('إكمال التجهيز وتفعيل الظهور'),
              ),
          ],
        ),
      );
      if (confirm != true) return;
      final activated = await ApiService().branchReadiness(id, activate: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activated['activated'] == true
                ? 'تم تفعيل ظهور الفرع. افتح لوحة الفرع لتشغيل استقبال الطلبات.'
                : 'تغيرت المتطلبات. أعد فحص جاهزية الفرع.',
          ),
        ),
      );
      await _loadBusinesses();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر فحص جاهزية الفرع. أعد المحاولة.');
      }
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
            'الحالة: ${b['status'] ?? 'قيد المراجعة'}\nيمكنك العودة واختيار نشاط آخر.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
      return;
    }
    if (_opening) return;
    final id = (b['businessId'] ?? b['id']).toString();
    setState(() {
      _opening = true;
      _openingId = id;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .setSessionWithBusinessData(id, b);
      if (!mounted) return;
      final session = ref.read(sessionProvider);
      if (!session.isAuthenticated || session.businessId != id) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const BusinessDashboard()));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح الفرع. أعد المحاولة.');
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _openingId = null;
        });
      }
    }
  }

  void _accountAction(String action) {
    final Widget? page = switch (action) {
      'memberships' => const BranchStaffScreen(),
      'profile' => const PersonProfileScreen(),
      _ => null,
    };
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else if (action == 'logout') {
      ref.read(authProviderRiverpod.notifier).signOut().then((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('أنشطتي وفروعي'),
            actions: [
              IconButton(
                tooltip: 'إعدادات الإشعارات',
                icon: const Icon(Icons.notifications_active_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsPage(),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'خيارات الحساب',
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: _accountAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'profile', child: Text('بياناتي الشخصية')),
                  PopupMenuItem(
                    value: 'memberships',
                    child: Text('دعواتي وعضوياتي'),
                  ),
                  PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      const MerchantWorkspaceHeader(
                        title: 'أهلًا بك في أعمالك',
                        subtitle:
                            'اختر النشاط أو الفرع الذي تريد إدارته، أو تابع إعداد نشاط جديد.',
                        icon: Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'الفروع والأنشطة',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (_error != null)
                        MerchantWorkspaceMessage(
                          message: _error!,
                          isError: true,
                          onRetry: _load,
                        )
                      else if (_businesses == null)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_businesses!.isEmpty)
                        const MerchantWorkspaceMessage(
                          message:
                              'حسابك الشخصي جاهز. لا توجد أنشطة مرتبطة به بعد.',
                        ),
                      for (final b
                          in _businesses ?? <Map<String, dynamic>>[]) ...[
                        CommercialRequestsBanner(
                          key: ValueKey('sharing-${b['businessId']}'),
                          businessId: b['businessId'].toString(),
                          businessName:
                              (b['businessName'] ?? b['name'])?.toString(),
                        ),
                        Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _opening ? null : () => _open(b),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDF2FA),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.storefront_outlined,
                                      color: Color(0xFF00296B),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (b['businessName'] ??
                                                  b['name'] ??
                                                  'نشاط')
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: const Color(0xFF182A43),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        MerchantBranchStatus(
                                          status: b['status']?.toString(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_openingId ==
                                      (b['businessId'] ?? b['id']).toString())
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else ...[
                                    if (b['status'] == 'approved')
                                      IconButton(
                                        tooltip: 'تجهيز وتفعيل الفرع',
                                        icon: const Icon(
                                            Icons.fact_check_outlined),
                                        onPressed: _opening
                                            ? null
                                            : () => _readiness(b),
                                      ),
                                    const Icon(
                                      Icons.chevron_left,
                                      color: Color(0xFF42526B),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _draft(),
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('إضافة نشاط أو فرع'),
                      ),
                      if (_draftError != null)
                        MerchantWorkspaceMessage(
                          message: _draftError!,
                          isError: true,
                          onRetry: _loadDrafts,
                        ),
                      if (_drafts
                          .any((d) => d['reviewStatus'] != 'APPROVED')) ...[
                        const SizedBox(height: 24),
                        Text(
                          'طلبات إنشاء الفروع',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                      for (final draft in _drafts.where(
                        (d) => d['reviewStatus'] != 'APPROVED',
                      ))
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.edit_note_outlined),
                            title: Text(draft['name'] as String),
                            subtitle: Text(
                              const {
                                    'DRAFT': 'مسودة — غير مقدمة للمراجعة',
                                    'SUBMITTED': 'مقدمة للمراجعة',
                                    'NEEDS_INFORMATION': 'يحتاج استكمالًا',
                                    'REJECTED': 'مرفوضة — راجع السبب',
                                  }[draft['reviewStatus']] ??
                                  'مسودة',
                            ),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => _draft(draft),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          title: const Text('المحافظ والصلاحيات المالية'),
                          subtitle: const Text(
                            'إدارة المحافظ والحسابات المتاحة لك',
                          ),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const MerchantWalletAccountsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DeleteAccountScreen(scope: 'ACCOUNT'),
                          ),
                        ),
                        child: const Text('إدارة حذف حسابي الشخصي'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
