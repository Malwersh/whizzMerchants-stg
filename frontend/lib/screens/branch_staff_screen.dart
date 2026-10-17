import 'dart:convert';
import 'branch_device_setup_screen.dart';
import 'staff_grant_editor.dart';
import 'staff_product_activity_screen.dart';
import 'auth/auth_surface.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/person_onboarding_service.dart';
import 'person_profile_screen.dart';

class BranchStaffScreen extends StatefulWidget {
  final String? businessId;
  final PersonOnboardingService? service;
  final bool employeeHome;
  final VoidCallback? onSignOut;
  const BranchStaffScreen(
      {super.key,
      this.businessId,
      this.service,
      this.employeeHome = false,
      this.onSignOut})
      : assert(!employeeHome || businessId == null);
  @override
  State<BranchStaffScreen> createState() => _BranchStaffScreenState();
}

class _BranchStaffScreenState extends State<BranchStaffScreen> {
  late final api = widget.service ?? PersonOnboardingService();
  final phone = TextEditingController();
  String? error, notice, customRequestId, customFingerprint;
  bool busy = true;
  List<Map<String, dynamic>> invites = [], members = [];
  static const roles = {
    'MANAGER': 'مدير الفرع',
    'RECEPTION': 'استقبال',
    'FINANCE': 'مالي — قراءة فقط',
    'REPORT_READER': 'قارئ التقارير'
  };
  bool get owner => widget.businessId != null;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() => busy = true);
    try {
      final r = await api.call(owner
          ? 'branch-staff?businessId=${Uri.encodeComponent(widget.businessId!)}'
          : 'branch-staff?view=invitations');
      final memberships =
          owner ? r : await api.call('branch-staff?view=memberships');
      if (mounted)
        setState(() {
          error = null;
          invites = List<Map<String, dynamic>>.from(
              r[owner ? 'invitations' : 'items'] ?? []);
          members = List<Map<String, dynamic>>.from(
              memberships[owner ? 'members' : 'items'] ?? []);
        });
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(Map<String, dynamic> body) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await api.call('branch-staff', body: body);
      if (body['action'] == 'invite') {
        customRequestId = null;
        customFingerprint = null;
        phone.clear();
        notice =
            'تم إنشاء الدعوة. تظهر للموظف بعد دخوله بالرقم المدعو والتحقق منه.';
      }
      await load();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(title: Text(text), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('تأكيد'))
              ])) ??
      false;
  Future<void> customize({Map<String, dynamic>? member}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await api.call(
          'branch-staff?view=policy&businessId=${Uri.encodeComponent(widget.businessId!)}');
      if (!mounted) return;
      setState(() => busy = false);
      final grant = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => StaffGrantEditor(
              policy: Map<String, dynamic>.from(response['policy']),
              initialGrant: member?['grant'] == null
                  ? null
                  : Map<String, dynamic>.from(member!['grant'])));
      if (grant == null || !mounted) return;
      if (member == null) {
        final fingerprint = jsonEncode({'phone': phone.text, 'grant': grant});
        if (customFingerprint != fingerprint) {
          customFingerprint = fingerprint;
          customRequestId = const Uuid().v4();
        }
        await act({
          'action': 'invite',
          'businessId': widget.businessId,
          'requestId': customRequestId,
          'phoneNumber': phone.text,
          'grant': grant
        });
      } else {
        await act({
          'action': 'update',
          'businessId': widget.businessId,
          'subjectId': member['subjectId'],
          'baseVersion': member['version'],
          'grant': grant
        });
      }
    } catch (e) {
      if (mounted)
        setState(
            () => error = 'تعذر تحميل أو حفظ سياسة الصلاحيات. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Map<String, dynamic> member) => customize(member: member);

  @override
  Widget build(BuildContext context) => AuthSurface(
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              appBar: AppBar(
                  title: Text(owner
                      ? 'الموظفون والصلاحيات'
                      : widget.employeeHome
                          ? 'مساحة الموظف'
                          : 'دعواتي وعضوياتي'),
                  automaticallyImplyLeading: !widget.employeeHome,
                  actions: [
                    if (widget.employeeHome)
                      IconButton(
                          tooltip: 'تسجيل الخروج',
                          onPressed: widget.onSignOut,
                          icon: const Icon(Icons.logout))
                  ]),
              backgroundColor: const Color(0xFFF5F7FA),
              body: ListView(padding: const EdgeInsets.all(20), children: [
                Card(
                  elevation: 0,
                  color: const Color(0xFF00296B),
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.badge_outlined,
                                color: Color(0xFFFDC500), size: 32),
                            const SizedBox(height: 12),
                            Text(owner ? 'فريق الفرع' : 'فروعك ومهامك',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                                owner
                                    ? 'ادعُ الموظفين واختر نوع عمل كل شخص لهذا الفرع، ثم اعتمد جهاز الفرع للعمل.'
                                    : 'اقبل دعوة المالك، ثم ابدأ العمل على جهاز الفرع المعتمد باستخدام PIN الشخصي.',
                                style: const TextStyle(
                                    color: Colors.white, height: 1.6)),
                          ])),
                ),
                if (owner)
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BranchDeviceSetupScreen(
                                  businessId: widget.businessId!,
                                  owner: true))),
                      icon: const Icon(Icons.tablet_mac_outlined),
                      label: const Text('أجهزة الفرع ورموز الربط')),
                if (owner)
                  OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => StaffProductActivityScreen(
                                  businessId: widget.businessId!,
                                  service: api))),
                      icon: const Icon(Icons.history),
                      label: const Text('سجل نشاط الموظفين')),
                if (notice != null) Text(notice!),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                TextButton(
                    onPressed: busy ? null : load, child: const Text('تحديث')),
                if (owner) ...[
                  const Text('دعوة موظف إلى هذا الفرع'),
                  TextField(
                      controller: phone,
                      enabled: !busy,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'هاتف الموظف', hintText: '07XX XXX XXXX')),
                  OutlinedButton(
                      onPressed: busy ? null : () => customize(),
                      child: const Text('اختيار نوع الموظف وإرسال الدعوة')),
                  const Text(
                      'تظهر الدعوة لصاحب الرقم بعد دخوله والتحقق منه. لا ترسل هذه الخطوة رسالة نصية. تنتهي الدعوة بعد سبعة أيام.'),
                ] else
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PersonProfileScreen())),
                      child: const Text('بياناتي الشخصية وإكمال الملف')),
                const Divider(),
                const Text('الدعوات'),
                if (invites.isEmpty && !busy && error == null)
                  const Text('لا توجد دعوات.'),
                for (final i in invites)
                  Card(
                      child: ListTile(
                          title: Text(owner
                              ? (i['phoneNumber'] ?? '')
                              : (i['businessName'] ?? '')),
                          subtitle: Text(
                              '${i['grant']?['roleNameAr'] ?? roles[i['role']] ?? i['role']} — ${{
                                    'PENDING': 'بانتظار القبول',
                                    'ACCEPTED': 'مقبولة',
                                    'CANCELLED': 'ملغاة',
                                    'EXPIRED': 'منتهية'
                                  }[i['status']] ?? i['status']}'),
                          trailing: i['status'] == 'PENDING'
                              ? TextButton(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          if (await confirm(owner
                                              ? 'إلغاء الدعوة؟'
                                              : 'قبول دعوة هذا الفرع؟')) {
                                            if (mounted)
                                              await act({
                                                'action':
                                                    owner ? 'cancel' : 'accept',
                                                'businessId': i['businessId'],
                                                'requestId': i['requestId'],
                                                'baseVersion': i['version']
                                              });
                                          }
                                        },
                                  child: Text(owner ? 'إلغاء الدعوة' : 'قبول'))
                              : null)),
                const Divider(),
                Text(widget.employeeHome ? 'الفروع المفوضة لي' : 'العضويات'),
                if (members.isEmpty && !busy && error == null)
                  const Text('لا توجد عضويات.'),
                for (final m in members)
                  Card(
                      child: Column(children: [
                    ListTile(
                        title: Text(owner
                            ? (m['displayName'] ?? 'موظف')
                            : (m['businessName'] ?? '')),
                        subtitle: Text(
                            '${m['grant']?['roleNameAr'] ?? roles[m['role']] ?? m['role']} — ${m['status'] == 'ACTIVE' ? 'عضوية مقبولة' : 'مسحوبة'}')),
                    if (!owner && m['status'] == 'ACTIVE')
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  BranchDeviceSetupScreen(
                                                      businessId:
                                                          m['businessId']))),
                                  icon: const Icon(Icons.tablet_mac_outlined),
                                  label:
                                      const Text('تجهيز جهاز الفرع للعمل')))),
                    if (owner)
                      TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => StaffProductActivityScreen(
                                      businessId: widget.businessId!,
                                      subjectId: m['subjectId'],
                                      service: api))),
                          child: const Text('سجل نشاط الموظف')),
                    if (m['status'] == 'ACTIVE')
                      Wrap(children: [
                        if (owner)
                          TextButton(
                              onPressed: busy ? null : () => edit(m),
                              child: const Text('تغيير نوع الموظف')),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    if (await confirm(owner
                                        ? 'سحب عضوية الموظف؟'
                                        : 'مغادرة عضوية هذا الفرع؟')) {
                                      if (mounted)
                                        await act({
                                          'action': owner ? 'revoke' : 'leave',
                                          'businessId': m['businessId'],
                                          'subjectId': m['subjectId'],
                                          'baseVersion': m['version']
                                        });
                                    }
                                  },
                            child: Text(owner ? 'سحب العضوية' : 'مغادرة الفرع'))
                      ])
                  ])),
              ]))));
}
