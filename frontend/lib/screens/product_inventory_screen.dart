import '../widgets/product_operations_theme.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/product_service.dart';

class ProductInventoryScreen extends StatefulWidget {
  final String businessId;
  const ProductInventoryScreen({super.key, required this.businessId});
  @override
  State<ProductInventoryScreen> createState() => _ProductInventoryScreenState();
}

class _ProductInventoryScreenState extends State<ProductInventoryScreen> {
  List<Map<String, dynamic>> products = [], reviews = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        busy = true;
        error = null;
      });
    try {
      final p = await ProductService.getProducts(businessId: widget.businessId);
      final r = await ProductService.inventoryRequest(widget.businessId);
      if (p['success'] != true || r['success'] != true)
        throw StateError(
            (r['code'] ?? r['message'] ?? p['message'] ?? 'تعذر التحميل')
                .toString());
      if (mounted)
        setState(() {
          products = List<Map<String, dynamic>>.from(p['products']);
          reviews = List<Map<String, dynamic>>.from(r['reviews'] ?? const []);
        });
    } catch (_) {
      if (mounted)
        setState(() => error =
            'تعذر تحميل المخزون. تحقق من الاتصال والصلاحية ثم أعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(Map<String, dynamic> body) async {
    setState(() => busy = true);
    try {
      final r =
          await ProductService.inventoryRequest(widget.businessId, body: body);
      if (r['success'] != true)
        throw StateError('${r['code'] ?? r['message']}');
      await load();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().contains('STOCK_CHANGED')
            ? 'تغيّرت الكمية أثناء العمل. حدّث الصفحة وأعد المحاولة.'
            : 'تعذر حفظ المخزون. حدّث الصفحة وأعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Map<String, dynamic> p) async {
    final text = TextEditingController(text: p['stock']?.toString() ?? '');
    var unlimited = p['stock'] == null;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text((p['name'] ?? 'المنتج').toString(),
                          style: Theme.of(ctx).textTheme.titleLarge),
                      SwitchListTile(
                          title: const Text('بدون تتبّع الكمية'),
                          subtitle:
                              const Text('المنتجات المعتادة دون كمية محدودة'),
                          value: unlimited,
                          onChanged: (v) => setLocal(() => unlimited = v)),
                      if (!unlimited)
                        TextField(
                            controller: text,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'الكمية المتاحة الآن',
                                border: OutlineInputBorder())),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                              'يتغير المتاح مباشرة. تُخصم الكمية عند إنشاء الطلب، ولا يُسمح ببيع كمية غير متوفرة.')),
                      FilledButton(
                          onPressed: () {
                            final stock = int.tryParse(text.text);
                            if (!unlimited &&
                                (stock == null ||
                                    stock < 0 ||
                                    stock > 1000000)) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'أدخل عددًا صحيحًا من 0 إلى 1000000')));
                              return;
                            }
                            Navigator.pop(ctx, {
                              'productId': p['productId'] ?? p['id'],
                              'stock': unlimited ? null : stock,
                              'expectedStock': p['stock'],
                              'requestId': const Uuid().v4()
                            });
                          },
                          child: const Text('حفظ الكمية'))
                    ]))));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    text.dispose();
    if (result != null && mounted) await save(result);
  }

  Future<void> review(Map<String, dynamic> r, String action) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(action == 'RESTOCK'
                    ? 'إعادة الكمية إلى المتاح؟'
                    : 'اعتماد استهلاك الكمية؟'),
                content: Text(action == 'RESTOCK'
                    ? 'أكد أن المنتجات عادت صالحة للبيع. لا تُعِد الطعام التالف إلى المخزون.'
                    : 'تظل الكمية مخصومة لأنها استُهلكت أو تلفت.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('تراجع')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأكيد'))
                ]));
    if (ok == true && mounted)
      await save({'action': action, 'orderId': r['orderId']});
  }

  @override
  Widget build(BuildContext context) => ProductOperationsTheme(
      child: Scaffold(
          appBar: AppBar(title: const Text('كميات المخزون'), actions: [
            IconButton(
                onPressed: busy ? null : load, icon: const Icon(Icons.refresh))
          ]),
          body: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text(
                    'الكميات اختيارية. نفاد الكمية يوقف البيع تلقائيًا. تغييرات الكمية مباشرة، بينما تغيير السعر والمحتوى يحتاج نشر القائمة.'),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                if (reviews.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('كميات طلبات ملغاة تحتاج مراجعة',
                      style: Theme.of(context).textTheme.titleMedium),
                  ...reviews.map((r) => Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('طلب ${r['orderId']}'),
                                const Text(
                                    'تحقق من صلاحية المنتجات قبل إعادة الكمية للبيع.'),
                                Wrap(spacing: 8, children: [
                                  OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => review(r, 'RESTOCK'),
                                      child: const Text('إعادة الكمية للمتاح')),
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => review(r, 'CONSUMED'),
                                      child: const Text('استهلكت / تلفت'))
                                ])
                              ]))))
                ],
                const SizedBox(height: 16),
                ...products.map((p) => Card(
                    child: ListTile(
                        title: Text((p['name'] ?? 'منتج').toString()),
                        subtitle: Text(p['stock'] == null
                            ? 'دون تتبع الكمية'
                            : 'المتاح: ${p['stock']}'),
                        trailing: IconButton(
                            onPressed: busy ? null : () => edit(p),
                            icon: const Icon(Icons.edit_outlined)))))
              ]))));
}
