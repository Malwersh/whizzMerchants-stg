import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/services/commercial_notice_navigation.dart';
import 'package:whizz_merchants/services/merchant_notification_inbox.dart';
import 'package:whizz_merchants/widgets/commercial_requests_banner.dart';

Map<String,dynamic> item() => {'campaignLabel':'خصم الاختبار','draft':{'id':'share','kind':'FUNDING','version':1,'baseVersion':0,'hash':'hash','businessIds':['branch'],'createdAt':'2026-10-17T00:00:00.000Z','values':{'merchantNumerator':30,'denominator':100,'effectiveFrom':'2026-10-17T00:00:00.000Z','effectiveTo':'2026-11-01T00:00:00.000Z'}},'ownerAccepted':false};
class Api extends PersonOnboardingService {
 List<dynamic> items=[item()]; final calls=<String>[];
 @override Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async { calls.add(path);return {'items':items,'can':{'direct':true}}; }
}
String jwt(String sub) => '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub':sub,'exp':DateTime.now().millisecondsSinceEpoch~/1000+3600})))}.fixture';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(() { SharedPreferences.setMockInitialValues({}); FlutterSecureStorage.setMockInitialValues({'secure_access_token':jwt('owner')}); CommercialNoticeNavigation.ownerReady=false; });
 test('pending requests reconstruct inbox once without push and disappear after resolution',() async {
  var pending=[item()];final inbox=MerchantNotificationInbox(subjectLoader:()async=>'owner',orderLoader:(_)async=>[],sharingLoader:(_)async=>pending);
  await inbox.load('branch');expect(inbox.items.single.type,'commercial_sharing_requested');expect(inbox.items.single.id,'sharing:share:1');await inbox.load('branch');expect(inbox.items.length,1);pending=[];await inbox.load('branch');expect(inbox.items,isEmpty);
 });
 test('delivery request reconstructs distinct inbox entry without financial push data',() async {
  final delivery=item();delivery['draft']={...delivery['draft'],'kind':'DELIVERY'};
  final inbox=MerchantNotificationInbox(subjectLoader:()async=>'owner',orderLoader:(_)async=>[],sharingLoader:(_)async=>[item(),delivery]);
  await inbox.load('branch');expect(inbox.items.length,2);final notice=inbox.items.singleWhere((x)=>x.id=='delivery:share:1');expect(notice.title,'عرض توصيل بانتظار موافقتك');expect(notice.data['requestKind'],'DELIVERY');expect(notice.data.containsKey('values'),false);
 });
 testWidgets('banner shows pending count and is removed when request is resolved',(t) async {
  final api=Api();await t.pumpWidget(MaterialApp(home:Scaffold(body:CommercialRequestsBanner(businessId:'branch',service:api))));await t.pumpAndSettle();expect(find.textContaining('1 طلب عرض أو مشاركة'),findsOneWidget);api.items=[];CommercialNoticeNavigation.changes.value++;await t.pumpAndSettle();expect(find.textContaining('طلب عرض أو مشاركة'),findsNothing);await t.pumpWidget(const SizedBox());
 });
 testWidgets('notification target waits for owner home, verifies server visibility and opens correct sharing',(t)async{
  final api=Api();await t.pumpWidget(MaterialApp(navigatorKey:CommercialNoticeNavigation.navigatorKey,home:const Scaffold(body:Text('home'))));
  CommercialNoticeNavigation.receive({'action':'commercial_sharing_requested','subjectId':'owner','businessId':'branch','sharingId':'share'},tapped:true);await t.pumpAndSettle();expect(api.calls,isEmpty);
  CommercialNoticeNavigation.ownerReady=true;final opening=CommercialNoticeNavigation.tryOpen(service:api);await t.pumpAndSettle();expect(find.text('شروط المشاركة'),findsOneWidget);expect(api.calls.first,contains('view=pending-sharing'));CommercialNoticeNavigation.navigatorKey.currentState!.pop();await t.pumpAndSettle();await opening;await t.pumpWidget(const SizedBox());
 });
 testWidgets('another signed-in account cannot follow an owner notification',(t)async{
  final api=Api();await t.pumpWidget(MaterialApp(navigatorKey:CommercialNoticeNavigation.navigatorKey,home:const Scaffold(body:Text('home'))));
  CommercialNoticeNavigation.receive({'action':'commercial_sharing_requested','subjectId':'other','businessId':'branch','sharingId':'share'},tapped:true);CommercialNoticeNavigation.ownerReady=true;await CommercialNoticeNavigation.tryOpen(service:api);await t.pumpAndSettle();expect(api.calls,isEmpty);expect(find.text('شروط المشاركة'),findsNothing);await t.pumpWidget(const SizedBox());
 });
}
