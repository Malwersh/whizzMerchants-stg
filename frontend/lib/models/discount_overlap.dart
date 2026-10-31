import 'discount.dart';

/// Editorial overlap is advisory. Redemption still selects one offer on server.
List<Discount> alternativeDiscounts({
  required List<Discount> existing,
  required DiscountApplicability applicability,
  required List<String> itemIds,
  required List<String> categoryIds,
  required Map<String, String> productCategories,
  required DateTime start,
  required DateTime end,
  String? currentId,
}) {
  bool intersects(Discount d) {
    final broad = [
      DiscountApplicability.allItems,
      DiscountApplicability.minimumOrder
    ];
    if (broad.contains(d.applicability) || broad.contains(applicability))
      return true;
    if (applicability == DiscountApplicability.specificItems) {
      return itemIds.any((id) =>
          d.applicability == DiscountApplicability.specificItems
              ? d.applicableItemIds.contains(id)
              : d.applicableCategoryIds.contains(productCategories[id]));
    }
    return d.applicability == DiscountApplicability.specificCategories
        ? categoryIds.any(d.applicableCategoryIds.contains)
        : d.applicableItemIds
            .any((id) => categoryIds.contains(productCategories[id]));
  }

  if (!start.isBefore(end)) return [];
  return existing
      .where((d) =>
          d.id != currentId &&
          [DiscountStatus.active, DiscountStatus.scheduled]
              .contains(d.status) &&
          d.type != DiscountType.freeDelivery &&
          d.validFrom.isBefore(end) &&
          start.isBefore(d.validTo) &&
          intersects(d))
      .toList();
}
