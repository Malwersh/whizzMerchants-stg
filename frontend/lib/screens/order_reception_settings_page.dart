import '../services/notification_sound_policy.dart';
import 'package:flutter/material.dart';
import '../services/order_reception_service.dart';
import '../services/sound_notification_settings.dart';
import '../services/branch_employee_access.dart';
import '../services/app_state.dart';
import '../widgets/preparation_time_sheet.dart';

class OrderReceptionSettingsPage extends StatefulWidget {
  final String businessId;
  final BranchEmployeeAccess? access;
  const OrderReceptionSettingsPage(
      {super.key, required this.businessId, this.access});
  @override
  State<OrderReceptionSettingsPage> createState() =>
      _OrderReceptionSettingsPageState();
}

class _OrderReceptionSettingsPageState
    extends State<OrderReceptionSettingsPage> {
  late final api =
      OrderReceptionService(widget.businessId, access: widget.access);
  final minimumController = TextEditingController();
  @override
  void dispose() {
    minimumController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? data;
  bool busy = false, auto = false;
  int prep = 20, pause = 15;
  String? error;
  bool get canEdit => data?['canEdit'] == true && data?['enabled'] == true;
  @override
  void initState() {
    super.initState();
    SoundNotificationSettings().initialize();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await api.call({'action': 'read_order_reception'});
      if (mounted)
        setState(() {
          data = r;
          minimumController.text = r['minimumOrderAmountIqd']?.toString() ?? '';
          auto = r['settings']['autoAccept'] == true;
          prep = (r['settings']['defaultPreparationMinutes'] as num).toInt();
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحميل الإعدادات. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save({bool pausing = false}) async {
    if (busy || !canEdit) return;
    final raw = minimumController.text.trim();
    final minimum = raw.isEmpty ? null : int.tryParse(raw);
    if (!pausing &&
        raw.isNotEmpty &&
        (minimum == null || minimum < 0 || minimum > 1000000000)) {
      setState(
          () => error = 'أدخل مبلغًا صحيحًا بالدينار أو اترك الحقل فارغًا.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await api.call({
        'action': pausing ? 'pause_orders' : 'set_order_reception',
        'baseRevision': data!['revision'],
        if (pausing) 'minutes': pause,
        if (!pausing)
          'settings': {
            'autoAccept': auto,
            'defaultPreparationMinutes': prep,
            'minimumOrderAmountIqd': minimum == 0 ? null : minimum
          }
      });
      if (!mounted) return;
      setState(() => data = r);
      if (!pausing) await rememberPreparationMinutes(widget.businessId, prep);
      if (widget.access == null)
        await AppState().setOnline(r['acceptingOrders'] == true, (_) async {});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(pausing
                ? 'تم إيقاف استقبال الطلبات مؤقتًا'
                : 'حُفظت إعدادات استقبال الطلبات')));
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'تعذر حفظ التغيير. حدّث الإعدادات وأعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sound = SoundNotificationSettings();
    final until = DateTime.tryParse(data?['pausedUntil']?.toString() ?? '');
    return Scaffold(
        appBar: AppBar(title: const Text('استقبال الطلبات'), actions: [
          IconButton(
              onPressed: busy ? null : load, icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          ListenableBuilder(
              listenable: sound,
              builder: (context, _) => Card(
                  child: SwitchListTile(
                      title: const Text('صوت الطلبات داخل التطبيق'),
                      subtitle: const Text(
                          'مفعّل افتراضيًا. تبقى التنبيهات المرئية عند كتم الصوت.'),
                      value: sound.soundEnabled && sound.newOrderSoundEnabled,
                      onChanged: (v) async {
                        await sound.setSoundEnabled(v);
                        await sound.setNewOrderSoundEnabled(v);
                      },
                      secondary: Icon(sound.soundEnabled
                          ? Icons.volume_up
                          : Icons.volume_off)))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(
                      'مهلة قبول الطلب: ${NotificationSoundPolicy.acceptanceSeconds / 60} دقيقة'),
                  subtitle: const Text(
                      'تضبطها المنصة للطلبات الجديدة. تبدأ عند إنشاء الطلب ولا تتجدد عند فتحه.'))),
          if (data != null && data!['enabled'] != true)
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('إعدادات الاستقبال غير متاحة حاليًا.')),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('قبول الطلبات تلقائيًا'),
                            subtitle: const Text(
                                'اختياري. تُقبل الطلبات الجديدة أثناء استقبال الفرع للطلبات باستخدام وقت التحضير أدناه.'),
                            value: auto,
                            onChanged: busy || !canEdit
                                ? null
                                : (v) => setState(() => auto = v)),
                        DropdownButtonFormField<int>(
                            initialValue: prep,
                            decoration: const InputDecoration(
                                labelText: 'متوسط وقت تحضير الطلب',
                                helperText:
                                    'يظهر للزبون ويدخل في تقدير الوصول. يمكنك تعديل مدة طلب معين عند قبوله.'),
                            items: ([
                              ...{10, 15, 20, 30, 45, 60, prep}
                            ]..sort())
                                .map((v) => DropdownMenuItem(
                                    value: v, child: Text('$v دقيقة')))
                                .toList(),
                            onChanged: busy || !canEdit
                                ? null
                                : (v) {
                                    if (v != null) setState(() => prep = v);
                                  }),
                        const SizedBox(height: 16),
                        TextField(
                            controller: minimumController,
                            enabled: !busy && canEdit,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'الحد الأدنى للطلب (دينار)',
                                helperText:
                                    'اختياري. قيمة الأصناف قبل الخصم، دون رسوم التوصيل والخدمة. اتركه فارغًا لإلغائه.',
                                helperMaxLines: 3)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: busy || !canEdit ? null : () => save(),
                            child: const Text('حفظ الإعدادات')),
                      ]))),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('المطعم مشغول؟',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        const Text(
                            'أوقف استقبال طلبات جديدة مؤقتًا. تستمر متابعة طلباتك الحالية.'),
                        if (until != null && until.isAfter(DateTime.now()))
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                  'متوقف مؤقتًا حتى ${TimeOfDay.fromDateTime(until.toLocal()).format(context)}')),
                        Wrap(
                            spacing: 8,
                            children: [15, 30, 60]
                                .map((v) => ChoiceChip(
                                    label: Text('$v دقيقة'),
                                    selected: pause == v,
                                    onSelected: busy
                                        ? null
                                        : (_) => setState(() => pause = v)))
                                .toList()),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: busy ||
                                    !canEdit ||
                                    data?['acceptingOrders'] != true
                                ? null
                                : () => save(pausing: true),
                            icon: const Icon(Icons.pause_circle_outline),
                            label: const Text('إيقاف الاستقبال مؤقتًا')),
                      ]))),
        ]));
  }
}
