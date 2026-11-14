import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/wallet_effect_summary.dart';

Widget panel(Map<String, dynamic>? summary) => MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child: WalletEffectSummary(summary: summary))));
void main() {
  testWidgets(
      'available and locked movements remain separate and never become a deposit total',
      (tester) async {
    await tester.pumpWidget(panel({
      'status': 'AVAILABLE',
      'totals': {
        'AVAILABLE': {'increases': 0, 'decreases': 300, 'net': -300},
        'LOCKED': {'increases': 300, 'decreases': 0, 'net': 300}
      }
    }));
    expect(find.text('نقص المتاح: 300 د.ع'), findsOneWidget);
    expect(find.text('زيادة المحجوز: 300 د.ع'), findsOneWidget);
    expect(find.text('صافي تغير المتاح: -300 د.ع'), findsOneWidget);
    expect(find.textContaining('لا تمثل إجمالي الإيداعات'), findsOneWidget);
  });
  testWidgets('unknown entries and unsafe totals hide all monetary summaries',
      (tester) async {
    for (final reason in ['UNCLASSIFIED_ENTRIES', 'UNSAFE_TOTAL']) {
      await tester.pumpWidget(panel({
        'status': 'UNAVAILABLE',
        'reason': reason,
        'unclassifiedCount': 1,
        'totals': {
          'AVAILABLE': {'increases': 999999, 'decreases': 0, 'net': 999999}
        }
      }));
      expect(find.textContaining('999999'), findsNothing);
      expect(
          find.textContaining(reason == 'UNSAFE_TOTAL'
              ? 'الحد العددي الآمن'
              : 'لا تُعرض مجاميع جزئية'),
          findsOneWidget);
    }
  });
  testWidgets('missing interpretation never silently shows zero totals',
      (tester) async {
    await tester.pumpWidget(panel(null));
    expect(find.textContaining('الإجماليات غير متاحة'), findsOneWidget);
    expect(find.textContaining('زيادة المتاح:'), findsNothing);
  });
}
