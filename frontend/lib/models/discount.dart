enum DiscountType {
  percentage,
  fixedAmount,
  conditional,
  buyXGetY,
  freeDelivery,
}

enum DiscountApplicability {
  allItems,
  specificItems,
  specificCategories,
  minimumOrder,
}

enum DiscountStatus {
  active,
  scheduled,
  expired,
  inactive,
}

enum ConditionalDiscountRule {
  buyXGetY,
  minimumAmount,
  firstOrder,
  loyaltyCustomer,
}

class Discount {
  final String id;
  final String name;
  final String title; // Alias for name for backward compatibility
  final String description;
  final DiscountType type;
  final double value;
  final DiscountApplicability applicability;
  final DiscountStatus status;
  final DateTime startDate;
  final DateTime validFrom; // Alias for startDate
  final DateTime endDate;
  final DateTime validTo; // Alias for endDate
  final double? minimumOrderAmount;
  final int? maxUsage;
  final int currentUsage;
  final List<String> applicableItemIds;
  final List<String> applicableCategoryIds;
  final ConditionalDiscountRule? conditionalRule;
  final Map<String, dynamic>? conditionalRuleData;
  final Map<String, dynamic>?
      conditionalParameters; // Alias for conditionalRuleData
  final String businessId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Discount({
    required this.id,
    required this.name,
    String? title,
    required this.description,
    required this.type,
    required this.value,
    required this.applicability,
    required this.status,
    required this.startDate,
    DateTime? validFrom,
    required this.endDate,
    DateTime? validTo,
    this.minimumOrderAmount,
    this.maxUsage,
    this.currentUsage = 0,
    this.applicableItemIds = const [],
    this.applicableCategoryIds = const [],
    this.conditionalRule,
    this.conditionalRuleData,
    Map<String, dynamic>? conditionalParameters,
    required this.businessId,
    required this.createdAt,
    required this.updatedAt,
  })  : title = title ?? name,
        validFrom = validFrom ?? startDate,
        validTo = validTo ?? endDate,
        conditionalParameters = conditionalParameters ?? conditionalRuleData;

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'] ?? json['discount_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: _parseDiscountType(json['type']),
      value: (json['value'] ?? 0).toDouble(),
      applicability: _parseDiscountApplicability(json['applicability']),
      status: _parseDiscountStatus(json['status']),
      startDate:
          DateTime.tryParse(json['startDate'] ?? json['start_date'] ?? '') ??
              DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? json['end_date'] ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      minimumOrderAmount: json['minimumOrderAmount'] != null
          ? (json['minimumOrderAmount']).toDouble()
          : null,
      maxUsage: json['maxUsage'] ?? json['max_usage'],
      currentUsage: json['currentUsage'] ?? json['current_usage'] ?? 0,
      applicableItemIds: List<String>.from(
          json['applicableItemIds'] ?? json['applicable_item_ids'] ?? []),
      applicableCategoryIds: List<String>.from(json['applicableCategoryIds'] ??
          json['applicable_category_ids'] ??
          []),
      conditionalRule: _parseConditionalRule(
          json['conditionalRule'] ?? json['conditional_rule']),
      conditionalRuleData:
          json['conditionalRuleData'] ?? json['conditional_rule_data'],
      businessId: json['businessId'] ?? json['business_id'] ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ??
              DateTime.now(),
    );
  }

  static DiscountType _parseDiscountType(String? type) {
    switch (type?.toLowerCase()) {
      case 'percentage':
        return DiscountType.percentage;
      case 'fixedamount':
      case 'fixed_amount':
        return DiscountType.fixedAmount;
      case 'conditional':
        return DiscountType.conditional;
      case 'buyxgety':
      case 'buy_x_get_y':
        return DiscountType.buyXGetY;
      case 'freedelivery':
      case 'free_delivery':
        return DiscountType.freeDelivery;
      default:
        return DiscountType.percentage;
    }
  }

  static DiscountApplicability _parseDiscountApplicability(
      String? applicability) {
    switch (applicability?.toLowerCase()) {
      case 'allitems':
      case 'all_items':
        return DiscountApplicability.allItems;
      case 'specificitems':
      case 'specific_items':
        return DiscountApplicability.specificItems;
      case 'specificcategories':
      case 'specific_categories':
        return DiscountApplicability.specificCategories;
      case 'minimumorder':
      case 'minimum_order':
        return DiscountApplicability.minimumOrder;
      default:
        return DiscountApplicability.allItems;
    }
  }

  static DiscountStatus _parseDiscountStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return DiscountStatus.active;
      case 'scheduled':
        return DiscountStatus.scheduled;
      case 'expired':
        return DiscountStatus.expired;
      case 'inactive':
        return DiscountStatus.inactive;
      default:
        return DiscountStatus.active;
    }
  }

  static ConditionalDiscountRule? _parseConditionalRule(String? rule) {
    switch (rule?.toLowerCase()) {
      case 'buyxgety':
      case 'buy_x_get_y':
        return ConditionalDiscountRule.buyXGetY;
      case 'minimumamount':
      case 'minimum_amount':
        return ConditionalDiscountRule.minimumAmount;
      case 'firstorder':
      case 'first_order':
        return ConditionalDiscountRule.firstOrder;
      case 'loyaltycustomer':
      case 'loyalty_customer':
        return ConditionalDiscountRule.loyaltyCustomer;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title, // Add title field that backend expects
      'description': description,
      'type': type.name,
      'value': value,
      'applicability': applicability.name,
      'status': status.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'validFrom': validFrom.toIso8601String(), // Backend expects validFrom
      'validTo': validTo.toIso8601String(), // Backend expects validTo
      'minimumOrderAmount': minimumOrderAmount,
      'maxUsage': maxUsage,
      'currentUsage': currentUsage,
      'applicableItemIds': applicableItemIds,
      'applicableCategoryIds': applicableCategoryIds,
      'conditionalRule': conditionalRule?.name,
      'conditionalRuleData': conditionalRuleData,
      'conditionalParameters':
          conditionalParameters, // Add this field for backend validation
      'businessId': businessId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isActive {
    final now = DateTime.now();
    return status == DiscountStatus.active &&
        now.isAfter(startDate) &&
        now.isBefore(endDate) &&
        (maxUsage == null || currentUsage < maxUsage!);
  }

  bool get isExpired {
    return DateTime.now().isAfter(endDate) || status == DiscountStatus.expired;
  }

  double calculateDiscount(double orderAmount, {int quantity = 1}) {
    if (!isActive) return 0.0;

    switch (type) {
      case DiscountType.percentage:
        return (orderAmount * value / 100).clamp(0.0, orderAmount);
      case DiscountType.fixedAmount:
        return value.clamp(0.0, orderAmount);
      case DiscountType.freeDelivery:
        return 0.0; // Delivery discount handled separately
      case DiscountType.conditional:
      case DiscountType.buyXGetY:
        // Complex discount calculation would go here
        return 0.0;
    }
  }

  Discount copyWith({
    String? id,
    String? name,
    String? description,
    DiscountType? type,
    double? value,
    DiscountApplicability? applicability,
    DiscountStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    double? minimumOrderAmount,
    int? maxUsage,
    int? currentUsage,
    List<String>? applicableItemIds,
    List<String>? applicableCategoryIds,
    ConditionalDiscountRule? conditionalRule,
    Map<String, dynamic>? conditionalRuleData,
    String? businessId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Discount(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      applicability: applicability ?? this.applicability,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      maxUsage: maxUsage ?? this.maxUsage,
      currentUsage: currentUsage ?? this.currentUsage,
      applicableItemIds: applicableItemIds ?? this.applicableItemIds,
      applicableCategoryIds:
          applicableCategoryIds ?? this.applicableCategoryIds,
      conditionalRule: conditionalRule ?? this.conditionalRule,
      conditionalRuleData: conditionalRuleData ?? this.conditionalRuleData,
      businessId: businessId ?? this.businessId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Discount && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Discount(id: $id, name: $name, type: $type, value: $value)';
  }
}
