import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/config/app_config.dart';
import '../core/utils/app_logger.dart';
import 'app_auth_service.dart';
import '../core/exceptions/auth_exceptions.dart';
import 'secure_token_storage.dart';
import 'token_refresh_service.dart';

class ProductService {
  static String get baseUrl => AppConfig.baseUrl;

  /// Get businessId from SharedPreferences
  /// Checks both 'business_id' (used by SessionProvider) and 'session_business_id' (used by AdvancedSessionService)
  static Future<String?> _getBusinessId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try 'business_id' first (used by wizzbussiness SessionProvider)
      String? businessId = prefs.getString('business_id');
      // Fallback to 'session_business_id' (used by AdvancedSessionService)
      businessId ??= prefs.getString('session_business_id');
      
      if (businessId == null || businessId.isEmpty) {
        AppLogger.warning('[ProductService] No businessId found in SharedPreferences');
      } else {
        AppLogger.info('[ProductService] Found businessId: $businessId');
      }
      
      return businessId;
    } catch (e) {
      AppLogger.error('[ProductService] Error getting businessId: $e');
      return null;
    }
  }

  static Future<String?> _getPreferredIdToken() async {
    final id = await SecureTokenStorage.getIdToken();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  static Future<String?> _getAccessTokenRaw() async {
    final at = await SecureTokenStorage.getAccessToken();
    if (at != null && at.isNotEmpty) return at;
    return null;
  }

  static Future<String?> _getBestToken() async {
    final id = await _getPreferredIdToken();
    if (id != null) return id;
    return await _getAccessTokenRaw();
  }

  static Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<http.Response> _resilientGet(Uri uri) async {
    String? token = await _getBestToken();
    if (token == null) {
      throw AuthTokenExpiredException('Authentication token missing');
    }
    http.Response resp = await http.get(uri, headers: _authHeaders(token));

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      await TokenRefreshService.refreshTokens();
      token = await _getPreferredIdToken();
      token ??= await _getAccessTokenRaw();
      if (token == null) return resp;
      resp = await http.get(uri, headers: _authHeaders(token));
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        final accessOnly = await _getAccessTokenRaw();
        if (accessOnly != null && accessOnly != token) {
          resp = await http.get(uri, headers: _authHeaders(accessOnly));
        }
      }
    }
    return resp;
  }

  static Map<String, dynamic> _safeDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Get all products for the authenticated business (resilient auth)
  /// ✅ FIXED: Using /products endpoint (wizzbussiness shared backend)
  ///     wizzuser endpoint requires wizzuser token (403 error)
  static Future<Map<String, dynamic>> getProducts() async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) {
        AppLogger.error('[ProductService] No businessId found in session');
        return {'success': false, 'message': 'No business ID found - please login again'};
      }
      
      // Use wizzbussiness endpoint (shared backend) instead of wizzuser
      final uri = Uri.parse('$baseUrl/products');
      final response = await _resilientGet(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'products': data['products'] ?? []};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // ⚠️ Following wizzuser: Log only, NO exception thrown
        AppLogger.warning('[ProductService] Auth error ${response.statusCode} - user needs to re-login (wizzuser approach)');
        return {
          'success': false,
          'message': 'Authentication required - please re-login',
          'isAuthError': true,
        };
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode} fetching products',
        };
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch products',
        };
      }
    } catch (e) {
      // ⚠️ Following wizzuser: Don't rethrow auth exceptions
      AppLogger.error('[ProductService] Error fetching products: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Create a new product (resilient auth)
  static Future<Map<String, dynamic>> createProduct({
    required String name,
    required String description,
    required double price,
    required String categoryId,
    String? imageUrl,
    bool isAvailable = true,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      String? token = await _getBestToken();
      if (token == null) throw AuthTokenExpiredException('Authentication token expired');

      final productData = {
        'name': name,
        'description': description,
        'price': price,
        'categoryId': categoryId,
        'isAvailable': isAvailable,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (additionalData != null) ...additionalData,
      };

      final businessId = await _getBusinessId();
      if (businessId == null) {
        return {'success': false, 'message': 'No business ID found - please login again'};
      }

      Future<http.Response> doPost(String t) => http.post(
            Uri.parse('$baseUrl/products'),
            headers: _authHeaders(t),
            body: jsonEncode(productData),
          );

      var response = await doPost(token);
      if (response.statusCode == 401 || response.statusCode == 403) {
        await TokenRefreshService.refreshTokens();
        token = await _getPreferredIdToken();
        token ??= await _getAccessTokenRaw();
        if (token != null) response = await doPost(token);
      }
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'product': data['product'],
          'message': 'Product created successfully',
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning('[ProductService] Auth error creating product - user needs to re-login (wizzuser approach)');
        return {'success': false, 'message': 'Authentication required - please re-login', 'isAuthError': true};
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode} creating product',
        };
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to create product',
        };
      }
    } catch (e) {
      // ⚠️ Following wizzuser: Don't rethrow auth exceptions
      AppLogger.error('[ProductService] Error creating product: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Update an existing product (resilient auth)
  static Future<Map<String, dynamic>> updateProduct({
    required String productId,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? imageUrl,
    bool? isAvailable,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      String? token = await _getBestToken();
      if (token == null) throw AuthTokenExpiredException('Authentication token expired');

      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (price != null) updateData['price'] = price;
      if (categoryId != null) updateData['categoryId'] = categoryId;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (isAvailable != null) updateData['isAvailable'] = isAvailable;
      if (additionalData != null) updateData.addAll(additionalData);

      final businessId = await _getBusinessId();
      if (businessId == null) {
        return {'success': false, 'message': 'No business ID found - please login again'};
      }

      Future<http.Response> doPut(String t) => http.put(
            Uri.parse('$baseUrl/products/$productId'),
            headers: _authHeaders(t),
            body: jsonEncode(updateData),
          );

      var response = await doPut(token);
      if (response.statusCode == 401 || response.statusCode == 403) {
        await TokenRefreshService.refreshTokens();
        token = await _getPreferredIdToken();
        token ??= await _getAccessTokenRaw();
        if (token != null) response = await doPut(token);
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'product': data['product'],
          'message': 'Product updated successfully',
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning('[ProductService] Auth error updating product - user needs to re-login (wizzuser approach)');
        return {'success': false, 'message': 'Authentication required - please re-login', 'isAuthError': true};
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode} updating product',
        };
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to update product',
        };
      }
    } catch (e) {
      // ⚠️ Following wizzuser: Don't rethrow auth exceptions
      AppLogger.error('[ProductService] Error updating product: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Delete a product (resilient auth)
  static Future<Map<String, dynamic>> deleteProduct(String productId) async {
    try {
      String? token = await _getBestToken();
      if (token == null) throw AuthTokenExpiredException('Authentication token expired');

      final businessId = await _getBusinessId();
      if (businessId == null) {
        return {'success': false, 'message': 'No business ID found - please login again'};
      }

      Future<http.Response> doDelete(String t) => http.delete(
            Uri.parse('$baseUrl/products/$productId'),
            headers: _authHeaders(t),
          );

      var response = await doDelete(token);
      if (response.statusCode == 401 || response.statusCode == 403) {
        await TokenRefreshService.refreshTokens();
        token = await _getPreferredIdToken();
        token ??= await _getAccessTokenRaw();
        if (token != null) response = await doDelete(token);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Product deleted successfully',
          'product': data['product'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning('[ProductService] Auth error deleting product - user needs to re-login (wizzuser approach)');
        return {'success': false, 'message': 'Authentication required - please re-login', 'isAuthError': true};
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode} deleting product',
        };
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to delete product',
        };
      }
    } catch (e) {
      // ⚠️ Following wizzuser: Don't rethrow auth exceptions
      AppLogger.error('[ProductService] Error deleting product: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Search for products by name
  static Future<Map<String, dynamic>> searchProducts(String query) async {
    try {
      final businessId = await _getBusinessId();
      if (businessId == null) {
        return {'success': false, 'message': 'No business ID found - please login again'};
      }
      
      final token = await AppAuthService.getAccessToken();
      if (token == null) {
        throw AuthTokenExpiredException('Authentication token expired');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/products/search?q=${Uri.encodeComponent(query)}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'products': data['products'] ?? []};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning('[ProductService] Auth error searching products - user needs to re-login (wizzuser approach)');
        return {'success': false, 'message': 'Authentication required - please re-login', 'isAuthError': true};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to search products'
        };
      }
    } catch (e) {
      // ⚠️ Following wizzuser: Don't rethrow auth exceptions
      AppLogger.error('[ProductService] Error searching products: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Get a specific product by ID
  static Future<Map<String, dynamic>> getProduct(String productId) async {
    try {
      final token = await AppAuthService.getAccessToken();
      if (token == null) {
        throw AuthTokenExpiredException('Authentication token expired');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'product': data['product'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning('[ProductService] Auth error fetching product - user needs to re-login (wizzuser approach)');
        return {'success': false, 'message': 'Authentication required - please re-login', 'isAuthError': true};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch product',
        };
      }
    } catch (e) {
      // ⚠️ Following wizzuser: Don't rethrow auth exceptions
      AppLogger.error('[ProductService] Error fetching product: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get categories for a specific business type
  static Future<Map<String, dynamic>> getCategoriesForBusinessType(
      String businessType) async {
    AppLogger.info(
        'ProductService: Getting categories for business type: $businessType');

    try {
      final url = '$baseUrl/categories/business-type/$businessType';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final apiCategories = data['categories'] ?? [];

        AppLogger.success(
            'ProductService: API returned ${apiCategories.length} categories');
        AppLogger.info('ProductService: Categories data: $apiCategories');


        return {
          'success': true,
          'categories': apiCategories,
        };
      } else {
        final errorData = jsonDecode(response.body);
        AppLogger.error('ProductService: API error: ${errorData['message']}');

        
        // Fallback to predefined categories when API fails
        AppLogger.info(
            'ProductService: Using fallback categories for business type: $businessType');
        final fallbackCategories = _getFallbackCategories(businessType);
        
        return {
          'success': true,
          'categories': fallbackCategories,
          'source': 'fallback',
          'message': 'API temporarily unavailable, using default categories',
        };
      }
    } catch (e) {
      AppLogger.error('ProductService: Network error: $e');

      
      // Fallback to predefined categories on network error
      AppLogger.info(
          'ProductService: Network error, using fallback categories for business type: $businessType');
      final fallbackCategories = _getFallbackCategories(businessType);
      
      return {
        'success': true,
        'categories': fallbackCategories,
        'source': 'fallback',
        'message': 'Network error, using default categories',
      };
    }
  }

  /// Get fallback categories when API is unavailable
  static List<Map<String, dynamic>> _getFallbackCategories(
      String businessType) {
    final fallbackCategories = <Map<String, dynamic>>[];

    switch (businessType.toLowerCase()) {
      case 'restaurant':
      case 'kitchen':
        fallbackCategories.addAll([
          {
            'categoryId': 'fb-appetizers-001',
            'name': 'Appetizers',
            'name_ar': 'المقبلات',
            'description': 'Starters and appetizers',
            'businessType': 'restaurant',
            'is_active': true,
          },
          {
            'categoryId': 'fb-main-courses-002',
            'name': 'Main Courses',
            'name_ar': 'الأطباق الرئيسية',
            'description': 'Main dishes and entrees',
            'businessType': 'restaurant',
            'is_active': true,
          },
          {
            'categoryId': 'fb-desserts-003',
            'name': 'Desserts',
            'name_ar': 'الحلويات',
            'description': 'Sweet desserts and treats',
            'businessType': 'restaurant',
            'is_active': true,
          },
          {
            'categoryId': 'fb-beverages-004',
            'name': 'Beverages',
            'name_ar': 'المشروبات',
            'description': 'Drinks and beverages',
            'businessType': 'restaurant',
            'is_active': true,
          },
          {
            'categoryId': 'fb-sides-005',
            'name': 'Sides',
            'name_ar': 'الأطباق الجانبية',
            'description': 'Side dishes',
            'businessType': 'restaurant',
            'is_active': true,
          },
        ]);
        break;

      case 'cloudkitchen':
        fallbackCategories.addAll([
          {
            'categoryId': 'fb-ck-appetizers-001',
            'name': 'Appetizers',
            'name_ar': 'المقبلات',
            'description': 'Starters and appetizers',
            'businessType': 'cloudkitchen',
            'is_active': true,
          },
          {
            'categoryId': 'fb-ck-main-002',
            'name': 'Main Courses',
            'name_ar': 'الأطباق الرئيسية',
            'description': 'Main dishes and entrees',
            'businessType': 'cloudkitchen',
            'is_active': true,
          },
          {
            'categoryId': 'fb-ck-desserts-003',
            'name': 'Desserts',
            'name_ar': 'الحلويات',
            'description': 'Sweet desserts and treats',
            'businessType': 'cloudkitchen',
            'is_active': true,
          },
          {
            'categoryId': 'fb-ck-beverages-004',
            'name': 'Beverages',
            'name_ar': 'المشروبات',
            'description': 'Drinks and beverages',
            'businessType': 'cloudkitchen',
            'is_active': true,
          },
        ]);
        break;

      case 'store':
        fallbackCategories.addAll([
          {
            'categoryId': 'fb-store-grocery-001',
            'name': 'Groceries',
            'name_ar': 'البقالة',
            'description': 'Daily groceries and essentials',
            'businessType': 'store',
            'is_active': true,
          },
          {
            'categoryId': 'fb-store-snacks-002',
            'name': 'Snacks',
            'name_ar': 'الوجبات الخفيفة',
            'description': 'Snacks and light meals',
            'businessType': 'store',
            'is_active': true,
          },
          {
            'categoryId': 'fb-store-beverages-003',
            'name': 'Beverages',
            'name_ar': 'المشروبات',
            'description': 'Drinks and beverages',
            'businessType': 'store',
            'is_active': true,
          },
          {
            'categoryId': 'fb-store-household-004',
            'name': 'Household Items',
            'name_ar': 'أدوات منزلية',
            'description': 'Household supplies and items',
            'businessType': 'store',
            'is_active': true,
          },
        ]);
        break;

      case 'pharmacy':
        fallbackCategories.addAll([
          {
            'categoryId': 'fb-pharm-prescription-001',
            'name': 'Prescription Medications',
            'name_ar': 'الأدوية الموصوفة',
            'description': 'Prescription drugs and medications',
            'businessType': 'pharmacy',
            'is_active': true,
          },
          {
            'categoryId': 'fb-pharm-otc-002',
            'name': 'Over-the-Counter',
            'name_ar': 'أدوية بدون وصفة',
            'description': 'Non-prescription medications',
            'businessType': 'pharmacy',
            'is_active': true,
          },
          {
            'categoryId': 'fb-pharm-vitamins-003',
            'name': 'Vitamins & Supplements',
            'name_ar': 'الفيتامينات والمكملات',
            'description': 'Health supplements and vitamins',
            'businessType': 'pharmacy',
            'is_active': true,
          },
          {
            'categoryId': 'fb-pharm-personal-004',
            'name': 'Personal Care',
            'name_ar': 'العناية الشخصية',
            'description': 'Personal care and hygiene products',
            'businessType': 'pharmacy',
            'is_active': true,
          },
        ]);
        break;

      case 'cafe':
      case 'caffe':
        fallbackCategories.addAll([
          {
            'categoryId': 'fb-cafe-coffee-001',
            'name': 'Coffee',
            'name_ar': 'القهوة',
            'description': 'Hot and cold coffee beverages',
            'businessType': 'cafe',
            'is_active': true,
          },
          {
            'categoryId': 'fb-cafe-tea-002',
            'name': 'Tea',
            'name_ar': 'الشاي',
            'description': 'Various types of tea',
            'businessType': 'cafe',
            'is_active': true,
          },
          {
            'categoryId': 'fb-cafe-pastries-003',
            'name': 'Pastries',
            'name_ar': 'المعجنات',
            'description': 'Fresh pastries and baked goods',
            'businessType': 'cafe',
            'is_active': true,
          },
          {
            'categoryId': 'fb-cafe-sandwiches-004',
            'name': 'Sandwiches',
            'name_ar': 'الساندويشات',
            'description': 'Light meals and sandwiches',
            'businessType': 'cafe',
            'is_active': true,
          },
        ]);
        break;

      case 'bakery':
        fallbackCategories.addAll([
          {
            'categoryId': 'fb-bakery-bread-001',
            'name': 'Bread',
            'name_ar': 'الخبز',
            'description': 'Fresh bread and rolls',
            'businessType': 'bakery',
            'is_active': true,
          },
          {
            'categoryId': 'fb-bakery-cakes-002',
            'name': 'Cakes',
            'name_ar': 'الكيك',
            'description': 'Cakes and celebration desserts',
            'businessType': 'bakery',
            'is_active': true,
          },
          {
            'categoryId': 'fb-bakery-pastries-003',
            'name': 'Pastries',
            'name_ar': 'المعجنات',
            'description': 'Sweet and savory pastries',
            'businessType': 'bakery',
            'is_active': true,
          },
          {
            'categoryId': 'fb-bakery-cookies-004',
            'name': 'Cookies',
            'name_ar': 'البسكويت',
            'description': 'Cookies and biscuits',
            'businessType': 'bakery',
            'is_active': true,
          },
        ]);
        break;

      default:
        // Default categories for unsupported business types
        fallbackCategories.addAll([
          {
            'categoryId': 'fb-general-001',
            'name': 'General Items',
            'name_ar': 'أصناف عامة',
            'description': 'General product category',
            'businessType': businessType,
            'is_active': true,
          },
          {
            'categoryId': 'fb-popular-002',
            'name': 'Popular Items',
            'name_ar': 'أصناف شائعة',
            'description': 'Popular and featured items',
            'businessType': businessType,
            'is_active': true,
          },
        ]);
    }

    AppLogger.info(
        'ProductService: Generated ${fallbackCategories.length} fallback categories');
    return fallbackCategories;
  }

  /// Get all categories
  static Future<Map<String, dynamic>> getAllCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'categories': data['categories'] ?? [],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to fetch categories',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
