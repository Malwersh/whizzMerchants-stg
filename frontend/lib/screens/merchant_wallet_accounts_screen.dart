import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/whizz_colors.dart';
import '../services/wallet_transfer_service.dart';
import '../providers/auth_provider_riverpod.dart';
import '../widgets/merchant_workspace_widgets.dart';
import 'wallet_transfer_screen.dart';
import 'delete_account_screen.dart';
import 'auth/auth_screen.dart';
import 'auth/auth_surface.dart';

final merchantWalletAccountsLoaderProvider =
    Provider<Future<Map<String, dynamic>> Function()>(
        (ref) => () => WalletTransferService(businessId: '').call('accounts'));

class MerchantWalletAccountsScreen extends StatelessWidget {
  const MerchantWalletAccountsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthSurface(child: _MerchantWalletAccountsContent());
}

class _MerchantWalletAccountsContent extends ConsumerStatefulWidget {
  const _MerchantWalletAccountsContent();
  @override
  ConsumerState<_MerchantWalletAccountsContent> createState() =>
      _MerchantWalletAccountsScreenState();
}

class _MerchantWalletAccountsScreenState
    extends ConsumerState<_MerchantWalletAccountsContent> {
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
      final result = await ref.read(merchantWalletAccountsLoaderProvider)();
      if (mounted) {
        setState(() {
          accounts = List<Map<String, dynamic>>.from(result['accounts'] ?? []);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'تعذر تحميل المحافظ. تحقق من الاتصال وأعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('المحافظ والصلاحيات'),
            actions: [
              IconButton(
                tooltip: 'تسجيل الخروج',
                icon: const Icon(Icons.logout),
                onPressed: () =>
                    ref.read(authProviderRiverpod.notifier).signOut(),
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
                        title: 'محافظ أعمالك',
                        subtitle:
                            'تظهر هنا المطاعم التي تملكها أو مُنحت صلاحية مالية عليها.',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(height: 24),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (error != null)
                        MerchantWorkspaceMessage(
                          message: error!,
                          isError: true,
                          onRetry: _load,
                        )
                      else if (accounts.isEmpty) ...[
                        const MerchantWorkspaceMessage(
                          message:
                              'لا توجد محافظ متاحة لحسابك. اطلب من صاحب المطعم تعيينك موظفًا ماليًا باستخدام بريدك المسجل.',
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AuthScreen()),
                          ),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('إعداد حساب متجر'),
                        ),
                      ],
                      for (final a in accounts)
                        Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF2FA),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: WhizzColors.secondary,
                              ),
                            ),
                            title: Text(
                              a['name'] ?? 'المطعم',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                a['isOwner'] == true
                                    ? 'صاحب المطعم'
                                    : 'موظف مالي',
                                style:
                                    const TextStyle(color: Color(0xFF42526B)),
                              ),
                            ),
                            trailing: a['isOwner'] == true
                                ? const Icon(Icons.chevron_left)
                                : PopupMenuButton<String>(
                                    tooltip: 'خيارات الصلاحية',
                                    onSelected: (_) async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DeleteAccountScreen(
                                            scope: 'MEMBERSHIP',
                                            businessId: a['businessId'],
                                          ),
                                        ),
                                      );
                                      if (mounted) await _load();
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'leave',
                                        child: Text(
                                          'مغادرة المطعم وإزالة صلاحياتي',
                                        ),
                                      ),
                                    ],
                                  ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WalletTransferScreen(
                                  businessId: a['businessId'],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DeleteAccountScreen(scope: 'ACCOUNT'),
                          ),
                        ),
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('إدارة حذف حسابي الشخصي'),
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
