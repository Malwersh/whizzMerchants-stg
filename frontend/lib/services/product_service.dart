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

  /// Search the shared global catalog (products other merchants already added).
  /// Picking a result reuses its name/image so the merchant only sets a price.
  static Future<List<Map<String, dynamic>>> searchGlobalCatalog(
      String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      final uri = Uri.parse('$baseUrl/products/global-search')
          .replace(queryParameters: {'q': q});
      final response = await _resilientGet(uri);
      if (response.statusCode != 200) return [];
      final data = _safeDecode(response.body);
      return List<Map<String, dynamic>>.from(data['products'] ?? []);
    } catch (e) {
      AppLogger.error('[ProductService] Global catalog search failed: $e');
      return [];
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
      final businessId = await _getBusinessId();
      final url = Uri.parse('$baseUrl/categories/business-type/$businessType')
          .replace(queryParameters: {if (businessId != null) 'businessId': businessId}).toString();
      final response = await _resilientGet(Uri.parse(url));

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

        
        return {'success': false, 'categories': [],
          'message': 'تعذر تحميل الأقسام. أعد المحاولة.'};
      }
    } catch (e) {
      return {'success': false, 'categories': [],
        'message': 'تعذر تحميل الأقسام. تحقق من الاتصال وأعد المحاولة.'};
    }
  }


  /// Get all categories
  static Future<Map<String, dynamic>> getAllCategories() async {
    try {
      final businessId = await _getBusinessId();
      final response = await _resilientGet(Uri.parse('$baseUrl/categories').replace(
        queryParameters: {if (businessId != null) 'businessId': businessId}));

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
