import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/models/business.dart';
import 'package:whizz_merchants/services/api_service.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/widgets/location_settings_full_bottom_drawer.dart';
import 'package:whizz_merchants/config/app_config.dart';
class LocationApiFixture extends ApiService {
 Map<String,dynamic>? saved;
 @override Future<Map<String,dynamic>> getBusinessLocationSettings(String id) async => {'settings':{'latitude':31.92,'longitude':44.45,'address':'العنوان المحفوظ عند الإنشاء','regionPath':['country','province','district','area'],'locationVersion':'v1'}};
 @override Future<Map<String,dynamic>> updateBusinessLocationSettings(String id,Map<String,dynamic> body)async {saved=body;return {'success':true};}
}
class RegionFixture extends PersonOnboardingService {
 @override Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true})async=>{'items':[for(var i=0;i<4;i++){'id':['country','province','district','area'][i],'level':i,'parentId':i==0?null:['country','province','district','area'][i-1],'labelAr':['العراق','محافظة النجف','قضاء المناذرة','مركز المناذرة'][i]},{'id':'other','level':0,'parentId':null,'labelAr':'بلد آخر'}]};
}
class ProductionChangesFixture extends RegionFixture {
  Map<String, dynamic>? submitted;

  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    expect(authenticated, true);
    if (path == 'business-changes?businessId=fixture') {
      return LocationApiFixture().getBusinessLocationSettings('fixture');
    }
    if (path == 'branch-drafts/regions') return super.call(path);
    expect(path, 'business-changes');
    submitted = body;
    return {'request': {'status': 'PENDING'}};
  }
}
Future<void> open(WidgetTester tester,LocationApiFixture api,{RegionFixture? onboarding})async {
 tester.view.physicalSize=const Size(1200,2400);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
 await tester.pumpWidget(ProviderScope(child:MaterialApp(locale:const Locale('ar'),localizationsDelegates:AppLocalizations.localizationsDelegates,supportedLocales:AppLocalizations.supportedLocales,home:Scaffold(body:LocationSettingsFullBottomDrawer(business:Business.fromJson({'businessId':'fixture','businessName':'فتوش'}),api:api,onboarding:onboarding??RegionFixture())))));await tester.pumpAndSettle();
}
void main(){
 testWidgets('settings restores creation region identifiers and detailed address and saves the same path',(tester)async {
  final api=LocationApiFixture();await open(tester,api);
  for(final label in ['العراق','محافظة النجف','قضاء المناذرة','مركز المناذرة']){expect(find.text(label),findsOneWidget);}
  expect(find.byType(DropdownButtonFormField<String>),findsNWidgets(4));
  expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,'العنوان المحفوظ عند الإنشاء');
  final buttons=find.byIcon(Icons.save);await tester.ensureVisible(buttons.last);await tester.tap(buttons.last);await tester.pumpAndSettle();
  expect(api.saved!['regionPath'],['country','province','district','area']);expect(api.saved!['address'],'العنوان المحفوظ عند الإنشاء');expect(api.saved!['locationVersion'],'v1');expect(api.saved!['latitude'],31.92);
 }, skip: AppConfig.isProduction);
 testWidgets('changing a parent clears children and the previous location',(tester)async {
  final api=LocationApiFixture();await open(tester,api);await tester.tap(find.byType(DropdownButtonFormField<String>).first);await tester.pumpAndSettle();await tester.tap(find.text('بلد آخر').last);await tester.pumpAndSettle();
  expect(find.text('محافظة النجف'),findsNothing);expect(find.text('مركز المناذرة'),findsNothing);expect(find.textContaining('31.9200000'),findsNothing);
 }, skip: AppConfig.isProduction);
 testWidgets('production submits a changed address for review', (tester) async {
   final api = LocationApiFixture();
   final changes = ProductionChangesFixture();
   await open(tester, api, onboarding: changes);
   await tester.enterText(find.byType(TextFormField), 'العنوان المقترح');
   final save = find.byIcon(Icons.save).last;
   await tester.ensureVisible(save);
   await tester.tap(save);
   await tester.pump();
   await tester.pump(const Duration(milliseconds: 350));
   final dialog = find.byType(AlertDialog);
   await tester.enterText(find.descendant(of: dialog, matching: find.byType(TextField)), 'شرح التعديل');
   await tester.tap(find.text('إرسال للمراجعة'));
   await tester.pumpAndSettle();
   expect(api.saved, isNull);
   expect(changes.submitted?['kind'], 'LOCATION');
   expect(changes.submitted?['baseUpdatedAt'], 'v1');
   expect(changes.submitted?['proposed']['address'], 'العنوان المقترح');
 }, skip: !AppConfig.isProduction);
}
