import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/product_service.dart';

// State class for products
class ProductState {
  final List<Product> products;
  final List<ProductCategory> categories;
  final bool isLoading;
  final String? error;
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
    String? error,
    Product? selectedProduct,
  }) {
    return ProductState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedProduct: selectedProduct ?? this.selectedProduct,
    );
  }
}

// StateNotifier for managing product state
class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier() : super(const ProductState());

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ProductService.getProducts();
      if (result['success'] == true && result['products'] != null) {
        final productsList = result['products'] as List;
        final products =
            productsList.map((json) => Product.fromJson(json)).toList();
        state = state.copyWith(
          products: products,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Failed to load products',
          products: [],
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        products: [],
      );
    }
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result =
          await ProductService.getCategoriesForBusinessType('restaurant');
      if (result['success'] == true && result['categories'] != null) {
        final categoriesList = result['categories'] as List;
        final categories = categoriesList
            .map((json) => ProductCategory.fromJson(json))
            .toList();
        state = state.copyWith(
          categories: categories,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Failed to load categories',
          categories: [],
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        categories: [],
      );
    }
  }

  Future<bool> addProduct(Product product) async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await ProductService.createProduct(
        name: product.name,
        description: product.description,
        price: product.price,
        categoryId: product.categoryId,
        imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
        isAvailable: product.isAvailable,
      );

      if (result['success'] == true && result['product'] != null) {
        final newProduct = Product.fromJson(result['product']);
        final updatedProducts = [...state.products, newProduct];
        state = state.copyWith(
          products: updatedProducts,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Failed to create product',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await ProductService.updateProduct(
        productId: product.id,
        name: product.name,
        description: product.description,
        price: product.price,
        categoryId: product.categoryId,
        imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
        isAvailable: product.isAvailable,
      );

      if (result['success'] == true && result['product'] != null) {
        final updatedProduct = Product.fromJson(result['product']);
        final updatedProducts = state.products
            .map((p) => p.id == product.id ? updatedProduct : p)
            .toList();

        state = state.copyWith(
          products: updatedProducts,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Failed to update product',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await ProductService.deleteProduct(productId);

      if (result['success'] == true) {
        final updatedProducts =
            state.products.where((p) => p.id != productId).toList();
        state = state.copyWith(
          products: updatedProducts,
          isLoading: false,
          error: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result['message'] ?? 'Failed to delete product',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
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

// Riverpod provider
final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier();
});
