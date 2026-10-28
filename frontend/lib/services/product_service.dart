import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:whizz_merchants/config/app_config.dart';
import '../core/utils/app_logger.dart';
import '../core/exceptions/auth_exceptions.dart';
import 'secure_token_storage.dart';
import 'token_refresh_service.dart';
import 'merchant_branch_scope.dart';

class ProductService {
  static String productMutationError(dynamic code) =>
      const <String, String>{
        'INVALID_MENU_UPDATE':
            'تعذر حفظ التغييرات. راجع بيانات المنتج والصورة المرفوعة لهذا الفرع.',
        'CATEGORY_UNAVAILABLE':
            'القسم غير متاح. اختر قسمًا من قائمة هذا المطعم.',
        'INVALID_PRICE': 'أدخل سعرًا صحيحًا موجبًا بالدينار العراقي.',
        'MENU_PUBLISH_REQUIRED':
            'انشر قائمة المطعم الحالية أولًا ثم أعد المحاولة.',
        'VERSION_OR_STATE_CONFLICT':
            'تغير المنتج أثناء التعديل. حدّث القائمة وأعد المحاولة.',
        'PRODUCT_UNAVAILABLE': 'المنتج غير موجود في هذا الفرع. حدّث القائمة.',
        'INVALID_BRANCH_PRODUCT_OPTIONS': 'راجع خيارات المنتج وأسعارها.',
      }[code] ??
      (code is String && code.isNotEmpty
          ? code
          : 'تعذر حفظ التغيير. أعد المحاولة.');

  static String get baseUrl => AppConfig.baseUrl;

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

