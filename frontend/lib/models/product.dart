class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String businessId;
  final bool isAvailable;
  final String? imageUrl;
  final List<String> imageUrls;
  final List<String> images; // Alias for imageUrls for backward compatibility
  final int? stock;
  final Map<String, dynamic>? nutritionalInfo;
  final List<String> allergens;
  final int preparationTime;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.businessId,
    this.isAvailable = true,
    this.imageUrl,
    this.imageUrls = const [],
    List<String>? images,
    this.stock,
    this.nutritionalInfo,
    this.allergens = const [],
    this.preparationTime = 15,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  }) : images = images ?? imageUrls;

  factory Product.fromJson(Map<String, dynamic> json) {
    // Handle imageUrls - create array from single imageUrl if needed
    List<String> imageUrlsList = [];
    
    // First try to get from imageUrls array
    if (json['imageUrls'] != null) {
      imageUrlsList = List<String>.from(json['imageUrls']);
    } else if (json['image_urls'] != null) {
      imageUrlsList = List<String>.from(json['image_urls']);
    } else if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
      // If single imageUrl exists, add it to the list
      imageUrlsList = [json['imageUrl'].toString()];
    } else if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
      // If single image_url exists, add it to the list  
      imageUrlsList = [json['image_url'].toString()];
    }
    
    return Product(
      id: json['id'] ?? json['product_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      categoryId: json['categoryId'] ?? json['category_id'] ?? '',
      businessId: json['businessId'] ?? json['business_id'] ?? '',
      isAvailable: json['isAvailable'] ?? json['is_available'] ?? true,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      imageUrls: imageUrlsList,
      stock: json['stock'],
      nutritionalInfo: json['nutritionalInfo'] ?? json['nutritional_info'],
      allergens: List<String>.from(json['allergens'] ?? []),
      preparationTime:
          json['preparationTime'] ?? json['preparation_time'] ?? 15,
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? json['review_count'] ?? 0,
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
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'businessId': businessId,
      'isAvailable': isAvailable,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'nutritionalInfo': nutritionalInfo,
      'allergens': allergens,
      'preparationTime': preparationTime,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? businessId,
    bool? isAvailable,
    String? imageUrl,
    List<String>? imageUrls,
    Map<String, dynamic>? nutritionalInfo,
    List<String>? allergens,
    int? preparationTime,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      businessId: businessId ?? this.businessId,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      allergens: allergens ?? this.allergens,
      preparationTime: preparationTime ?? this.preparationTime,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: \$${price.toStringAsFixed(2)})';
  }
}

class ProductCategory {
  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final String businessType;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.iconUrl,
    this.businessType = '',
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] ?? json['categoryId'] ?? json['category_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['iconUrl'] ?? json['icon_url'],
      businessType: json['businessType'] ?? json['business_type'] ?? '',
      sortOrder: json['sortOrder'] ?? json['sort_order'] ?? 0,
      isActive: json['isActive'] ?? json['is_active'] ?? true,
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
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ProductCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ProductCategory(id: $id, name: $name)';
  }
}
