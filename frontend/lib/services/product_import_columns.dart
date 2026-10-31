const productImportFields = <String, String>{
  'name': 'اسم المنتج',
  'price': 'السعر بالدينار',
  'categoryId': 'معرف القسم',
  'productId': 'معرف المنتج للتحديث',
  'rowId': 'معرف الصف',
  'description': 'الوصف',
  'barcode': 'الباركود',
  'isAvailable': 'متاح للبيع',
  'imageFile': 'اسم ملف الصورة',
  'imageUrl': 'رابط صورة مرفوعة لهذا الفرع',
  'stock': 'الكمية المتاحة (اختياري)',
  'optionGroupsJson': 'الخيارات بصيغة JSON',
};
List<String> productImportHeaders(String csv) {
  final cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < csv.length; i++) {
    final c = csv[i];
    if (c == '"') {
      if (quoted && i + 1 < csv.length && csv[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && (c == ',' || c == '\n')) {
      cells.add(cell.toString().replaceFirst('\ufeff', '').trim());
      cell.clear();
      if (c == '\n') return cells;
    } else {
      cell.write(c);
    }
  }
  cells.add(cell.toString().replaceFirst('\ufeff', '').trim());
  return cells;
}

Map<String, String> suggestProductImportMapping(List<String> headers) {
  const aliases = <String, List<String>>{
    'name': ['اسم المنتج', 'اسم الصنف', 'الاسم', 'product name', 'name'],
    'price': ['السعر', 'سعر', 'سعر البيع', 'price'],
    'categoryId': ['معرف القسم', 'categoryid', 'category id'],
    'description': ['الوصف', 'description'],
    'barcode': ['باركود', 'الباركود', 'barcode'],
    'stock': ['الكمية', 'كمية', 'المخزون', 'quantity', 'stock'],
    'imageFile': [
      'الصورة',
      'اسم الصورة',
      'اسم ملف الصورة',
      'image',
      'imagefile'
    ],
    'productId': ['معرف المنتج', 'productid'],
    'isAvailable': ['متاح', 'isavailable'],
  };
  final result = <String, String>{};
  for (final field in productImportFields.keys) {
    for (final h in headers) {
      if (h.toLowerCase() == field.toLowerCase() ||
          (aliases[field]?.contains(h.toLowerCase()) ?? false)) {
        if (!result.containsValue(h)) result[field] = h;
        break;
      }
    }
  }
  return result;
}
