import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/screens/merchant_branch_draft_screen.dart';
import 'package:whizz_merchants/services/onboarding_config_service.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';

class FixtureApi extends PersonOnboardingService {
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    if (path == 'onboarding-regions')
      return {
        'items': [
          for (var i = 0; i < 4; i++)
            {
              'id': 'a$i',
              'parentId': i == 0 ? null : 'a${i - 1}',
              'level': i,
              'labelAr': [
                'العراق',
                'النجف',
                'قضاء المناذرة',
                'المناذرة المركز'
              ][i]
            },
          {'id': 'b0', 'parentId': null, 'level': 0, 'labelAr': 'بلد ثان'},
          {'id': 'b1', 'parentId': 'b0', 'level': 1, 'labelAr': 'محافظة أخرى'}
        ]
      };
    if (path == 'branch-drafts' && body == null) return {'items': []};
    saved = body;
    return {
      'draft': {...body!, 'version': 3, 'reviewStatus': 'DRAFT'}
    };
  }
}

void main() {
  testWidgets(
      'changing a country clears dependent regions and stale GPS before draft save',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FixtureApi(),
        config = OnboardingConfigService(
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'configVersion': 'v1',
                  'version': 1,
                  'termsVersion': 'agreement',
                  'termsTextAr': 'fixture agreement',
                  'types': [
                    {
                      'id': 'MARKET',
                      'labelAr': 'أسواق',
                      'labelEn': 'Market',
                      'model': 'RETAIL',
                      'fields': []
                    }
                  ]
                }),
                200)));
    await tester.pumpWidget(MaterialApp(
        home: MerchantBranchDraftScreen(
            service: api,
            configService: config,
            draft: {
          'draftId': '11111111-1111-4111-8111-111111111111',
          'version': 2,
          'name': 'Fixture',
          'businessTypeId': 'MARKET',
          'regionPath': ['a0', 'a1', 'a2', 'a3'],
          'latitude': 31.9,
          'longitude': 44.4,
          'reviewStatus': 'DRAFT'
        })));
    await tester.pumpAndSettle();
    expect(find.text('النجف'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('بلد ثان').last);
    await tester.pumpAndSettle();
    expect(find.text('النجف'), findsNothing);
    expect(find.text('قضاء المناذرة'), findsNothing);
    final latitude = tester.widget<TextField>(find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'خط العرض'));
    expect(latitude.controller!.text, isEmpty);
    await tester.ensureVisible(find.text('حفظ المسودة'));
    await tester.tap(find.text('حفظ المسودة'));
    await tester.pumpAndSettle();
    expect(api.saved!['regionPath'], ['b0']);
    expect(api.saved!['latitude'], isNull);
    expect(api.saved!['longitude'], isNull);
  });
  testWidgets(
      'removing a private certificate explicitly clears its backend reference',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FixtureApi(),
        config = OnboardingConfigService(
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'configVersion': 'v1',
                  'version': 1,
                  'termsVersion': 'agreement',
                  'termsTextAr': 'fixture agreement',
                  'types': [
                    {
                      'id': 'MARKET',
                      'labelAr': 'أسواق',
                      'labelEn': 'Market',
                      'model': 'RETAIL',
                      'fields': []
                    }
                  ]
                }),
                200)));
    await tester.pumpWidget(MaterialApp(
        home: MerchantBranchDraftScreen(
            service: api,
            configService: config,
            draft: {
          'draftId': '11111111-1111-4111-8111-111111111111',
          'version': 2,
          'name': 'Fixture',
          'businessTypeId': 'MARKET',
          'registrationCertificateAssetId':
              '22222222-2222-4222-8222-222222222222',
          'reviewStatus': 'DRAFT'
        })));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('إزالة المرفق'));
    await tester.tap(find.text('إزالة المرفق'));
    await tester.pumpAndSettle();
    expect(api.saved!.containsKey('registrationCertificateAssetId'), isTrue);
    expect(api.saved!['registrationCertificateAssetId'], isNull);
    expect(find.text('عرض المرفق'), findsNothing);
  });
}
