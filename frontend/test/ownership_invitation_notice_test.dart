import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/config/app_config.dart';
import '../lib/services/commercial_notice_navigation.dart';

void main() {
  testWidgets('a foreground invitation offers to open the incoming requests',
      (tester) async {
    CommercialNoticeNavigation.ownerReady = true;
    addTearDown(() => CommercialNoticeNavigation.ownerReady = false);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: CommercialNoticeNavigation.navigatorKey,
      home: const Scaffold(body: Text('مطاعمي وأنشطتي')),
    ));

    CommercialNoticeNavigation.receive({'type': 'ownership_invitation'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('لديك دعوة جديدة لنقل ملكية نشاط.'), findsOneWidget);
    expect(find.text('عرض الدعوة'), findsOneWidget);
    expect(find.text('مطاعمي وأنشطتي'), findsOneWidget);
  }, skip: !AppConfig.ownershipTransferEnabled);

  testWidgets('a foreground acceptance tells the current owner about the review',
      (tester) async {
    CommercialNoticeNavigation.ownerReady = true;
    addTearDown(() => CommercialNoticeNavigation.ownerReady = false);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: CommercialNoticeNavigation.navigatorKey,
      home: const Scaffold(),
    ));

    CommercialNoticeNavigation.receive({'type': 'ownership_accepted'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('قَبِل المالك الجديد دعوة النقل. الطلب بانتظار مراجعة الإدارة.'),
        findsOneWidget);
  }, skip: !AppConfig.ownershipTransferEnabled);
}
