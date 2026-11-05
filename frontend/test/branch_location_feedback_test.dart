import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import 'package:whizz_merchants/models/business.dart';
import 'package:whizz_merchants/services/merchant_places_service.dart';
import 'package:whizz_merchants/widgets/location_settings_full_bottom_drawer.dart';
import 'location_settings_regions_test.dart' show LocationApiFixture, RegionFixture;

class LocationApi extends LocationApiFixture {
  final bool initial;
  LocationApi(this.initial);
  @override
  Future<Map<String,dynamic>> getBusinessLocationSettings(String id) async {
    final result = await super.getBusinessLocationSettings(id);
    if(initial) result['settings'] = <String,dynamic>{...result['settings'], 'latitude':null, 'longitude':null};
    return result;
  }
}
class Requests extends RegionFixture {
  final posts=<Map<String,dynamic>>[];
  bool fail=false;
  @override
  Future<Map<String,dynamic>> call(String path,{Map<String,dynamic>? body,bool authenticated=true}) async {
    if(body==null) return super.call(path,authenticated:authenticated);
    posts.add(body);
    if(fail) throw Exception('تعذر الاتصال');
    return {'request':{'status':'PENDING'}};
  }
}
Future<void> open(WidgetTester t,Requests requests,{bool initial=false}) async {
  t.view.physicalSize=const Size(390,1000);t.view.devicePixelRatio=1;
  addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(ProviderScope(child:MaterialApp(locale:const Locale('ar'),
    localizationsDelegates:AppLocalizations.localizationsDelegates,
    supportedLocales:AppLocalizations.supportedLocales,
    home:Scaffold(body:LocationSettingsFullBottomDrawer(
      business:Business.fromJson({'businessId':'branch-one','businessName':'الفرع الأول'}),
      api:LocationApi(initial),onboarding:requests,
      pickLocation:(_)async=>const MerchantLocation(31.93,44.46))))));
  await t.pumpAndSettle();
  final map=find.text('تعديل الموقع على الخريطة');await t.ensureVisible(map);
  await t.tap(map);await t.pumpAndSettle();
  final save=find.byIcon(Icons.save).last;await t.ensureVisible(save);
  await t.tap(save);await t.pumpAndSettle();
}
void main(){
  testWidgets('existing location explains required reason and visibly confirms review request',(t)async{
    final r=Requests();await open(t,r);
    await t.tap(find.text('إرسال للمراجعة'));await t.pumpAndSettle();
    expect(find.text('اكتب سبباً من خمسة أحرف على الأقل.'),findsOneWidget);
    expect(r.posts,isEmpty);
    await t.enterText(find.widgetWithText(TextFormField,'سبب تحديد أو تعديل الموقع'),'تصحيح نقطة الفرع');
    await t.tap(find.text('إرسال للمراجعة'));await t.pumpAndSettle();
    expect(r.posts.single['businessId'],'branch-one');
    expect(r.posts.single['proposed']['latitude'],31.93);
    expect(find.text('تم إرسال طلب تعديل الموقع للمراجعة. الموقع المحفوظ لم يتغير بعد.'),findsOneWidget);
    expect(t.takeException(),isNull);
  });
  testWidgets('first location uses initial wording and a truthful pending confirmation',(t)async{
    final r=Requests();await open(t,r,initial:true);
    expect((t.widget<AlertDialog>(find.byType(AlertDialog)).title as Text).data,'تحديد موقع الفرع لأول مرة');
    await t.tap(find.text('إرسال للمراجعة'));await t.pumpAndSettle();
    expect(r.posts.single['reason'],'تحديد موقع الفرع لأول مرة');
    expect(find.text('تم إرسال الموقع الأول للمراجعة. لم يُعتمد بعد.'),findsOneWidget);
    expect(t.takeException(),isNull);
  });
  testWidgets('failed request shows error and retry reuses request identity',(t)async{
    final r=Requests()..fail=true;await open(t,r,initial:true);
    await t.tap(find.text('إرسال للمراجعة'));await t.pumpAndSettle();
    expect(find.textContaining('لم يتم تأكيد الحفظ أو إرسال الطلب.'),findsOneWidget);
    final save=find.byIcon(Icons.save).last;await t.ensureVisible(save);await t.tap(save);await t.pumpAndSettle();
    r.fail=false;await t.tap(find.text('إرسال للمراجعة'));await t.pumpAndSettle();
    expect(r.posts.length,2);expect(r.posts[0]['requestId'],r.posts[1]['requestId']);
    expect(find.text('تم إرسال الموقع الأول للمراجعة. لم يُعتمد بعد.'),findsOneWidget);
  });
}
