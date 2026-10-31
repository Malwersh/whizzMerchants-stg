import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/widgets/merchant_order_attention.dart';
import 'package:whizz_merchants/services/merchant_order_alerts.dart';
import 'package:whizz_merchants/services/commercial_notice_navigation.dart';
import 'package:whizz_merchants/services/sound_notification_settings.dart';
void main(){testWidgets('branch-scoped alert is immediate, dismissible and never changes the current tab',(tester)async{
 SharedPreferences.setMockInitialValues({'sound_notifications_enabled':false});await SoundNotificationSettings().initialize();var loads=0,opens=0;
 await tester.pumpWidget(MaterialApp(navigatorKey:CommercialNoticeNavigation.navigatorKey,home:MerchantOrderAttention(businessId:'branchA',load:()async{loads++;return [];},open:(_)=>opens++,child:const Scaffold(body:Text('التحليلات')))));
 await tester.pump();MerchantOrderAlerts.receive({'businessId':'branchB','orderId':'other'});await tester.pump();expect(find.textContaining('طلب جديد'),findsNothing);
 MerchantOrderAlerts.receive({'businessId':'branchA','orderId':'new'});await tester.pump();await tester.pump(const Duration(milliseconds:300));expect(find.text('التحليلات'),findsOneWidget);expect(find.text('عرض الطلب'),findsOneWidget);expect(find.byIcon(Icons.close),findsOneWidget);
 MerchantOrderAlerts.receive({'businessId':'branchA','orderId':'new'});await tester.pump();expect(find.text('عرض الطلب'),findsOneWidget);
 await tester.ensureVisible(find.text('عرض الطلب'));await tester.pumpAndSettle();await tester.tap(find.text('عرض الطلب'));await tester.pumpAndSettle();expect(opens,1);expect(loads,2);
 await tester.pumpWidget(const SizedBox.shrink());
 });}
