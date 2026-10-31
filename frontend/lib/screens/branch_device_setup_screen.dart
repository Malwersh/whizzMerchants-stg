import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider_riverpod.dart';
import '../providers/branch_device_provider.dart';
import '../services/person_onboarding_service.dart';
import 'auth/auth_surface.dart';

class BranchDeviceSetupScreen extends ConsumerStatefulWidget {
  final String businessId;
  final bool owner;
  final PersonOnboardingService? service;
  const BranchDeviceSetupScreen(
      {super.key, required this.businessId, this.owner = false, this.service});
  @override
  ConsumerState<BranchDeviceSetupScreen> createState() =>
      _BranchDeviceSetupState();
}

class _BranchDeviceSetupState extends ConsumerState<BranchDeviceSetupScreen> {
  final name = TextEditingController(text: 'جهاز استقبال الطلبات');
  final code = TextEditingController();
  late final api = widget.service ?? PersonOnboardingService();
  String? pairingCode, error;
  bool busy = false;
  List<Map<String, dynamic>> devices = [];
  @override
  void initState() {
    super.initState();
    if (widget.owner) load();
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    await run(() async {
      final r = await api.call(
          'branch-devices?businessId=${Uri.encodeComponent(widget.businessId)}');
      if (mounted)
        setState(() =>
            devices = List<Map<String, dynamic>>.from(r['devices'] ?? []));
    });
  }

  Future<void> claim() async {
    await run(() async {
      final deviceNotifier = ref.read(branchDeviceProvider.notifier);
      final auth = ref.read(authProviderRiverpod.notifier);
      final r = await api.call('branch-devices', body: {
        'action': 'claim_pairing',
        'businessId': widget.businessId,
        'pairingCode': code.text
      });
      // Remove the personal session before entering persistent device mode.
      await auth.signOut();
      await deviceNotifier.activate(r);
      if (mounted)
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    });
  }

