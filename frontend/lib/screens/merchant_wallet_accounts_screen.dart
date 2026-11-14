import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/whizz_colors.dart';
import '../services/wallet_transfer_service.dart';
import '../providers/auth_provider_riverpod.dart';
import 'wallet_transfer_screen.dart';
import 'delete_account_screen.dart';
import 'auth/auth_screen.dart';

class MerchantWalletAccountsScreen extends ConsumerStatefulWidget {
  const MerchantWalletAccountsScreen({super.key});
  @override
  ConsumerState<MerchantWalletAccountsScreen> createState() =>
      _MerchantWalletAccountsScreenState();
}

class _MerchantWalletAccountsScreenState
    extends ConsumerState<MerchantWalletAccountsScreen> {
  final api = WalletTransferService(businessId: '');
  List<Map<String, dynamic>> accounts = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await api.call('accounts');
      if (mounted) {
        setState(() =>
            accounts = List<Map<String, dynamic>>.from(r['accounts'] ?? []));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: WhizzColors.grey50,
          appBar: AppBar(title: const Text('محافظ المطاعم'), actions: [
            IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () =>
                    ref.read(authProviderRiverpod.notifier).signOut(),
                icon: const Icon(Icons.logout))
          ]),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    const Text(
                        'تظهر هنا المطاعم التي تملكها أو مُنحت صلاحية مالية عليها.'),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeleteAccountScreen(scope: 'ACCOUNT'))),
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('حذف حسابي الشخصي'),
                    ),
                    if (error != null) ...[
                      Text(error!),
                      TextButton(
                          onPressed: _load, child: const Text('إعادة المحاولة'))
                    ],
                    if (accounts.isEmpty && error == null) ...[
                      const Text(
                          'لا توجد محافظ متاحة لحسابك. اطلب من صاحب المطعم تعيينك موظفًا ماليًا باستخدام بريدك المسجل.'),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AuthScreen())),
                          child: const Text('إعداد حساب متجر'))
                    ],
                    for (final a in accounts)
                      Card(
                          color: Colors.white,
                          elevation: 0,
                          child: ListTile(
                              leading: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: WhizzColors.secondary),
                              title: Text(a['name'] ?? 'المطعم'),
                              subtitle: Text(a['isOwner'] == true
                                  ? 'صاحب المطعم'
                                  : 'موظف مالي'),
                              trailing: a['isOwner'] == true ? const Icon(Icons.chevron_left) : PopupMenuButton<String>(
                                onSelected: (_) async {
                                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeleteAccountScreen(scope: 'MEMBERSHIP', businessId: a['businessId'])));
                                  if (mounted) await _load();
                                },
                                itemBuilder: (_) => [const PopupMenuItem(value: 'leave', child: Text('مغادرة المطعم وإزالة صلاحياتي'))],
                              ),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => WalletTransferScreen(
                                          businessId: a['businessId'])))))
                  ]))));
}
