import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/branch_staff_screen.dart';
import 'package:whizz_merchants/screens/commercial_agreements_screen.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
class ManagerApi extends PersonOnboardingService {
 final String role;
 ManagerApi(this.role);
 @override
 Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async {
  if(path.contains('view=memberships')) return {'items':[{'businessId':'branch','businessName':'فرع الاختبار','role':role,'status':'ACTIVE'}]};
  if(path.startsWith('commercial-agreements')) return {'items':[],'can':{'direct':true}};
  return {'items':[]};
 }
}
void main(){
 testWidgets('manager sees branch discount approvals and opens existing consent screen',(t)async{
  final api=ManagerApi('MANAGER');await t.pumpWidget(MaterialApp(home:BranchStaffScreen(employeeHome:true,service:api)));
  await t.pumpAndSettle();expect(find.text('موافقات الخصومات'),findsOneWidget);
  await t.ensureVisible(find.text('موافقات الخصومات'));await t.tap(find.text('موافقات الخصومات'));await t.pumpAndSettle();
  expect(find.byType(CommercialAgreementsScreen),findsOneWidget);
  await t.pumpWidget(const SizedBox());await t.pumpAndSettle();
 });
 testWidgets('ordinary reception member has no manager approval action',(t)async{
  await t.pumpWidget(MaterialApp(home:BranchStaffScreen(employeeHome:true,service:ManagerApi('RECEPTION'))));await t.pumpAndSettle();expect(find.text('موافقات الخصومات'),findsNothing);await t.pumpWidget(const SizedBox());
 });
}
