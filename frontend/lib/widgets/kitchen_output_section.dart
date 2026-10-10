import 'package:flutter/material.dart';

import '../services/kitchen_dispatch_service.dart';

const _ink = Color(0xFF1A1A1A);
const _muted = Color(0xFF6B6B6B);

/// Kitchen output settings: LAN thermal printers + optional kitchen display.
/// Accepted orders are sent here automatically.
class KitchenOutputSection extends StatefulWidget {
  const KitchenOutputSection({super.key});

  @override
  State<KitchenOutputSection> createState() => _KitchenOutputSectionState();
}

class _KitchenOutputSectionState extends State<KitchenOutputSection> {
  KitchenSettings _s = const KitchenSettings();
  bool _loaded = false;
  final _kdsUrl = TextEditingController();
  final _kdsKey = TextEditingController();

  @override
  void initState() {
    super.initState();
    KitchenDispatchService.load().then((s) {
      if (!mounted) return;
      setState(() {
        _s = s;
        _kdsUrl.text = s.kdsUrl;
        _kdsKey.text = s.kdsApiKey;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _kdsUrl.dispose();
    _kdsKey.dispose();
    super.dispose();
  }

  Future<void> _save(KitchenSettings s) async {
    setState(() => _s = s);
    await KitchenDispatchService.save(s);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _editPrinter({int? index}) async {
    final existing = index != null ? _s.printers[index] : null;
    final name = TextEditingController(text: existing?.name ?? 'طابعة المطبخ');
    final ip = TextEditingController(text: existing?.ip ?? '');
    final port =
        TextEditingController(text: (existing?.port ?? 9100).toString());
    var width = existing?.paperWidthMm ?? 80;
    var copies = existing?.copies ?? 1;

    final result = await showModalBottomSheet<KitchenPrinter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('طابعة مطبخ (شبكة / WiFi)',
                  style: TextStyle(
                      color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _field(name, 'الاسم (مثال: مشويات، مشروبات)'),
              _field(ip, 'عنوان IP (مثال: 192.168.1.50)',
                  keyboard: TextInputType.number),
              _field(port, 'المنفذ (Port)', keyboard: TextInputType.number),
              Row(children: [
                const Text('عرض الورق:', style: TextStyle(color: _ink)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('80mm'),
                  selected: width == 80,
                  onSelected: (_) => setSheet(() => width = 80),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('58mm'),
                  selected: width == 58,
                  onSelected: (_) => setSheet(() => width = 58),
                ),
              ]),
              Row(children: [
                const Text('عدد النسخ:', style: TextStyle(color: _ink)),
                IconButton(
                  onPressed: copies > 1 ? () => setSheet(() => copies--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$copies', style: const TextStyle(color: _ink)),
                IconButton(
                  onPressed: copies < 5 ? () => setSheet(() => copies++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ]),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  final ipText = ip.text.trim();
                  if (ipText.isEmpty) return;
                  Navigator.pop(
                    ctx,
                    KitchenPrinter(
                      name: name.text.trim(),
                      ip: ipText,
                      port: int.tryParse(port.text.trim()) ?? 9100,
                      paperWidthMm: width,
                      copies: copies,
                      enabled: existing?.enabled ?? true,
                    ),
                  );
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    final list = [..._s.printers];
    if (index != null) {
      list[index] = result;
    } else {
      list.add(result);
    }
    await _save(KitchenSettings(
      autoDispatchOnAccept: _s.autoDispatchOnAccept,
      printers: list,
      kdsUrl: _s.kdsUrl,
      kdsApiKey: _s.kdsApiKey,
    ));
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        style: const TextStyle(color: _ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _muted),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _testPrinter(KitchenPrinter p) async {
    try {
      await KitchenDispatchService.testPrinter(p);
      _snack('تم إرسال صفحة تجريبية إلى ${p.name}');
    } catch (e) {
      _snack('فشل الاتصال بالطابعة ${p.ip}:${p.port} — $e', error: true);
    }
  }

  Future<void> _saveKds() async {
    final s = KitchenSettings(
      autoDispatchOnAccept: _s.autoDispatchOnAccept,
      printers: _s.printers,
      kdsUrl: _kdsUrl.text.trim(),
      kdsApiKey: _kdsKey.text.trim(),
    );
    await _save(s);
    if (s.kdsUrl.isEmpty) {
      _snack('تم الحفظ');
      return;
    }
    try {
      await KitchenDispatchService.testKds(s);
      _snack('تم الحفظ والاتصال بشاشة المطبخ ناجح');
    } catch (e) {
      _snack('تم الحفظ لكن فشل الاتصال بالشاشة: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.soup_kitchen_rounded, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Text('المطبخ: الطابعات والشاشات',
                  style: TextStyle(
                      color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إرسال تلقائي عند قبول الطلب',
                  style: TextStyle(color: _ink)),
              subtitle: const Text(
                  'كل طلب تقبله يُطبع في المطبخ ويظهر على شاشة المطبخ',
                  style: TextStyle(color: _muted)),
              value: _s.autoDispatchOnAccept,
              onChanged: (v) => _save(KitchenSettings(
                autoDispatchOnAccept: v,
                printers: _s.printers,
                kdsUrl: _s.kdsUrl,
                kdsApiKey: _s.kdsApiKey,
              )),
            ),
            const Divider(),
            const Text('طابعات المطبخ',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
            if (_s.printers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'لا توجد طابعات. أضف طابعة حرارية متصلة بنفس شبكة WiFi (منفذ 9100).',
                    style: TextStyle(color: _muted)),
              ),
            ...List.generate(_s.printers.length, (i) {
              final p = _s.printers[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.print_rounded,
                    color: p.enabled ? const Color(0xFF2E7D32) : _muted),
                title: Text(p.name.isEmpty ? p.ip : p.name,
                    style: const TextStyle(color: _ink)),
                subtitle: Text(
                    '${p.ip}:${p.port} • ${p.paperWidthMm}mm • ${p.copies}x',
                    style: const TextStyle(color: _muted)),
                onTap: () => _editPrinter(index: i),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'طباعة تجريبية',
                    icon: const Icon(Icons.receipt_long_rounded),
                    onPressed: () => _testPrinter(p),
                  ),
                  Switch(
                    value: p.enabled,
                    onChanged: (v) {
                      final list = [..._s.printers];
                      list[i] = p.copyWith(enabled: v);
                      _save(KitchenSettings(
                        autoDispatchOnAccept: _s.autoDispatchOnAccept,
                        printers: list,
                        kdsUrl: _s.kdsUrl,
                        kdsApiKey: _s.kdsApiKey,
                      ));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      final list = [..._s.printers]..removeAt(i);
                      _save(KitchenSettings(
                        autoDispatchOnAccept: _s.autoDispatchOnAccept,
                        printers: list,
                        kdsUrl: _s.kdsUrl,
                        kdsApiKey: _s.kdsApiKey,
                      ));
                    },
                  ),
                ]),
              );
            }),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _editPrinter(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة طابعة'),
              ),
            ),
            const Divider(),
            const Text('شاشة المطبخ (KDS) — اختياري',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
                'رابط يستقبل الطلب المقبول بصيغة JSON (مثل شاشة مطبخ أو نظام POS).',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 8),
            _field(_kdsUrl, 'رابط الشاشة (https://...)',
                keyboard: TextInputType.url),
            _field(_kdsKey, 'مفتاح API (اختياري)'),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _saveKds,
                child: const Text('حفظ واختبار'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
