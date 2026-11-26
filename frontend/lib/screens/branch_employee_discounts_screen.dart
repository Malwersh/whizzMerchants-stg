import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/branch_employee_access.dart';
import '../widgets/discount_funding_notice.dart';

class BranchEmployeeDiscountsScreen extends StatefulWidget {
  final BranchEmployeeAccess access;
  const BranchEmployeeDiscountsScreen({super.key, required this.access});
  @override
  State<BranchEmployeeDiscountsScreen> createState() => _DiscountState();
}

class _DiscountState extends State<BranchEmployeeDiscountsScreen> {
  final items = <Map<String, dynamic>>[];
  final attempts = <String, String>{};
  String? cursor, error, notice;
  bool busy = false;
  int generation = 0;
  DialogRoute<bool>? editor;
  String scope(BranchEmployeeAccess a) =>
      jsonEncode([a.token, a.session, a.businessId, a.capabilities]);
  bool can(String key) => widget.access.capabilities[key] == true;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant BranchEmployeeDiscountsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (scope(oldWidget.access) != scope(widget.access)) {
      generation++;
      items.clear();
      attempts.clear();
      cursor = null;
      notice = null;
      closeEditor();
      load();
    }
  }

  void closeEditor() {
    final route = editor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    });
  }

  @override
  void dispose() {
    generation++;
    closeEditor();
    super.dispose();
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> body) {
    final a = widget.access;
    return a.api.call(a.token, body, session: a.session);
  }

  Future<void> load({bool more = false}) async {
    final current = ++generation;
    setState(() {
      busy = true;
      error = null;
      if (!more) {
        items.clear();
        cursor = null;
      }
    });
    try {
      if (!can('readDiscounts')) {
        throw StateError('ليس لديك إذن لقراءة الخصومات.');
      }
      final result = await request({
        'action': 'discounts_list',
        if (more && cursor != null) 'cursor': cursor
      });
      if (!mounted || current != generation) return;
      setState(() {
        items
            .addAll(List<Map<String, dynamic>>.from(result['discounts'] ?? []));
        cursor = result['nextCursor'];
      });
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          items.clear();
          cursor = null;
          error = e.toString();
        });
      }
    } finally {
      if (mounted && current == generation) setState(() => busy = false);
    }
  }

  Future<void> mutate(Map<String, dynamic> body) async {
    final fingerprint = jsonEncode(body);
    final id = attempts.putIfAbsent(fingerprint, () => const Uuid().v4());
    final originalScope = scope(widget.access);
    await request({...body, 'requestId': id});
    if (mounted && originalScope == scope(widget.access)) {
      attempts.remove(fingerprint);
    }
  }

  String day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  Future<void> edit([Map<String, dynamic>? item]) async {
    if (!can(item == null ? 'createDiscounts' : 'editDiscounts') ||
        item != null && (item['editable'] != true || item['sharingLocked'] == true)) {
      return;
    }
    final originalScope = scope(widget.access);
    bool valid() => mounted && originalScope == scope(widget.access);
    final title = TextEditingController(text: item?['title'] ?? ''),
        description = TextEditingController(text: item?['description'] ?? ''),
        amount = TextEditingController(text: item?['value']?.toString() ?? ''),
        minimum = TextEditingController(
            text: item?['minimum_order_amount']?.toString() ?? '0');
    var type = item?['type'] as String? ?? 'percentage';
    var from = DateTime.tryParse(item?['valid_from'] ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    var to = DateTime.tryParse(item?['valid_to'] ?? '')?.toUtc() ??
        from.add(const Duration(days: 7));
    bool sending = false;
    String? failure;
    final route = DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(builder: (dialog, update) {
              Future<void> choose(bool start) async {
                final value = await showDatePicker(
                    context: dialog,
                    initialDate: start ? from : to,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100));
                if (value == null || !valid() || !dialog.mounted) return;
                update(() {
                  if (start) {
                    from = DateTime.utc(value.year, value.month, value.day);
                  } else {
                    to = DateTime.utc(
                        value.year, value.month, value.day, 23, 59, 59, 999);
                  }
                });
              }

              return AlertDialog(
                  title: Text(item == null ? 'إضافة خصم' : 'تعديل الخصم'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DiscountFundingNotice(editing: item != null),
                    TextField(
                        controller: title,
                        enabled: !sending,
                        decoration:
                            const InputDecoration(labelText: 'اسم الخصم')),
                    TextField(
                        controller: description,
                        enabled: !sending,
                        decoration: const InputDecoration(labelText: 'الوصف')),
                    DropdownButtonFormField<String>(
                        initialValue: type,
                        items: const [
                          DropdownMenuItem(
                              value: 'percentage', child: Text('نسبة مئوية')),
                          DropdownMenuItem(
                              value: 'fixedAmount',
                              child: Text('مبلغ ثابت بالدينار'))
                        ],
                        onChanged:
                            sending ? null : (v) => update(() => type = v!),
                        decoration:
                            const InputDecoration(labelText: 'نوع الخصم')),
                    TextField(
                        controller: amount,
                        enabled: !sending,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: type == 'percentage'
                                ? 'النسبة المئوية (حتى 100)'
                                : 'قيمة الخصم بالدينار')),
                    TextField(
                        controller: minimum,
                        enabled: !sending,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'الحد الأدنى للطلب بالدينار')),
                    TextButton(
                        onPressed: sending ? null : () => choose(true),
                        child: Text('من ${day(from)}')),
                    TextButton(
                        onPressed: sending ? null : () => choose(false),
                        child: Text('إلى ${day(to)}')),
                    const Text(
                        'الفترة بتوقيت UTC. الخصم لكامل الطلب، ويُنشأ متوقفًا حتى تفعيله.'),
                    if (failure != null) Text(failure!),
                    if (sending) const LinearProgressIndicator(),
                  ])),
                  actions: [
                    TextButton(
                        onPressed:
                            sending ? null : () => Navigator.pop(dialog, false),
                        child: const Text('رجوع')),
                    FilledButton(
                        onPressed: sending
                            ? null
                            : () async {
                                if (!valid()) return;
                                final value = num.tryParse(amount.text),
                                    min = int.tryParse(minimum.text);
                                if (title.text.trim().isEmpty ||
                                    value == null ||
                                    !value.isFinite ||
                                    value <= 0 ||
                                    type == 'percentage' && value > 100 ||
                                    type == 'fixedAmount' &&
                                        value != value.round() ||
                                    min == null ||
                                    min < 0 ||
                                    !to.isAfter(from)) {
                                  update(() => failure =
                                      'راجع الاسم والقيمة والفترة والحد الأدنى.');
                                  return;
                                }
                                update(() {
                                  sending = true;
                                  failure = null;
                                });
                                try {
                                  await mutate({
                                    'action': item == null
                                        ? 'discounts_create'
                                        : 'discounts_update',
                                    if (item != null) ...{
                                      'discountId': item['discountId'],
                                      'baseRevision': item['revision']
                                    },
                                    'data': {
                                      'title': title.text.trim(),
                                      'description': description.text,
                                      'type': type,
                                      'value': value,
                                      'minimumOrderAmount': min,
                                      'validFrom': from.toIso8601String(),
                                      'validTo': to.toIso8601String()
                                    }
                                  });
                                  if (valid() && dialog.mounted) {
                                    Navigator.pop(dialog, true);
                                  }
                                } catch (e) {
                                  if (valid() && dialog.mounted) {
                                    update(() {
                                      sending = false;
                                      failure = e.toString();
                                    });
                                  }
                                }
                              },
                        child: const Text('حفظ'))
                  ]);
            }));
    editor = route;
    final saved = await Navigator.of(context).push(route);
    await route.completed;
    if (editor == route) editor = null;
    title.dispose();
    description.dispose();
    amount.dispose();
    minimum.dispose();
    if (saved == true && valid()) {
      notice = 'تم حفظ الخصم على الخادم.';
      await load();
    }
  }

  Future<void> change(Map<String, dynamic> item, bool remove) async {
    if (busy || !can(remove ? 'deleteDiscounts' : 'activateDiscounts')) return;
    final originalScope = scope(widget.access);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(remove
                    ? 'حذف الخصم؟'
                    : item['status'] == 'active'
                        ? 'إيقاف الخصم؟'
                        : 'تفعيل الخصم؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد'))
                ]));
    if (confirmed != true ||
        !mounted ||
        originalScope != scope(widget.access)) {
      return;
    }
    final current = ++generation;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await mutate({
        'action': remove ? 'discounts_delete' : 'discounts_status',
        'discountId': item['discountId'],
        'baseRevision': item['revision'],
        if (!remove) 'active': item['status'] != 'active'
      });
      if (!mounted || current != generation) return;
      notice = 'تم حفظ التغيير على الخادم.';
      await load();
    } catch (e) {
      if (mounted && current == generation) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('خصومات الفرع'),
        const DiscountFundingNotice(),
        const Text(
            'تدعم الإدارة هنا خصم النسبة أو المبلغ الثابت لكامل الطلب. الأنواع الأخرى للعرض فقط.'),
        Row(children: [
          if (can('createDiscounts'))
            FilledButton(
                onPressed: busy ? null : () => edit(),
                child: const Text('إضافة خصم')),
          IconButton(
              onPressed: busy ? null : () => load(),
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث')
        ]),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (notice != null) Text(notice!),
        if (!busy && error == null && items.isEmpty && cursor == null)
          const Text('لا توجد خصومات.'),
        for (final item in items)
          Card(
              child: ListTile(
                  title: Text(item['title']?.toString() ?? 'خصم'),
                  subtitle: Text(
                      '${item['sharingLocked'] == true ? 'خصم مشترك — الشروط مقفلة\n' : ''}${item['value'] ?? 'غير مسجل'} ${item['type'] == 'percentage' ? '%' : 'د.ع'} • ${item['status'] == 'active' ? 'مفعّل' : 'متوقف أو مجدول'}\n${item['valid_from'] ?? ''} — ${item['valid_to'] ?? ''}'),
                  trailing: item['editable'] != true
                      ? const Text('للقراءة فقط')
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (can('editDiscounts') && item['sharingLocked'] != true)
                            IconButton(
                                onPressed: busy ? null : () => edit(item),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'تعديل الخصم'),
                          if (can('activateDiscounts') && !(item['sharingLocked'] == true && item['sharingCanActivate'] != true && item['status'] != 'active'))
                            IconButton(
                                onPressed:
                                    busy ? null : () => change(item, false),
                                icon: Icon(item['status'] == 'active'
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                tooltip: item['status'] == 'active'
                                    ? 'إيقاف الخصم'
                                    : 'تفعيل الخصم'),
                          if (can('deleteDiscounts') && item['sharingLocked'] != true)
                            IconButton(
                                onPressed:
                                    busy ? null : () => change(item, true),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'حذف الخصم'),
                        ]))),
        if (cursor != null)
          TextButton(
              onPressed: busy ? null : () => load(more: true),
              child: const Text('المزيد من الخصومات')),
      ]);
}
