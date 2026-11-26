import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/person_onboarding_service.dart';

/// Owner management only. The server independently checks ownership; no owner
/// credential is copied to the kitchen browser.
class KitchenScreensScreen extends StatefulWidget {
  final String businessId;
  final PersonOnboardingService? service;
  const KitchenScreensScreen(
      {super.key, required this.businessId, this.service});
  @override
  State<KitchenScreensScreen> createState() => _KitchenScreensState();
}

class _KitchenScreensState extends State<KitchenScreensScreen> {
  late final api = widget.service ?? PersonOnboardingService();
  List<Map<String, dynamic>> screens = [];
  bool busy = false;
  String? error;
  String? displayUrl;
  static const ink = Color(0xFF062B68);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> fetch() async {
    final r = await api.call('kitchen-screens',
        body: {'action': 'list', 'businessId': widget.businessId});
    if (mounted) {
      setState(() {
        screens = List<Map<String, dynamic>>.from(r['screens'] ?? []);
        displayUrl = r['displayUrl'] as String?;
      });
    }
  }

  Future<void> load() => run(fetch);
  Future<void> editor([Map<String, dynamic>? screen]) async {
    final code = TextEditingController(),
        name = TextEditingController(text: screen?['name'] ?? 'المطبخ الرئيسي');
    var mode = screen?['mode'] ?? 'display';
    final input = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setSheet) => Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 22, 24, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(screen == null ? 'ربط شاشة مطبخ' : 'إعدادات الشاشة',
                          style: const TextStyle(
                              color: ink,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (screen == null) ...[
                        const Text(
                            'افتح رابط شاشة المطبخ على التلفزيون، وأدخل الرمز الظاهر عليه هنا.'),
                        const SizedBox(height: 16),
                        TextField(
                            controller: code,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(8)
                            ],
                            decoration: const InputDecoration(
                                labelText: 'رمز الشاشة — ٨ أرقام',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 14)
                      ],
                      TextField(
                          controller: name,
                          maxLength: 60,
                          decoration: const InputDecoration(
                              labelText: 'اسم الشاشة',
                              border: OutlineInputBorder())),
                      SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'display', label: Text('عرض فقط')),
                            ButtonSegment(
                                value: 'interactive',
                                label: Text('مطبخ تفاعلي')),
                          ],
                          selected: {
                            mode
                          },
                          onSelectionChanged: (values) =>
                              setSheet(() => mode = values.first)),
                      const SizedBox(height: 10),
                      Text(mode == 'display'
                          ? 'مشاهدة الطلبات دون تغيير حالتها.'
                          : 'يسمح للعاملين على الشاشة ببدء التحضير وتحديد الجاهز.'),
                      const SizedBox(height: 14),
                      FilledButton(
                          onPressed: () {
                            if (name.text.trim().isEmpty ||
                                (screen == null && code.text.length != 8)) {
                              return;
                            }
                            Navigator.pop(ctx, {
                              'name': name.text.trim(),
                              'mode': mode,
                              if (screen == null) 'pairingCode': code.text
                            });
                          },
                          style: FilledButton.styleFrom(
                              backgroundColor: ink,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48)),
                          child: Text(screen == null
                              ? 'تأكيد ربط الشاشة بالفرع'
                              : 'حفظ الإعدادات')),
                    ])))));
    // Controllers are kept alive until the closing sheet transition finishes.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    code.dispose();
    name.dispose();
    if (input == null || !mounted) return;
    await run(() async {
      await api.call('kitchen-screens', body: {
        'action': screen == null ? 'approve' : 'configure',
        'businessId': widget.businessId,
        ...input,
        if (screen != null) ...{
          'screenId': screen['screenId'],
          'baseVersion': screen['version']
        }
      });
      await fetch();
    });
  }

  Future<void> revoke(Map<String, dynamic> s) async {
    final ok = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إلغاء ربط الشاشة',
                      style: TextStyle(
                          color: ink,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                      'ستتوقف الشاشة عن الوصول إلى طلبات هذا الفرع. يلزم رمز جديد لربطها مرة أخرى.'),
                  const SizedBox(height: 20),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('إلغاء الربط'))
                ])));
    if (ok != true || !mounted) return;
    await run(() async {
      await api.call('kitchen-screens', body: {
        'action': 'revoke',
        'businessId': widget.businessId,
        'screenId': s['screenId'],
        'baseVersion': s['version']
      });
      await fetch();
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: const Color(0xFFF3F5F9),
          appBar: AppBar(
              title: const Text('شاشات المطبخ'),
              leading: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => Navigator.pop(context)),
              actions: [
                IconButton(
                    onPressed: busy ? null : load,
                    icon: const Icon(Icons.refresh))
              ]),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            const Text(
                'كل شاشة مرتبطة بهذا الفرع فقط. اختر عرض الطلبات أو السماح بإجراءات المطبخ.',
                style: TextStyle(color: ink)),
            if (displayUrl != null) ...[
              const SizedBox(height: 16),
              const Text('افتح هذا الرابط في متصفح شاشة المطبخ:'),
              SelectableText(displayUrl!, textDirection: TextDirection.ltr),
              TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: displayUrl!)),
                  icon: const Icon(Icons.copy),
                  label: const Text('نسخ الرابط')),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: busy ? null : editor,
                icon: const Icon(Icons.add_link),
                label: const Text('ربط شاشة برمز'),
                style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48))),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red))),
            if (!busy && screens.isEmpty && error == null)
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد شاشات مرتبطة بعد.',
                      textAlign: TextAlign.center)),
            ...screens.map((s) {
              final expired = (s['expiresAt'] as num? ?? 0) <=
                  DateTime.now().millisecondsSinceEpoch / 1000;
              final active = s['status'] == 'ACTIVE' && !expired;
              return Card(
                  margin: const EdgeInsets.only(top: 14),
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s['name'] ?? 'شاشة مطبخ',
                                style: const TextStyle(
                                    color: ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(active
                                ? (s['mode'] == 'interactive'
                                    ? 'مطبخ تفاعلي'
                                    : 'عرض فقط')
                                : (s['status'] == 'REVOKED'
                                    ? 'أُلغي الربط'
                                    : 'انتهى اعتماد الشاشة')),
                            if (active)
                              Wrap(spacing: 12, children: [
                                TextButton(
                                    onPressed: busy ? null : () => editor(s),
                                    child: const Text('الإعدادات')),
                                TextButton(
                                    onPressed: busy ? null : () => revoke(s),
                                    child: const Text('إلغاء الربط',
                                        style: TextStyle(color: Colors.red)))
                              ])
                          ])));
            }),
          ])));
}
