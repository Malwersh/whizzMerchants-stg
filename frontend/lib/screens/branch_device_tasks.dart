import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../services/branch_device_service.dart';

class BranchDeviceTasks extends StatefulWidget {
  final BranchDeviceService api;
  final String token, session, businessId;
  final Map<String, dynamic> capabilities;
  final String role;
  final String? initialTab;
  final bool showTabs;
  const BranchDeviceTasks(
      {super.key,
      required this.api,
      required this.token,
      required this.session,
      required this.businessId,
      required this.capabilities,
      required this.role,
      this.initialTab,
      this.showTabs = true});
  @override
  State<BranchDeviceTasks> createState() => _TasksState();
}

class _TasksState extends State<BranchDeviceTasks> {
  String tab = 'orders';
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> hours = {};
  bool busy = false;
  String? error, notice, createRequestId, createFingerprint;
  Map<String, dynamic>? createDraft;
  final editRequests = <String, String>{};
  final days = const {
    'sunday': 'الأحد',
    'monday': 'الاثنين',
    'tuesday': 'الثلاثاء',
    'wednesday': 'الأربعاء',
    'thursday': 'الخميس',
    'friday': 'الجمعة',
    'saturday': 'السبت'
  };
  bool get readMenu =>
      (widget.capabilities['readMenu'] ?? widget.capabilities['editMenu']) ==
      true;
  bool get readHours =>
      (widget.capabilities['readHours'] ?? widget.capabilities['editHours']) ==
      true;
  bool get editInfo =>
      (widget.capabilities['editProductInfo'] ??
          widget.capabilities['editMenu']) ==
      true;
  bool get editPrice =>
      (widget.capabilities['editProductPrice'] ??
          widget.capabilities['editMenu']) ==
      true;
  bool get editAvailability =>
      (widget.capabilities['editProductAvailability'] ??
          widget.capabilities['editMenu']) ==
      true;
  bool get createAllowed => widget.capabilities['createProduct'] == true;
  bool get deleteAllowed => widget.capabilities['deleteProduct'] == true;
  bool get editProductAllowed => editInfo || editPrice || editAvailability;
  bool get ordersAllowed => ['MANAGER', 'RECEPTION'].contains(widget.role);
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab ??
        (ordersAllowed
            ? 'orders'
            : readMenu
                ? 'menu'
                : 'none');
    load();
  }

  Future<Map<String, dynamic>> call(String path,
          {Map<String, dynamic>? body, String? method}) =>
      widget.api.operation(widget.token, path,
          session: widget.session, body: body, method: method);
  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = tab == 'orders'
          ? await call('merchant/orders/${widget.businessId}')
          : tab == 'menu'
              ? await call('products')
              : tab == 'hours'
                  ? await call('businesses/${widget.businessId}/working-hours')
                  : <String, dynamic>{};
      if (mounted)
        setState(() {
          items = List<Map<String, dynamic>>.from(
              r[tab == 'orders' ? 'orders' : 'products'] ?? []);
          hours = Map<String, dynamic>.from(r['workingHours'] ?? {});
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> save(String path, Map<String, dynamic> body,
      {String? method}) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await call(path,
          body: {'businessId': widget.businessId, ...body}, method: method);
      if (mounted) {
        notice = 'تم الحفظ على الخادم.';
        await load();
      }
      return true;
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> orderAction(Map<String, dynamic> order, String action) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text({
                  'confirm': 'قبول الطلب؟',
                  'reject': 'رفض الطلب؟',
                  'preparing': 'بدء التحضير؟',
                  'ready': 'الطلب جاهز للتسليم؟'
                }[action]!),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد'))
                ]));
    if (ok != true || !mounted) return;
    await save(
        'merchant/order/${order['orderId']}/${[
          'confirm',
          'reject'
        ].contains(action) ? action : 'status'}',
        action == 'confirm'
            ? {'estimatedPreparationTime': 20}
            : action == 'reject'
                ? {'reason': 'رفض موظف الفرع'}
                : {'status': action});
  }

  Future<void> createProduct() async {
    if (!createAllowed) return;
    setState(() {
      busy = true;
      error = null;
    });
    List<Map<String, dynamic>> categories;
    try {
      final result = await call('categories');
      categories = List<Map<String, dynamic>>.from(result['categories'] ?? [])
          .where((c) => c['isActive'] != false && c['is_active'] != false)
          .toList();
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          error = e.toString();
        });
      return;
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (categories.isEmpty) {
      setState(() => error = 'لا توجد أقسام متاحة لإضافة المنتج.');
      return;
    }
    final name = TextEditingController(text: createDraft?['name'] ?? ''),
        description =
            TextEditingController(text: createDraft?['description'] ?? ''),
        price = TextEditingController(
            text: createDraft?['price']?.toString() ?? '');
    String? categoryId = createDraft?['categoryId'];
    if (!categories.any((c) => c['categoryId'] == categoryId))
      categoryId = null;
    bool available = createDraft?['isAvailable'] != false, sending = false;
    String? failure;
    final route = DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, update) => AlertDialog(
                  title: const Text('إضافة منتج'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        enabled: !sending,
                        decoration:
                            const InputDecoration(labelText: 'اسم المنتج')),
                    TextField(
                        controller: description,
                        enabled: !sending,
                        decoration:
                            const InputDecoration(labelText: 'وصف المنتج')),
                    TextField(
                        controller: price,
                        enabled: !sending,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'السعر بالدينار')),
                    DropdownButtonFormField<String>(
                        initialValue: categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'القسم'),
                        items: categories
                            .map((c) => DropdownMenuItem<String>(
                                value: c['categoryId'],
                                child: Text(c['categoryName'] ??
                                    c['name_ar'] ??
                                    c['name'] ??
                                    'قسم')))
                            .toList(),
                        onChanged: sending
                            ? null
                            : (v) => update(() => categoryId = v)),
                    SwitchListTile(
                        title: const Text('متاح للطلب'),
                        value: available,
                        onChanged: sending
                            ? null
                            : (v) => update(() => available = v)),
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
                                final amount = int.tryParse(price.text.trim());
                                if (name.text.trim().isEmpty ||
                                    categoryId == null ||
                                    amount == null ||
                                    amount <= 0) {
                                  update(() => failure =
                                      'أكمل الاسم والقسم والسعر الصحيح.');
                                  return;
                                }
                                createDraft = {
                                  'name': name.text.trim(),
                                  'description': description.text,
                                  'price': amount,
                                  'categoryId': categoryId,
                                  'isAvailable': available
                                };
                                final fingerprint = jsonEncode(createDraft);
                                if (createFingerprint != fingerprint) {
                                  createFingerprint = fingerprint;
                                  createRequestId = const Uuid().v4();
                                }
                                update(() {
                                  sending = true;
                                  failure = null;
                                });
                                try {
                                  await call('products',
                                      body: {
                                        'businessId': widget.businessId,
                                        ...createDraft!,
                                        'requestId': createRequestId
                                      },
                                      method: 'POST');
                                  if (dialog.mounted)
                                    Navigator.pop(dialog, true);
                                } catch (e) {
                                  if (dialog.mounted)
                                    update(() {
                                      sending = false;
                                      failure = e.toString();
                                    });
                                }
                              },
                        child: const Text('إضافة')),
                  ],
                )));
    final created = await Navigator.of(context).push(route);
    await route.completed;
    name.dispose();
    description.dispose();
    price.dispose();
    if (created == true && mounted) {
      createDraft = null;
      createFingerprint = null;
      createRequestId = null;
      setState(() => notice = 'أضيف المنتج بنجاح.');
      await load();
    }
  }

  Future<void> deleteProduct(Map<String, dynamic> product) async {
    if (!deleteAllowed) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('حذف المنتج؟'),
                content: Text(product['name'] ?? ''),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('رجوع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('حذف')),
                ]));
    if (accepted == true && mounted)
      await save('products/${product['productId']}', {}, method: 'DELETE');
  }

  Future<void> editProduct(Map<String, dynamic> p) async {
    if (!editProductAllowed) return;
    final name = TextEditingController(text: p['name'] ?? ''),
        price = TextEditingController(text: '${p['price'] ?? ''}'),
        description = TextEditingController(text: p['description'] ?? '');
    bool available = p['isAvailable'] == true, sending = false;
    String? failure;
    final session = widget.session,
        token = widget.token,
        branch = widget.businessId;
    final allowInfo = editInfo,
        allowPrice = editPrice,
        allowAvailability = editAvailability;
    bool stillAuthorized() =>
        mounted &&
        widget.session == session &&
        widget.token == token &&
        widget.businessId == branch &&
        editInfo == allowInfo &&
        editPrice == allowPrice &&
        editAvailability == allowAvailability;
    final route = DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, update) => AlertDialog(
                    title: const Text('تعديل المنتج'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      if (allowInfo)
                        TextField(
                            controller: name,
                            enabled: !sending,
                            decoration:
                                const InputDecoration(labelText: 'اسم المنتج')),
                      if (allowInfo)
                        TextField(
                            controller: description,
                            enabled: !sending,
                            decoration:
                                const InputDecoration(labelText: 'وصف المنتج')),
                      if (allowPrice)
                        TextField(
                            controller: price,
                            enabled: !sending,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                                labelText: 'السعر بالدينار')),
                      if (allowAvailability)
                        SwitchListTile(
                            title: const Text('متاح للطلب'),
                            value: available,
                            onChanged: sending
                                ? null
                                : (v) => update(() => available = v)),
                      if (failure != null) Text(failure!),
                      if (sending) const LinearProgressIndicator(),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: sending
                              ? null
                              : () => Navigator.pop(dialog, false),
                          child: const Text('رجوع')),
                      FilledButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  if (!stillAuthorized()) {
                                    Navigator.pop(dialog, false);
                                    return;
                                  }
                                  final value = int.tryParse(price.text.trim());
                                  if (allowPrice &&
                                      (value == null || value <= 0)) {
                                    update(() => failure =
                                        'أدخل سعرًا صحيحًا أكبر من صفر.');
                                    return;
                                  }
                                  if (allowInfo && name.text.trim().isEmpty) {
                                    update(() => failure = 'أدخل اسم المنتج.');
                                    return;
                                  }
                                  final changes = <String, dynamic>{
                                    if (allowInfo &&
                                        name.text.trim() != p['name'])
                                      'name': name.text.trim(),
                                    if (allowInfo &&
                                        description.text !=
                                            (p['description'] ?? ''))
                                      'description': description.text,
                                    if (allowPrice && value != p['price'])
                                      'price': value,
                                    if (allowAvailability &&
                                        available != p['isAvailable'])
                                      'isAvailable': available
                                  };
                                  if (changes.isEmpty) {
                                    Navigator.pop(dialog, false);
                                    return;
                                  }
                                  final id = p['productId'] ?? p['id'];
                                  final fingerprint =
                                      jsonEncode([id, p['updatedAt'], changes]);
                                  final requestId = editRequests.putIfAbsent(
                                      fingerprint, () => const Uuid().v4());
                                  update(() {
                                    sending = true;
                                    failure = null;
                                  });
                                  try {
                                    await widget.api.operation(
                                        token, 'products/$id',
                                        session: session,
                                        body: {
                                          'businessId': branch,
                                          ...changes,
                                          'requestId': requestId
                                        });
                                    if (stillAuthorized()) {
                                      editRequests.remove(fingerprint);
                                      if (dialog.mounted)
                                        Navigator.pop(dialog, true);
                                    } else if (dialog.mounted) {
                                      Navigator.pop(dialog, false);
                                    }
                                  } catch (e) {
                                    if (dialog.mounted) {
                                      if (!stillAuthorized()) {
                                        Navigator.pop(dialog, false);
                                        return;
                                      }
                                      update(() {
                                        sending = false;
                                        failure = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: const Text('حفظ'))
                    ])));
    final edited = await Navigator.of(context).push(route);
    await route.completed;
    name.dispose();
    price.dispose();
    description.dispose();
    if (edited == true && stillAuthorized()) {
      setState(() => notice = 'تم الحفظ على الخادم.');
      await load();
    }
  }

  Future<void> editDay(String day) async {
    final existing = Map<String, dynamic>.from(hours[day] ?? {});
    bool open = existing['isOpen'] == true;
    TimeOfDay parse(dynamic s) {
      final p = '$s'.split(':');
      return p.length == 2
          ? TimeOfDay(
              hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0)
          : const TimeOfDay(hour: 9, minute: 0);
    }

    var from = parse(existing['openTime']), to = parse(existing['closeTime']);
    final edited = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, set) => AlertDialog(
                    title: Text(days[day]!),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      SwitchListTile(
                          title: const Text('الفرع مفتوح'),
                          value: open,
                          onChanged: (v) => set(() => open = v)),
                      if (open) ...[
                        TextButton(
                            onPressed: () async {
                              final v = await showTimePicker(
                                  context: c, initialTime: from);
                              if (v != null && c.mounted) set(() => from = v);
                            },
                            child: Text('الفتح: ${from.format(c)}')),
                        TextButton(
                            onPressed: () async {
                              final v = await showTimePicker(
                                  context: c, initialTime: to);
                              if (v != null && c.mounted) set(() => to = v);
                            },
                            child: Text('الإغلاق: ${to.format(c)}')),
                      ]
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('رجوع')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('تطبيق'))
                    ])));
    if (edited == true && mounted) {
      if (open && to.hour * 60 + to.minute <= from.hour * 60 + from.minute) {
        setState(() => error = 'يجب أن يكون الإغلاق بعد الفتح.');
        return;
      }
      String fmt(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      setState(() => hours[day] = {
            'isOpen': open,
            'isClosed': !open,
            'openTime': open ? fmt(from) : 'closed',
            'closeTime': open ? fmt(to) : 'closed'
          });
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.showTabs)
          Wrap(spacing: 8, children: [
            if (ordersAllowed)
              ChoiceChip(
                  label: const Text('الطلبات'),
                  selected: tab == 'orders',
                  onSelected: busy
                      ? null
                      : (_) {
                          setState(() => tab = 'orders');
                          load();
                        }),
            if (readMenu)
              ChoiceChip(
                  label: const Text('القائمة'),
                  selected: tab == 'menu',
                  onSelected: busy
                      ? null
                      : (_) {
                          setState(() => tab = 'menu');
                          load();
                        }),
            if (readHours)
              ChoiceChip(
                  label: const Text('ساعات العمل'),
                  selected: tab == 'hours',
                  onSelected: busy
                      ? null
                      : (_) {
                          setState(() => tab = 'hours');
                          load();
                        }),
          ]),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!,
                  style: const TextStyle(color: Color(0xFF9B1C1C)))),
        if (notice != null)
          Text(notice!, style: const TextStyle(color: Color(0xFF00296B))),
        if (tab == 'none')
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      'لا توجد مهام تشغيلية متاحة لهذا الدور في هذه المرحلة.'))),
        if (tab == 'orders') ...[
          TextButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث الطلبات')),
          if (!busy && error == null && items.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لا توجد طلبات لعرضها.'))),
          for (final o in items)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('طلب ${o['orderId']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00296B))),
                          Text({
                                'pending': 'جديد',
                                'confirmed': 'مقبول',
                                'preparing': 'قيد التحضير',
                                'ready': 'جاهز'
                              }[o['status']] ??
                              '${o['status']}'),
                          for (final item in (o['items'] as List? ?? []))
                            Text(
                                '${item['quantity'] ?? 1} × ${item['name'] ?? item['productName'] ?? ''}'),
                          if (o['notes'] != null)
                            Text('ملاحظات: ${o['notes']}'),
                          if (widget.showTabs)
                            Wrap(spacing: 8, children: [
                              if (o['status'] == 'pending') ...[
                                FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => orderAction(o, 'confirm'),
                                    child: const Text('قبول — 20 دقيقة')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => orderAction(o, 'reject'),
                                    child: const Text('رفض')),
                              ],
                              if (o['status'] == 'confirmed')
                                FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => orderAction(o, 'preparing'),
                                    child: const Text('بدء التحضير')),
                              if (['preparing', 'in_kitchen']
                                  .contains(o['status']))
                                FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => orderAction(o, 'ready'),
                                    child: const Text('جاهز للتسليم')),
                            ])
                        ]))),
        ],
        if (tab == 'menu')
          TextButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث المنتجات')),
        if (tab == 'menu' && !busy && error == null && items.isEmpty)
          const Text('لا توجد منتجات.'),
        if (tab == 'menu' && createAllowed)
          FilledButton.icon(
              onPressed: busy ? null : createProduct,
              icon: const Icon(Icons.add),
              label: const Text('إضافة منتج')),
        if (tab == 'menu')
          for (final p in items)
            Card(
                child: ListTile(
                    title: Text(p['name'] ?? ''),
                    subtitle: Text(
                        '${p['price']} د.ع • ${p['isAvailable'] == true ? 'متاح' : 'غير متاح'}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (editProductAllowed) const Icon(Icons.edit_outlined),
                      if (deleteAllowed)
                        IconButton(
                            tooltip: 'حذف المنتج',
                            onPressed: busy ? null : () => deleteProduct(p),
                            icon: const Icon(Icons.delete_outline)),
                    ]),
                    onTap: busy || !editProductAllowed
                        ? null
                        : () => editProduct(p))),
        if (tab == 'hours') ...[
          for (final d in days.entries)
            Card(
                child: ListTile(
                    title: Text(d.value),
                    subtitle: Text(hours[d.key]?['isOpen'] == true
                        ? '${hours[d.key]['openTime']} — ${hours[d.key]['closeTime']}'
                        : 'مغلق'),
                    trailing: const Icon(Icons.schedule),
                    onTap: busy || widget.capabilities['editHours'] != true
                        ? null
                        : () => editDay(d.key))),
          if (widget.capabilities['editHours'] == true)
            FilledButton(
                onPressed: busy
                    ? null
                    : () => save(
                        'businesses/${widget.businessId}/working-hours',
                        {'workingHours': hours}),
                child: const Text('حفظ أسبوع العمل')),
        ],
      ]);
}
