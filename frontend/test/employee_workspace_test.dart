import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/employee_home_screen.dart';
import '../lib/services/person_onboarding_service.dart';

class WorkspaceApi extends PersonOnboardingService {
  final paths = <String>[];
  bool accepted = false;
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    paths.add(path);
    if (body != null) {
      if (body['action'] == 'accept') accepted = true;
      return {'success': true};
    }
    if (path == 'branch-staff?view=invitations')
      return {
        'items': accepted
            ? []
            : [
                {
                  'businessId': 'delegated-branch',
                  'businessName': 'فتوش',
                  'requestId': 'invite',
                  'version': 1,
                  'role': 'MANAGER',
                  'status': 'PENDING'
                }
              ]
      };
    if (path == 'branch-staff?view=memberships')
      return {
        'items': !accepted
            ? []
            : [
                {
                  'businessId': 'delegated-branch',
                  'businessName': 'فتوش',
                  'subjectId': 'employee',
                  'role': 'MANAGER',
                  'status': 'ACTIVE',
                  'version': 1,
                  'operationalAccessReady': false
                }
              ]
      };
    throw StateError('Employee workspace requested an owner endpoint: $path');
  }
}

void main() {
  testWidgets(
      'acceptance stays in employee workspace and never loads owned businesses',
      (t) async {
    final api = WorkspaceApi();
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(home: EmployeeHomeScreen(service: api))));
    await t.pumpAndSettle();
    expect(find.text('مساحة الموظف'), findsOneWidget);
    expect(find.text('مساحة أنشطتي'), findsNothing);
    expect(find.text('إضافة نشاط أو فرع'), findsNothing);
    await t.tap(find.text('قبول'));
    await t.pumpAndSettle();
    await t.tap(find.text('تأكيد'));
    await t.pumpAndSettle();
    expect(find.text('مساحة الموظف'), findsOneWidget);
    expect(find.text('فتوش'), findsOneWidget);
    expect(find.text('الفروع المفوضة لي'), findsOneWidget);
    expect(find.text('مغادرة الفرع'), findsOneWidget);
    expect(find.byTooltip('تسجيل الخروج'), findsOneWidget);
    expect(
        api.paths.every(
            (p) => p == 'branch-staff' || p.startsWith('branch-staff?view=')),
        true);
    expect(find.byIcon(Icons.dashboard), findsNothing);
    expect(t.takeException(), isNull);
  });
}
