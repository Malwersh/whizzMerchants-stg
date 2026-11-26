import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/whizz_colors.dart';
import '../services/account_deletion_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/business_provider.dart';
import '../services/secure_token_storage.dart';
import 'auth/auth_screen.dart';
import 'merchant_wallet_accounts_screen.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen(
      {super.key, required this.scope, this.businessId, this.service});
  final AccountDeletionService? service;
  final String scope;
  final String? businessId;
  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  late final AccountDeletionService _service;
  final _code = TextEditingController();
  final _requestId = const Uuid().v4();
  Map<String, dynamic>? _request;
  List<Map<String, dynamic>>? _accountBlockers;
  List<Map<String, dynamic>> _ownedBusinesses = [];
  String? _challengeId, _phoneHint, _error;
  bool _busy = true, _confirmed = false, _statusKnown = false;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        AccountDeletionService(
            scope: widget.scope, businessId: widget.businessId);
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.close();
    _code.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refresh() => _perform(() async {
        _accountBlockers = null;
        final data =
            await _service.call('status', followReceipt: _request != null);
        if (widget.scope == 'ACCOUNT' && data['request'] == null) {
          final eligibility = await _service.call('eligibility');
          _accountBlockers = _issues(eligibility['blockers']);
          _ownedBusinesses = _issues(eligibility['businesses']);
        }
        if (widget.scope == 'ACCOUNT' &&
            (data['request'] as Map?)?['status'] == 'COMPLETED') {
          if (await SecureTokenStorage.getAccessToken() != null) {
            await ref.read(authProviderRiverpod.notifier).signOut();
            await ref.read(sessionProvider.notifier).clearSession();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (_) => false);
            }
            return;
          }
        }
        if (widget.scope == 'BUSINESS' &&
            (data['request'] as Map?)?['status'] == 'COMPLETED') {
          if (ref.read(sessionProvider).businessId == widget.businessId) {
            await ref.read(sessionProvider.notifier).clearBusinessSelection();
            ref.invalidate(businessProvider);
          }
        }
        if (mounted) {
          setState(() {
            _request = data['request'] as Map<String, dynamic>?;
            _statusKnown = true;
          });
        }
      });

  List<Map<String, dynamic>> _issues(dynamic items) => (items as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  bool get _canStart =>
      _statusKnown &&
      (widget.scope != 'ACCOUNT' || _accountBlockers?.isEmpty == true);

  Future<void> _openResolution(Widget destination) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => destination));
    if (mounted) await _refresh();
  }

  Future<void> _send() => _perform(() async {
        final data =
            await _service.call('send', body: {'requestId': _requestId});
        if (!mounted) return;
        setState(() {
          _challengeId = data['challengeId'] as String;
          _phoneHint = data['phoneHint'] as String?;
          _resendSeconds = (data['resendAfter'] as num).toInt();
          _code.clear();
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || _resendSeconds <= 1) {
            timer.cancel();
          }
          if (mounted) {
            setState(() {
              _resendSeconds = (_resendSeconds - 1).clamp(0, 60);
            });
          }
        });
      });

  Future<void> _submit() => _perform(() async {
        final data = await _service.call(
          'request',
          body: {
            'requestId': _requestId,
            'challengeId': _challengeId,
            'code': _code.text.trim(),
          },
        );
        if (mounted) {
          setState(() {
            _request = data;
            _code.clear();
          });
        }
      });

  String get _statusText => switch (_request?['status']) {
        'COMPLETED' => widget.scope == 'BUSINESS'
            ? 'اكتمل إغلاق وحذف المطعم'
            : widget.scope == 'MEMBERSHIP'
                ? 'اكتملت مغادرة المطعم وإزالة الصلاحيات'
                : 'اكتمل حذف الحساب',
        'PENDING_EXTERNAL_ASSET' =>
          'طلب الحذف مسجّل وينتظر إكمال الوصول إلى الملفات القديمة',
        'PENDING_SETTLEMENT' => widget.scope == 'BUSINESS'
            ? 'طلب إغلاق الفرع مسجّل وبانتظار تسوية الطلبات أو الأموال'
            : 'طلب الحذف مسجّل وبانتظار تسوية الطلبات أو الأموال',
        'CANCELLED' => widget.scope == 'BUSINESS'
            ? 'أُلغي طلب إغلاق الفرع'
            : 'أُلغي طلب الحذف',
        'PENDING_POLICY' => 'طلب الحذف مسجّل وبانتظار اكتمال تجهيز التنفيذ',
        'PROCESSING' => widget.scope == 'BUSINESS'
            ? 'إغلاق الفرع قيد التنفيذ'
            : 'حذف الحساب قيد التنفيذ',
        'RETRY_REQUIRED' => 'طلبك محفوظ؛ التنفيذ يحتاج متابعة وإعادة محاولة',
        _ => 'طلب الحذف مسجّل وبانتظار التنفيذ',
      };

  String? _branchResolution(Map<String, dynamic> item) =>
      switch (item['code']) {
        'ACTIVE_ORDERS' =>
          'راجع الطلبات المفتوحة في تطبيق المطعم وأكمل معالجتها.',
        'PENDING_PAYMENTS' ||
        'PENDING_TRANSFERS' =>
          'راجع العمليات المعلّقة في المحفظة. أحِل العملية إلى الإدارة المالية إذا كانت تنتظر اعتمادها.',
        'ACTIVE_HOLDS' ||
        'LOCKED_BALANCE' =>
          'اطلب من الإدارة المالية مراجعة العملية المرتبطة بالحجز وتسويتها.',
        'REFUND_REQUIRED' ||
        'AMOUNT_DUE' =>
          'راجع الرصيد مع الإدارة المالية لاستكمال الصرف أو التحصيل.',
        'EXTERNAL_ASSET_ACCESS_REQUIRED' =>
          'تراجع الإدارة وصولها إلى ملفات الفرع القديمة.',
        _ => null,
      };

  String _blockerDetails(Map<String, dynamic> item) {
    final message = _blocker(item);
    final resolution =
        widget.scope == 'BUSINESS' ? _branchResolution(item) : null;
    return resolution == null ? message : '$message\n$resolution';
  }

  String _blocker(Map<String, dynamic> item) => switch (item['code']) {
        'REFUND_REQUIRED' =>
          'رصيد يحتاج تسوية: ${item['amount']} د.ع. يمكنك تحويله إلى محفظة أخرى أو طلب صرف زين كاش من الإدارة.',
        'AMOUNT_DUE' =>
          'مبلغ مستحق يحتاج تسوية: ${(item['amount'] as num?)?.abs() ?? 'غير متاح'} د.ع.',
        'ACTIVE_ORDERS' => 'توجد طلبات لم تنتهِ بعد.',
        'ACTIVE_HOLDS' => 'توجد أموال محجوزة مرتبطة بالطلبات.',
        'LOCKED_BALANCE' => 'رصيد محجوز: ${item['amount']} د.ع.',
        'PENDING_TRANSFERS' => 'توجد تحويلات لم تُحسم بعد.',
        'EXTERNAL_ASSET_ACCESS_REQUIRED' =>
          'تحتاج الإدارة إكمال الوصول إلى مخزن صورة المطعم القديمة قبل تنفيذ التنظيف.',
        'OWNED_BUSINESSES' =>
          'يجب نقل ملكية المطاعم التي تملكها أو إغلاقها قبل حذف حسابك.',
        'PENDING_PAYMENTS' => 'توجد عمليات دفع أو شحن لم تُحسم بعد.',
        _ => 'يوجد إجراء يحتاج متابعة قبل تنفيذ الحذف.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WhizzColors.backgroundPrimary,
        appBar: AppBar(
          title: Text(widget.scope == 'BUSINESS'
              ? 'إغلاق وحذف المطعم'
              : widget.scope == 'MEMBERSHIP'
                  ? 'مغادرة المطعم'
                  : 'حذف الحساب'),
          centerTitle: true,
          backgroundColor: WhizzColors.white,
          foregroundColor: WhizzColors.secondary,
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.person_remove_outlined,
                size: 48,
                color: WhizzColors.secondary,
              ),
              const SizedBox(height: 20),
              Text(
                widget.scope == 'BUSINESS'
                    ? 'إغلاق الفرع وحذف بياناته'
                    : widget.scope == 'MEMBERSHIP'
                        ? 'إزالة عضويتك وصلاحياتك في المطعم'
                        : 'حذف حسابك وبياناتك الشخصية',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                widget.scope == 'MEMBERSHIP'
                    ? 'تُزال صلاحياتك في هذا المطعم فقط. يبقى حسابك الشخصي وحساب المطعم ومحفظته كما هي، ويمكن للمالك منحك عضوية جديدة لاحقًا.'
                    : widget.scope == 'BUSINESS'
                        ? 'بعد تأكيد طلب الإغلاق يتوقف استقبال طلبات الزبائن الجديدة في هذا الفرع. يكتمل الإغلاق بعد معالجة الطلبات القائمة وتسوية المحفظة. يبقى حسابك الشخصي وحسابات الموظفين قائمة. تُحفظ السجلات المالية المطلوبة وفق سياسة الاحتفاظ.'
                        : 'يتطلب حذف الحساب التحقق من هويتك. أغلق الفروع التي تملكها أو انقل ملكيتها أولًا. تُحفظ السجلات المالية المطلوبة وفق سياسة الاحتفاظ.',
                style: TextStyle(height: 1.7, color: WhizzColors.textSecondary),
              ),
              const SizedBox(height: 24),
              if (_request != null) ...[
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in (_request!['blockers'] as List? ?? []))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_blockerDetails(
                        Map<String, dynamic>.from(item as Map))),
                  ),
                SelectableText(
                  'مرجع الطلب: ${_request!['requestId']}',
                  style: const TextStyle(color: WhizzColors.textSecondary),
                ),
              ] else ...[
                if (widget.scope == 'ACCOUNT' && _accountBlockers != null) ...[
                  Text(
                    _accountBlockers!.isEmpty
                        ? 'لا توجد موانع حالية لحذف الحساب.'
                        : 'موانع حذف الحساب الحالية',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final item in _accountBlockers!) Text(_blocker(item)),
                  for (final business in _ownedBusinesses)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(business['name'] as String),
                            for (final item in _issues(business['blockers']))
                              Text(_blocker(item)),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _openResolution(
                                        DeleteAccountScreen(
                                            scope: 'BUSINESS',
                                            businessId: business['businessId']
                                                as String),
                                      ),
                              child: const Text('إدارة إغلاق المطعم'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_ownedBusinesses.isNotEmpty)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _openResolution(
                              const MerchantWalletAccountsScreen()),
                      child: const Text('مراجعة المحافظ والتسويات'),
                    ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: WhizzColors.secondary,
                  value: _confirmed,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _confirmed = v ?? false;
                          }),
                  title: Text(widget.scope == 'MEMBERSHIP'
                      ? 'أوافق على مغادرة المطعم وإزالة صلاحياتي'
                      : widget.scope == 'BUSINESS'
                          ? 'أوافق على إغلاق هذا الفرع وأريد متابعة الطلب'
                          : 'أفهم أثر حذف الحساب وأريد متابعة الطلب'),
                ),
                if (_challengeId != null) ...[
                  Text(
                      'أرسلنا رمزًا إلى رقم حسابك $_phoneHint. أدخله لتأكيد الطلب.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'رمز التحقق',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _busy || !_confirmed || !_canStart ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: WhizzColors.secondary,
                      foregroundColor: WhizzColors.white,
                    ),
                    child: Text(widget.scope == 'BUSINESS'
                        ? 'تأكيد طلب إغلاق الفرع'
                        : 'تأكيد طلب الحذف'),
                  ),
                ],
                TextButton(
                  onPressed:
                      _busy || !_confirmed || !_canStart || _resendSeconds > 0
                          ? null
                          : _send,
                  child: Text(
                    _resendSeconds > 0
                        ? 'إعادة الإرسال بعد $_resendSeconds ثانية'
                        : _challengeId == null
                            ? 'إرسال رمز التحقق'
                            : 'إعادة إرسال الرمز',
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: WhizzColors.secondary),
                  ),
                ),
              if (_busy)
                const Center(
                  child:
                      CircularProgressIndicator(color: WhizzColors.secondary),
                ),
              if (widget.scope == 'BUSINESS' &&
                  _request?['status'] == 'COMPLETED')
                FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          const DeleteAccountScreen(scope: 'ACCOUNT'))),
                  child: const Text('متابعة حذف حسابي الشخصي'),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _busy ? null : _refresh,
                child: const Text('تحديث حالة الطلب'),
              ),
            ],
          ),
        ),
      );
}

Future<void> openMerchantDeletion(
    BuildContext context, String? businessId) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: WhizzColors.white,
    builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(
          padding: EdgeInsets.all(20),
          child: Text('إدارة الحذف',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      if (businessId != null)
        ListTile(
          leading:
              const Icon(Icons.store_outlined, color: WhizzColors.secondary),
          title: const Text('إغلاق وحذف المطعم'),
          subtitle: const Text('بعد تسوية الطلبات والمحفظة، مع إبقاء حسابك'),
          onTap: () => Navigator.pop(context, 'BUSINESS'),
        ),
      ListTile(
        leading: const Icon(Icons.person_remove_outlined,
            color: WhizzColors.secondary),
        title: const Text('حذف حسابي الشخصي'),
        subtitle: const Text('يتطلب نقل ملكية مطاعمك أو إغلاقها أولًا'),
        onTap: () => Navigator.pop(context, 'ACCOUNT'),
      ),
      const SizedBox(height: 16),
    ])),
  );
  if (choice == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DeleteAccountScreen(
          scope: choice,
          businessId: choice == 'BUSINESS' ? businessId : null)));
}
