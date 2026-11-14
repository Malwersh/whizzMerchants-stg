import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/branch_staff_screen.dart';
import '../lib/services/person_onboarding_service.dart';

class FakeStaffApi extends PersonOnboardingService {
  final requests = <Map<String, dynamic>>[];
  final bool owner;
  final bool central;
  FakeStaffApi(this.owner, {this.central = false});
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    if (body != null) {
      requests.add(body);
      return {'success': true};
    }
    if (path.contains('view=policy'))
      return {
        'policy': {
          'version': 4,
          'enabledPermissions': ['branch.read'],
          'roles': [
            {
              'id': 'custom_type',
              'enabled': true,
              'nameAr': 'نوع مركزي تجريبي',
              'permissions': ['branch.read']
            }
          ],
          'capabilities': [
            {
              'id': 'branch.read',
              'group': 'branch',
              'implemented': true,
              'delegable': true,
              'requires': []
            }
          ]
        }
      };
    if (owner)
      return {
        'permissionMode': central ? 'CENTRAL' : 'LEGACY',
        'invitations': [],
        'members': []
      };
    if (path.contains('view=memberships')) return {'items': []};
    return {
      'items': [
        {
          'businessId': 'b',
          'businessName': 'الفرع المدعو',
          'requestId': 'invitation-id',
          'version': 2,
          'role': 'MANAGER',
          'status': 'PENDING',
          'extraPermissions': []
        }
      ]
    };
  }
}

void main() {
  testWidgets('central mode removes fixed role and legacy invitation actions',
      (t) async {
    final api = FakeStaffApi(true, central: true);
    await t.pumpWidget(
        MaterialApp(home: BranchStaffScreen(businessId: 'b', service: api)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
        find.text('اختيار نوع الموظف وإرسال الدعوة'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('إنشاء الدعوة'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.text('أذونات إضافية'), findsNothing);
    expect(api.requests, isEmpty);
  });

  testWidgets(
      'owner custom invitation uses server type and explicit grant only',
      (t) async {
    final api = FakeStaffApi(true);
    await t.pumpWidget(
        MaterialApp(home: BranchStaffScreen(businessId: 'b', service: api)));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'هاتف الموظف'), '07811111111');
    await t.scrollUntilVisible(
        find.text('اختيار نوع الموظف وإرسال الدعوة'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await t.tap(find.text('اختيار نوع الموظف وإرسال الدعوة'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('نوع مركزي تجريبي').last);
    await t.pumpAndSettle();
    await t.tap(find.text('اعتماد النوع'));
    await t.pumpAndSettle();
    expect(api.requests.single['grant'],
        {'roleId': 'custom_type', 'expectedPolicyVersion': 4});
    expect(api.requests.single.containsKey('role'), false);
    expect(api.requests.single.containsKey('extraPermissions'), false);
  });

  testWidgets(
      'owner creates phone invitation with explicit branch and no guessed recipient identity',
      (t) async {
    final api = FakeStaffApi(true);
    await t.pumpWidget(
        MaterialApp(home: BranchStaffScreen(businessId: 'b', service: api)));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'هاتف الموظف'), '07811111111');
    await t.scrollUntilVisible(
        find.text('اختيار نوع الموظف وإرسال الدعوة'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await t.tap(find.text('اختيار نوع الموظف وإرسال الدعوة'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('نوع مركزي تجريبي').last);
    await t.pumpAndSettle();
    await t.tap(find.text('اعتماد النوع'));
    await t.pumpAndSettle();
    expect(api.requests.single['action'], 'invite');
    expect(api.requests.single['businessId'], 'b');
    expect(api.requests.single['phoneNumber'], '07811111111');
    expect(api.requests.single.containsKey('subjectId'), false);
    expect(api.requests.single['requestId'], isNotEmpty);
  });
  testWidgets(
      'employee accepts only server-returned invitation and version after confirmation',
      (t) async {
    final api = FakeStaffApi(false);
    await t.pumpWidget(MaterialApp(home: BranchStaffScreen(service: api)));
    await t.pumpAndSettle();
    expect(find.text('الفرع المدعو'), findsOneWidget);
    expect(find.text('إنشاء الدعوة'), findsNothing);
    await t.tap(find.text('قبول'));
    await t.pumpAndSettle();
    await t.tap(find.text('تأكيد'));
    await t.pumpAndSettle();
    expect(api.requests.single['action'], 'accept');
    expect(api.requests.single['requestId'], 'invitation-id');
    expect(api.requests.single['baseVersion'], 2);
    expect(find.byIcon(Icons.dashboard), findsNothing);
  });
  testWidgets('cancelled acceptance confirmation writes nothing', (t) async {
    final api = FakeStaffApi(false);
    await t.pumpWidget(MaterialApp(home: BranchStaffScreen(service: api)));
    await t.pumpAndSettle();
    await t.tap(find.text('قبول'));
    await t.pumpAndSettle();
    await t.tap(find.text('إلغاء'));
    await t.pumpAndSettle();
    expect(api.requests, isEmpty);
  });
}
