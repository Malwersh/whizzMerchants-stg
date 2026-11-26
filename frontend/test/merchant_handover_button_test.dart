import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/widgets/merchant_handover_button.dart';
Order order({bool assigned=true,bool recorded=false})=>Order.fromJson({'orderId':'o1','businessId':'b1','items':[],'totalAmount':12000,'status':'arrived_at_store','createdAt':'2026-10-24T12:00:00Z',if(assigned)'driverId':'driver1',if(assigned)'financialAssignment':{'offerId':'offer1','attempt':1},if(recorded)'merchantHandover':{'state':'HANDED_TO_DRIVER','attempt':1}});
void main(){
 testWidgets('assigned order has permanent handover action with explicit physical handover confirmation',(tester)async{await tester.pumpWidget(MaterialApp(home:Scaffold(body:MerchantHandoverButton(order:order()))));expect(find.text('تم تسليم الطلب للسائق'),findsOneWidget);await tester.tap(find.text('تم تسليم الطلب للسائق'));await tester.pumpAndSettle();expect(find.text('تأكيد التسليم للسائق'),findsOneWidget);await tester.tap(find.text('رجوع'));await tester.pumpAndSettle();expect(find.text('تم تسليم الطلب للسائق'),findsOneWidget);});
 testWidgets('unassigned order cannot report handing to a driver',(tester)async{await tester.pumpWidget(MaterialApp(home:Scaffold(body:MerchantHandoverButton(order:order(assigned:false)))));expect(find.text('تم تسليم الطلب للسائق'),findsNothing);});
 testWidgets('confirmed handover survives model copying and renders recorded state',(tester)async{final value=order(recorded:true).copyWith();expect(value.toJson()['merchantHandover']['state'],'HANDED_TO_DRIVER');await tester.pumpWidget(MaterialApp(home:Scaffold(body:MerchantHandoverButton(order:value))));expect(find.text('✓ أكّد المطعم تسليم الطلب للسائق'),findsOneWidget);expect(find.text('تم تسليم الطلب للسائق'),findsNothing);});
}
