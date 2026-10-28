import 'package:flutter/material.dart';
import '../services/product_service.dart';

class BranchCategoriesScreen extends StatefulWidget {
  final String businessId;
  const BranchCategoriesScreen({super.key, required this.businessId});
  @override
  State<BranchCategoriesScreen> createState() => _BranchCategoriesScreenState();
}

class _BranchCategoriesScreenState extends State<BranchCategoriesScreen> {
  List<Map<String, dynamic>> rows = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    final r =
        await ProductService.getAllCategories(businessId: widget.businessId);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r['success'] == true) {
        rows = List<Map<String, dynamic>>.from(r['categories'] ?? []);
        rows.sort((a, b) => ((a['sortOrder'] ?? 0) as num)
            .compareTo((b['sortOrder'] ?? 0) as num));
      } else {
        error = r['message']?.toString();
      }
    });
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final own = row?['businessId'] == widget.businessId,
        name = TextEditingController(
            text: row?['categoryName']?.toString() ??
                row?['name_ar']?.toString() ??
                ''),
        order = TextEditingController(
            text: (row?['sortOrder'] ?? rows.length).toString());
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(row == null ? 'إضافة قسم' : 'تعديل القسم'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      autofocus: true,
                      decoration:
                          const InputDecoration(labelText: 'اسم القسم')),
                  TextField(
                      controller: order,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الترتيب'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, {
                            'name': name.text.trim(),
                            'sortOrder': int.tryParse(order.text)
                          }),
                      child: const Text('حفظ'))
                ]));
    name.dispose();
    order.dispose();
    if (result == null ||
        result['name'].toString().isEmpty ||
        result['sortOrder'] == null) {
      return;
    }
    setState(() => busy = true);
    final r = await ProductService.mutateCategory(
        businessId: widget.businessId,
        categoryId: own ? row!['categoryId']?.toString() : null,
        method: own ? 'PUT' : 'POST',
        name: result['name'],
        sortOrder: result['sortOrder']);
    if (r['success'] == true) {
      await load();
    } else if (mounted) {
      setState(() {
        busy = false;
        error = r['message']?.toString();
      });
    }
  }

  Future<void> hide(Map<String, dynamic> row) async {
    setState(() => busy = true);
    final r = await ProductService.mutateCategory(
        businessId: widget.businessId,
        categoryId: row['categoryId'].toString(),
        method: 'DELETE');
    if (r['success'] == true) {
      await load();
    } else if (mounted) {
      setState(() {
        busy = false;
        error = r['message'] == 'CATEGORY_IN_USE'
            ? 'لا يمكن إخفاء القسم لأنه مرتبط بمنتجات. انقل المنتجات أولاً.'
            : r['message']?.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أقسام القائمة')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('قسم جديد'),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: busy
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (error != null)
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(error!),
                          ),
                        ),
                      for (final row in rows)
                        Card(
                          child: ListTile(
                            title: Text(row['categoryName']?.toString() ??
                                row['name_ar']?.toString() ??
                                row['name']?.toString() ??
                                'قسم'),
                            subtitle: Text(row['businessId'] ==
                                    widget.businessId
                                ? 'قسم خاص بهذا الفرع • ترتيب ${row['sortOrder'] ?? 0}'
                                : 'قسم عام'),
                            leading: Icon(row['isActive'] == false
                                ? Icons.visibility_off
                                : Icons.category),
                            trailing: row['businessId'] == widget.businessId
                                ? PopupMenuButton<String>(
                                    onSelected: (value) =>
                                        value == 'edit' ? edit(row) : hide(row),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'edit', child: Text('تعديل')),
                                      PopupMenuItem(
                                          value: 'hide', child: Text('إخفاء')),
                                    ],
                                  )
                                : const Icon(Icons.lock_outline),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      );
}
