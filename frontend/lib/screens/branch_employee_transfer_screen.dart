import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../services/branch_employee_access.dart';
import '../services/branch_employee_transfer_service.dart';
import '../services/wallet_transfer_service.dart';
import '../widgets/transfer_verification_sheet.dart';

class BranchEmployeeTransferScreen extends StatefulWidget {
  final BranchEmployeeAccess initial;
  final BranchEmployeeAccess? Function() access;
  final BranchEmployeeTransferService? service;
  const BranchEmployeeTransferScreen(
      {super.key, required this.initial, required this.access, this.service});
  @override
  State<BranchEmployeeTransferScreen> createState() => _TransferState();
}

class _TransferState extends State<BranchEmployeeTransferScreen> {
  late final initial = widget.initial;
  late final api = widget.service ??
      BranchEmployeeTransferService(expected: initial, current: widget.access);
  static const storage = FlutterSecureStorage();
  final phone = TextEditingController(),
      amount = TextEditingController(),
      reason = TextEditingController();
  Map<String, dynamic>? account, recipient, pending;
  String? error;
  String type = 'DRIVER';
  bool busy = false, verificationOpen = false;
  String get storageKey =>
      'branch_transfer_${initial.businessId}_${initial.token.split(':')[1]}_${initial.profile['staff']?['subjectId']}';
  @override
  void initState() {
    super.initState();
    api.onRevoked = () {
      if (!mounted) return;
      live();
      if (verificationOpen) {
        verificationOpen = false;
        Navigator.of(context).pop();
      }
    };
    load();
  }

