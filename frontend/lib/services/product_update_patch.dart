import 'dart:convert';
import '../models/product.dart';

/// Send only edited fields; legacy images/categories must not block unrelated edits.
Map<String, dynamic> productUpdatePatch(Product before, Product after) {
  String? image(Product p) =>
      p.imageUrls.isNotEmpty ? p.imageUrls.first : p.imageUrl;
  final old = <String, dynamic>{
    'name': before.name,
    'barcode': before.barcode,
    'description': before.description,
    'price': before.price,
    'categoryId': before.categoryId,
    'isAvailable': before.isAvailable,
    'imageUrl': image(before),
    'optionGroups': before.optionGroups
  };
  final next = <String, dynamic>{
    'name': after.name,
    'barcode': after.barcode,
    'description': after.description,
    'price': after.price,
    'categoryId': after.categoryId,
    'isAvailable': after.isAvailable,
    'imageUrl': image(after),
    'optionGroups': after.optionGroups
  };
  return Map.fromEntries(
      next.entries.where((e) => jsonEncode(e.value) != jsonEncode(old[e.key])));
}

/// Mutation responses contain editable fields, not stock/accounting metadata.
/// Keep omitted metadata and normalize a replaced single image consistently.
Product mergeProductUpdateResponse(
    Product previous, Map<String, dynamic> response) {
  return Product.fromJson({
    ...previous.toJson(),
    ...response,
    if (response.containsKey('imageUrl') && !response.containsKey('imageUrls'))
      'imageUrls':
          response['imageUrl'] == null ? <String>[] : [response['imageUrl']],
  });
}
