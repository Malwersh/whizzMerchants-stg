import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/product_service.dart';
import '../services/xlsx_csv_decoder.dart';

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
      'rowId,productId,name,description,price,categoryId,isAvailable,barcode,optionGroupsJson\n'
      'burger-1,,برغر كلاسيك,وصف المنتج,6000,food,true,001234567890,';
  final csv = TextEditingController();
  String mode = 'ADD_ONLY';
  Map<String, dynamic>? job;
  final selected = <String>{};
  bool busy = false;
  String? error;
  String get _resumeKey => 'product_import_${widget.businessId}';

  @override
  void initState() {
    super.initState();
    _restore();
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
      if (result['success'] != true) throw StateError('expired');
      final value = Map<String, dynamic>.from(result['job']);
      final remembered = value['selectedRowIds'] ?? saved['selected'];
      selected
        ..clear()
        ..addAll(List<String>.from(remembered ?? const []));
      if (mounted) setState(() => job = value);
    } catch (_) {
      await prefs.remove(_resumeKey);
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
      busy = true;
      error = null;
      job = null;
      selected.clear();
    });
    try {
      final result = await ProductService.previewCsvImport(
          businessId: widget.businessId, csv: csv.text, mode: mode);
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
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
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
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('استيراد المنتجات')),
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const Text(
                  'الصق محتوى CSV ثم افحصه. المعاينة لا تغيّر المنتجات الحية، والمنتج الغائب من الملف لا يُحذف.'),
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
                  onSelectionChanged:
                      busy ? null : (v) => setState(() => mode = v.single)),
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
                              const ClipboardData(text: template));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم نسخ قالب CSV')));
                          }
                        },
                  icon: const Icon(Icons.content_copy),
                  label: const Text('نسخ القالب العربي')),
              TextField(
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
                          : errors.join('، ')));
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
      );
}
