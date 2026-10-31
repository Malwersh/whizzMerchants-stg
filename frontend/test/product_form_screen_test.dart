import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/models/product.dart';
import 'package:whizz_merchants/providers/product_provider_riverpod.dart';
import 'package:whizz_merchants/screens/add_product_screen.dart';
import 'package:whizz_merchants/screens/edit_product_screen.dart';
import 'package:whizz_merchants/screens/product_form_screen.dart';

Product fixture() => Product.fromJson({
      'productId': 'p',
      'businessId': 'b',
      'name': 'برغر',
      'description': 'وصف محفوظ',
      'price': 3000,
      'categoryId': 'c',
      'imageUrl': 'https://example.invalid/old.jpg',
      'isAvailable': false,
      'stock': 7,
      'barcode': '12345',
      'optionGroups': [
        {
          'id': 'g',
          'title': 'إضافات',
          'required': false,
          'maxSelections': 1,
          'options': [
            {'id': 'o', 'name': 'جبن', 'extraPrice': 500, 'isAvailable': true}
          ]
        }
      ]
    });

class FormFake extends ProductNotifier {
  final List<Product> writes = [];
  FormFake(super.ref) : super(businessId: 'b') {
    state = ProductState(products: [
      fixture()
    ], categories: [
      ProductCategory.fromJson({'categoryId': 'c', 'categoryName': 'وجبات'})
    ]);
  }
  @override
  Future<void> loadCategories(String type) async {}
  @override
  Future<bool> updateProduct(Product p) async {
    writes.add(p);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    state =
        state.copyWith(error: const ProductError(message: 'تعذر الحفظ مؤقتًا'));
    return false;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'business_id': 'b'}));
  Future<FormFake> mount(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    late FormFake fake;
    await t.pumpWidget(ProviderScope(overrides: [
      productProviderRiverpod.overrideWith((ref) => fake = FormFake(ref))
    ], child: MaterialApp(home: child)));
    await t.pumpAndSettle();
    return fake;
  }

  testWidgets('add and edit entry points use identical shared form', (t) async {
    await mount(t, const AddProductScreen(businessId: 'b'));
    expect(find.byType(ProductFormScreen), findsOneWidget);
    expect(find.text('إضافة منتج'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump();
    await mount(t, EditProductScreen(product: fixture()));
    expect(find.byType(ProductFormScreen), findsOneWidget);
    expect(find.text('تعديل المنتج'), findsOneWidget);
    expect(find.text('برغر'), findsOneWidget);
    expect(find.text('وصف محفوظ'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
  });
  testWidgets(
      'failed save preserves image stock options and inputs; double tap submits once',
      (t) async {
    final original = fixture();
    final fake =
        await mount(t, ProductFormScreen(product: original, businessId: 'b'));
    await t.enterText(
        find.byWidgetPredicate(
            (w) => w is TextFormField && w.controller?.text == '3000'),
        '4500');
    final save = find.byKey(const ValueKey('product-save'));
    await t.tap(save);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('product-save')));
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(fake.writes, hasLength(1));
    final p = fake.writes.single;
    expect(p.price, 4500);
    expect(p.imageUrls, original.imageUrls);
    expect(p.optionGroups, original.optionGroups);
    expect(p.barcode, '12345');
    expect(p.stock, 7);
    expect(p.isAvailable, false);
    await t.scrollUntilVisible(find.text('تعذر الحفظ مؤقتًا'), 400,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('تعذر الحفظ مؤقتًا'), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'zero price blocks update before network; stored product remains unchanged',
      (t) async {
    final original = fixture();
    final fake =
        await mount(t, ProductFormScreen(product: original, businessId: 'b'));
    await t.enterText(
        find.byWidgetPredicate(
            (w) => w is TextFormField && w.controller?.text == '3000'),
        '0');
    await t.tap(find.byKey(const ValueKey('product-save')));
    await t.pumpAndSettle();
    expect(fake.writes, isEmpty);
    expect(original.price, 3000);
    expect(t.takeException(), isNull);
  });
}
