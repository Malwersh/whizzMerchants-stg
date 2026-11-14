import 'package:flutter/material.dart';
import '../services/person_onboarding_service.dart';
import 'auth/auth_surface.dart';

class StaffProductActivityScreen extends StatefulWidget {
  final String businessId;
  final String? subjectId;
  final PersonOnboardingService? service;
  final Future<DateTimeRange?> Function(BuildContext)? periodPicker;
  const StaffProductActivityScreen(
      {super.key,
      required this.businessId,
      this.subjectId,
      this.service,
      this.periodPicker});
  @override
  State<StaffProductActivityScreen> createState() => _ActivityState();
}

class _ActivityState extends State<StaffProductActivityScreen> {
  final fallbackApi = PersonOnboardingService();
  final events = <Map<String, dynamic>>[];
  static const actions = {
    'all': 'كل العمليات المشمولة',
    'MENU_PRODUCT_CREATED': 'إضافة منتج',
    'MENU_PRODUCT_DELETED': 'حذف منتج',
    'MENU_PRODUCT_UPDATED': 'تعديل منتج',
    'BRANCH_STATUS_CHANGED': 'تغيير استقبال الطلبات',
    'ORDER_STATUS_CHANGED': 'تغيير حالة طلب',
    'DISCOUNT_CREATED': 'إضافة خصم',
    'DISCOUNT_UPDATED': 'تعديل خصم',
    'DISCOUNT_STATUS_CHANGED': 'تفعيل أو إيقاف خصم',
    'DISCOUNT_DELETED': 'حذف خصم',
    'BRANCH_HOURS_CHANGED': 'تعديل ساعات العمل',
    'MERCHANT_STAFF_BALANCE_READ': 'عرض رصيد المحفظة',
    'MERCHANT_STAFF_TRANSACTIONS_READ': 'عرض حركات المحفظة',
    'MERCHANT_STAFF_STATEMENT_READ': 'عرض كشف المحفظة',
    'MERCHANT_STAFF_STATEMENT_EXPORT': 'تجهيز تصدير كشف المحفظة',
    'MERCHANT_STAFF_SALES_REPORT_READ': 'عرض تقرير المبيعات',
    'MERCHANT_STAFF_SALES_REPORT_EXPORT': 'تجهيز تصدير تقرير المبيعات',
    'MERCHANT_STAFF_TRANSFER_CONTEXT_READ': 'عرض حدود تحويل الفرع',
    'MERCHANT_STAFF_TRANSFER_RECIPIENT_READ': 'التحقق من مستلم التحويل',
    'MERCHANT_STAFF_TRANSFER_HISTORY_READ': 'عرض سجل التحويلات',
    'MERCHANT_STAFF_TRANSFER_STATUS_READ': 'التحقق من حالة التحويل',
    'MERCHANT_STAFF_TRANSFER_VERIFICATION_REQUESTED': 'طلب تحقق لتحويل الرصيد',
    'MERCHANT_STAFF_TRANSFER_COMPLETED': 'تحويل الرصيد',
    'MERCHANT_STAFF_TRANSFER_CANCELLED': 'إلغاء محاولة تحويل',
  };
  String selection = 'all';
  final referenceInput = TextEditingController();
  String? reference;
  DateTimeRange? period;
  String day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    referenceInput.dispose();
    super.dispose();
  }

  Future<void> choosePeriod() async {
    final now = DateTime.now().toUtc();
    final branch = widget.businessId, subject = widget.subjectId;
    final selected = await (widget.periodPicker?.call(context) ??
        showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year, now.month, now.day),
          initialDateRange: period,
          helpText: 'فترة السجل — أيام UTC',
        ));
    if (!mounted ||
        selected == null ||
        branch != widget.businessId ||
        subject != widget.subjectId) {
      return;
    }
    setState(() => period = selected);
    load(reset: true);
  }

  void applyReference() {
    final value = referenceInput.text.trim();
    if (value.isNotEmpty && !RegExp(r'^[\w-]{1,150}$').hasMatch(value)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('أدخل معرف المنتج أو الفرع أو الطلب كاملًا دون مسافات.')));
      return;
    }
    reference = value.isEmpty ? null : value;
    load(reset: true);
  }

  String? cursor, error;
  bool busy = false, loaded = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void didUpdateWidget(covariant StaffProductActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId ||
        oldWidget.subjectId != widget.subjectId ||
        oldWidget.service != widget.service) {
      generation++;
      selection = 'all';
      reference = null;
      referenceInput.clear();
      period = null;
      busy = false;
      load(reset: true);
    }
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    final requestGeneration = ++generation;
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        events.clear();
        cursor = null;
        loaded = false;
      }
    });
    try {
      final query = Uri(queryParameters: {
        'view': 'activity',
        'businessId': widget.businessId,
        if (widget.subjectId != null) 'subjectId': widget.subjectId!,
        if (selection != 'all') 'action': selection,
        if (reference != null) 'reference': reference!,
        if (period != null) ...{
          'from': day(period!.start),
          'to': day(period!.end)
        },
        if (!reset && cursor != null) 'cursor': cursor!
      }).query;
      final response =
          await (widget.service ?? fallbackApi).call('branch-staff?$query');
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        events.addAll(List<Map<String, dynamic>>.from(response['items'] ?? []));
        cursor = response['nextCursor'];
        loaded = true;
      });
    } catch (e) {
      if (mounted && requestGeneration == generation) {
        setState(() {
          events.clear();
          cursor = null;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted && requestGeneration == generation) {
        setState(() => busy = false);
      }
    }
  }

  String reception(dynamic state) {
    final value = state is Map ? state['acceptingOrders'] : null;
    return value == true
        ? 'متصل'
        : value == false
            ? 'غير متصل'
            : 'غير مسجل';
  }

  String productValue(dynamic value) => value == null
      ? 'غير مسجل'
      : value == true
          ? 'متاح'
          : value == false
              ? 'غير متاح'
              : value.toString();

  String orderState(dynamic state) {
    final value = state is Map ? state['status'] : null;
    return const {
          'pending': 'بانتظار القبول',
          'confirmed': 'مقبول',
          'rejected': 'مرفوض',
          'preparing': 'قيد التحضير',
          'in_kitchen': 'في المطبخ',
          'ready': 'جاهز',
        }[value] ??
        'غير مسجل';
  }

  String hoursDay(dynamic value) {
    if (value is! Map || value['isClosed'] is! bool) return 'غير مسجل';
    if (value['isClosed'] == true) return 'مغلق';
    return '${value['opening'] ?? 'غير مسجل'} — ${value['closing'] ?? 'غير مسجل'}';
  }

  List<String> hoursChanges(Map<String, dynamic> event) {
    final before = event['before'] is Map ? event['before']['days'] : null;
    final after = event['after'] is Map ? event['after']['days'] : null;
    final previous = {
      if (before is List)
        for (final day in before.whereType<Map>()) day['weekday']: day
    };
    return [
      if (after is List)
        for (final day in after.whereType<Map>())
          if (hoursDay(previous[day['weekday']]) != hoursDay(day))
            '${const {
                  'Monday': 'الاثنين',
                  'Tuesday': 'الثلاثاء',
                  'Wednesday': 'الأربعاء',
                  'Thursday': 'الخميس',
                  'Friday': 'الجمعة',
                  'Saturday': 'السبت',
                  'Sunday': 'الأحد'
                }[day['weekday']] ?? 'اليوم'} قبل: ${hoursDay(previous[day['weekday']])}؛ بعد: ${hoursDay(day)}',
    ];
  }

  String discountValue(dynamic value) => value == null
      ? 'غير مسجل'
      : const {
            'percentage': 'نسبة مئوية',
            'fixedAmount': 'مبلغ ثابت',
            'active': 'مفعّل',
            'inactive': 'متوقف',
            'scheduled': 'مجدول',
            'expired': 'منتهٍ',
          }[value] ??
          value.toString();

  Widget eventCard(Map<String, dynamic> event) {
    final status = event['action'] == 'BRANCH_STATUS_CHANGED';
    final order = event['action'] == 'ORDER_STATUS_CHANGED';
    final hours = event['action'] == 'BRANCH_HOURS_CHANGED';
    final finance =
        event['action']?.toString().startsWith('MERCHANT_STAFF_') == true;
    final discount =
        event['action']?.toString().startsWith('DISCOUNT_') == true;
    final product = event['after'] ?? event['before'];
    final details = <String>[
      if (!status &&
          !order &&
          !hours &&
          !finance &&
          !discount &&
          product is Map)
        product['name']?.toString() ?? '',
      event['actorName']?.toString().isNotEmpty == true
          ? event['actorName'].toString()
          : 'موظف الفرع',
      event['roleName']?.toString() ?? '',
      if (event['entityId'] is String) 'المرجع: ${event['entityId']}',
      DateTime.tryParse(event['createdAt'] ?? '')?.toLocal().toString() ?? '',
      if (event['action'] == 'MENU_PRODUCT_UPDATED') ...[
        for (final field in const {
          'name': 'الاسم',
          'description': 'الوصف',
          'price': 'السعر',
          'isAvailable': 'التوفر'
        }.entries)
          if (event['before']?[field.key] != event['after']?[field.key])
            '${field.value} قبل: ${productValue(event['before']?[field.key])}؛ بعد: ${productValue(event['after']?[field.key])}',
      ],
      if (discount) ...[
        if (product is Map) product['title']?.toString() ?? '',
        for (final entry in const {
          'title': 'الاسم',
          'value': 'القيمة',
          'type': 'نوع الخصم',
          'status': 'الحالة',
          'minimum_order_amount': 'الحد الأدنى',
          'valid_from': 'البداية',
          'valid_to': 'النهاية'
        }.entries)
          if (event['before']?[entry.key] != event['after']?[entry.key])
            '${entry.value} قبل: ${discountValue(event['before']?[entry.key])}؛ بعد: ${discountValue(event['after']?[entry.key])}',
      ] else if (finance) ...[
        if (event['amount'] is num && event['currency'] == 'IQD')
          'المبلغ: ${event['amount']} د.ع',
        if (event['transferStatus'] == 'COMPLETED') 'حالة التحويل: مكتمل',
        if (event['transferStatus'] == 'CANCELLED') 'حالة التحويل: ملغى',
        if (event['action'] == 'MERCHANT_STAFF_TRANSFER_VERIFICATION_REQUESTED')
          'سُجل طلب التحقق؛ لا يثبت هذا الحدث تسليم الرسالة أو إتمام التحويل.',
        if (event['periodFrom'] != null && event['periodTo'] != null)
          'الفترة: ${event['periodFrom']} — ${event['periodTo']} (UTC)',
        if (event['format'] == 'csv')
          'جُهّز CSV؛ حفظ الملف على الجهاز إجراء مستقل.',
      ] else if (hours)
        ...hoursChanges(event)
      else if (status) ...[
        'الاستقبال قبل: ${reception(event['before'])}',
        'الاستقبال بعد: ${reception(event['after'])}',
      ] else if (order) ...[
        'حالة الطلب قبل: ${orderState(event['before'])}',
        'حالة الطلب بعد: ${orderState(event['after'])}',
      ] else if (product is Map && product['price'] != null)
        'السعر: ${product['price']} د.ع',
      event['result'] == 'SUCCEEDED' ? 'تم التنفيذ' : 'نتيجة غير متاحة',
    ];
    return Card(
        child: ListTile(
      leading: Icon(discount
          ? Icons.local_offer_outlined
          : finance
              ? Icons.account_balance_wallet_outlined
              : hours
                  ? Icons.schedule
                  : order
                      ? Icons.receipt_long_outlined
                      : status
                          ? Icons.power_settings_new
                          : event['action'] == 'MENU_PRODUCT_CREATED'
                              ? Icons.add_circle_outline
                              : event['action'] == 'MENU_PRODUCT_UPDATED'
                                  ? Icons.edit_outlined
                                  : Icons.delete_outline),
      title: Text(actions[event['action']] ?? 'إجراء غير معروف'),
      subtitle: Text(details.where((value) => value.isNotEmpty).join('\n')),
    ));
  }

  @override
  Widget build(BuildContext context) => AuthSurface(
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              appBar: AppBar(title: const Text('سجل نشاط الموظفين')),
              body: ListView(padding: const EdgeInsets.all(16), children: [
                const Text(
                    'يشمل السجل تغييرات المنتجات وحالات الطلبات والاستقبال وساعات العمل، والخصومات والاطلاع المالي وتجهيز التصدير من جلسات الموظفين. بقية الأنشطة غير مشمولة بعد.'),
                DropdownButtonFormField<String>(
                  initialValue: selection,
                  decoration: const InputDecoration(labelText: 'نوع العملية'),
                  items: actions.entries
                      .map((entry) => DropdownMenuItem(
                          value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null || value == selection) return;
                          setState(() => selection = value);
                          load(reset: true);
                        },
                ),
                TextButton.icon(
                    onPressed: busy ? null : choosePeriod,
                    icon: const Icon(Icons.date_range),
                    label: Text(period == null
                        ? 'اختيار الفترة (UTC)'
                        : '${day(period!.start)} — ${day(period!.end)} (UTC)')),
                if (period != null)
                  TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() => period = null);
                              load(reset: true);
                            },
                      child: const Text('إلغاء الفترة')),
                TextField(
                  controller: referenceInput,
                  enabled: !busy,
                  textDirection: TextDirection.ltr,
                  maxLength: 150,
                  decoration: const InputDecoration(
                      labelText: 'معرف المنتج أو الفرع أو الطلب',
                      helperText:
                          'بحث بالمعرف الكامل؛ ليس باسم المنتج أو الموظف'),
                  onSubmitted: busy ? null : (_) => applyReference(),
                ),
                TextButton(
                    onPressed: busy ? null : applyReference,
                    child: const Text('تطبيق البحث')),
                TextButton(
                    onPressed: busy ? null : () => load(reset: true),
                    child: const Text('تحديث السجل')),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (loaded &&
                    !busy &&
                    error == null &&
                    events.isEmpty &&
                    cursor == null)
                  const Text('لا توجد عمليات مسجلة.'),
                for (final event in events) eventCard(event),
                if (cursor != null)
                  TextButton(
                      onPressed: busy ? null : load,
                      child: const Text('المزيد من العمليات')),
              ]))));
}
