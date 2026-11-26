import 'package:flutter/material.dart';
import '../services/wallet_transfer_service.dart';
import '../core/theme/whizz_colors.dart';

class MerchantFinanceMembersScreen extends StatefulWidget {
  final String businessId;
  const MerchantFinanceMembersScreen({super.key, required this.businessId});
  @override
  State<MerchantFinanceMembersScreen> createState() =>
      _MerchantFinanceMembersScreenState();
}

class _MerchantFinanceMembersScreenState
    extends State<MerchantFinanceMembersScreen> {
  late final api = WalletTransferService(businessId: widget.businessId);
  final email = TextEditingController();
  List<Map<String, dynamic>> members = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('members');
      if (mounted) {
        setState(() =>
            members = List<Map<String, dynamic>>.from(r['members'] ?? []));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save(String address, bool enabled) async {
    if (busy) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title:
                    Text(enabled ? 'منح صلاحية مالية' : 'سحب الصلاحية المالية'),
                content: Text(enabled
                    ? 'سيستطيع $address عرض رصيد المطعم وسجل التحويلات وإرسال مبالغ ضمن الحدود المحددة.'
                    : 'لن يستطيع $address إرسال تحويلات أو عرض المحفظة بعد سحب الصلاحية.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد'))
                ]));
    if (yes != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.call('members', body: {'email': address, 'enabled': enabled});
      email.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: WhizzColors.grey50,
          appBar: AppBar(
              title: const Text('الموظفون الماليون'),
              backgroundColor: Colors.white),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            const Text(
                'تُمنح الصلاحية لحساب موظف مسجل في تطبيق المطعم. صلاحية إدارة الطلبات وحدها لا تسمح بالتحويل.'),
            const SizedBox(height: 24),
            TextField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.text,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    labelText: 'بريد الموظف الموثّق أو رقم هاتفه',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: WhizzColors.primary,
                    foregroundColor: WhizzColors.secondary),
                onPressed: busy ? null : () => _save(email.text.trim(), true),
                child: const Text('تعيين موظف مالي')),
            if (busy)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(error!)),
            const SizedBox(height: 24),
            for (final m in members)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m['memberEmail'] ?? ''),
                  subtitle: Text(m['enabled'] == true
                      ? 'صلاحية مالية نشطة'
                      : 'الصلاحية مسحوبة'),
                  trailing: TextButton(
                      onPressed: busy
                          ? null
                          : () => _save(m['memberEmail'], m['enabled'] != true),
                      child: Text(m['enabled'] == true ? 'سحب' : 'تفعيل')))
          ])));
}
