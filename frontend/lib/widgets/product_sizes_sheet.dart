import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ProductSizesResult {
  final int basePrice;
  final Map<String, dynamic> group;
  const ProductSizesResult(this.basePrice, this.group);
}

/// Store final size prices as base + option delta, matching the existing cart API.
ProductSizesResult buildProductSizes(List<Map<String, dynamic>> rows,
    {String? groupId}) {
  if (rows.length < 2 || rows.length > 40) {
    throw const FormatException('أضف حجمين على الأقل');
  }
  final names = <String>{};
  for (final row in rows) {
    final name = row['name']?.toString().trim() ?? '';
    final price = row['price'];
    if (name.isEmpty ||
        name.length > 150 ||
        !names.add(name.toLowerCase()) ||
        price is! int ||
        price <= 0 ||
        price > 1000000000) {
      throw const FormatException('راجع أسماء الأحجام وأسعارها');
    }
  }
  final base =
      rows.map((r) => r['price'] as int).reduce((a, b) => a < b ? a : b);
  return ProductSizesResult(base, {
    'id': groupId ?? const Uuid().v4(),
    'title': 'الحجم',
    'required': true,
    'maxSelections': 1,
    'options': [
      for (final row in rows)
        {
          'id': row['id'] ?? const Uuid().v4(),
          'name': row['name'].toString().trim(),
          'extraPrice': (row['price'] as int) - base,
          'isAvailable': row['isAvailable'] != false,
        }
    ],
  });
}

Future<ProductSizesResult?> showProductSizesSheet(BuildContext context,
    {required int basePrice, Map<String, dynamic>? existing}) {
  final form = GlobalKey<FormState>();
  final rows = <Map<String, dynamic>>[];
  String money(num n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();
  if (existing != null) {
    for (final option in existing['options'] as List) {
      rows.add({
        'id': option['id'],
        'name': option['name'],
        'priceText': money(basePrice + (option['extraPrice'] as num)),
        'isAvailable': option['isAvailable']
      });
    }
  } else {
    for (final name in ['صغير', 'وسط', 'كبير']) {
      rows.add({
        'id': const Uuid().v4(),
        'name': name,
        'priceText': basePrice > 0 ? '$basePrice' : '',
        'isAvailable': true
      });
    }
  }
  return showModalBottomSheet<ProductSizesResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .85),
                child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                            child: Row(children: [
                              const Expanded(
                                  child: Text('الأحجام وأسعارها',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF00296B)))),
                              IconButton(
                                  tooltip: 'إغلاق',
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(Icons.close)),
                            ])),
                        const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Text(
                                'اكتب السعر الكامل لكل حجم. سيختار الزبون حجمًا واحدًا، وتُحسب الإضافات الأخرى فوق سعره.',
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: Color(0xFF52627A)))),
                        Flexible(
                            child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(children: [
                                  for (final row in rows)
                                    Padding(
                                        key: ValueKey(row['id']),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                  child: TextFormField(
                                                      initialValue:
                                                          row['name'] as String,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'اسم الحجم'),
                                                      onChanged: (v) =>
                                                          row['name'] = v,
                                                      validator: (v) => v ==
                                                                  null ||
                                                              v.trim().isEmpty
                                                          ? 'أدخل اسم الحجم'
                                                          : null)),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: TextFormField(
                                                      initialValue:
                                                          row['priceText']
                                                              as String,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'السعر الكامل (د.ع)'),
                                                      onChanged: (v) =>
                                                          row['priceText'] = v,
                                                      validator: (v) {
                                                        final n = int.tryParse(
                                                            v ?? '');
                                                        return n == null ||
                                                                n <= 0 ||
                                                                n > 1000000000
                                                            ? 'أدخل سعرًا صحيحًا'
                                                            : null;
                                                      })),
                                              IconButton(
                                                  tooltip: 'حذف الحجم',
                                                  onPressed: rows.length > 2
                                                      ? () => refresh(() =>
                                                          rows.remove(row))
                                                      : null,
                                                  icon: const Icon(Icons
                                                      .remove_circle_outline)),
                                            ])),
                                  TextButton.icon(
                                      onPressed: rows.length < 40
                                          ? () => refresh(() => rows.add({
                                                'id': const Uuid().v4(),
                                                'name': '',
                                                'priceText': '',
                                                'isAvailable': true
                                              }))
                                          : null,
                                      icon: const Icon(Icons.add),
                                      label: const Text('إضافة حجم آخر')),
                                ]))),
                        Padding(
                            padding: const EdgeInsets.all(20),
                            child: SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00296B),
                                        foregroundColor: Colors.white),
                                    onPressed: () {
                                      if (!form.currentState!.validate())
                                        return;
                                      try {
                                        final result = buildProductSizes([
                                          for (final row in rows)
                                            {
                                              ...row,
                                              'price': int.parse(
                                                  row['priceText'] as String)
                                            }
                                        ], groupId: existing?['id'] as String?);
                                        Navigator.pop(sheetContext, result);
                                      } on FormatException catch (e) {
                                        ScaffoldMessenger.of(sheetContext)
                                            .showSnackBar(SnackBar(
                                                content: Text(e.message)));
                                      }
                                    },
                                    child: const Text(
                                        'اعتماد الأحجام والأسعار')))),
                      ]),
                    )),
              ),
            )),
  );
}