    if (resp.statusCode == 401) {
      await TokenRefreshService.refreshTokens();
      token = await _getPreferredIdToken();
      token ??= await _getAccessTokenRaw();
      if (token == null) return resp;
      resp = await http.get(uri, headers: _authHeaders(token));
      if (resp.statusCode == 401) {
        final accessOnly = await _getAccessTokenRaw();
        if (accessOnly != null && accessOnly != token) {
          resp = await http.get(uri, headers: _authHeaders(accessOnly));
        }
      }
    }
    return resp;
  }

  static Future<http.Response> _resilientPost(
      Uri uri, Map<String, dynamic> body) async {
    String? token = await _getBestToken();
    if (token == null) {
      throw AuthTokenExpiredException('Authentication token missing');
    }
    Future<http.Response> send(String value) =>
        http.post(uri, headers: _authHeaders(value), body: jsonEncode(body));
    var response = await send(token);
    if (response.statusCode == 401) {
      await TokenRefreshService.refreshTokens();
      token = await _getBestToken();
      if (token != null) response = await send(token);
    }
    return response;
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
  static Future<Map<String, dynamic>> getProducts({String? businessId}) async {
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);

      // Use wizzbussiness endpoint (shared backend) instead of wizzuser
      final uri = scope.uri('$baseUrl/products');
      final response = await _resilientGet(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'products': data['products'] ?? []};
      } else if (response.statusCode == 401) {
        // ⚠️ Following wizzuser: Log only, NO exception thrown
        AppLogger.warning(
            '[ProductService] Auth error ${response.statusCode} - user needs to re-login (wizzuser approach)');
        return {
          'success': false,
          'message': 'Authentication required - please re-login',
          'isAuthError': true,
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'message':
              'تعذر تحميل منتجات هذا الفرع. تحقق من الفرع المختار وصلاحية الوصول إليه.',
          'isAuthError': false,
        };
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'تعذر الاتصال بخدمة المنتجات. أعد المحاولة.',
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
  static Future<List<Map<String, dynamic>>> searchGlobalCatalog(String query,
      {String? businessId}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      final uri = scope.uri('$baseUrl/products/global-search', query: {'q': q});
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
    String? businessId,
    required String name,
    required String description,
    required double price,
    required String categoryId,
    String? imageUrl,
    bool isAvailable = true,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      String? token = await _getBestToken();
      if (token == null) {
        throw AuthTokenExpiredException('Authentication token expired');
      }

      final productData = {
        'requestId': const Uuid().v4(),
        'name': name,
        'description': description,
        'price': price,
        'categoryId': categoryId,
        'isAvailable': isAvailable,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (additionalData != null) ...additionalData,
      };

      Future<http.Response> doPost(String t) => http.post(
            scope.uri('$baseUrl/products'),
            headers: _authHeaders(t),
            body: jsonEncode(scope.body(productData)),
          );

      var response = await doPost(token);
      if (response.statusCode == 401) {
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
      } else if (response.statusCode == 401) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning(
            '[ProductService] Auth error creating product - user needs to re-login (wizzuser approach)');
        return {
          'success': false,
          'message': 'Authentication required - please re-login',
          'isAuthError': true
        };
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
    String? businessId,
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
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      String? token = await _getBestToken();
      if (token == null) {
        throw AuthTokenExpiredException('Authentication token expired');
      }

      final updateData = <String, dynamic>{};
      updateData['requestId'] = const Uuid().v4();
      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (price != null) updateData['price'] = price;
      if (categoryId != null) updateData['categoryId'] = categoryId;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (isAvailable != null) updateData['isAvailable'] = isAvailable;
      if (additionalData != null) updateData.addAll(additionalData);

      Future<http.Response> doPut(String t) => http.put(
            scope.uri('$baseUrl/products/${Uri.encodeComponent(productId)}'),
            headers: _authHeaders(t),
            body: jsonEncode(scope.body(updateData)),
          );

      var response = await doPut(token);
      if (response.statusCode == 401) {
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
      } else if (response.statusCode == 401) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning(
            '[ProductService] Auth error updating product - user needs to re-login (wizzuser approach)');
        return {
          'success': false,
          'message': 'Authentication required - please re-login',
          'isAuthError': true
        };
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode} updating product',
        };
      } else {
        final errorData = _safeDecode(response.body);
        return {
          'success': false,
          'message':
              productMutationError(errorData['code'] ?? errorData['message']),
        };
      }
    } catch (e) {
      // ⚠️ Following wizzuser: Don't rethrow auth exceptions
      AppLogger.error('[ProductService] Error updating product: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  /// Delete a product (resilient auth)
  static Future<Map<String, dynamic>> deleteProduct(String productId,
      {String? businessId}) async {
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      String? token = await _getBestToken();
      if (token == null) {
        throw AuthTokenExpiredException('Authentication token expired');
      }

      Future<http.Response> doDelete(String t) => http.delete(
            scope.uri('$baseUrl/products/${Uri.encodeComponent(productId)}'),
            headers: _authHeaders(t),
          );

      var response = await doDelete(token);
      if (response.statusCode == 401) {
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
      } else if (response.statusCode == 401) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning(
            '[ProductService] Auth error deleting product - user needs to re-login (wizzuser approach)');
        return {
          'success': false,
          'message': 'Authentication required - please re-login',
          'isAuthError': true
        };
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
  static Future<Map<String, dynamic>> searchProducts(String query,
      {String? businessId}) async {
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);

      final token = await _getBestToken();
      if (token == null) {
        throw AuthTokenExpiredException('Authentication token expired');
      }

      final response = await http.get(
        scope.uri('$baseUrl/products/search', query: {'q': query}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'products': data['products'] ?? []};
      } else if (response.statusCode == 401) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning(
            '[ProductService] Auth error searching products - user needs to re-login (wizzuser approach)');
        return {
          'success': false,
          'message': 'Authentication required - please re-login',
          'isAuthError': true
        };
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
  static Future<Map<String, dynamic>> getProduct(String productId,
      {String? businessId}) async {
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      final token = await _getBestToken();
      if (token == null) {
        throw AuthTokenExpiredException('Authentication token expired');
      }

      final response = await http.get(
        scope.uri('$baseUrl/products/${Uri.encodeComponent(productId)}'),
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
      } else if (response.statusCode == 401) {
        // ⚠️ Following wizzuser: Log only, NO exception
        AppLogger.warning(
            '[ProductService] Auth error fetching product - user needs to re-login (wizzuser approach)');
        return {
          'success': false,
          'message': 'Authentication required - please re-login',
          'isAuthError': true
        };
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
      String businessType,
      {String? businessId}) async {
    AppLogger.info(
        'ProductService: Getting categories for business type: $businessType');

    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      final url = scope
          .uri(
              '$baseUrl/categories/business-type/${Uri.encodeComponent(businessType)}')
          .toString();
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

        return {
          'success': false,
          'categories': [],
          'message': 'تعذر تحميل الأقسام. أعد المحاولة.'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'categories': [],
        'message': 'تعذر تحميل الأقسام. تحقق من الاتصال وأعد المحاولة.'
      };
    }
  }

  /// Get all categories
  static Future<Map<String, dynamic>> getAllCategories(
      {String? businessId}) async {
    try {
      final scope = await MerchantBranchScope.capture(businessId: businessId);
      final response = await _resilientGet(scope.uri('$baseUrl/categories'));

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

  static Future<Map<String, dynamic>> mutateCategory({
    required String businessId,
    String? categoryId,
    required String method,
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final token = await _getBestToken();
    if (token == null) {
      throw AuthTokenExpiredException('Authentication token missing');
    }
    final uri = scope.uri(categoryId == null
        ? '$baseUrl/categories'
        : '$baseUrl/categories/${Uri.encodeComponent(categoryId)}');
    final body = scope.body({
      'requestId': const Uuid().v4(),
      if (name != null) 'name': name,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (isActive != null) 'isActive': isActive,
    });
    late http.Response response;
    if (method == 'POST') {
      response = await http.post(uri,
          headers: _authHeaders(token), body: jsonEncode(body));
    } else if (method == 'PUT') {
      response = await http.put(uri,
          headers: _authHeaders(token), body: jsonEncode(body));
    } else {
      response = await http.delete(uri,
          headers: _authHeaders(token), body: jsonEncode(body));
    }
    final data = _safeDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        'success': false,
        'message': data['code'] ?? data['message'] ?? 'تعذر حفظ القسم'
      };
    }
    await scope.assertCurrent();
    return {'success': true, 'category': data['category']};
  }

  static Future<Map<String, dynamic>> previewCsvImport({
    required String businessId,
    required String csv,
    required String mode,
    Map<String, String>? columnMapping,
    String? defaultCategoryId,
    Map<String, String>? images,
  }) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final response = await _resilientPost(
        scope.uri('$baseUrl/products/imports/preview'),
        scope.body({
          'format': 'CSV',
          'mode': mode,
          'csv': csv,
          if (columnMapping != null) 'columnMapping': columnMapping,
          if (defaultCategoryId != null) 'defaultCategoryId': defaultCategoryId,
          if (images != null) 'images': images
        }));
    final data = _safeDecode(response.body);
    if (response.statusCode != 201 || data['job'] is! Map) {
      return {
        'success': false,
        'message': data['code'] ?? data['message'] ?? 'تعذر فحص الملف'
      };
    }
    await scope.assertCurrent();
    return {'success': true, 'job': Map<String, dynamic>.from(data['job'])};
  }

  static Future<Map<String, dynamic>> getImportJob({
    required String businessId,
    required String jobId,
  }) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final response = await _resilientGet(
        scope.uri('$baseUrl/products/imports/${Uri.encodeComponent(jobId)}'));
    final data = _safeDecode(response.body);
    if (response.statusCode != 200 || data['job'] is! Map) {
      return {
        'success': false,
        'message': data['code'] ?? data['message'] ?? 'تعذر استعادة الاستيراد'
      };
    }
    await scope.assertCurrent();
    return {'success': true, 'job': Map<String, dynamic>.from(data['job'])};
  }

  static Future<Map<String, dynamic>> commitImportBatch({
    required String businessId,
    required String jobId,
    required int expectedVersion,
    required int offset,
    required List<String> selectedRowIds,
  }) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final response = await _resilientPost(
        scope.uri(
            '$baseUrl/products/imports/${Uri.encodeComponent(jobId)}/commit'),
        scope.body({
          'expectedVersion': expectedVersion,
          'offset': offset,
          'selectedRowIds': selectedRowIds,
        }));
    final data = _safeDecode(response.body);
    if (response.statusCode != 200 || data['job'] is! Map) {
      return {
        'success': false,
        'message': data['code'] ?? data['message'] ?? 'تعذر تطبيق الدفعة'
      };
    }
    await scope.assertCurrent();
    return {'success': true, 'job': Map<String, dynamic>.from(data['job'])};
  }

  static Future<Map<String, dynamic>> getMenuVersions(String businessId) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final response = await _resilientGet(scope.uri('$baseUrl/menu/versions'));
    final data = _safeDecode(response.body);
    if (response.statusCode != 200)
      return {
        'success': false,
        'message': data['code'] ?? 'تعذر تحميل سجل النشر'
      };
    await scope.assertCurrent();
    return {
      'success': true,
      'active': data['active'],
      'versions': data['versions'] ?? []
    };
  }

  static Future<Map<String, dynamic>> publishMenu(String businessId) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final response = await _resilientPost(
        scope.uri('$baseUrl/menu/versions/publish'),
        scope.body({'requestId': const Uuid().v4()}));
    final data = _safeDecode(response.body);
    if (response.statusCode != 200)
      return {'success': false, 'message': data['code'] ?? 'تعذر نشر القائمة'};
    await scope.assertCurrent();
    return {'success': true, 'active': data['active']};
  }

  static Future<Map<String, dynamic>> rollbackMenu(
      String businessId, String version) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final response = await _resilientPost(
        scope.uri('$baseUrl/menu/versions/rollback'),
        scope.body({'requestId': const Uuid().v4(), 'version': version}));
    final data = _safeDecode(response.body);
    if (response.statusCode != 200)
      return {
        'success': false,
        'message': data['code'] ?? 'تعذر استرجاع النسخة'
      };
    await scope.assertCurrent();
    return {'success': true, 'active': data['active']};
  }

  static Future<Map<String, dynamic>> inventoryRequest(String businessId,
      {Map<String, dynamic>? body}) async {
    final scope = await MerchantBranchScope.capture(businessId: businessId);
    final uri = scope.uri('$baseUrl/products/inventory');
    final response = body == null
        ? await _resilientGet(uri)
        : await _resilientPost(uri, scope.body(body));
    final data = _safeDecode(response.body);
    await scope.assertCurrent();
    return {
      ...data,
      'success': response.statusCode == 200 && data['success'] == true
    };
  }
}
