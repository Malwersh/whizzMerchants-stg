import 'delivery_address.dart';
import '../core/utils/app_logger.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready, // deprecated - استخدم readyForPickup بدلاً منها
  readyForPickup, // ✅ الحالة الصحيحة لنظام الموجات
  reassigning, // 🔄 جاري البحث عن سائق بديل (بعد unassignment)
  // 🚗 حالات السائق - Driver delivery states
  assigned, // تم تعيين سائق
  headingToStore, // السائق في الطريق للمطعم
  arrivedAtStore, // السائق وصل للمطعم
  pickedUp, // تم استلام الطلب من المطعم
  headingToCustomer, // في الطريق للعميل
  arrivedAtCustomer, // وصل إلى الزبون
  // حالات إتمام الطلب
  completed,
  cancelled,
  expired,
  onTheWay, // deprecated - استخدم headingToCustomer
  delivered,
  returned,
  returning,
  returnArrived,
}

class OrderItem {
  String id;
  String name;
  double price;
  int quantity;
  String? notes;
  final List<String> modifiers;

  OrderItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.notes,
    this.modifiers = const [],
  });

  // Getter for dishId (alias for id for backward compatibility)
  String get dishId => id;
  String get dishName => name;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? json['itemId'] ?? json['skuId'] ?? json['dishId'] ?? '',
      name: json['name'] ??
          json['dishName'] ??
          json['productName'] ??
          'عنصر غير محدد',
      price: json['price'] != null
          ? _parsePrice(json['price'])
          : _parsePrice(json['unitPrice']) / 1000,
      quantity: json['quantity'] ?? 1,
      notes: json['notes'] ?? json['specialInstructions'],
      modifiers: (json['modifiers'] as List? ?? []).whereType<Map>().map((m)=>m['name']?.toString() ?? '').where((s)=>s.isNotEmpty).toList(),
    );
  }

  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;

    double amount = 0.0;
    if (price is double) {
      amount = price;
    } else if (price is int) {
      amount = price.toDouble();
    } else if (price is String) {
      amount = double.tryParse(price) ?? 0.0;
    }

    // No conversion needed - prices are already in IQD format
    // The database stores prices as IQD (e.g., 5000 IQD)
    return amount;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'notes': notes,
      'modifiers': modifiers.map((name)=>{'name':name}).toList(),
    };
  }

  double get totalPrice => price * quantity;
}

class Order {
  final bool driverSearchUnavailable;
  final Map<String,dynamic>? financialAssignment;
  final Map<String,dynamic>? merchantHandover;
  final Map<String,dynamic>? exceptionCancellation;
  final String? exceptionPolicyVersion;
  DateTime? merchantAcceptanceDeadlineAt;
  int? estimatedPreparationTime;
  String id;
  String businessId;
  String customerId;
  String customerName;
  String? customerPhone;
  String? customerAddress;
  DeliveryAddress? deliveryAddress;
  List<OrderItem> items;
  double totalAmount;
  OrderStatus status;
  DateTime createdAt;
  DateTime? updatedAt;
  String? notes;
  String? orderNumber; // Add order number
  double deliveryFee; // Add delivery fee
  final String paymentMethod;
  final String? deliveryInstructions;

  // 🚗 معلومات السائق (عند التعيين)
  String? driverId; // معرف السائق
  String? driverName; // اسم السائق
  String? driverPhone; // رقم هاتف السائق
  String? vehicleType; // نوع المركبة
  String? vehiclePlate; // رقم اللوحة
  DateTime? driverAssignedAt; // وقت تعيين السائق
  DateTime? pickedUpAt; // وقت استلام السائق للطلب

  Order({
    this.driverSearchUnavailable = false,
    this.financialAssignment,
    this.exceptionCancellation,
    this.merchantHandover,
    this.exceptionPolicyVersion,
    this.merchantAcceptanceDeadlineAt,
    this.estimatedPreparationTime,
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.deliveryAddress,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.orderNumber,
    this.deliveryFee = 0.0,
    this.paymentMethod = 'cash',
    this.deliveryInstructions,
    // Driver information
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.vehicleType,
    this.vehiclePlate,
    this.driverAssignedAt,
    this.pickedUpAt,
  });

