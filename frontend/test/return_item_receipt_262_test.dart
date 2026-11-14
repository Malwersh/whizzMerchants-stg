import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/screens/order_return_screen.dart';
import 'package:whizz_merchants/screens/return_item_receipt_editor.dart';
import 'package:whizz_merchants/services/order_returns_service.dart';
final manifest=<String,dynamic>{'digest':'snapshot-262','lines':[{'lineId':'line_1','name':'وجبة الاختبار','expectedQty':2}]};
void main(){
 testWidgets('explicit conditions and bounded quantities are required', (tester)async{
 List<Map<String,dynamic>>? result;
 await tester.pumpWidget(MaterialApp(home:Scaffold(body:ReturnItemReceiptEditor(manifest:manifest,enabled:true,onChanged:(v)=>result=v))));
 final qty=find.byKey(const ValueKey('return-qty-line_1'));
 await tester.enterText(qty,'1');expect(result,isNull);
 await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();await tester.tap(find.text('مغلّف وسليم').last);await tester.pumpAndSettle();
 expect(result!.single['receivedQty'],1);expect(result!.single['condition'],'SEALED_INTACT');
 await tester.enterText(qty,'3');expect(result,isNull);await tester.enterText(qty,'0');await tester.pump();expect(result!.single['condition'],'MISSING');
 });
 testWidgets('partial receipt sends pinned line IDs and exact quantities', (tester)async{
 final posts=<Map<String,dynamic>>[];
 final service=OrderReturnsService(token:()async=>'owner-test',client:MockClient((request)async{
 if(request.method=='POST'){posts.add(jsonDecode(request.body)as Map<String,dynamic>);return http.Response(jsonEncode({'success':true,'orderId':'order1'}),200);}
 return http.Response(jsonEncode({'success':true,'orderId':'order1','status':posts.isEmpty?'ARRIVED_AT_BRANCH':'REVIEW_REQUIRED','version':3,'returnId':'return1','itemManifest':manifest}),200,headers:{'content-type':'application/json; charset=utf-8'});}));
 await tester.pumpWidget(MaterialApp(home:OrderReturnScreen(selectors:{'businessId':'branch1','orderId':'order1','offerId':'offer1','attempt':1},service:service)));await tester.pumpAndSettle();
 final qty=find.byKey(const ValueKey('return-qty-line_1'));await tester.ensureVisible(qty);await tester.enterText(qty,'1');
 final cond=find.byKey(const ValueKey('return-condition-line_1'));await tester.ensureVisible(cond);await tester.tap(cond);await tester.pumpAndSettle();await tester.tap(find.text('مغلّف وسليم').last);await tester.pumpAndSettle();
 final responsibility=find.text('هل توجد ملاحظة تحتاج مراجعة؟');await tester.ensureVisible(responsibility);await tester.tap(responsibility);await tester.pumpAndSettle();await tester.tap(find.text('تحتاج مراجعة').last);await tester.pumpAndSettle();
 final cash=find.text('أؤكد أن هذه عودة بلا مبلغ محصل من الزبون');await tester.ensureVisible(cash);await tester.tap(cash);await tester.pumpAndSettle();
 final submit=find.text('مراجعة وتأكيد الاستلام');await tester.ensureVisible(submit);await tester.tap(submit);await tester.pumpAndSettle();await tester.tap(find.text('تأكيد الإقرار'));await tester.pumpAndSettle();
 expect(posts.length,1);expect(posts.single['allItemsReceived'],false);expect(posts.single['condition'],'MISSING');expect(posts.single['itemReceipts'],[{'lineId':'line_1','receivedQty':1,'condition':'SEALED_INTACT'}]);expect(posts.single.containsKey('expectedQty'),false);
 await tester.pumpWidget(const SizedBox());
 });
}
