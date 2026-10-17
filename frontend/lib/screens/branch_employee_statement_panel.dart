import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/wallet_effect_summary.dart';
import '../widgets/merchant_sales_report_summary.dart';
import '../services/statement_file_export_service.dart';
import '../services/branch_employee_access.dart';
import '../services/branch_employee_wallet_service.dart';

class BranchEmployeeStatementPanel extends StatefulWidget {
  final BranchEmployeeAccess access;
  final BranchEmployeeWalletService api;
  final StatementFileExportService? fileExporter;
  final bool sales;
  const BranchEmployeeStatementPanel(
      {super.key,
      required this.access,
      required this.api,
      this.fileExporter,
      this.sales = false});
  @override
  State<BranchEmployeeStatementPanel> createState() => _StatementState();
}

class _StatementState extends State<BranchEmployeeStatementPanel> {
  DateTimeRange? period;
  Map<String, dynamic>? statement;
  String? error;
  bool busy = false;
  int generation = 0;
  @override
  void didUpdateWidget(covariant BranchEmployeeStatementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.access, current = widget.access;
    if (oldWidget.sales != widget.sales ||
        old.capabilities['readSalesReports'] !=
            current.capabilities['readSalesReports'] ||
        old.businessId != current.businessId ||
        old.token != current.token ||
        old.session != current.session ||
        old.capabilities['readWalletTransactions'] !=
            current.capabilities['readWalletTransactions'] ||
        old.capabilities['exportSalesReports'] !=
            current.capabilities['exportSalesReports'] ||
        old.capabilities['exportWallet'] !=
            current.capabilities['exportWallet']) {
      generation++;
      statement = null;
      error = null;
      busy = false;
    }
  }

  String day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  Future<void> choose() async {
    final now = DateTime.now().toUtc();
    final last = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final epoch = generation;
    final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: last,
        initialDateRange: period,
        helpText: widget.sales
            ? 'فترة التقرير — أيام UTC مكتملة، حتى 31 يومًا'
            : 'فترة الكشف — أيام UTC مكتملة، حتى 31 يومًا');
    if (!mounted || epoch != generation || selected == null) return;
    setState(() {
      period = selected;
      statement = null;
      error = null;
    });
  }

  Future<void> load({bool export = false, bool saveFile = false}) async {
    if (busy || period == null) return;
    final epoch = generation, access = widget.access, selected = period!;
    bool savingFile = false;
    setState(() {
      busy = true;
      statement = null;
      error = null;
    });
    try {
      final data = await widget.api.read(
          access, widget.sales ? 'sales-report' : 'statement',
          from: day(selected.start), to: day(selected.end), exportCsv: export);
      if (!mounted || epoch != generation) return;
      if (data['complete'] != true) {
        throw StateError('تعذر إعداد كشف مكتمل');
      }
      if (export) {
        if (data['csv'] is! String) throw StateError('تعذر إعداد CSV');
        if (saveFile) {
          savingFile = true;
          final saved =
              await (widget.fileExporter ?? StatementFileExportService()).save(
                  filename: data['filename'] as String,
                  csv: data['csv'] as String);
          if (!mounted || epoch != generation) return;
          if (saved) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    widget.sales ? 'تم حفظ ملف التقرير' : 'تم حفظ ملف الكشف')));
          }
        } else {
          await Clipboard.setData(ClipboardData(text: data['csv']));
          if (!mounted || epoch != generation) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(widget.sales
                  ? 'نُسخ تقرير CSV؛ يمكنك لصقه في ملف أو جدول'
                  : 'نُسخ كشف CSV؛ يمكنك لصقه في ملف أو جدول')));
        }
      }
      setState(() => statement = data);
    } catch (_) {
      if (mounted && epoch == generation) {
        setState(() {
          statement = null;
          error = savingFile
              ? 'تعذر حفظ ملف CSV. تحقق من وجهة الحفظ والمساحة المتاحة ثم أعد المحاولة.'
              : widget.sales
                  ? 'تعذر إعداد التقرير. تحقق من صلاحيتك والفترة المختارة ثم أعد المحاولة.'
                  : 'تعذر إعداد الكشف. تحقق من صلاحيتك واختر فترة لا تتجاوز 31 يومًا؛ إذا كانت الحركات كثيرة اختر فترة أقصر.';
        });
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.access.capabilities[
            widget.sales ? 'readSalesReports' : 'readWalletTransactions'] !=
        true) {
      return const SizedBox.shrink();
    }
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  widget.sales ? 'تقرير الطلبات والمبيعات' : 'كشف حركة المحفظة',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(widget.sales
                  ? 'أيام UTC مكتملة، حتى 31 يومًا و500 طلب مطابق. التقرير يعرض بيانات الفترة بعد اكتمال القراءة فقط.'
                  : 'أيام UTC مكتملة، بحد أقصى 31 يومًا و500 حركة. المبالغ والأرصدة كما سُجلت؛ لا يمثل الكشف تقرير أرباح أو تسوية محاسبية.'),
              TextButton(
                  onPressed: busy ? null : choose,
                  child: Text(period == null
                      ? (widget.sales
                          ? 'اختيار فترة التقرير'
                          : 'اختيار فترة الكشف')
                      : '${day(period!.start)} — ${day(period!.end)} UTC')),
              Wrap(children: [
                TextButton(
                    onPressed: busy || period == null ? null : load,
                    child: Text(widget.sales ? 'عرض التقرير' : 'عرض الكشف')),
                if (widget.access.capabilities[
                        widget.sales ? 'exportSalesReports' : 'exportWallet'] ==
                    true)
                  TextButton(
                      onPressed: busy || period == null
                          ? null
                          : () => load(export: true),
                      child: const Text('نسخ CSV')),
                if (widget.access.capabilities[
                        widget.sales ? 'exportSalesReports' : 'exportWallet'] ==
                    true)
                  TextButton(
                      onPressed: busy || period == null
                          ? null
                          : () => load(export: true, saveFile: true),
                      child: const Text('حفظ ملف CSV')),
              ]),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (statement != null) ...[
                if (!widget.sales)
                  Text('عدد الحركات: ${statement!['rowCount']}'),
                Text('وقت القراءة: ${statement!['asOf'] ?? ''}'),
                if (widget.sales && statement!['summary'] is Map)
                  MerchantSalesReportSummary(
                      summary:
                          Map<String, dynamic>.from(statement!['summary'])),
                if (!widget.sales)
                  WalletEffectSummary(
                      summary: statement!['effectSummary'] is Map
                          ? Map<String, dynamic>.from(
                              statement!['effectSummary'])
                          : null),
                for (final row in statement!['entries'] ?? [])
                  ListTile(
                      title:
                          Text('${row['amount']} د.ع — ${row['type'] ?? ''}'),
                      subtitle: Text(
                          '${row['description'] ?? ''}\n${row['createdAt'] ?? row['timestamp'] ?? row['sk']}'
                          '${row['ledgerEffect']?['status'] == 'CLASSIFIED' ? '\nتغير ${row['ledgerEffect']['bucket'] == 'LOCKED' ? 'المحجوز' : 'المتاح'}: ${row['ledgerEffect']['delta']} د.ع' : ''}')),
              ],
            ])));
  }
}