  @override
  void dispose() {
    api.onRevoked = null;
    phone.dispose();
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  bool live() {
    if (!mounted) return false;
    try {
      api.check();
      return true;
    } catch (_) {
      setState(() {
        account = null;
        recipient = null;
        pending = null;
        error = 'تغيرت جلسة الموظف. ارجع إلى جهاز الفرع.';
      });
      return false;
    }
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      api.check();
      await work();
    } catch (e) {
      if (live()) {
        setState(() {
          error = e.toString();
          account = null;
          recipient = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
        final data = await api.call('context');
        if (!mounted || !live()) return;
        final subject = initial.profile['staff']?['subjectId'];
        if (subject is! String || subject.isEmpty) {
          throw WalletTransferException('حدّث جلسة الموظف قبل التحويل.');
        }
        final saved = await storage.read(key: storageKey);
        if (!mounted || !live()) return;
        Map<String, dynamic>? restored;
        if (saved != null) {
          restored = Map<String, dynamic>.from(jsonDecode(saved));
        }
        setState(() {
          account = data;
          pending = restored;
        });
      });
  Future<void> find() => run(() async {
        final value = await api.call('recipient',
            query: {'phone': phone.text.trim(), 'type': type});
        if (live()) setState(() => recipient = value);
      });
  Future<void> submit() => run(() async {
        if (pending == null) {
          final n = int.tryParse(amount.text.replaceAllMapped(
              RegExp('[٠-٩]'), (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!).toString()));
          final a = account;
          if (a == null ||
              a['canTransfer'] != true ||
              recipient == null ||
              n == null ||
              n < (a['minAmount'] as num) ||
              n > (a['maxAmount'] as num) ||
              n > (a['available'] as num) ||
              n > (a['dailyRemaining'] as num) ||
              reason.text.trim().length < 5) {
            throw WalletTransferException(
                'اختر المستلم وأدخل مبلغًا ضمن الرصيد والحدود وسببًا من خمسة أحرف.');
          }
          final chosen = Map<String, dynamic>.from(recipient!);
          final accepted = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                      title: const Text('تأكيد التحويل'),
                      content: Text(
                          '${chosen['name']}\n${chosen['phone']}\n$n د.ع\n${reason.text.trim()}'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('رجوع')),
                        FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('متابعة التحقق'))
                      ]));
          if (!live() || accepted != true) return;
          pending = {
            'requestId': const Uuid().v4(),
            'recipientWalletId': chosen['walletId'],
            'amount': n,
            'reason': reason.text.trim()
          };
          await storage.write(key: storageKey, value: jsonEncode(pending));
          if (!mounted || !live()) return;
        }
        final request = Map<String, dynamic>.from(pending!);
        var result = await api.call('status',
            query: {'requestId': request['requestId'].toString()});
        if (!mounted || !live()) return;
        if (result['status'] == 'NOT_FOUND') {
          try {
            result = await api.call('request', body: request);
          } on WalletTransferException catch (e) {
            if (!mounted || e.code != 'REAUTH_REQUIRED' || !live()) rethrow;
            verificationOpen = true;
            final proof = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TransferVerificationSheet(
                    request: request,
                    call: (path, body) => api.call(path, body: body)));
            verificationOpen = false;
            if (!mounted || !live() || proof == null) return;
            result = await api
                .call('request', body: {...request, 'verificationId': proof});
          }
        }
        if (!mounted || !live()) return;
        if (!['COMPLETED', 'CANCELLED'].contains(result['status'])) {
          throw WalletTransferException(
              'لم تتأكد النتيجة. احتفظ بمرجع المحاولة وأعد التحقق.');
        }
        await storage.delete(key: storageKey);
        if (!mounted || !live()) return;
        setState(() {
          pending = null;
          recipient = null;
          account = null;
          phone.clear();
          amount.clear();
          reason.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['status'] == 'COMPLETED'
                ? 'اكتمل التحويل.'
                : 'المحاولة ملغاة دون خصم.')));
      });
  Future<void> cancel() => run(() async {
        final request = pending;
        if (request == null) return;
        final result = await api.call('cancel', body: request);
        if (!mounted || !live()) return;
        if (!['CANCELLED', 'COMPLETED'].contains(result['status'])) {
          throw WalletTransferException('تعذر تأكيد إلغاء المحاولة.');
        }
        await storage.delete(key: storageKey);
        if (!mounted || !live()) return;
        setState(() {
          pending = null;
          account = null;
          recipient = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['status'] == 'COMPLETED'
                ? 'التحويل نُفذ بالفعل؛ لم يُلغَ أو يتكرر الخصم.'
                : 'أُلغيت المحاولة دون خصم.')));
      });
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: const Text('تحويل من محفظة الفرع')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            const Text(
                'يُرسل رمز التحقق إلى هاتف الموظف الفاعل. يخضع التحويل لرصيد الفرع وحدوده وصلاحياتك الحالية.'),
            if (error != null)
              Text(error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(
                onPressed: busy ? null : load,
                child: const Text('تحديث الرصيد والحدود')),
            if (account != null)
              Text(
                  'المتاح: ${account!['available']} د.ع — المتبقي اليوم: ${account!['dailyRemaining']} د.ع'),
            if (pending != null) ...[
              Text('محاولة تحتاج تأكيد النتيجة: ${pending!['requestId']}'),
              Text('المبلغ: ${pending!['amount']} د.ع'),
              FilledButton(
                  onPressed: busy ? null : submit,
                  child: const Text('التحقق بنفس المرجع والمتابعة')),
              TextButton(
                  onPressed: busy ? null : cancel,
                  child: const Text('إلغاء المحاولة إن لم تنفّذ'))
            ] else ...[
              DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'DRIVER', child: Text('سائق')),
                    DropdownMenuItem(value: 'CUSTOMER', child: Text('مستخدم'))
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                            type = v!;
                            recipient = null;
                          })),
              TextField(
                  controller: phone,
                  onChanged: (_) => setState(() => recipient = null),
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'هاتف المستلم')),
              TextButton(
                  onPressed: busy ? null : find,
                  child: const Text('البحث عن المستلم')),
              if (recipient != null)
                Text('${recipient!['name']} — ${recipient!['phone']}'),
              TextField(
                  controller: amount,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'المبلغ بالدينار')),
              TextField(
                  controller: reason,
                  enabled: !busy,
                  maxLength: 250,
                  decoration: const InputDecoration(labelText: 'سبب التحويل')),
              FilledButton(
                  onPressed: busy || account == null ? null : submit,
                  child: const Text('مراجعة التحويل والتحقق')),
            ],
            if (busy) const Center(child: CircularProgressIndicator())
          ])));
}
