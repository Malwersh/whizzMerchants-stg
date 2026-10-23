import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/screens/merchant_cancellation_screen.dart';
import 'package:whizz_merchants/services/order_returns_service.dart';
void main(){
 test('exception policy marker survives cache and copy for unassigned orders',(){final o=Order.fromJson({'orderId':'order1','businessId':'branch1','status':'preparing','items':[],'exceptionPolicyVersion':'OECSR_STAGING_COD_V1'});expect(o.exceptionPolicyVersion,'OECSR_STAGING_COD_V1');expect(o.copyWith().exceptionPolicyVersion,o.exceptionPolicyVersion);expect(Order.fromJson(o.toJson()).exceptionPolicyVersion,o.exceptionPolicyVersion);expect(o.financialAssignment,isNull);});
 testWidgets('owner cancellation requires reason, custody and no-cash confirmations and exact server acknowledgement',(t)async{
  var posts=0;Map<String,dynamic>? seen;
  final api=OrderReturnsService(token:()async=>'owner-token',client:MockClient((r)async{posts++;seen=jsonDecode(r.body);return http.Response(jsonEncode({'success':true,'orderId':'order1','cancellationStatus':'CANCELLED'}),200,headers:{'content-type':'application/json; charset=utf-8'});}));
  final o=Order.fromJson({'orderId':'order1','businessId':'branch1','status':'preparing','items':[],'exceptionPolicyVersion':'OECSR_STAGING_COD_V1'});
  await t.pumpWidget(MaterialApp(home:MerchantCancellationScreen(order:o,service:api)));await t.pumpAndSettle();expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
  await t.enterText(find.byType(TextField),'نفاد الصنف بعد بدء التجهيز');for(final box in find.byType(CheckboxListTile).evaluate().toList()){await t.tap(find.byWidget(box.widget));await t.pumpAndSettle();}await t.ensureVisible(find.text('مراجعة الإلغاء'));await t.tap(find.text('مراجعة الإلغاء'));await t.pumpAndSettle();expect(posts,0);await t.tap(find.text('تأكيد الإلغاء'));await t.pumpAndSettle();expect(posts,1);expect(seen!['merchantCancellation'],true);expect(seen!['reason'],'نفاد الصنف بعد بدء التجهيز');expect(seen!['preparationState'],'STARTED');expect(seen!['idempotencyKey'],matches(RegExp(r'^[a-f0-9-]{36}$')));expect(seen!.containsKey('amount'),false);expect(find.textContaining('أكد الخادم إلغاء الطلب'),findsOneWidget);await t.pumpWidget(const SizedBox());
 });
}