  // Add getter for display order number
  String get displayOrderNumber {
    if (orderNumber != null && orderNumber!.isNotEmpty) {
      return orderNumber!;
    }
    // Fallback to a shorter version of the ID
    if (id.length > 8) {
      return 'ORD${id.substring(0, 8).toUpperCase()}';
    }
    return 'ORD$id';
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    AppLogger.debug('Order.fromJson - Full JSON: ${json.keys.join(', ')}');

    AppLogger.debug('Order.fromJson - id field: ${json['id']}');

    AppLogger.debug('Order.fromJson - orderId field: ${json['orderId']}');

    final orderId = json['orderId'] ?? json['id'] ?? '';
    AppLogger.debug('Order.fromJson - Final orderId: $orderId');

    if (orderId.isEmpty) {
      AppLogger.warning('WARNING: Order ID is empty! Full JSON: $json');
    }

    return Order(
      id: orderId,
      driverSearchUnavailable: json['driverSearchUnavailable'] == true &&
          json['driverId'] == null && json['assignedDriverId'] == null &&
          ['ready', 'ready_for_pickup', 'reassigning'].contains(json['status']),
      exceptionPolicyVersion: json['exceptionPolicyVersion']?.toString(),
      merchantHandover: json['merchantHandover'] is Map ? Map<String,dynamic>.unmodifiable(json['merchantHandover']) : null,
      exceptionCancellation: json['exceptionCancellation'] is Map ? Map<String,dynamic>.unmodifiable(json['exceptionCancellation']) : null,
      financialAssignment: json['financialAssignment'] is Map ? Map<String,dynamic>.unmodifiable(json['financialAssignment']) : null,
      merchantAcceptanceDeadlineAt: _parseDateTime(json['merchantAcceptanceDeadlineAt']),
      estimatedPreparationTime: (json['estimatedPreparationTime'] as num?)?.toInt(),
      businessId: json['businessId'] ?? json['storeId'] ?? '',
      customerId: json['customerId'] ??
          json['userId'] ??
          json['customer_id'] ??
          'unknown',
      customerName: json['customerName'] ?? 'عميل غير محدد',
      customerPhone: json['customerPhone'],
      customerAddress: json['customerAddress'],
      deliveryAddress: json['deliveryAddress'] != null
          ? DeliveryAddress.fromJson(json['deliveryAddress'])
          : null,
      items: _parseItems(json['items']),
      totalAmount: _parseTotalAmount(json),
      status: _parseOrderStatus(json['status'] ?? 'pending'),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt:
          json['updatedAt'] != null ? _parseDateTime(json['updatedAt']) : null,
      notes: json['notes'],
      orderNumber: json['orderNumber'] ?? json['orderNumber_gsi'],
      deliveryFee: _parseDeliveryFee(json),
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      deliveryInstructions: json['deliveryInstructions']?.toString(),
      // Parse driver information
      driverId: json['driverId'],
      driverName: json['driverName'] ?? json['driver_name'],
      driverPhone: json['driverPhone'] ?? json['driver_phone'],
      vehicleType: json['vehicleType'] ?? json['vehicle_type'],
      vehiclePlate: json['vehiclePlate'] ??
          json['vehicle_plate'] ??
          json['licenseNumber'] ??
          json['license_number'],
      driverAssignedAt: json['driverAssignedAt'] != null
          ? _parseDateTime(json['driverAssignedAt'])
          : null,
      pickedUpAt: json['pickedUpAt'] != null
          ? _parseDateTime(json['pickedUpAt'])
          : null,
    )..logDriverInfo(); // Add logging after creation
  }

  // WizzOrders pricing uses thousandths of IQD; API display fields use IQD.
  static double? _minorToIqd(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    return amount != null && amount.isFinite ? amount / 1000 : null;
  }

  static double _parseDeliveryFee(Map<String, dynamic> json) {
    // Try different possible field names for delivery fee
    final candidates = [
      json['deliveryFee'],
      json['delivery_fee'],
      _minorToIqd(json['pricing']?['deliveryFee']),
      _minorToIqd(json['pricing']?['delivery_fee']),
    ];

    for (final candidate in candidates) {
      if (candidate != null) {
        if (candidate is double) return candidate;
        if (candidate is int) return candidate.toDouble();
        if (candidate is String) {
          final parsed = double.tryParse(candidate);
          if (parsed != null) return parsed;
        }
      }
    }
    return 0.0;
  }

  static List<OrderItem> _parseItems(dynamic itemsData) {
    if (itemsData == null) return [];
    if (itemsData is! List) return [];

    try {
      return itemsData
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error parsing order items: $e');

      return [];
    }
  }

  static double _parseTotalAmount(Map<String, dynamic> json) {
    // Try different possible field names for total amount
    final candidates = [
      json['totalAmount'],
      json['total'],
      _minorToIqd(json['pricing']?['total']),
      json['amount'],
    ];

    for (final candidate in candidates) {
      if (candidate != null) {
        double amount = 0.0;
        if (candidate is double) {
          amount = candidate;
        } else if (candidate is int) {
          amount = candidate.toDouble();
        } else if (candidate is String) {
          final parsed = double.tryParse(candidate);
          amount = parsed ?? 0.0;
        }

        // No conversion needed - amounts are already in IQD format
        // Direct API fields and the converted pricing fallback are IQD.
        return amount;
      }
    }
    return 0.0;
  }

  static DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        AppLogger.error('Error parsing datetime: $dateTime');

