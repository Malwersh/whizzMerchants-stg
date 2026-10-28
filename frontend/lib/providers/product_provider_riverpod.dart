import 'session_provider.dart';
import '../services/product_update_patch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_logger.dart';
import '../core/exceptions/auth_exceptions.dart';
import '../models/product.dart';
import '../services/product_service.dart';

// State class for product management
class ProductState {
  final List<Product> products;
  final List<ProductCategory> categories;
  final bool isLoading;
  final ProductError? error;
  final Product? selectedProduct;

  const ProductState({
    this.products = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.selectedProduct,
  });

  ProductState copyWith({
    List<Product>? products,
    List<ProductCategory>? categories,
    bool? isLoading,
    ProductError? error,
    Product? selectedProduct,
  }) {
    return ProductState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedProduct: selectedProduct ?? this.selectedProduct,
    );
  }
}

class ProductError {
  final String message;
  final bool isAuth;
  final bool isNetwork;
  final bool isServer;
  const ProductError(
      {required this.message,
      this.isAuth = false,
      this.isNetwork = false,
      this.isServer = false});
}

// Product StateNotifier
class ProductNotifier extends StateNotifier<ProductState> {
  final Ref ref;

  final String? businessId;
  ProductNotifier(this.ref, {this.businessId}) : super(const ProductState());

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ProductService.getProducts(businessId: businessId);
      if (result['success'] == true && result['products'] != null) {
        final productsList = result['products'] as List;
        final products =
            productsList.map((json) => Product.fromJson(json)).toList();

        if (!mounted) return;
        state = state.copyWith(
          products: products,
          isLoading: false,
          error: null,
        );
      } else {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: ProductError(
              message: result['message'] ?? 'Failed to load products',
              isServer: true),
        );
      }
    } on AuthTokenExpiredException catch (e) {
      AppLogger.error('[ProductProvider] Auth token expired: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession on token expiry - just log
      AppLogger.warning(
          '[ProductProvider] Token expired - user will need to re-login (wizzuser approach)');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Token expired - please re-login', isAuth: true),
      );
    } on UnauthorizedException catch (e) {
      AppLogger.error('[ProductProvider] Unauthorized: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession on 401 - just log
      AppLogger.warning(
          '[ProductProvider] Unauthorized - user will need to re-login (wizzuser approach)');
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Unauthorized - please re-login', isAuth: true),
      );
    } catch (e) {
      AppLogger.error('[ProductProvider] Error loading products: $e');
      // Don't clear session on network/server errors
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(message: e.toString(), isNetwork: true),
      );
    }
  }

  Future<void> loadCategories(String businessType) async {
    // Don't reload if categories are already loaded for this business type
    if (state.categories.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ProductService.getCategoriesForBusinessType(
          businessType,
          businessId: businessId);
      if (result['success'] == true && result['categories'] != null) {
        final categoriesList = result['categories'] as List;
        List<ProductCategory> categories = categoriesList
            .map((json) => ProductCategory.fromJson(json))
            .toList();

        // Remove duplicates based on category ID
        final Map<String, ProductCategory> uniqueCategories = {};
        for (final category in categories) {
          uniqueCategories[category.id] = category;
        }
        categories = uniqueCategories.values.toList();

        AppLogger.debug(
            'ProductProvider: Loaded ${categories.length} unique categories');

        if (!mounted) return;
        state = state.copyWith(
          categories: categories,
          isLoading: false,
          error: null,
        );
      } else {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: ProductError(
              message: result['message'] ?? 'Failed to load categories',
              isServer: true),
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(message: e.toString(), isNetwork: true),
      );
    }
  }

  Future<void> forceLoadCategories(String businessType) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ProductService.getCategoriesForBusinessType(
          businessType,
          businessId: businessId);
      if (result['success'] == true && result['categories'] != null) {
        final categoriesList = result['categories'] as List;
        List<ProductCategory> categories = categoriesList
            .map((json) => ProductCategory.fromJson(json))
            .toList();

        // Remove duplicates based on category ID
        final Map<String, ProductCategory> uniqueCategories = {};
        for (final category in categories) {
          uniqueCategories[category.id] = category;
        }
        categories = uniqueCategories.values.toList();

        AppLogger.debug(
            'ProductProvider: Force loaded ${categories.length} unique categories');

        if (!mounted) return;
        state = state.copyWith(
          categories: categories,
          isLoading: false,
          error: null,
        );
      } else {
        if (!mounted) return;
        state = state.copyWith(
          isLoading: false,
          error: ProductError(
              message: result['message'] ?? 'Failed to load categories',
              isServer: true),
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(message: e.toString(), isNetwork: true),
      );
    }
  }

  Future<bool> addProduct(Product product, {String? globalProductId}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ProductService.createProduct(
        businessId: businessId,
        name: product.name,
        description: product.description,
        price: product.price,
        categoryId: product.categoryId,
        imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
        isAvailable: product.isAvailable,
        additionalData: {
          'optionGroups': product.optionGroups,
          if (globalProductId != null) 'globalProductId': globalProductId
        },
      );

      if (result['success'] == true && result['product'] != null) {
        final newProduct = Product.fromJson(result['product']);
        final updatedProducts = [...state.products, newProduct];

        if (!mounted) return false;
        state = state.copyWith(
          products: updatedProducts,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        if (!mounted) return false;
        state = state.copyWith(
          isLoading: false,
          error: ProductError(
              message: result['message'] ?? 'Failed to create product',
              isServer: true),
        );
        return false;
      }
    } on AuthTokenExpiredException catch (e) {
      AppLogger.error(
          '[ProductProvider] Auth token expired during addProduct: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession - just log
      AppLogger.warning(
          '[ProductProvider] Token expired - user will need to re-login (wizzuser approach)');
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Token expired - please re-login', isAuth: true),
      );
      return false;
    } on UnauthorizedException catch (e) {
      AppLogger.error(
          '[ProductProvider] Unauthorized during addProduct: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession - just log
      AppLogger.warning(
          '[ProductProvider] Unauthorized - user will need to re-login (wizzuser approach)');
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Unauthorized - please re-login', isAuth: true),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(message: e.toString(), isNetwork: true),
      );
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    final previous =
        state.products.where((p) => p.id == product.id).firstOrNull;
    if (previous == null) return false;
    final patch = productUpdatePatch(previous, product);
    if (patch.isEmpty) return true;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ProductService.updateProduct(
        businessId: businessId,
        productId: product.id,
        additionalData: patch,
      );

      if (result['success'] == true && result['product'] != null) {
        final updatedProduct = Product.fromJson(result['product']);
        final updatedProducts = state.products.map((p) {
          return p.id == product.id ? updatedProduct : p;
        }).toList();

        if (!mounted) return false;
        state = state.copyWith(
          products: updatedProducts,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        if (!mounted) return false;
        state = state.copyWith(
          isLoading: false,
          error: ProductError(
              message: result['message'] ?? 'Failed to update product',
              isServer: true),
        );
        return false;
      }
    } on AuthTokenExpiredException catch (e) {
      AppLogger.error(
          '[ProductProvider] Auth token expired during updateProduct: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession - just log
      AppLogger.warning(
          '[ProductProvider] Token expired - user will need to re-login (wizzuser approach)');
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Token expired - please re-login', isAuth: true),
      );
      return false;
    } on UnauthorizedException catch (e) {
      AppLogger.error(
          '[ProductProvider] Unauthorized during updateProduct: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession - just log
      AppLogger.warning(
          '[ProductProvider] Unauthorized - user will need to re-login (wizzuser approach)');
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Unauthorized - please re-login', isAuth: true),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(message: e.toString(), isNetwork: true),
      );
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result =
          await ProductService.deleteProduct(productId, businessId: businessId);

      if (result['success'] == true) {
        final updatedProducts =
            state.products.where((p) => p.id != productId).toList();

        if (!mounted) return false;
        state = state.copyWith(
          products: updatedProducts,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        if (!mounted) return false;
        state = state.copyWith(
          isLoading: false,
          error: ProductError(
              message: result['message'] ?? 'Failed to delete product',
              isServer: true),
        );
        return false;
      }
    } on AuthTokenExpiredException catch (e) {
      AppLogger.error(
          '[ProductProvider] Auth token expired during deleteProduct: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession - just log
      AppLogger.warning(
          '[ProductProvider] Token expired - user will need to re-login (wizzuser approach)');
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Token expired - please re-login', isAuth: true),
      );
      return false;
    } on UnauthorizedException catch (e) {
      AppLogger.error(
          '[ProductProvider] Unauthorized during deleteProduct: ${e.message}');
      // ⚠️ Following wizzuser: NO clearSession - just log
      AppLogger.warning(
          '[ProductProvider] Unauthorized - user will need to re-login (wizzuser approach)');
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(
            message: 'Unauthorized - please re-login', isAuth: true),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        error: ProductError(message: e.toString(), isNetwork: true),
      );
      return false;
    }
  }

  void selectProduct(Product? product) {
    state = state.copyWith(selectedProduct: product);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  List<Product> getProductsByCategory(String categoryId) {
    return state.products
        .where((product) => product.categoryId == categoryId)
        .toList();
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return state.products;

    return state.products.where((product) {
      return product.name.toLowerCase().contains(query.toLowerCase()) ||
          product.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
}

// Provider for product management
final productProviderRiverpod =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final businessId =
      ref.watch(sessionProvider.select((session) => session.businessId));
  return ProductNotifier(ref, businessId: businessId ?? '');
});

// Convenience providers for specific data
final productsProvider = Provider<List<Product>>((ref) {
  return ref.watch(productProviderRiverpod).products;
});

final productCategoriesProvider = Provider<List<ProductCategory>>((ref) {
  return ref.watch(productProviderRiverpod).categories;
});

final productLoadingProvider = Provider<bool>((ref) {
  return ref.watch(productProviderRiverpod).isLoading;
});

final productErrorProvider = Provider<ProductError?>((ref) {
  return ref.watch(productProviderRiverpod).error;
});

final selectedProductProvider = Provider<Product?>((ref) {
  return ref.watch(productProviderRiverpod).selectedProduct;
});
