import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../providers/product_provider_riverpod.dart';
import '../services/image_upload_service.dart';
import '../services/product_service.dart';
import '../widgets/branch_options_editor.dart';
import '../widgets/product_operations_theme.dart';
import 'product_inventory_screen.dart';

/// One editor for both entry points. Existing images/options remain untouched
/// unless explicitly replaced; publishing is a separate merchant action.
class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? businessId;
  const ProductFormScreen({super.key, this.product, this.businessId});
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, description, price, barcode;
  late List<Map<String, dynamic>> options;
  late bool available;
  String? category, imageUrl, branch;
  Uint8List? imageBytes;
  bool busy = false, picking = false;
  String? error;
  Timer? debounce;
  int searchVersion = 0;
  List<Map<String, dynamic>> suggestions = [];
  String? globalId;
  String? lastCreatePayload, createRequestId;
  bool get editing => widget.product != null;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    description = TextEditingController(text: p?.description ?? '');
    price = TextEditingController(
        text: p == null
            ? ''
            : (p.price == p.price.roundToDouble()
                ? p.price.toStringAsFixed(0)
                : p.price.toString()));
    barcode = TextEditingController(text: p?.barcode ?? '');
    category = p?.categoryId;
    available = p?.isAvailable ?? true;
    imageUrl = p == null
        ? null
        : (p.imageUrls.isNotEmpty ? p.imageUrls.first : p.imageUrl);
    options = (jsonDecode(jsonEncode(p?.optionGroups ?? [])) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      branch = widget.businessId ??
          p?.businessId ??
          ref.read(productProviderRiverpod.notifier).businessId;
      if (ref.read(productProviderRiverpod).categories.isEmpty) {
        ref.read(productProviderRiverpod.notifier).loadCategories('restaurant');
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    name.dispose();
    description.dispose();
    price.dispose();
    barcode.dispose();
    super.dispose();
  }

  void search(String query) {
    if (editing) return;
    globalId = null;
    debounce?.cancel();
    final version = ++searchVersion;
    debounce = Timer(const Duration(milliseconds: 400), () async {
      final values =
          await ProductService.searchGlobalCatalog(query, businessId: branch);
      if (mounted && version == searchVersion && !busy)
        setState(() => suggestions = values);
    });
  }

  Future<void> pickImage() async {
    if (busy || picking) return;
    setState(() => picking = true);
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85);
      if (picked == null) return;
      final source = await picked.readAsBytes();
      if (source.isEmpty || source.length > 5 * 1024 * 1024) {
        throw StateError('اختر صورة أصغر من 5 MB.');
      }
      final decoder = img.findDecoderForData(source);
      final info = decoder?.startDecode(source);
      if (info == null || info.width * info.height > 20000000) {
        throw StateError('أبعاد الصورة غير مناسبة.');
      }
      final decoded = decoder?.decodeFrame(0);
      if (decoded == null) throw StateError('تعذر قراءة الصورة.');
      final bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
      if (bytes.length > 3 * 1024 * 1024) throw StateError('اختر صورة أصغر.');
      if (mounted)
        setState(() {
          imageBytes = bytes;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error =
            'تعذر اختيار الصورة. تحقق من صلاحية الوصول للصور وأعد المحاولة.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (busy || picking || !form.currentState!.validate()) return;
    if (!editing && imageBytes == null && imageUrl == null) {
      setState(() => error = 'أضف صورة واضحة للمنتج قبل الحفظ.');
      return;
    }
    final notifier = ref.read(productProviderRiverpod.notifier);
    if (branch != null &&
        notifier.businessId != null &&
        notifier.businessId!.isNotEmpty &&
        branch != notifier.businessId) {
      setState(() =>
          error = 'تغير الفرع أثناء التعديل. أعد فتح المنتج من الفرع الصحيح.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      suggestions = [];
    });
    try {
      if (imageBytes != null) {
        final result = await ImageUploadService.uploadProductImageFromBytes(
            imageBytes: imageBytes!,
            fileName: 'product.jpg',
            businessId: branch);
        if (result['success'] != true)
          throw StateError('تعذر رفع الصورة. احتُفظ بتعديلاتك؛ أعد المحاولة.');
        imageUrl = result['imageUrl'] as String;
        imageBytes = null;
      }
      if (!mounted) return;
      final p = widget.product;
      final updated = p == null
          ? Product(
              id: '',
              businessId: branch ?? '',
              name: name.text.trim(),
              description: description.text.trim(),
              price: double.parse(price.text),
              categoryId: category!,
              imageUrls: [if (imageUrl != null) imageUrl!],
              barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
              optionGroups: options,
              isAvailable: available,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now())
          : p.copyWith(
              name: name.text.trim(),
              description: description.text.trim(),
              price: double.parse(price.text),
              categoryId: category,
              barcode: barcode.text.trim().isEmpty ? null : barcode.text.trim(),
              imageUrls: imageUrl == null ? p.imageUrls : [imageUrl!],
              optionGroups: options,
              isAvailable: available);
      if (!editing) {
        final payload = jsonEncode([
          updated.name,
          updated.description,
          updated.price,
          updated.categoryId,
          updated.imageUrls,
          updated.barcode,
          updated.optionGroups,
          updated.isAvailable,
          globalId
        ]);
        if (payload != lastCreatePayload) {
          lastCreatePayload = payload;
          createRequestId = const Uuid().v4();
        }
      }
      final success = editing
          ? await notifier.updateProduct(updated)
          : await notifier.addProduct(updated,
              globalProductId: globalId, requestId: createRequestId);
      if (!mounted) return;
      if (!success) {
        setState(() => error =
            ref.read(productProviderRiverpod).error?.message ??
                'تعذر الحفظ. أعد المحاولة.');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'حُفظت التغييرات. انشر القائمة لإظهار المحتوى المحدث؛ التوفر يُطبق فور الحفظ.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget section(String title, IconData icon, List<Widget> children) =>
      Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE4E9F1))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, color: ProductOperationsTheme.navy, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: ProductOperationsTheme.navy)))
            ]),
            const SizedBox(height: 18),
            ...children
          ]));
  InputDecoration field(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProviderRiverpod);
    final categories =
        {for (final c in state.categories) c.id: c}.values.toList();
    return ProductOperationsTheme(
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: PopScope(
              canPop: !busy,
              child: Scaffold(
                backgroundColor: const Color(0xFFF4F6FA),
                appBar: AppBar(
                    title: Text(editing ? 'تعديل المنتج' : 'إضافة منتج'),
                    backgroundColor: Colors.white,
                    foregroundColor: ProductOperationsTheme.navy,
                    centerTitle: true),
                body: Form(
                    key: form,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                              'بيانات المنتج تخص هذا الفرع. انشر القائمة لإظهار تغييرات الاسم والسعر والصورة والخيارات للزبائن. التوفر يؤثر في الطلبات الجديدة فور الحفظ.',
                              style: TextStyle(
                                  color: Color(0xFF52627A), height: 1.5))),
                      section('صورة المنتج', Icons.photo_outlined, [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                                height: 170,
                                child: imageBytes != null
                                    ? Image.memory(imageBytes!,
                                        fit: BoxFit.cover)
                                    : imageUrl != null
                                        ? Image.network(imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Center(
                                                    child: Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        size: 44)))
                                        : const ColoredBox(
                                            color: Color(0xFFF0F3F9),
                                            child: Center(
                                                child: Icon(
                                                    Icons
                                                        .add_photo_alternate_outlined,
                                                    size: 44,
                                                    color:
                                                        ProductOperationsTheme
                                                            .navy))))),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            onPressed: busy || picking ? null : pickImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(picking
                                ? 'جارٍ فتح الصور…'
                                : imageUrl == null && imageBytes == null
                                    ? 'اختيار صورة'
                                    : 'تغيير الصورة')),
                        if (editing)
                          const Text(
                              'تُحفظ الصورة الحالية ما لم تختر صورة بديلة.',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF52627A))),
                      ]),
                      section('بيانات المنتج', Icons.restaurant_menu, [
                        TextFormField(
                            controller: name,
                            enabled: !busy,
                            maxLength: 150,
                            decoration: field('اسم المنتج *'),
                            onChanged: search,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'أدخل اسم المنتج'
                                : null),
                        if (suggestions.isNotEmpty && !editing) ...[
                          const Text('اقتراحات من الكتالوج'),
                          for (final item in suggestions.take(5))
                            ListTile(
                                title: Text((item['canonicalName'] ??
                                        item['name'] ??
                                        '')
                                    .toString()),
                                subtitle: const Text(
                                    'استخدام الاسم والوصف؛ اختر صورة المنتج لهذا الفرع'),
                                onTap: busy
                                    ? null
                                    : () => setState(() {
                                          searchVersion++;
                                          globalId = item['globalProductId']
                                              ?.toString();
                                          name.text = (item['canonicalName'] ??
                                                  item['name'] ??
                                                  '')
                                              .toString();
                                          description.text =
                                              (item['description'] ?? '')
                                                  .toString();
                                          suggestions = [];
                                        })),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: description,
                            enabled: !busy,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: field('الوصف (اختياري)')),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: price,
                            enabled: !busy,
                            keyboardType: TextInputType.number,
                            decoration: field('السعر بالدينار العراقي *'),
                            validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '');
                              return n == null || n <= 0 || n > 1000000000
                                  ? 'أدخل سعرًا صحيحًا موجبًا بالدينار'
                                  : null;
                            }),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                            initialValue:
                                categories.any((c) => c.id == category)
                                    ? category
                                    : null,
                            isExpanded: true,
                            decoration: field('القسم *'),
                            items: categories
                                .map((c) => DropdownMenuItem(
                                    value: c.id, child: Text(c.name)))
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) => setState(() => category = v),
                            validator: (v) => v == null
                                ? 'اختر قسمًا متاحًا لهذا الفرع'
                                : null),
                        if (categories.isEmpty)
                          TextButton.icon(
                              onPressed: busy || state.isLoading
                                  ? null
                                  : () => ref
                                      .read(productProviderRiverpod.notifier)
                                      .loadCategories('restaurant'),
                              icon: const Icon(Icons.refresh),
                              label: Text(state.isLoading
                                  ? 'جارٍ تحميل الأقسام…'
                                  : 'إعادة تحميل الأقسام')),
                        const SizedBox(height: 18),
                        TextFormField(
                            controller: barcode,
                            enabled: !busy,
                            decoration: field('الباركود (اختياري)'),
                            validator: (v) => editing &&
                                    (widget.product!.barcode?.isNotEmpty ??
                                        false) &&
                                    (v?.isEmpty ?? true)
                                ? 'أدخل باركودًا بدل الباركود الحالي'
                                : v != null &&
                                        v.isNotEmpty &&
                                        !RegExp(r'^[0-9A-Za-z._-]{1,100}$')
                                            .hasMatch(v)
                                    ? 'استخدم أرقامًا أو أحرفًا دون مسافات'
                                    : null),
                      ]),
                      section('التوفر والمخزون', Icons.inventory_2_outlined, [
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('متاح للبيع'),
                            subtitle: const Text(
                                'يُطبق فور الحفظ على الطلبات الجديدة، دون حذف المنتج.'),
                            value: available,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => available = v)),
                        if (editing) ...[
                          const Divider(),
                          Text(widget.product!.stock == null
                              ? 'المخزون: لا يجري تتبع الكمية'
                              : 'الكمية المسجلة: ${widget.product!.stock}'),
                          TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () {
                                      if (branch != null)
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    ProductInventoryScreen(
                                                        businessId: branch!)));
                                    },
                              icon: const Icon(Icons.inventory_outlined),
                              label: const Text('إدارة كميات المخزون'))
                        ],
                      ]),
                      section('الخيارات والإضافات', Icons.tune, [
                        BranchOptionsEditor(
                            value: options,
                            enabled: !busy,
                            onChanged: (v) => setState(() => options = v))
                      ]),
                      if (error != null)
                        Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(error!,
                                style:
                                    const TextStyle(color: Color(0xFFAF2525)))),
                      const SizedBox(height: 12),
                    ])),
                bottomNavigationBar: SafeArea(
                    top: false,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: FilledButton.icon(
                            key: const ValueKey('product-save'),
                            onPressed: busy || picking ? null : save,
                            icon: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.check),
                            label: Text(busy
                                ? 'جارٍ الحفظ…'
                                : editing
                                    ? 'حفظ التغييرات'
                                    : 'إضافة المنتج')))),
              ),
            )));
  }
}
