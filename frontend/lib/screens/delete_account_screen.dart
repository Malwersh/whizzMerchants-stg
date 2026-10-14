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


class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, required this.scope, this.businessId, this.service});
  final AccountDeletionService? service;
  final String scope;
  final String? businessId;
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  late final AccountDeletionService _service;
  final _code = TextEditingController();
  final _requestId = const Uuid().v4();
  Map<String, dynamic>? _request;
  String? _challengeId, _phoneHint, _error;
  bool _busy = true, _confirmed = false, _statusKnown = false;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AccountDeletionService(scope: widget.scope, businessId: widget.businessId);
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
    final data = await _service.call('status', followReceipt: _request != null);
    if (widget.scope == 'ACCOUNT' && (data['request'] as Map?)?['status'] == 'COMPLETED') {
      if (await SecureTokenStorage.getAccessToken() != null) {
        await ref.read(authProviderRiverpod.notifier).signOut();
        await ref.read(sessionProvider.notifier).clearSession();
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
        return;
      }
    }
    if (widget.scope == 'BUSINESS' && (data['request'] as Map?)?['status'] == 'COMPLETED') {
      await ref.read(sessionProvider.notifier).clearBusinessSelection();
      ref.invalidate(businessProvider);
    }
    if (mounted) {
      setState(() {
        _request = data['request'] as Map<String, dynamic>?;
        _statusKnown = true;
      });
    }
  });

  Future<void> _send() => _perform(() async {
    final data = await _service.call('send', body: {'requestId': _requestId});
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
    'COMPLETED' => widget.scope == 'BUSINESS' ? 'اكتمل إغلاق وحذف المطعم' : widget.scope == 'MEMBERSHIP' ? 'اكتملت مغادرة المطعم وإزالة الصلاحيات' : 'اكتمل حذف الحساب',
    'PENDING_EXTERNAL_ASSET' => 'طلب الحذف مسجّل وينتظر إكمال الوصول إلى الملفات القديمة',
    'PENDING_SETTLEMENT' => 'طلب الحذف مسجّل وبانتظار تسوية الطلبات أو الأموال',
    'PENDING_POLICY' => 'طلب الحذف مسجّل وبانتظار اكتمال تجهيز التنفيذ',
    'PROCESSING' => 'حذف الحساب قيد التنفيذ',
    'RETRY_REQUIRED' => 'طلبك محفوظ؛ التنفيذ يحتاج متابعة وإعادة محاولة',
    _ => 'طلب الحذف مسجّل وبانتظار التنفيذ',
  };

  String _blocker(Map<String, dynamic> item) => switch (item['code']) {
    'REFUND_REQUIRED' =>
      'رصيد يحتاج تسوية: ${item['amount']} د.ع. يمكنك تحويله إلى محفظة أخرى أو طلب صرف زين كاش من الإدارة.',
    'AMOUNT_DUE' => 'يوجد مبلغ مستحق يحتاج تسوية.',
    'ACTIVE_ORDERS' => 'توجد طلبات لم تنتهِ بعد.',
    'ACTIVE_HOLDS' || 'LOCKED_BALANCE' => 'توجد أموال محجوزة مرتبطة بالطلبات.',
    'PENDING_TRANSFERS' => 'توجد تحويلات لم تُحسم بعد.',
    'EXTERNAL_ASSET_ACCESS_REQUIRED' => 'تحتاج الإدارة إكمال الوصول إلى مخزن صورة المطعم القديمة قبل تنفيذ التنظيف.',
    'OWNED_BUSINESSES' => 'يجب نقل ملكية المطاعم التي تملكها أو إغلاقها قبل حذف حسابك.',
    'PENDING_PAYMENTS' => 'توجد عمليات دفع أو شحن لم تُحسم بعد.',
    _ => 'يوجد إجراء يحتاج متابعة قبل تنفيذ الحذف.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WhizzColors.backgroundPrimary,
    appBar: AppBar(
      title: Text(widget.scope == 'BUSINESS' ? 'إغلاق وحذف المطعم' : widget.scope == 'MEMBERSHIP' ? 'مغادرة المطعم' : 'حذف الحساب'),
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
            widget.scope == 'BUSINESS' ? 'حذف بيانات المطعم الخاصة' : widget.scope == 'MEMBERSHIP' ? 'إزالة عضويتك وصلاحياتك في المطعم' : 'حذف حسابك وبياناتك الشخصية',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            widget.scope == 'MEMBERSHIP' ? 'تُزال صلاحياتك في هذا المطعم فقط. يبقى حسابك الشخصي وحساب المطعم ومحفظته كما هي، ويمكن للمالك منحك عضوية جديدة لاحقًا.' : 'يتطلب الحذف التحقق من هويتك وتسوية الطلبات والمحفظة. حذف المطعم لا يحذف حساب مالكه أو حسابات الموظفين. حذف حساب المالك يتطلب أولًا نقل ملكية مطاعمه أو إغلاقها. نحتفظ بالسجلات المالية الضرورية لمدة 7 سنوات وفق السياسة الحالية، وبالبيانات اللازمة لنزاع أو التزام موثّق قائم.',
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
                child: Text(_blocker(Map<String, dynamic>.from(item as Map))),
              ),
            SelectableText(
              'مرجع الطلب: ${_request!['requestId']}',
              style: const TextStyle(color: WhizzColors.textSecondary),
            ),
          ] else ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: WhizzColors.secondary,
              value: _confirmed,
              onChanged:
                  _busy
                      ? null
                      : (v) => setState(() {
                        _confirmed = v ?? false;
                      }),
              title: Text(widget.scope == 'MEMBERSHIP' ? 'أوافق على مغادرة المطعم وإزالة صلاحياتي' : 'أفهم أثر حذف الحساب وأريد متابعة الطلب'),
            ),
            if (_challengeId != null) ...[
              Text(
                'أرسلنا رمزًا إلى رقم حسابك $_phoneHint. أدخله لتأكيد طلب الحذف.',
              ),
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
                onPressed: _busy || !_confirmed ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: WhizzColors.secondary,
                  foregroundColor: WhizzColors.white,
                ),
                child: const Text('تأكيد طلب الحذف'),
              ),
            ],
            TextButton(
              onPressed:
                  _busy || !_confirmed || !_statusKnown || _resendSeconds > 0
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
              child: CircularProgressIndicator(color: WhizzColors.secondary),
            ),
          if (widget.scope == 'BUSINESS' && _request?['status'] == 'COMPLETED')
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeleteAccountScreen(scope: 'ACCOUNT'))),
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

Future<void> openMerchantDeletion(BuildContext context, String? businessId) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: WhizzColors.white,
    builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(20), child: Text('إدارة الحذف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      if (businessId != null) ListTile(
        leading: const Icon(Icons.store_outlined, color: WhizzColors.secondary),
        title: const Text('إغلاق وحذف المطعم'),
        subtitle: const Text('بعد تسوية الطلبات والمحفظة، مع إبقاء حسابك'),
        onTap: () => Navigator.pop(context, 'BUSINESS'),
      ),
      ListTile(
        leading: const Icon(Icons.person_remove_outlined, color: WhizzColors.secondary),
        title: const Text('حذف حسابي الشخصي'),
        subtitle: const Text('يتطلب نقل ملكية مطاعمك أو إغلاقها أولًا'),
        onTap: () => Navigator.pop(context, 'ACCOUNT'),
      ),
      const SizedBox(height: 16),
    ])),
  );
  if (choice == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeleteAccountScreen(scope: choice, businessId: choice == 'BUSINESS' ? businessId : null)));
}
