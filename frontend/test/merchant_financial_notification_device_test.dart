import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/merchant_financial_notification_device.dart';
import '../lib/services/person_onboarding_service.dart';
class Api extends PersonOnboardingService{
 final calls=<Map<String,dynamic>>[];
 @override
 Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true})async{calls.add(Map.from(body!));return {'enabled':body['enabled']??false};}
}
void main(){
 testWidgets('reads server preference then saves explicit device opt-in without local optimistic approval',(tester)async{
  final api=Api();await tester.pumpWidget(MaterialApp(home:Scaffold(body:MerchantFinancialNotificationDevice(businessId:'b1',service:api,tokenLoader:()async=>'push-token'))));await tester.pumpAndSettle();
  expect(api.calls.single['action'],'FINANCIAL_NOTIFICATION_DEVICE_STATUS');expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,false);
  await tester.tap(find.byType(SwitchListTile));await tester.pumpAndSettle();expect(api.calls.last['enabled'],true);expect(api.calls.last['branchId'],'b1');expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,true);
 });
 testWidgets('missing device token disables changes and provides retry',(tester)async{
  final api=Api();await tester.pumpWidget(MaterialApp(home:Scaffold(body:MerchantFinancialNotificationDevice(businessId:'b1',service:api,tokenLoader:()async=>null))));await tester.pumpAndSettle();expect(api.calls,isEmpty);expect(find.text('إعادة المحاولة'),findsOneWidget);expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,isNull);
 });
}
