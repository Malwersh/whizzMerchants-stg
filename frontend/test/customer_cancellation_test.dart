import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/screens/customer_cancellation_screen.dart';
import 'package:whizz_merchants/services/order_returns_service.dart';
void main(){
 testWidgets('merchant must confirm no preparation; server-confirmed cancellation alone closes request',(t)async{
  var posts=0;
  final api=OrderReturnsService(token:()async=>'access',client:MockClient((r)async{
   expect(r.headers['Authorization'],'Bearer access');
   if(r.method=='POST'){posts++;final b=jsonDecode(r.body);expect(b['preparationNotStarted'],true);expect(b['expectedVersion'],1);expect(b['requestId'],'CAN:one');return http.Response(jsonEncode({'success':true,'orderId':'order1','cancellationStatus':'CANCELLED','message':'تم إلغاء الطلب دون رسوم'}),200,headers:{'content-type':'application/json; charset=utf-8'});}
   expect(r.url.queryParameters,{'businessId':'branch1','orderId':'order1'});
   return http.Response(jsonEncode({'success':true,'orderId':'order1','cancellationStatus':'REQUESTED','caseId':'OEX:one','cancellationRequestId':'CAN:one','version':1,'canConfirmNoPreparation':true}),200);
  }));
  await t.pumpWidget(MaterialApp(home:CustomerCancellationScreen(selectors:{'businessId':'branch1','orderId':'order1'},service:api)));await t.pumpAndSettle();
  expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);expect(posts,0);
  await t.tap(find.byType(CheckboxListTile));await t.pumpAndSettle();await t.tap(find.byType(FilledButton));await t.pumpAndSettle();expect(posts,1);expect(find.text('تم إلغاء الطلب دون رسوم'),findsOneWidget);
 });
 testWidgets('prepared or assigned case offers no no-preparation confirmation',(t)async{
  final api=OrderReturnsService(token:()async=>'access',client:MockClient((r)async=>http.Response(jsonEncode({'success':true,'orderId':'order1','cancellationStatus':'REQUESTED','canConfirmNoPreparation':false}),200)));
  await t.pumpWidget(MaterialApp(home:CustomerCancellationScreen(selectors:{'businessId':'branch1','orderId':'order1'},service:api)));await t.pumpAndSettle();expect(find.text('تأكيد عدم التجهيز وإلغاء الطلب'),findsNothing);expect(find.text('تسجيل إثبات بقاء الأصناف للإدارة'),findsOneWidget);expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
 });
 testWidgets('retention evidence sends actual state and optimistic version without claiming cancellation',(t)async{
  var posts=0; var retained=false;
  final api=OrderReturnsService(token:()async=>'access',client:MockClient((r)async{
   if(r.method=='POST'){posts++;final b=jsonDecode(r.body);expect(b['goodsRetainedByBranch'],true);expect(b['preparationState'],'STARTED');expect(b['note'],'بدأ تجهيز الطعام');expect(b['expectedVersion'],2);expect(b.containsKey('preparationNotStarted'),false);retained=true;return http.Response(jsonEncode({'success':true,'orderId':'order1'}),200);}
   return http.Response(jsonEncode({'success':true,'orderId':'order1','cancellationStatus':'REQUESTED','cancellationRequestId':'CAN:one','version':retained?3:2,'canConfirmNoPreparation':false,if(retained)'merchantRetentionProof':{'preparationState':'STARTED'}}),200);
  }));
  await t.pumpWidget(MaterialApp(home:CustomerCancellationScreen(selectors:{'businessId':'branch1','orderId':'order1'},service:api)));await t.pumpAndSettle();
  await t.enterText(find.byType(TextField),'بدأ تجهيز الطعام');await t.tap(find.byType(CheckboxListTile));await t.pumpAndSettle();await t.ensureVisible(find.byType(FilledButton));await t.tap(find.byType(FilledButton));await t.pumpAndSettle();
  expect(posts,1);await t.drag(find.byType(ListView),const Offset(0,900));await t.pumpAndSettle();expect(find.text('سُجل إثبات بقاء الأصناف لدى المطعم. لا يعني تسجيله اعتماد تعويض أو صرفه.'),findsOneWidget);expect(find.text('تأكيد عدم التجهيز وإلغاء الطلب'),findsNothing);
 });

}
