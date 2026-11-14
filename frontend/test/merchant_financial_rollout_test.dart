import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/providers/auth_provider_riverpod.dart';
import '../lib/services/person_onboarding_service.dart';
import '../lib/services/merchant_financial_session_state.dart';
import '../lib/screens/merchant_payouts_screen.dart';
import '../lib/screens/settlement_schedules_screen.dart';
import '../lib/screens/commercial_agreements_screen.dart';
import '../lib/screens/wallet_transfer_screen.dart';
import '../lib/widgets/merchant_financial_gate.dart';
class Owner extends AuthNotifier{Owner():super(signOutAction:()async{}){state=const AuthState(status:AuthStatus.authenticated,currentUser:{'sub':'owner'});}}
class NoRead extends PersonOnboardingService{
 int reads=0;
 @override Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true})async{reads++;throw StateError('protected data requested before unlock');}
}
void main(){
 testWidgets('enabled rollout gates every owner financial entry before a data request',(tester)async{
  final api=NoRead();
  for(final screen in <Widget>[MerchantPayoutsScreen(businessId:'branch',service:api),SettlementSchedulesScreen(businessId:'branch',service:api),CommercialAgreementsScreen(businessId:'branch',service:api),const WalletTransferScreen(businessId:'branch')]){
   MerchantFinancialSessionState.instance.clear();
   await tester.pumpWidget(ProviderScope(overrides:[authProviderRiverpod.overrideWith((_)=>Owner())],child:MaterialApp(home:screen)));
   await tester.pump();
   expect(find.byType(MerchantFinancialGate),findsOneWidget);
   expect(api.reads,0);
   await tester.pumpWidget(const SizedBox());
  }
 },skip:!merchantFinancialLockEnabled);
}
