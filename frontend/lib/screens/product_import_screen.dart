import '../widgets/product_operations_theme.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/product_service.dart';
import '../services/product_import_columns.dart';
import '../services/product_import_template.dart';
import '../services/image_upload_service.dart';
import 'package:image/image.dart' as img;
import '../services/xlsx_csv_decoder.dart';
import '../services/product_import_report.dart';

class ProductImportScreen extends StatefulWidget {
  final String businessId;
  final VoidCallback? onCompleted;
  const ProductImportScreen(
      {super.key, required this.businessId, this.onCompleted});

  @override
  State<ProductImportScreen> createState() => _ProductImportScreenState();
}

class _ProductImportScreenState extends State<ProductImportScreen> {
  static const template =
      'name,price,categoryId,description,imageFile,stock\nبرغر كلاسيك,6000,,وصف اختياري,,';
  String? pickedFileName;
  final csv = TextEditingController();
  String mode = 'ADD_ONLY';
  List<String> sourceHeaders = [];
  Map<String, String> mapping = {};
  final imageUrls = <String, String>{};
  String? defaultCategoryId;
  List<Map<String, dynamic>> categories = [];
  String? progress;
  Map<String, dynamic>? job;
  final selected = <String>{};
  bool busy = false;
  String? error;
  String get _resumeKey => 'product_import_${widget.businessId}';

  @override
  void initState() {
    super.initState();
    _restore();
    ProductService.getAllCategories(businessId: widget.businessId)
        .then((result) {
      if (mounted)
        setState(() => categories =
            List<Map<String, dynamic>>.from(result['categories'] ?? const []));
    });
  }

