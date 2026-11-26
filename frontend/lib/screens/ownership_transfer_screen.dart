import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../services/person_onboarding_service.dart';
import '../services/account_deletion_service.dart';
import '../services/app_auth_service.dart';

class OwnershipTransferScreen extends StatefulWidget {
  const OwnershipTransferScreen(
      {super.key, this.businessId, this.businessName});
  final String? businessId;
  final String? businessName;

  @override
  State<OwnershipTransferScreen> createState() =>
      _OwnershipTransferScreenState();
}

class _OwnershipTransferScreenState extends State<OwnershipTransferScreen> {
  final _api = PersonOnboardingService();
  final _recipient = TextEditingController();
  final _destinationCode = TextEditingController();
  final _newRequestId = const Uuid().v4();
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _agreement;
  bool _busy = false, _consent = false;
  String? _error, _destinationChallengeId, _maskedDestination;
  bool _destinationVerified = false;
  bool _destinationProfileRequired = false;
  List<String>? _previewBlockers;
  List<Map<String, dynamic>>? _invitations;

  @override
  void initState() {
    super.initState();
    if (widget.businessId != null &&
        (AppConfig.ownershipTransferEnabled ||
            AppConfig.ownershipPreviewEnabled(widget.businessId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(_loadSelectedBranch);
      });
    } else if (AppConfig.ownershipTransferEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(_loadInvitations);
      });
    }
  }

  Future<void> _loadInvitations() async {
    final data = await _api.call('ownership-transfer?incoming=1');
    final invitations =
        List<Map<String, dynamic>>.from(data['invitations'] as List);
    if (mounted) setState(() => _invitations = invitations);
  }

  @override
  void dispose() {
    _api.client.close();
    _recipient.dispose();
    _destinationCode.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _lookupPath(String organizationId, String requestId) =>
      Uri(path: 'ownership-transfer', queryParameters: {
        'organizationId': organizationId,
        'requestId': requestId,
      }).toString();

  Future<Map<String, dynamic>> _selectedBranchScope() => _api.call(
        Uri(path: 'ownership-transfer', queryParameters: {
          'businessId': widget.businessId!,
        }).toString(),
      );

  Future<void> _loadSelectedBranch() async {
    if (AppConfig.ownershipTransferEnabled) {
      final scope = await _selectedBranchScope();
      final activeRequestId = scope['activeRequestId'] as String?;
      if (activeRequestId != null) {
        await _load(scope['organizationId'] as String, activeRequestId);
        return;
      }
    }
    await _preview();
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _load(String organizationId, String requestId) async {
    final data = await _api.call(_lookupPath(organizationId, requestId));
    if (!mounted) return;
    setState(() {
      final next = data['request'] as Map<String, dynamic>;
      if (_request?['requestId'] != next['requestId']) {
        _destinationVerified = false;
        _destinationChallengeId = null;
        _maskedDestination = null;
        _destinationCode.clear();
      }
      _request = next;
      _agreement = data['agreement'] as Map<String, dynamic>?;
      _consent = false;
      _setDestination(data['destination'] as Map<String, dynamic>?);
    });
  }

  Future<void> _start() async {
    final recipient = AppAuthService.normalizeIraqiPhone(_recipient.text);
    if (recipient == null) {
      throw Exception('أدخل رقم هاتف المالك الجديد المسجّل في التطبيق.');
    }
    final scope = await _selectedBranchScope();
    final organizationId = scope['organizationId'] as String;
    final preview = await _api.call('ownership-transfer', body: {
      'action': 'PREVIEW_RECIPIENT',
      'organizationId': organizationId,
      'requestId': _newRequestId,
      'businessId': widget.businessId!,
      'recipientPhone': recipient,
    });
    if (!mounted) return;
    final confirmedRecipient = preview['recipient'] as Map<String, dynamic>;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تأكيد إرسال دعوة النقل',
                      style: theme.textTheme.headlineSmall),
                  if (widget.businessName != null) ...[
                    const SizedBox(height: 6),
                    Text(widget.businessName!,
                        style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 20),
                  Card.filled(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.person_outline_rounded)),
                      title: Text(confirmedRecipient['name'] as String),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المالك الجديد'),
                          Text(confirmedRecipient['phone'] as String,
                              textDirection: TextDirection.ltr),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'عند إرسال الدعوة، يتوقف استقبال طلبات الزبائن الجديدة في الفروع المشمولة. يستلزم إتمام النقل قبول المالك الجديد واعتماد الإدارة.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheet, true),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('إرسال الدعوة'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheet, false),
                    child: const Text('تعديل رقم الهاتف'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _api.call('ownership-transfer', body: {
      'action': 'START',
      'organizationId': organizationId,
      'requestId': _newRequestId,
      'recipientPhone': recipient,
      'expectedRecipientId': confirmedRecipient['id'],
    });
    await _load(organizationId, _newRequestId);
  }

  Future<void> _decide(String action) async {
    final request = _request!;
    await _api.call('ownership-transfer', body: {
      'action': action,
      'organizationId': request['organizationId'],
      'requestId': request['requestId'],
      if (action == 'ACCEPT') ...{
        'digest': request['digest'],
        'agreementVersion': _agreement!['version'],
      },
    });
    await _load(
        request['organizationId'] as String, request['requestId'] as String);
  }

  Future<void> _verifyDestination(bool submitCode) async {
    final request = _request!;
    final code = _destinationCode.text.trim();
    if (submitCode && code.length != 6) {
      throw Exception('أدخل رمز التحقق المكوّن من ستة أرقام.');
    }
    final data = await _api.call('ownership-transfer', body: {
      'action': submitCode ? 'VERIFY_DESTINATION' : 'START_DESTINATION',
      'organizationId': request['organizationId'],
      'requestId': request['requestId'],
      if (submitCode) ...{
        'challengeId': _destinationChallengeId,
        'code': code,
      },
    });
    if (!mounted) return;
    setState(
        () => _setDestination(data['destination'] as Map<String, dynamic>?));
  }

  void _setDestination(Map<String, dynamic>? destination) {
    _destinationVerified = destination?['status'] == 'VERIFIED';
    _destinationProfileRequired = destination?['status'] == 'PROFILE_REQUIRED';
    final challenge = destination?['challengeId'] as String?;
    if (_destinationChallengeId != challenge) _destinationCode.clear();
    _destinationChallengeId = challenge;
    _maskedDestination = destination?['destination'] as String?;
  }

  Widget _invitationCard(Map<String, dynamic> invitation) {
    final theme = Theme.of(context);
    final names =
        (invitation['branchNames'] as List).whereType<String>().join('، ');
    final accepted = invitation['status'] == 'AWAITING_REVIEW';
    final needsPhone =
        accepted && invitation['destinationStatus'] != 'VERIFIED';
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const CircleAvatar(child: Icon(Icons.storefront_outlined)),
              title: Text(names.isEmpty ? 'نشاط تجاري' : names,
                  style: theme.textTheme.titleMedium),
              subtitle: Text(
                  accepted ? 'بانتظار مراجعة الإدارة' : 'دعوة بانتظار ردّك'),
            ),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(() => _load(
                        invitation['organizationId'] as String,
                        invitation['requestId'] as String,
                      )),
              child: Text(
                  needsPhone ? 'تأكيد هاتف التسويات' : 'عرض تفاصيل طلب النقل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preview() async {
    final service = AccountDeletionService(
      scope: 'BUSINESS',
      businessId: widget.businessId,
    );
    try {
      final result = await service.call('eligibility');
      final rows = result['blockers'] as List<dynamic>;
      final orders = result['activeOrders'] as List<dynamic>? ?? [];
      final messagesForActiveOrders = orders.any(
        (order) =>
            (order as Map)['status']?.toString().toLowerCase() != 'expired',
      );
      final messages = rows
          .where((item) =>
              (item as Map)['code'] != 'ACTIVE_ORDERS' ||
              messagesForActiveOrders)
          .map((item) {
        final issue = item as Map<String, dynamic>;
        return switch (issue['code']) {
          'LOCKED_BALANCE' => 'رصيد محجوز يحتاج تسوية: ${issue['amount']} د.ع.',
          'REFUND_REQUIRED' => 'رصيد متاح يحتاج تسوية: ${issue['amount']} د.ع.',
          'AMOUNT_DUE' =>
            'مبلغ مستحق يحتاج تسوية: ${(issue['amount'] as num).abs()} د.ع.',
          'ACTIVE_ORDERS' => 'توجد طلبات مفتوحة.',
          'PENDING_PAYMENTS' =>
            'توجد عمليات مالية معلّقة أو حالات تحتاج مراجعة.',
          'PENDING_TRANSFERS' => 'توجد تحويلات معلّقة.',
          'ACTIVE_HOLDS' => 'توجد حجوزات مرتبطة بالطلبات.',
          _ => 'يحتاج الفرع إلى مراجعة قبل النقل (${issue['code']}).',
        };
      }).toList();
      if (mounted) setState(() => _previewBlockers = messages);
    } finally {
      service.close();
    }
  }

  List<Widget> _eligibilityDetails() {
    final blockers = _previewBlockers;
    if (_busy && blockers == null) {
      return const [Text('جارٍ التحقق من جاهزية النشاط للنقل…')];
    }
    if (blockers == null) return const [];
    if (blockers.isEmpty) {
      return const [
        Text('لم تظهر موانع مالية أو طلبات مفتوحة في الفحص الحالي.')
      ];
    }
    return [
      const Text('قبل إتمام النقل',
          style: TextStyle(fontWeight: FontWeight.bold)),
      for (final message in blockers)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: Text(message),
        ),
      const Text('بعد معالجة هذه الأمور، حدّث حالة النشاط لمراجعة النتيجة.'),
    ];
  }

  Widget _previewBody() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ..._eligibilityDetails(),
          if (_error != null) Text(_error!),
          if (_busy)
            const LinearProgressIndicator()
          else
            OutlinedButton(
              onPressed: () => _run(_preview),
              child: Text(
                  _previewBlockers == null ? 'إعادة المحاولة' : 'تحديث الحالة'),
            ),
          const SizedBox(height: 12),
          const Text(
              'إرسال طلب نقل الملكية غير متاح في نسخة الاختبار الحالية.'),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final request = _request;
    final branchNames =
        (request?['branchNames'] as List?)?.whereType<String>().toList() ??
            const <String>[];
    final branchCount = (request?['branchIds'] as List?)?.length ?? 0;
    final isOwner = request?['participant'] == 'OWNER';
    final status = request?['status'];
    final expiresAt = request?['expiresAt'] as int?;
    final pending = expiresAt != null &&
        expiresAt > DateTime.now().millisecondsSinceEpoch &&
        (status == 'AWAITING_REVIEW' || status == 'AWAITING_RECIPIENT');
    final statusText = !pending &&
            (status == 'AWAITING_REVIEW' || status == 'AWAITING_RECIPIENT')
        ? 'منتهي الصلاحية'
        : const {
            'AWAITING_REVIEW': 'بانتظار مراجعة الإدارة',
            'AWAITING_RECIPIENT': 'بانتظار قبول المالك الجديد',
            'COMPLETED': 'اكتمل النقل',
            'REJECTED': 'رفضت الإدارة الطلب',
            'CANCELLED': 'أُلغي الطلب',
          }[status];
    final statusIcon = pending
        ? status == 'AWAITING_RECIPIENT'
            ? Icons.mark_email_read_outlined
            : Icons.fact_check_outlined
        : status == 'COMPLETED'
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline_rounded;
    final statusDetail = pending
        ? status == 'AWAITING_REVIEW'
            ? 'تراجع الإدارة الطلب والتسويات قبل إتمام النقل.'
            : isOwner
                ? 'الدعوة موجودة في طلبات نقل الملكية لدى المالك الجديد.'
                : 'راجع الفروع المشمولة واتفاقية الشراكة قبل قبول الدعوة.'
        : null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('نقل ملكية النشاط')),
        body: !AppConfig.ownershipTransferEnabled &&
                AppConfig.ownershipPreviewEnabled(widget.businessId)
            ? _previewBody()
            : !AppConfig.ownershipTransferEnabled
                ? const Center(child: Text('نقل الملكية غير متاح حاليًا.'))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (widget.businessId != null && request == null) ...[
                        if (widget.businessName != null)
                          Text(widget.businessName!,
                              style: Theme.of(context).textTheme.titleLarge),
                        ..._eligibilityDetails(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _recipient,
                          keyboardType: TextInputType.phone,
                          enabled: !_busy,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                              labelText: 'رقم هاتف المالك الجديد في التطبيق'),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : () => _run(_start),
                          child: const Text('متابعة إلى التأكيد'),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (request == null && widget.businessId == null) ...[
                        Row(
                          children: [
                            Expanded(
                                child: Text('الدعوات الواردة',
                                    style: theme.textTheme.titleLarge)),
                            IconButton(
                              tooltip: 'تحديث الدعوات',
                              onPressed:
                                  _busy ? null : () => _run(_loadInvitations),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_invitations?.isEmpty == true)
                          const Card.filled(
                            child: ListTile(
                              leading: Icon(Icons.inbox_outlined),
                              title: Text('لا توجد دعوات نقل ملكية حاليًا.'),
                            ),
                          ),
                        for (final invitation in _invitations ?? [])
                          _invitationCard(invitation),
                      ],
                      if (request != null) ...[
                        Card.filled(
                          margin: EdgeInsets.zero,
                          color: colors.primaryContainer,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: colors.primary,
                                  foregroundColor: colors.onPrimary,
                                  child: Icon(statusIcon),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  statusText ?? 'حالة الطلب غير متاحة',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (statusDetail != null) ...[
                                  const SizedBox(height: 6),
                                  Text(statusDetail,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color:
                                                  colors.onPrimaryContainer)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('الفروع المشمولة',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Card.outlined(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: colors.outlineVariant),
                          ),
                          child: Column(
                            children: [
                              for (final branch in branchNames)
                                ListTile(
                                  leading: Icon(Icons.storefront_outlined,
                                      color: colors.primary),
                                  title: Text(branch),
                                ),
                              if (branchNames.isEmpty &&
                                  widget.businessName != null)
                                ListTile(
                                  leading: Icon(Icons.storefront_outlined,
                                      color: colors.primary),
                                  title: Text(widget.businessName!),
                                ),
                              if (branchNames.length < branchCount)
                                ListTile(
                                    title: Text(
                                        'إجمالي الفروع المشمولة $branchCount')),
                            ],
                          ),
                        ),
                        if (pending && isOwner) ...[
                          const SizedBox(height: 16),
                          Card.filled(
                            margin: EdgeInsets.zero,
                            color: colors.tertiaryContainer,
                            child: ListTile(
                              leading: Icon(Icons.pause_circle_outline_rounded,
                                  color: colors.onTertiaryContainer),
                              title: Text(
                                'استقبال الطلبات الجديدة متوقف',
                                style: TextStyle(
                                    color: colors.onTertiaryContainer),
                              ),
                              subtitle: Text(
                                'تستمر متابعة الطلبات القائمة في الفروع المشمولة.',
                                style: TextStyle(
                                    color: colors.onTertiaryContainer),
                              ),
                            ),
                          ),
                          if (status == 'AWAITING_REVIEW')
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _copy(
                                      "${request['organizationId']}/${request['requestId']}",
                                      'نُسخ مرجع الطلب.'),
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('نسخ مرجع الطلب للإدارة'),
                            ),
                        ],
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(() => _load(
                                  request['organizationId'] as String,
                                  request['requestId'] as String)),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تحديث حالة الطلب'),
                        ),
                        if (!isOwner && widget.businessId == null)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _request = null;
                                      _agreement = null;
                                    });
                                    _run(_loadInvitations);
                                  },
                            child: const Text('العودة إلى الدعوات'),
                          ),
                        if (pending && isOwner)
                          TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: colors.error),
                              onPressed: _busy
                                  ? null
                                  : () => _run(() => _decide('CANCEL')),
                              child: const Text('إلغاء طلب النقل')),
                        if (pending &&
                            status == 'AWAITING_RECIPIENT' &&
                            request['participant'] == 'RECIPIENT' &&
                            _agreement != null) ...[
                          Text(_agreement!['textAr'] as String),
                          CheckboxListTile(
                            value: _consent,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                    setState(() => _consent = value == true),
                            title: const Text(
                                'أوافق على استلام النشاط وفروعه وعلى اتفاقية الشراكة'),
                          ),
                          FilledButton(
                            onPressed: _busy || !_consent
                                ? null
                                : () => _run(() => _decide('ACCEPT')),
                            child: const Text('قبول طلب النقل'),
                          ),
                        ],
                        if (pending &&
                            status == 'AWAITING_RECIPIENT' &&
                            !isOwner)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() => _decide('DECLINE')),
                            child: const Text('رفض الدعوة'),
                          ),
                      ],
                      if (pending &&
                          status == 'AWAITING_REVIEW' &&
                          request?['participant'] == 'RECIPIENT') ...[
                        const SizedBox(height: 12),
                        Card.filled(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    child: Icon(_destinationVerified
                                        ? Icons.verified_outlined
                                        : Icons.phone_android_rounded),
                                  ),
                                  title: Text('هاتف التسويات',
                                      style: theme.textTheme.titleMedium),
                                  subtitle: Text(_destinationVerified
                                      ? 'تم تأكيد الهاتف. تراجع الإدارة وجهة التسويات.'
                                      : 'أكّد هاتفك المسجّل حتى تراجع الإدارة وجهة التسويات.'),
                                ),
                                if (_maskedDestination != null)
                                  Text(_maskedDestination!,
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right),
                                if (_destinationProfileRequired)
                                  const Text(
                                      'راجع رقم هاتفك في «بياناتي الشخصية» وتأكد من مطابقته لهاتف تسجيل الدخول.')
                                else if (!_destinationVerified) ...[
                                  if (_destinationChallengeId == null)
                                    FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _verifyDestination(false)),
                                      icon: const Icon(Icons.sms_outlined),
                                      label: const Text('إرسال رمز إلى هاتفي'),
                                    )
                                  else ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _destinationCode,
                                      enabled: !_busy,
                                      keyboardType: TextInputType.number,
                                      textDirection: TextDirection.ltr,
                                      autofillHints: const [
                                        AutofillHints.oneTimeCode
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6)
                                      ],
                                      decoration: const InputDecoration(
                                          labelText: 'رمز التحقق من ستة أرقام'),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _verifyDestination(true)),
                                      child: const Text('تأكيد هاتف التسويات'),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _run(
                                              () => _verifyDestination(false)),
                                      child: const Text('إعادة إرسال الرمز'),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_error != null) Text(_error!),
                      if (_busy) const LinearProgressIndicator(),
                    ],
                  ),
      ),
    );
  }
}
