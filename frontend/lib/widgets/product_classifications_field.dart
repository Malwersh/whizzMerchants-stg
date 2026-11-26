import 'package:flutter/material.dart';

/// Edits a local selection; dismissing the sheet never changes the product.
class ProductClassificationsField extends StatelessWidget {
  final List<Map<String, dynamic>> choices;
  final List<String> selected;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;
  const ProductClassificationsField(
      {super.key,
      required this.choices,
      required this.selected,
      required this.onChanged,
      this.enabled = true});

  Future<void> _open(BuildContext context) async {
    final draft = [...selected];
    var query = '';
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(builder: (context, update) {
        final filtered = choices
            .where((row) => row['label'].toString().contains(query.trim()))
            .toList();
        return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .75,
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                        child: Row(children: [
                          const Expanded(
                              child: Text('تصنيفات المنتج',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00296B)))),
                          IconButton(
                              tooltip: 'إغلاق',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close)),
                        ])),
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: TextField(
                            decoration: const InputDecoration(
                                hintText: 'ابحث عن تصنيف',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (value) => update(() => query = value))),
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('المختار ${draft.length} من ١٢',
                                style: const TextStyle(
                                    color: Color(0xFF647184))))),
                    Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('لا توجد تصنيفات مطابقة'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final row = filtered[index],
                                      id = filtered[index]['id'] as String;
                                  return CheckboxListTile(
                                      title: Text(row['label'].toString()),
                                      value: draft.contains(id),
                                      activeColor: const Color(0xFF00296B),
                                      dense: true,
                                      onChanged: !draft.contains(id) &&
                                              draft.length >= 12
                                          ? null
                                          : (checked) => update(() {
                                                if (checked == true) {
                                                  draft.add(id);
                                                } else {
                                                  draft.remove(id);
                                                }
                                              }));
                                })),
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF00296B),
                                    foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(context, draft),
                                child: const Text('اعتماد التصنيفات')))),
                  ])),
            ));
      }),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final labels = {
      for (final row in choices) row['id']: row['label'].toString()
    };
    return ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('تصنيفات المنتج — اختياري',
            style: TextStyle(color: Color(0xFF00296B))),
        subtitle: Text(
            selected.isEmpty
                ? 'اختيار تصنيفات إضافية للمنتج'
                : selected.map((id) => labels[id] ?? 'تصنيف محفوظ').join('، '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        leading: const Icon(Icons.category_outlined, color: Color(0xFF00296B)),
        trailing: const Icon(Icons.chevron_left, color: Color(0xFF00296B)),
        onTap: enabled && choices.isNotEmpty ? () => _open(context) : null);
  }
}
