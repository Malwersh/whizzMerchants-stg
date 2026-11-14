import 'package:flutter/material.dart';

class MerchantSalesReportSummary extends StatelessWidget {
  final Map<String, dynamic> summary;
  const MerchantSalesReportSummary({super.key, required this.summary});
  String amount(int subunits) {
    final whole = subunits ~/ 1000;
    final fraction = (subunits % 1000)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('عدد الطلبات في الفترة: ${summary['orderCount']}'),
        Text('الطلبات المكتملة حاليًا: ${summary['completedOrderCount']}'),
        const Text(
            'التقرير حسب تاريخ إنشاء الطلب وحالته الحالية. قيم الفواتير الأصلية تشمل الرسوم والخصومات؛ لا تثبت التحصيل أو الربح أو صافي المستحق بعد الاسترجاع.'),
        if (summary['status'] == 'AVAILABLE' &&
            summary['totalsSubunits'] is Map) ...[
          Text(
              'قيمة السلع قبل الخصومات: ${amount(summary['totalsSubunits']['goods'] as int)} د.ع'),
          Text(
              'خصومات الطلبات بكل مصادرها: ${amount(summary['totalsSubunits']['discount'] as int)} د.ع'),
          Text(
              'إجمالي الفواتير شامل الرسوم: ${amount(summary['totalsSubunits']['checkout'] as int)} د.ع'),
        ] else
          Text(
              'مجاميع المبيعات غير متاحة؛ لم يثبت تفسير أسعار ${summary['unclassifiedCompletedCount'] ?? '—'} طلب مكتمل أو تجاوز المجموع الحد العددي الآمن. لا تُعرض مجاميع جزئية.'),
      ]);
}