        return null;
      }
    }
    return null;
  }

  static OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready; // backward compatibility
      case 'ready_for_pickup':
      case 'readyforpickup':
        return OrderStatus.readyForPickup; // ✅ الحالة الصحيحة
      case 'reassigning': // 🔄 جاري البحث عن سائق بديل
        return OrderStatus.reassigning;
      // 🚗 حالات السائق - Driver states
      case 'assigned': // تم تعيين سائق
        return OrderStatus.assigned;
      case 'heading_to_store': // السائق في طريقه للمطعم
        return OrderStatus.headingToStore;
      case 'arrived_at_store': // السائق وصل للمطعم
      case 'arrive_at_store':
        return OrderStatus.arrivedAtStore;
      case 'picked_up': // السائق استلم الطلب
      case 'pickup_order':
        return OrderStatus.pickedUp;
      case 'heading_to_customer': // في طريقه للعميل
      case 'start_heading_to_customer':
      case 'ontheway':
      case 'on_the_way':
        return OrderStatus.headingToCustomer;
      case 'arrived_at_customer': // وصل للزبون
      case 'arrive_at_customer':
        return OrderStatus.arrivedAtCustomer;
      case 'delivered':
        return OrderStatus.delivered;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
      case 'canceled_by_user':
      case 'canceled_by_customer': // ✅ من OrderService
      case 'canceled_by_restaurant': // ✅ من OrderService
      case 'canceled_by_merchant':
      case 'canceled_by_store':
      case 'canceled_by_system':
        return OrderStatus.cancelled;
      case 'returning':
        return OrderStatus.returning;
      case 'return_arrived':
        return OrderStatus.returnArrived;
      case 'returned':
        return OrderStatus.returned;
      case 'expired':
        return OrderStatus.expired;
      default:
        return OrderStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    // تحويل readyForPickup إلى ready_for_pickup للـ Backend
    String statusString = status.name;
    if (status == OrderStatus.readyForPickup) {
      statusString = 'ready_for_pickup';
    }

    return {
      'id': id,
      'driverSearchUnavailable': driverSearchUnavailable,
      if(financialAssignment!=null) 'financialAssignment': financialAssignment,
      if(merchantHandover!=null) 'merchantHandover': merchantHandover,
      if(exceptionCancellation!=null) 'exceptionCancellation': exceptionCancellation,
      if(exceptionPolicyVersion!=null) 'exceptionPolicyVersion': exceptionPolicyVersion,
      'merchantAcceptanceDeadlineAt': merchantAcceptanceDeadlineAt?.toIso8601String(),
      'estimatedPreparationTime': estimatedPreparationTime,
      'paymentMethod': paymentMethod,
      'deliveryInstructions': deliveryInstructions,
      'businessId': businessId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': statusString, // ✅ استخدام statusString المحول
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  Order copyWith({
    String? id,
    String? businessId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    DeliveryAddress? deliveryAddress,
    List<OrderItem>? items,
    double? totalAmount,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? orderNumber,
    double? deliveryFee,
    // 🚗 Driver fields
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? vehicleType,
    String? vehiclePlate,
    DateTime? driverAssignedAt,
    DateTime? pickedUpAt,
  }) {
    return Order(
      id: id ?? this.id,
      driverSearchUnavailable: driverSearchUnavailable &&
          (driverId ?? this.driverId) == null &&
          [OrderStatus.ready, OrderStatus.readyForPickup, OrderStatus.reassigning].contains(status ?? this.status),
      financialAssignment: financialAssignment,
      exceptionCancellation: exceptionCancellation,
      merchantHandover: merchantHandover,
      exceptionPolicyVersion: exceptionPolicyVersion,
      merchantAcceptanceDeadlineAt: merchantAcceptanceDeadlineAt,
      estimatedPreparationTime: estimatedPreparationTime,
      businessId: businessId ?? this.businessId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      orderNumber: orderNumber ?? this.orderNumber,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      paymentMethod: paymentMethod,
      deliveryInstructions: deliveryInstructions,
      // 🚗 Preserve driver information
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      driverAssignedAt: driverAssignedAt ?? this.driverAssignedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
    );
  }

  bool shouldAutoReject() {
    // Display helper only. Expiration is decided by the server.
    return !DateTime.now().isBefore(merchantAcceptanceDeadlineAt ?? createdAt.add(const Duration(minutes: 5)));
  }

  @override
  String toString() {
    return 'Order(id: $id, customerName: $customerName, status: $status, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }

  /// 🚗 Log driver information for debugging
  void logDriverInfo() {
    AppLogger.debug('🚗 Order ${displayOrderNumber} - Driver Info:');
    AppLogger.debug('   driverId: $driverId');
    AppLogger.debug('   driverName: $driverName');
    AppLogger.debug('   driverPhone: $driverPhone');
    AppLogger.debug('   vehicleType: $vehicleType');
    AppLogger.debug('   vehiclePlate: $vehiclePlate');
    AppLogger.debug('   driverAssignedAt: $driverAssignedAt');
    AppLogger.debug('   pickedUpAt: $pickedUpAt');
    AppLogger.debug('   status: $status');
  }
}