  Future<void> _remember() async {
    if (job == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _resumeKey,
        jsonEncode({
          'jobId': job!['jobId'],
          'selected': selected.toList()..sort(),
        }));
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_resumeKey);
    if (raw == null) return;
    try {
      final saved = Map<String, dynamic>.from(jsonDecode(raw));
      final result = await ProductService.getImportJob(
          businessId: widget.businessId, jobId: saved['jobId'] as String);
      if (result['success'] != true) {
        final message = result['message']?.toString() ?? '';
        if (message == 'IMPORT_EXPIRED' || message == 'IMPORT_NOT_FOUND') {
          await prefs.remove(_resumeKey);
        }
        if (mounted)
          setState(() => error =
              'تعذر استعادة الاستيراد الآن. تحقق من الاتصال وأعد المحاولة.');
        return;
      }
      final value = Map<String, dynamic>.from(result['job']);
      final remembered = value['selectedRowIds'] ?? saved['selected'];
      selected
        ..clear()
        ..addAll(List<String>.from(remembered ?? const []));
      if (mounted) setState(() => job = value);
    } catch (_) {
      if (mounted)
        setState(() => error =
            'تعذر استعادة الاستيراد الآن. لم تُحذف جلسة الاستيراد المحفوظة.');
    }
  }

  Future<void> pickFile() async {
    setState(() {
      error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('الملف فارغ أو أكبر من 5 MB');
      }
      final extension = (file.extension ?? '').toLowerCase();
      String value;
      if (extension == 'csv') {
        value = utf8.decode(bytes);
      } else if (extension == 'xlsx') {
        value = xlsxToCsv(bytes);
      } else {
        throw const FormatException('استخدم CSV أو XLSX فقط');
      }
      if (utf8.encode(value).length > 256 * 1024) {
        throw const FormatException('الملف بعد التحويل أكبر من 256 KB');
      }
      csv.text = value;
      pickedFileName = file.name;
      sourceHeaders = productImportHeaders(value);
      mapping = suggestProductImportMapping(sourceHeaders);
      if (mounted) {
        setState(() {
          job = null;
          selected.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => error = e.toString().replaceFirst('FormatException: ', ''));
      }
    }
  }

  @override
  void dispose() {
    csv.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get rows =>
      List<Map<String, dynamic>>.from(job?['rows'] ?? const []);

  Future<void> preview() async {
    if (csv.text.trim().isEmpty) return;
    setState(() {
      sourceHeaders = productImportHeaders(csv.text);
      if (mapping.isEmpty) mapping = suggestProductImportMapping(sourceHeaders);
      busy = true;
      error = null;
      job = null;
      selected.clear();
    });
    try {
      final result = await ProductService.previewCsvImport(
          businessId: widget.businessId,
          csv: csv.text,
          mode: mode,
          columnMapping: mapping.isEmpty ? null : mapping,
          defaultCategoryId: defaultCategoryId,
          images: imageUrls);
      if (result['success'] != true) {
        throw StateError(result['message'] as String? ?? 'تعذر فحص الملف');
      }
      final value = Map<String, dynamic>.from(result['job']);
      for (final row
          in List<Map<String, dynamic>>.from(value['rows'] ?? const [])) {
        if ((row['errors'] as List?)?.isEmpty ?? false) {
          selected.add(row['rowId'] as String);
        }
      }
      if (mounted) setState(() => job = value);
      await _remember();
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = _jobError(e.toString().replaceFirst('Bad state: ', '')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> commit() async {
    if (job == null || selected.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      var current = job!;
      while (current['status'] != 'COMPLETED') {
        final result = await ProductService.commitImportBatch(
          businessId: widget.businessId,
          jobId: current['jobId'] as String,
          expectedVersion: current['version'] as int,
          offset: current['nextOffset'] as int? ?? 0,
          selectedRowIds: selected.toList()..sort(),
        );
        if (result['success'] != true) {
          throw StateError(result['message'] as String? ?? 'تعذر تطبيق الدفعة');
        }
        current = Map<String, dynamic>.from(result['job']);
        if (mounted) setState(() => job = current);
        await _remember();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_resumeKey);
      widget.onCompleted?.call();
    } catch (e) {
      if (mounted) {
        setState(() =>
            error = _jobError(e.toString().replaceFirst('Bad state: ', '')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickImages() async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
        withData: true);
    if (result == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (result.files.length > 100 ||
          result.files.fold<int>(0, (n, f) => n + f.size) > 40 * 1024 * 1024)
        throw const FormatException(
            'اختر حتى 100 صورة وبمجموع 40 MB في الدفعة.');
      final names = <String>{};
      for (var i = 0; i < result.files.length; i++) {
        if (!mounted) break;
        final file = result.files[i];
        if (!names.add(file.name))
          throw FormatException('اسم صورة مكرر: ${file.name}');
        final bytes = file.bytes;
        if (bytes == null || bytes.length > 5 * 1024 * 1024)
          throw FormatException(
              'الصورة غير صالحة أو أكبر من 5 MB: ${file.name}');
        final decoder = img.findDecoderForData(bytes);
        final info = decoder?.startDecode(bytes);
        if (info == null || info.width * info.height > 20000000)
          throw FormatException('أبعاد الصورة غير صالحة: ${file.name}');
        final decoded = decoder?.decodeFrame(0);
        if (decoded == null)
          throw FormatException('تعذر قراءة الصورة: ${file.name}');
        final resized = decoded.width > 1600 || decoded.height > 1600
            ? img.copyResize(decoded,
                width: decoded.width >= decoded.height ? 1600 : null,
                height: decoded.height > decoded.width ? 1600 : null)
            : decoded;
        final prepared =
            Uint8List.fromList(img.encodeJpg(resized, quality: 85));
        if (mounted)
          setState(
              () => progress = 'رفع الصور ${i + 1} / ${result.files.length}');
        final upload = await ImageUploadService.uploadProductImageFromBytes(
            imageBytes: prepared,
            fileName: 'product.jpg',
            businessId: widget.businessId);
        if (upload['success'] != true)
          throw StateError(
              'تعذر رفع ${file.name}. أعد اختيار الصور لإكمال الرفع.');
        imageUrls[file.name] = upload['imageUrl'] as String;
      }
      if (mounted)
        setState(() {
          job = null;
          selected.clear();
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          progress = null;
        });
    }
  }

  String _jobError(String code) =>
      const <String, String>{
        'IMPORT_PREVIEW_TOO_LARGE':
            'تفاصيل الملف أكبر من الحد المتاح للدفعة. قسّم المنتجات إلى ملفين ثم أعد الفحص.',
        'IMPORT_TOO_LARGE':
            'الحد الأقصى 500 صف في الملف. قسّم الملف إلى دفعات.',
        'INVALID_COLUMN_MAPPING':
            'راجع مطابقة الأعمدة: يجب ألا يستخدم أكثر من حقل العمود نفسه.',
        'INVALID_IMPORT_HEADERS':
            'اربط اسم المنتج والسعر، ثم اختر عمود القسم أو القسم الافتراضي.',
        'DUPLICATE_SOURCE_HEADERS':
            'أسماء أعمدة الملف مكررة. غيّر الأسماء المكررة ثم أعد رفع الملف.',
        'IMPORT_PRODUCT_CHANGED':
            'تغيّر أحد المنتجات أو مخزونه بعد المعاينة. أعد فحص الملف قبل اعتماده.',
        'IMPORT_VERSION_CONFLICT':
            'تغيّرت حالة الاستيراد. أعد فتح الشاشة لاستعادة آخر دفعة محفوظة.',
        'IMPORT_EXPIRED': 'انتهت صلاحية الاستيراد. اختر الملف وأعد فحصه.',
        'MENU_PUBLISH_REQUIRED':
            'انشر القائمة الحالية مرة واحدة من شاشة المنتجات قبل الاستيراد.',
      }[code] ??
      code;
  String _rowError(String code) =>
      const <String, String>{
        'INVALID_STOCK': 'أدخل كمية صحيحة بين صفر ومليون',
        'IMAGE_FILE_MISSING': 'صورة الصف لم تُرفق؛ اختر الصور ثم أعد المعاينة',
        'IMAGE_SCOPE_INVALID': 'الصورة لا تخص هذا الفرع؛ ارفعها من هذه الشاشة',
        'INVALID_IMAGE_FILENAME': 'اسم الصورة غير صالح',
        'CATEGORY_UNAVAILABLE': 'القسم غير موجود أو موقوف لهذا الفرع',
        'INVALID_CATEGORY': 'حدد قسمًا صالحًا أو اختر القسم الافتراضي',
        'INVALID_PRICE': 'السعر يجب أن يكون عددًا صحيحًا موجبًا بالدينار',
        'INVALID_NAME': 'اسم المنتج مطلوب ولا يتجاوز 150 حرفًا',
        'PRODUCT_ALREADY_EXISTS': 'المنتج موجود؛ استخدم وضع تحديث المحدد',
        'PRODUCT_NOT_FOUND': 'معرف المنتج غير موجود في هذا الفرع',
        'DUPLICATE_PRODUCT_ID': 'معرف المنتج مكرر في الملف',
        'DUPLICATE_ROW_ID': 'معرف الصف مكرر',
        'INVALID_BRANCH_PRODUCT_OPTIONS': 'بيانات الخيارات غير صالحة'
      }[code] ??
      'تعذر اعتماد هذا الصف ($code)';
  Widget mappingFields() => ExpansionTile(
          initiallyExpanded: true,
          title: const Text('مطابقة أعمدة الملف'),
          subtitle: const Text(
              'اختر عمود الاسم والسعر، والقسم أو قسمًا افتراضيًا. يمكنك تجاهل الأعمدة الأخرى.'),
          children: [
            ...productImportFields.entries.map((field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<String>(
                    key: ValueKey('${field.key}:${mapping[field.key]}'),
                    initialValue: mapping[field.key],
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: field.value,
                        border: const OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('تجاهل / غير موجود')),
                      ...sourceHeaders.toSet().map(
                          (h) => DropdownMenuItem(value: h, child: Text(h)))
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                              if (v == null) {
                                mapping.remove(field.key);
                              } else {
                                mapping.removeWhere((k, value) => value == v);
                                mapping[field.key] = v;
                              }
                              job = null;
                            })))),
            DropdownButtonFormField<String>(
                initialValue: defaultCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'قسم افتراضي للصفوف بدون قسم',
                    border: OutlineInputBorder()),
                items: categories
                    .map((c) => DropdownMenuItem(
                        value: (c['categoryId'] ?? c['id']).toString(),
                        child: Text((c['categoryName'] ??
                                c['name_ar'] ??
                                c['name'] ??
                                '')
                            .toString())))
                    .toList(),
                onChanged:
                    busy ? null : (v) => setState(() => defaultCategoryId = v)),
          ]);

  String get templateCategory =>
      defaultCategoryId ??
      (categories.isEmpty
          ? ''
          : (categories.first['categoryId'] ?? categories.first['id'] ?? '')
              .toString());
  String get templateCsv => productTemplateCsv(templateCategory);
  Future<void> downloadTemplate({bool excel = false}) async {
    try {
      await FilePicker.saveFile(
          dialogTitle: 'تنزيل قالب المنتجات',
          fileName: excel ? 'products-template.xlsx' : 'products-template.csv',
          type: FileType.custom,
          allowedExtensions: [excel ? 'xlsx' : 'csv'],
          bytes: excel
              ? productTemplateXlsx(templateCategory)
              : Uint8List.fromList(utf8.encode('\ufeff$templateCsv')));
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'تعذر حفظ القالب. أعد المحاولة واختر مجلدًا لحفظه.');
    }
  }

  Widget importGuide() => const ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        title: Text('كيف أرفع قائمة المنتجات؟'),
        children: [
          ListTile(
              leading: Icon(Icons.download_outlined),
              title: Text('١. نزّل القالب واملأه'),
              subtitle: Text(
                  'كل صف منتج واحد. اكتب الاسم والسعر بالدينار دون رمز العملة. استخدم Excel أو CSV؛ القالب يساعدك لكنه ليس إلزاميًا.')),
          ListTile(
              leading: Icon(Icons.folder_open),
              title: Text('٢. اختر الملف وحدد القسم'),
              subtitle: Text(
                  'طابق أعمدة ملفك، ثم اختر قسمًا افتراضيًا إذا لم تضع معرف القسم في الملف. يجب إنشاء الأقسام أولًا من شاشة المنتجات.')),
          ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: Text('٣. أرفق الصور عند الحاجة'),
              subtitle: Text(
                  'الصور ملفات منفصلة، وليست صورًا ملصقة داخل Excel. اكتب burger.jpg في عمود imageFile ثم اختر الصورة بالاسم نفسه من «إرفاق صور المنتجات». يمكنك تحديد عدة صور.')),
          ListTile(
              leading: Icon(Icons.fact_check_outlined),
              title: Text('٤. افحص ثم اعتمد وانشر'),
              subtitle: Text(
                  'المعاينة لا تغيّر المنتجات الحية. راجع الأخطاء وحدد الصفوف المطلوبة ثم اعتمدها. بعد الانتهاء انشر القائمة من شاشة المنتجات لإظهارها للزبائن.')),
          ListTile(
              title: Text('ما الحقول المطلوبة؟'),
              subtitle: Text(
                  'name: الاسم، price: سعر صحيح موجب. categoryId: معرف القسم، أو اختر قسمًا افتراضيًا هنا. description وimageFile وstock اختيارية. اترك الكمية فارغة إذا لم ترد تتبع المخزون؛ الصفر يعني نفاد المنتج.')),
          ListTile(
              title: Text('تحديث منتجات موجودة'),
              subtitle: Text(
                  'اختر «تحديث المحدد» وأضف عمود productId بمعرف المنتج الحالي. لا يُحذف أي منتج لم يرد في الملف. الخيار optionGroupsJson مخصص للخيارات المتقدمة، وليس مطلوبًا للوجبات البسيطة. الحد 500 صف، والصور JPG أو PNG أو WebP حتى 100 صورة في الدفعة.')),
        ],
      );

  Future<void> saveErrors() async {
    final report = buildProductImportErrorCsv(rows);
    await FilePicker.saveFile(
      dialogTitle: 'حفظ تقرير أخطاء الاستيراد',
      fileName: 'product-import-errors.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: Uint8List.fromList(utf8.encode(report)),
    );
  }

  @override
  Widget build(BuildContext context) => ProductOperationsTheme(
          child: Scaffold(
        appBar: AppBar(title: const Text('استيراد المنتجات')),
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              importGuide(),
              const Text(
                  'المعاينة لا تغيّر المنتجات الحية، والمنتج الغائب من الملف لا يُحذف.'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ADD_ONLY', label: Text('إضافة فقط')),
                    ButtonSegment(
                        value: 'UPDATE_SELECTED', label: Text('تحديث المحدد')),
                  ],
                  selected: {
                    mode
                  },
                  onSelectionChanged: busy
                      ? null
                      : (v) => setState(() {
                            mode = v.single;
                            job = null;
                            selected.clear();
                          })),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: busy ? null : pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('اختيار CSV أو XLSX')),
              OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await Clipboard.setData(
                              ClipboardData(text: templateCsv));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم نسخ قالب CSV')));
                          }
                        },
                  icon: const Icon(Icons.content_copy),
                  label: const Text('نسخ قالب المنتجات')),
              OutlinedButton.icon(
                  onPressed: busy ? null : () => downloadTemplate(),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('تنزيل قالب CSV')),
              OutlinedButton.icon(
                  onPressed: busy ? null : () => downloadTemplate(excel: true),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('تنزيل قالب Excel')),
              if (pickedFileName != null)
                ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(pickedFileName!),
                    subtitle: const Text(
                        'تمت قراءة الملف؛ راجع مطابقة الأعمدة أدناه.')),
              if (sourceHeaders.isNotEmpty) mappingFields(),
              OutlinedButton.icon(
                  onPressed: busy ? null : pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text('إرفاق صور المنتجات (${imageUrls.length})')),
              const Text(
                  'استخدم اسم ملف الصورة كاملًا في عمود الصورة، مثل burger.jpg. تُطابق الأسماء دون تغيير. الكمية الفارغة لا تغيّر المخزون؛ الرقم صفر يمنع البيع عند النفاد.'),
              if (progress != null) Text(progress!),
              TextField(
                  onChanged: (v) {
                    setState(() {
                      sourceHeaders = productImportHeaders(v);
                      mapping = suggestProductImportMapping(sourceHeaders);
                      job = null;
                    });
                  },
                  controller: csv,
                  enabled: !busy,
                  minLines: 7,
                  maxLines: 14,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'CSV',
                      hintText: template,
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: busy ? null : preview,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('فحص ومعاينة')),
              if (busy)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator())),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red))),
              if (job != null) ...[
                const Divider(height: 32),
                Text(
                    'النتيجة: ${(job!['counts'] as Map?)?['valid'] ?? 0} صالح، ${(job!['counts'] as Map?)?['rejected'] ?? 0} مرفوض'),
                if (((job!['counts'] as Map?)?['rejected'] ?? 0) > 0)
                  OutlinedButton.icon(
                    onPressed: busy ? null : saveErrors,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('تنزيل تقرير الأخطاء CSV'),
                  ),
                ...rows.map((row) {
                  final id = row['rowId'] as String;
                  final errors = List<String>.from(row['errors'] ?? const []);
                  final valid = errors.isEmpty;
                  return CheckboxListTile(
                      value: selected.contains(id),
                      onChanged: !valid || busy
                          ? null
                          : (v) {
                              setState(() => v == true
                                  ? selected.add(id)
                                  : selected.remove(id));
                              _remember();
                            },
                      title: Text('${row['name']} — ${row['price']} د.ع'),
                      subtitle: Text(valid
                          ? (row['action'] == 'CREATE'
                              ? 'منتج جديد'
                              : 'تحديث منتج موجود')
                          : errors.map((e) => _rowError(e)).join('، ')));
                }),
                FilledButton.icon(
                    onPressed: busy ||
                            selected.isEmpty ||
                            job!['status'] == 'COMPLETED'
                        ? null
                        : commit,
                    icon: const Icon(Icons.publish),
                    label: Text(job!['status'] == 'COMPLETED'
                        ? 'اكتمل الاستيراد'
                        : 'اعتماد ${selected.length} صف')),
              ],
            ])),
      ));
}