  Future<void> verifyAndCreate() async {
    final deviceName = name.text.trim();
    if (deviceName.isEmpty || deviceName.length > 60) {
      setState(() => error = 'أدخل اسمًا واضحًا للجهاز.');
      return;
    }
    // The server resolves the verified phone. The dialog never accepts a phone.
    String? maskedPhone;
    await run(() async {
      final info = await api.call('branch-devices', body: {
        'action': 'pairing_phone_info',
        'businessId': widget.businessId
      });
      maskedPhone = info['maskedPhone'];
    });
    if (!mounted || maskedPhone == null) return;
    final otp = TextEditingController();
    String? session, message;
    bool sending = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (c, update) {
        Future<void> submit() async {
          update(() {
            sending = true;
            message = null;
          });
          try {
            final result = await api.call('branch-devices', body: {
              'action': session == null
                  ? 'pairing_phone_start'
                  : 'pairing_phone_confirm',
              'businessId': widget.businessId,
              'name': deviceName,
              if (session != null) 'session': session,
              if (session != null) 'code': otp.text.trim(),
            });
            if (!c.mounted) return;
            if (result['pairingCode'] != null) {
              setState(() {
                pairingCode = result['pairingCode'];
                error = null;
              });
              Navigator.pop(c);
              return;
            }
            update(() {
              session = result['session'];
              maskedPhone = result['maskedPhone'] ?? maskedPhone;
              if (result['verified'] == false)
                message = 'رمز التحقق غير صحيح أو منتهي. حاول مجددًا.';
            });
          } catch (_) {
            if (c.mounted)
              update(() =>
                  message = 'تعذر إكمال التحقق. حاول مجددًا أو أعد الإرسال.');
          } finally {
            if (c.mounted) update(() => sending = false);
          }
        }

        return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تأكيد هاتف المالك'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'سنرسل رمز تحقق إلى رقم دخولك الموثق في حسابك. بعد التحقق سيظهر رمز ربط جهاز الفرع.'),
                if (maskedPhone != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child:
                          Text(maskedPhone!, textDirection: TextDirection.ltr)),
                if (session != null)
                  TextField(
                      controller: otp,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                          labelText: 'رمز التحقق المرسل لهاتف المالك',
                          border: OutlineInputBorder())),
                if (message != null)
                  Text(message!,
                      style: const TextStyle(color: Color(0xFFB3261E))),
              ])),
              actions: [
                TextButton(
                    onPressed: sending ? null : () => Navigator.pop(c),
                    child: const Text('إلغاء')),
                if (session != null)
                  TextButton(
                      onPressed: sending
                          ? null
                          : () {
                              update(() {
                                session = null;
                                otp.clear();
                              });
                            },
                      child: const Text('إعادة الإرسال')),
                FilledButton(
                    onPressed: sending ? null : submit,
                    child: Text(sending
                        ? 'جارٍ التحقق…'
                        : session == null
                            ? 'إرسال رمز التحقق'
                            : 'تحقق وإنشاء رمز الربط')),
              ],
            ));
      }),
    );
    // Allow the closing dialog to finish before disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    otp.dispose();
  }

  Widget buildPairingForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
                'بعد الربط تُغلق جلسة حسابك الشخصي على هذا الجهاز. يبقى استقبال الطلبات قائمًا عند قفل مهام الموظف، ويفتح الموظف مهامه بـPIN شخصي.'),
          ),
          const SizedBox(height: 24),
          TextField(
              controller: code,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'رمز الربط من المالك',
                  border: OutlineInputBorder())),
          FilledButton.icon(
              onPressed: busy ? null : claim,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('ربط هذا الجهاز وفتح الاستقبال')),
        ],
      );

  @override
  Widget build(BuildContext context) => AuthSurface(
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              appBar: AppBar(
                  title: Text(widget.owner ? 'أجهزة الفرع' : 'ربط جهاز الفرع')),
              body: ListView(padding: const EdgeInsets.all(24), children: [
                const Icon(Icons.tablet_mac_rounded,
                    size: 48, color: Color(0xFF00296B)),
                const SizedBox(height: 16),
                Text(
                    widget.owner
                        ? 'إدارة أجهزة استقبال الطلبات'
                        : 'ربط هذا الجهاز بالفرع',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(widget.owner
                    ? 'أنشئ رمزًا من حسابك، ثم أعطه للموظف ليُدخله على جهاز استقبال الطلبات في الفرع. إنشاء الرمز وحده لا يربط هاتفك.'
                    : 'على جهاز استقبال الطلبات، أدخل الرمز الذي أنشأه المالك لهذا الفرع. يجب أن تكون عضويتك مقبولة.'),
                const SizedBox(height: 12),
                const Text(
                    'كل جهاز جديد يحتاج رمزًا جديدًا من المالك. الرمز صالح لخمس دقائق ولمرة واحدة، ويختلف عن PIN الموظف اليومي.'),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(error!,
                          style: const TextStyle(color: Color(0xFFB3261E)))),
                if (widget.owner) ...[
                  const SizedBox(height: 24),
                  TextField(
                      controller: name,
                      maxLength: 60,
                      decoration: const InputDecoration(
                          labelText: 'اسم الجهاز الذي تريد اعتماده',
                          hintText: 'مثال: تابلت الكاشير',
                          border: OutlineInputBorder())),
                  FilledButton.icon(
                      onPressed: busy ? null : verifyAndCreate,
                      icon: const Icon(Icons.link),
                      label: const Text('إنشاء رمز لجهاز الفرع')),
                  if (pairingCode != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(children: [
                              const Text('رمز صالح لخمس دقائق ولمرة واحدة'),
                              SelectableText(pairingCode!,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                      fontSize: 32,
                                      letterSpacing: 4,
                                      color: Color(0xFF00296B))),
                              TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: pairingCode!));
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('نسخ الرمز')),
                            ]))),
                ],
                if (widget.owner)
                  ExpansionTile(
                    title: const Text('هل هذا هو جهاز الاستقبال؟'),
                    subtitle: const Text(
                        'افتح فقط إذا أردت تحويل الجهاز الحالي إلى جهاز الفرع'),
                    children: [buildPairingForm()],
                  )
                else
                  buildPairingForm(),
                if (widget.owner) ...[
                  const SizedBox(height: 24),
                  const Text('أجهزة هذا الفرع'),
                  if (!busy && devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                          'لا توجد أجهزة معتمدة بعد. أنشئ رمزًا لربط أول جهاز.'),
                    ),
                  for (final d in devices)
                    Card(
                        child: ListTile(
                            title: Text(d['name'] ?? 'جهاز الفرع'),
                            subtitle: Text(
                                d['status'] == 'ACTIVE' ? 'معتمد' : 'ملغى'),
                            trailing: d['status'] == 'ACTIVE'
                                ? TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (c) => AlertDialog(
                                                        title: const Text(
                                                            'إلغاء اعتماد الجهاز؟'),
                                                        content: const Text(
                                                            'يتوقف وصول هذا الجهاز وتُبطل جلسات الموظفين عليه.'),
                                                        actions: [
                                                          TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      c, false),
                                                              child: const Text(
                                                                  'رجوع')),
                                                          FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      c, true),
                                                              child: const Text(
                                                                  'إلغاء الاعتماد'))
                                                        ]));
                                            if (ok != true || !mounted) return;
                                            await run(() async {
                                              await api.call('branch-devices',
                                                  body: {
                                                    'action': 'revoke_device',
                                                    'businessId':
                                                        widget.businessId,
                                                    'deviceId': d['deviceId'],
                                                    'baseVersion': d['version']
                                                  });
                                            });
                                            if (mounted) await load();
                                          },
                                    child: const Text('إلغاء الاعتماد'))
                                : null)),
                ]
              ]))));
}
