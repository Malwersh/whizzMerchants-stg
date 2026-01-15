class DeliveryAddress {
  final String id;
  final String street;
  final String city;
  final String district;
  final String? state;
  final String country;
  final String? building;
  final String? floor;
  final String? apartment;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final String? label; // Home, Work, etc.
  final String customerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryAddress({
    required this.id,
    required this.street,
    required this.city,
    required this.district,
    this.state,
    required this.country,
    this.building,
    this.floor,
    this.apartment,
    this.landmark,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.label,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] ?? json['address_id'] ?? '',
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      district: json['district'] ?? json['neighborhood'] ?? '',
      state: json['state'],
      country: json['country'] ?? 'Iraq',
      building: json['building'],
      floor: json['floor'],
      apartment: json['apartment'],
      landmark: json['landmark'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      isDefault: json['isDefault'] ?? json['is_default'] ?? false,
      label: json['label'],
      customerId: json['customerId'] ?? json['customer_id'] ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] ?? json['updated_at'] ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'street': street,
      'city': city,
      'district': district,
      'country': country,
      'building': building,
      'floor': floor,
      'apartment': apartment,
      'landmark': landmark,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'label': label,
      'customerId': customerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get fullAddress {
    final parts = <String>[];

    if (building != null && building!.isNotEmpty) {
      parts.add('Building $building');
    }
    if (floor != null && floor!.isNotEmpty) {
      parts.add('Floor $floor');
    }
    if (apartment != null && apartment!.isNotEmpty) {
      parts.add('Apt $apartment');
    }

    parts.add(street);
    parts.add(district);
    parts.add(city);
    parts.add(country);

    return parts.where((part) => part.isNotEmpty).join(', ');
  }

  String get shortAddress {
    return '$street, $district, $city';
  }

  DeliveryAddress copyWith({
    String? id,
    String? street,
    String? city,
    String? district,
    String? country,
    String? building,
    String? floor,
    String? apartment,
    String? landmark,
    double? latitude,
    double? longitude,
    bool? isDefault,
    String? label,
    String? customerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      street: street ?? this.street,
      city: city ?? this.city,
      district: district ?? this.district,
      country: country ?? this.country,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      apartment: apartment ?? this.apartment,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      label: label ?? this.label,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryAddress && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DeliveryAddress(id: $id, address: $shortAddress)';
  }
}
