import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/models/product.dart';
import 'package:whizz_merchants/models/business.dart';
import 'package:whizz_merchants/providers/product_provider_riverpod.dart';
import 'package:whizz_merchants/screens/products_management_screen.dart';
import 'package:whizz_merchants/core/design_system/material_theme.dart';

class ProductActionsFake extends ProductNotifier {
  ProductActionsFake(super.ref) {
    state = ProductState(products: [
      Product.fromJson({
        'productId': 'p',
        'name': 'وجبة اختبار',
        'price': 3000,
        'categoryId': 'c',
        'isAvailable': true
      })
    ], categories: [
      ProductCategory.fromJson({'categoryId': 'c', 'categoryName': 'وجبات'})
    ]);
  }
  @override
  Future<void> loadProducts() async {}
  @override
  Future<void> loadCategories(String type) async {}
  @override
  Future<bool> updateProduct(Product p) async {
    state = state.copyWith(isLoading: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = state.copyWith(
        isLoading: false, error: const ProductError(message: 'تعذر الحفظ'));
    return false;
  }

  @override
  Future<bool> deleteProduct(String id) async {
    state = state.copyWith(isLoading: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = state.copyWith(products: [], isLoading: false);
    return true;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        overrides: [
          productProviderRiverpod.overrideWith((ref) => ProductActionsFake(ref))
        ],
        child: MaterialApp(
            theme: MaterialTheme.lightTheme,
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProductsManagementScreen(
                business: Business(
                    id: 'b',
                    name: 'مطعم',
                    email: '',
                    businessType: BusinessType.restaurant)))));
    await t.pumpAndSettle();
    ScaffoldMessenger.of(t.element(find.byType(ProductsManagementScreen)))
        .clearSnackBars();
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.more_vert_rounded));
    await t.pumpAndSettle();
  }

  testWidgets('failed availability edit keeps product list mounted', (t) async {
    await open(t);
    await t.tap(find.text('جعل غير متاح'));
    await t.pump();
    expect(find.text('وجبة اختبار'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(find.text('وجبة اختبار'), findsOneWidget);
    expect(find.text('تعذر الحفظ'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('delete closes confirmation before async result', (t) async {
    await open(t);
    await t.tap(find.text('حذف'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'حذف'));
    await t.pumpAndSettle();
    expect(find.text('وجبة اختبار'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('edit sheet opens and closes safely', (t) async {
    await open(t);
    await t.tap(find.text('تعديل'));
    await t.pumpAndSettle();
    expect(find.byType(Form), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(find.text('وجبة اختبار'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
