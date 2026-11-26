import 'package:flutter/material.dart';

/// Interpreted changes to each balance bucket; these are not sales or profit.
class WalletEffectSummary extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const WalletEffectSummary({super.key, required this.summary});
  @override
  Widget build(BuildContext context) {
    final data = summary;
    if (data == null ||
        data['status'] != 'AVAILABLE' ||
        data['totals'] is! Map) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(data?['reason'] == 'UNSAFE_TOTAL'
            ? 'تعذر حساب الإجماليات لأن المجموع تجاوز الحد العددي الآمن. الحركات الأصلية معروضة أدناه.'
            : 'الإجماليات غير متاحة: توجد حركات لم يُثبت تفسيرها (${data?['unclassifiedCount'] ?? '—'}). لا تُعرض مجاميع جزئية؛ راجع الحركات الأصلية أدناه.'),
      );
    }
    final totals = data['totals'] as Map;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('تغير أرصدة المحفظة خلال الفترة',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const Text(
          'تشمل التغيرات نقل الرصيد بين المتاح والمحجوز؛ لا تمثل إجمالي الإيداعات والسحوبات الخارجية أو المبيعات والأرباح.'),
      for (final bucket
          in const {'AVAILABLE': 'المتاح', 'LOCKED': 'المحجوز'}.entries)
        if (totals[bucket.key] is Map)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تغير الرصيد ${bucket.value}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            'زيادة ${bucket.value}: ${totals[bucket.key]['increases']} د.ع'),
                        Text(
                            'نقص ${bucket.value}: ${totals[bucket.key]['decreases']} د.ع'),
                        Text(
                            'صافي تغير ${bucket.value}: ${totals[bucket.key]['net']} د.ع'),
                      ]))),
    ]);
  }
}
