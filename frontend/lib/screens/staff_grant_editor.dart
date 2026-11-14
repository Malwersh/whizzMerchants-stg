import 'package:flutter/material.dart';

/// Selects a complete centrally managed job type. The server builds its snapshot.
class StaffGrantEditor extends StatefulWidget {
  final Map<String, dynamic> policy;
  final Map<String, dynamic>? initialGrant;
  const StaffGrantEditor({super.key, required this.policy, this.initialGrant});
  @override
  State<StaffGrantEditor> createState() => _StaffGrantEditorState();
}

class _StaffGrantEditorState extends State<StaffGrantEditor> {
  String? roleId;
  late final roles =
      List<Map<String, dynamic>>.from(widget.policy['roles'] ?? [])
          .where((r) => r['enabled'] == true)
          .toList();
  bool ready(Map<String, dynamic> role) {
    final permissions = List<String>.from(role['permissions'] ?? []);
    final capabilities =
        List<Map<String, dynamic>>.from(widget.policy['capabilities'] ?? []);
    const orderActions = [
      'orders.accept',
      'orders.reject',
      'orders.prepare',
      'orders.ready'
    ];
    final completeOrders = !orderActions.any(permissions.contains) ||
        orderActions.every(permissions.contains);
    return completeOrders &&
        permissions.contains('branch.read') &&
        permissions.every((id) =>
            (widget.policy['enabledPermissions'] as List? ?? []).contains(id) &&
            capabilities.any((c) =>
                c['id'] == id &&
                c['implemented'] == true &&
                c['delegable'] == true));
  }

  Map<String, dynamic>? get selected {
    for (final role in roles) {
      if (role['id'] == roleId) return role;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final id = widget.initialGrant?['roleId'];
    if (roles.any((r) => r['id'] == id)) roleId = id as String;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('اختيار نوع الموظف'),
        content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text(
                      'اختر نوع الموظف لهذا الفرع. يحصل الموظف على حزمة عمل النوع كاملة، دون تحديد كل إجراء على حدة.'),
                  DropdownButtonFormField<String>(
                      initialValue: roleId,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'نوع الموظف'),
                      items: roles
                          .map((r) => DropdownMenuItem<String>(
                              value: r['id'] as String,
                              child: Text(r['nameAr'] as String)))
                          .toList(),
                      onChanged: (v) => setState(() => roleId = v)),
                  if (roles.isEmpty)
                    const Text(
                        'لا توجد أنواع موظفين متاحة. أعد المحاولة بعد تجهيزها من المنصة.'),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    Text((selected!['description'] as String?)
                                ?.trim()
                                .isNotEmpty ==
                            true
                        ? selected!['description'] as String
                        : 'صلاحيات هذا النوع تحددها المنصة المركزية.'),
                    if (!ready(selected!))
                      const Text(
                          'هذا النوع غير جاهز للتعيين حاليًا. تحتاج حزمة عمله إلى تجهيز أو إتاحة من المنصة.'),
                  ],
                  if (widget.initialGrant != null)
                    const Text(
                        'الحفظ يعيد تعيين حزمة النوع الحالية كاملة وقد يضيف أو يسحب صلاحيات مقارنة بالتعيين السابق، وينهي جلسة الموظف السابقة. تعديل القالب وحده لا يغير تعيينًا قائمًا.'),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: selected == null || !ready(selected!)
                  ? null
                  : () => Navigator.pop(context, <String, dynamic>{
                        'roleId': roleId,
                        'expectedPolicyVersion': widget.policy['version']
                      }),
              child: const Text('اعتماد النوع')),
        ],
      );
}
