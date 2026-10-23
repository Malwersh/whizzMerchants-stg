import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/commercial_agreements_screen.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
class AgreementApi extends PersonOnboardingService {
 final calls=<Map<String,dynamic>>[];
 bool failed=false,accepted=false,direct=false,sharing=false;
 Completer<Map<String,dynamic>>? waiting;
 @override
 Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async {
  if(body!=null){calls.add(Map.from(body));if(waiting!=null)return waiting!.future;if(failed)throw Exception('timeout');accepted=true;return {};}
  if(failed&&calls.isEmpty)throw Exception('read failed');
  return {'can':{'direct':direct},'items':[{'supportReference':'AG-000123','draft':{'kind':sharing?'FUNDING':'AGREEMENT','id':'contract','version':1,'baseVersion':0,'hash':'draft-hash','businessIds':['branch-a'],'publishedVersion':direct&&accepted?1:null,'fundingPolicies':[],'values':sharing?{'merchantNumerator':30,'denominator':100,'effectiveFrom':'2026-10-01T00:00:00.000Z','effectiveTo':'2026-11-01T00:00:00.000Z'}:{
    'effectiveFrom':'2026-10-01T00:00:00.000Z','effectiveTo':null,
    'commission':{'kind':'PERCENT','basis':'AFTER_MERCHANT_DISCOUNT','rate':{'numerator':10,'denominator':100},'finalRounding':{'incrementIqd':1,'mode':'HALF_AWAY_FROM_ZERO'}},
    'serviceFee':{'kind':'FIXED','fixed':{'minorAmount':500000},'finalRounding':{'incrementIqd':1,'mode':'HALF_AWAY_FROM_ZERO'}}}},'ownerAccepted':accepted,'current':null}]};
 }
}
class MultipleSharingApi extends AgreementApi {
 @override
 Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async {
  final result=await super.call(path,body:body,authenticated:authenticated);
  if(body!=null)return result;
  final first=Map<String,dynamic>.from((result['items'] as List).first);
  return {...result,'items':[first,{...first,'campaignLabel':'عرض ثان','draft':{...first['draft'],'id':'second','hash':'second-hash'}}]};
 }
}
class DeliveryApi extends AgreementApi {
 @override Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async {
  final result=await super.call(path,body:body,authenticated:authenticated);
  if(body!=null)return {'publishedVersion':1};
  final item=(result['items'] as List).first as Map;
  item['draft']={...item['draft'],'kind':'DELIVERY','publishedVersion':accepted?1:null,'values':{
   'customerRule':{'kind':'CAPPED_PRICE','amount':{'minorAmount':1500000}},'funding':{'kind':'PLATFORM'},
   'limits':{'merchantPerOrder':{'minorAmount':0},'platformPerOrder':{'minorAmount':2500000},'merchantBudget':{'minorAmount':0},'platformBudget':{'minorAmount':100000000},'perCustomerUses':3},
   'eligibility':{'minimumGoods':{'minorAmount':10000000},'minimumGoodsBasis':'AFTER_GOODS_DISCOUNTS','maximumRoadMeters':5000,'regionIds':['zone'],'audience':'ALL','goodsDiscountStacking':'ALLOW'},
   'effectiveFrom':'2026-10-18T00:00:00.000Z','effectiveTo':'2026-10-25T00:00:00.000Z'}};
  return result;
 }
}
class DatedDeliveryApi extends DeliveryApi {
 dynamic schemaVersion = 2;
 @override Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async {
  final result=await super.call(path,body:body,authenticated:authenticated);
  if(body!=null)return result;
  final values=result['items'][0]['draft']['values'] as Map;
  values.remove('limits');values['schemaVersion']=schemaVersion;
  values['customerRule']['kind']='FIXED_TARIFF';
  values['commission']={'rate':{'numerator':5,'denominator':100}};
  return result;
 }
}
void main(){
 Future<void> open(WidgetTester t,AgreementApi api,{String branch='branch-a'})async{await t.pumpWidget(MaterialApp(home:CommercialAgreementsScreen(businessId:branch,service:api)));await t.pumpAndSettle();if(find.byType(ExpansionTile).evaluate().isNotEmpty){await t.tap(find.byType(ExpansionTile).first);await t.pumpAndSettle();}}
 Future<void> consent(WidgetTester t)async{await t.scrollUntilVisible(find.byType(CheckboxListTile),250,scrollable:find.byType(Scrollable).first);await t.pumpAndSettle();await t.tap(find.byType(CheckboxListTile));await t.pumpAndSettle();await t.ensureVisible(find.text('تأكيد الموافقة على النسخة'));await t.pumpAndSettle();await t.tap(find.text('تأكيد الموافقة على النسخة'));await t.pump();}
 testWidgets('shows explicit rates and requires checkbox before acceptance; sends only versioned consent',(t)async{
  final api=AgreementApi();await open(t,api);expect(find.textContaining('10%'),findsOneWidget);expect(find.textContaining('500 دينار'),findsOneWidget);
  expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);await consent(t);await t.pumpAndSettle();
  expect(api.calls.single['businessId'],'branch-a');expect(api.calls.single['baseVersion'],0);expect(api.calls.single['hash'],'draft-hash');expect(api.calls.single.containsKey('commission'),false);expect(find.textContaining('تنتظر اعتماد المنصة.'),findsWidgets);
 });
 testWidgets('failed acceptance keeps same request id and never shows accepted state',(t)async{final api=AgreementApi()..failed=true;api.calls.add({'setup':true});await open(t,api);api.calls.clear();await consent(t);await t.pumpAndSettle();await t.ensureVisible(find.text('تأكيد الموافقة على النسخة'));await t.pumpAndSettle();await t.tap(find.text('تأكيد الموافقة على النسخة'));await t.pumpAndSettle();expect(api.calls.length,2);expect(api.calls.first['requestId'],api.calls.last['requestId']);expect(find.textContaining('وافقت على هذه النسخة'),findsNothing);});
 testWidgets('read failure is explicit and clears old agreement scope',(t)async{final api=AgreementApi();await open(t,api);api.failed=true;await open(t,api,branch:'branch-b');expect(find.text('read failed'),findsNothing);expect(find.textContaining('read failed'),findsOneWidget);expect(find.byType(CheckboxListTile),findsNothing);});
 testWidgets('late success from previous branch does not acknowledge consent in new branch',(t)async{final api=AgreementApi()..waiting=Completer();await open(t,api);await consent(t);await open(t,api,branch:'branch-b');api.waiting!.complete({});await t.pumpAndSettle();expect(find.text('سُجلت موافقتك على هذه النسخة. تنتظر اعتماد المنصة.'),findsNothing);});
 testWidgets('direct agreement flow does not show pending peer approval after publication',(t)async{final api=AgreementApi()..direct=true;await open(t,api);expect(find.textContaining('حتى اعتماد المنصة'),findsNothing);await consent(t);await t.pumpAndSettle();expect(find.text('تم اعتماد هذه النسخة.'),findsOneWidget);expect(find.textContaining('تنتظر اعتماد المنصة'),findsNothing);});

 testWidgets('readable agreement hides technical references and formats dates and money on narrow RTL screen',(t)async{
  t.view.physicalSize=const Size(375,812);t.view.devicePixelRatio=1;addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  final api=AgreementApi();await t.pumpWidget(MaterialApp(home:CommercialAgreementsScreen(businessId:'branch-a',businessName:'مطعم فتوش',service:api)));await t.pumpAndSettle();await t.tap(find.byType(ExpansionTile).first);await t.pumpAndSettle();
  expect(find.text('مطعم فتوش'),findsWidgets);expect(find.textContaining('10%'),findsOneWidget);expect(find.textContaining('500 دينار'),findsOneWidget);expect(find.textContaining('2026-10-01T'),findsNothing);expect(find.textContaining('branch-a'),findsNothing);expect(find.textContaining('contract'),findsNothing);expect(t.takeException(),isNull);
  await t.scrollUntilVisible(find.text('AG-000123'),250,scrollable:find.byType(Scrollable).first);await t.pumpAndSettle();expect(find.text('AG-000123'),findsOneWidget);expect(find.textContaining('contract'),findsNothing);expect(find.text('branch-a'),findsNothing);expect(find.byTooltip('نسخ مرجع الدعم'),findsOneWidget);String? copied;TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,(call)async{if(call.method=='Clipboard.setData')copied=call.arguments['text'];return null;});addTearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,null));await t.ensureVisible(find.byTooltip('نسخ مرجع الدعم'));await t.pumpAndSettle();await t.tap(find.byTooltip('نسخ مرجع الدعم'));await t.pumpAndSettle();expect(copied,'AG-000123 / V1');expect(t.takeException(),isNull);
 });

 testWidgets('sharing consent shows campaign shares separately and sends ACCEPT_FUNDING',(t)async{final api=AgreementApi()..sharing=true;await open(t,api);expect(find.textContaining('30%'),findsOneWidget);expect(find.textContaining('70%'),findsOneWidget);expect(find.text('العمولة ورسوم الخدمة'),findsNothing);await consent(t);await t.pumpAndSettle();expect(api.calls.single['action'],'ACCEPT_FUNDING');expect(api.calls.single.containsKey('merchantNumerator'),false);expect(t.takeException(),isNull);});

 testWidgets('delivery shows funding terms and sends acceptance without another staff approval',(t)async{
  final api=DeliveryApi();await open(t,api);expect(find.text('عرض توصيل'),findsOneWidget);expect(find.textContaining('1,500 دينار'),findsOneWidget);expect(find.text('المنصة تتحمل دعم التوصيل بالكامل'),findsOneWidget);expect(find.text('العمولة ورسوم الخدمة'),findsNothing);
  await consent(t);await t.pumpAndSettle();expect(api.calls.single['action'],'ACCEPT_DELIVERY');expect(api.calls.single.containsKey('values'),false);expect(find.text('تم اعتماد هذه النسخة.'),findsOneWidget);expect(t.takeException(),isNull);
 });
 testWidgets('multiple requests start collapsed and each can open and close independently',(t)async{
  final api=MultipleSharingApi()..sharing=true;
  await t.pumpWidget(MaterialApp(home:CommercialAgreementsScreen(businessId:'branch-a',service:api)));
  await t.pumpAndSettle();
  expect(find.text('عرض ثان'),findsOneWidget);
  expect(find.byType(CheckboxListTile),findsNothing);
  await t.tap(find.byType(ExpansionTile).first);await t.pumpAndSettle();
  expect(find.byType(CheckboxListTile),findsOneWidget);
  await t.ensureVisible(find.text('مشاركة تمويل خصم'));await t.tap(find.text('مشاركة تمويل خصم'));await t.pumpAndSettle();
  expect(find.byType(CheckboxListTile),findsNothing);
  await t.tap(find.text('عرض ثان'));await t.pumpAndSettle();
  expect(find.byType(CheckboxListTile),findsOneWidget);
  expect(api.calls,isEmpty);
 });

 testWidgets('notification opens dated agreement without budget limits and requires explicit consent',(t)async{
  final api=DatedDeliveryApi();
  await t.pumpWidget(MaterialApp(home:CommercialAgreementsScreen(businessId:'branch-a',focusSharingId:'contract',focusRequestKind:'DELIVERY',service:api)));
  await t.pumpAndSettle();expect(t.takeException(),isNull);
  expect(find.text('اتفاقية أسعار وتوصيل'),findsOneWidget);
  expect(find.textContaining('5%'),findsOneWidget);
  expect(find.textContaining('توصيل ثابت للزبون: 1,500'),findsOneWidget);
  expect(api.calls,isEmpty);
  await consent(t);await t.pumpAndSettle();
  expect(api.calls.single['action'],'ACCEPT_DELIVERY');
  expect(api.calls.single['hash'],'draft-hash');
  expect(api.calls.single.containsKey('values'),false);
 });
 testWidgets('unsupported delivery terms without limits cannot crash or solicit consent',(t)async{
  final api=DatedDeliveryApi()..schemaVersion=3;await open(t,api);
  expect(t.takeException(),isNull);
  expect(find.text('تعذر عرض شروط الاتفاقية'),findsOneWidget);
  expect(find.byType(CheckboxListTile),findsNothing);expect(api.calls,isEmpty);
 });

}
