import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/discount.dart';
import 'package:whizz_merchants/models/discount_overlap.dart';

void main() {
  final start = DateTime.utc(2026, 10, 30), end = DateTime.utc(2026, 11, 2);
  Discount offer(String id, DiscountApplicability scope, {List<String> items = const [], List<String> categories = const [], DateTime? from, DateTime? to, DiscountStatus status = DiscountStatus.active, DiscountType type = DiscountType.percentage}) => Discount(id: id, name: id, description: '', type: type, value: 15, applicability: scope, status: status, startDate: from ?? start, endDate: to ?? end, applicableItemIds: items, applicableCategoryIds: categories, businessId: 'b', createdAt: start, updatedAt: start);
  List<Discount> matches(List<Discount> rows, {String? current}) => alternativeDiscounts(existing: rows, applicability: DiscountApplicability.specificItems, itemIds: ['p'], categoryIds: [], productCategories: {'p':'pizza','q':'burger'}, start: start, end: end, currentId: current);
  test('basket-wide offer is an alternative, never a creation veto', () {
    final rows=matches([offer('basket',DiscountApplicability.allItems)]);
    expect(rows.map((d)=>d.id),['basket']);
  });
  test('expired, paused, future nonoverlapping and delivery offers are excluded', () {
    expect(matches([
      offer('expired',DiscountApplicability.allItems,to:start),
      offer('paused',DiscountApplicability.allItems,status:DiscountStatus.inactive),
      offer('later',DiscountApplicability.allItems,from:end,to:end.add(const Duration(days:1))),
      offer('delivery',DiscountApplicability.allItems,type:DiscountType.freeDelivery),
    ]),isEmpty);
  });
  test('item versus category intersection works in both directions and own edit is excluded', () {
    expect(matches([offer('pizza',DiscountApplicability.specificCategories,categories:['pizza']),offer('other',DiscountApplicability.specificItems,items:['q'])]).map((d)=>d.id),['pizza']);
    expect(matches([offer('self',DiscountApplicability.allItems)],current:'self'),isEmpty);
    expect(alternativeDiscounts(existing:[offer('item',DiscountApplicability.specificItems,items:['p'])],applicability:DiscountApplicability.specificCategories,itemIds:[],categoryIds:['pizza'],productCategories:{'p':'pizza'},start:start,end:end).map((d)=>d.id),['item']);
  });
}
