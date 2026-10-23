import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/merchant_business_changes_screen.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
class ChangesFake extends PersonOnboardingService {
 final calls=<Map<String,dynamic>>[];
 bool failed=false;
 @override
 Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async {
  if(body==null)return {'items':[],'baseUpdatedAt':'v1'};
  calls.add(body);
  if(failed)throw Exception('timeout');
  return {'request':{'status':'PENDING'}};
 }
}
void main(){
 testWidgets('name proposal submits selected branch and version without publishing name', (tester)async{
  final api=ChangesFake();await tester.pumpWidget(MaterialApp(home:MerchantBusinessChangesScreen(businessId:'branch-a',service:api)));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0),'اسم مقترح');await tester.enterText(find.byType(TextField).at(1),'تصحيح الاسم التجاري');await tester.tap(find.text('إرسال طلب تعديل الاسم'));await tester.pumpAndSettle();
  expect(api.calls.single['businessId'],'branch-a');expect(api.calls.single['baseUpdatedAt'],'v1');expect(api.calls.single['kind'],'NAME');expect(api.calls.single['proposed'],{'businessName':'اسم مقترح'});expect(find.textContaining('يبقى الاسم المعتمد ظاهرًا'),findsOneWidget);
 });
 testWidgets('retry after timeout preserves request identity',(tester)async{
  final api=ChangesFake()..failed=true;await tester.pumpWidget(MaterialApp(home:MerchantBusinessChangesScreen(businessId:'branch-a',service:api)));await tester.pumpAndSettle();await tester.enterText(find.byType(TextField).at(0),'مقترح');await tester.enterText(find.byType(TextField).at(1),'سبب واضح');
  await tester.tap(find.text('إرسال طلب تعديل الاسم'));await tester.pumpAndSettle();await tester.tap(find.text('إرسال طلب تعديل الاسم'));await tester.pumpAndSettle();expect(api.calls.length,2);expect(api.calls[0]['requestId'],api.calls[1]['requestId']);
 });
 testWidgets('embedded requests share the activity page without a second scaffold', (tester)async{
  final api=ChangesFake();
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:MerchantBusinessChangesScreen(businessId:'branch-a',service:api,embedded:true)))));
  await tester.pumpAndSettle();expect(find.byType(Scaffold),findsOneWidget);expect(find.text('تحديث حالة الطلبات'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}
