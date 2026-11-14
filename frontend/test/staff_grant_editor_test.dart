import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/screens/staff_grant_editor.dart';

Map<String, dynamic> policy({bool enabled = true}) => {
      'version': 7,
      'enabledPermissions': enabled ? ['branch.read'] : [],
      'roles': [
        {
          'id': 'operational',
          'nameAr': 'موظف تشغيلي',
          'description':
              'قبول الطلبات ورفضها وتحديث حالاتها دون تعديل المنتجات.',
          'enabled': true,
          'permissions': ['branch.read']
        }
      ],
      'capabilities': [
        {'id': 'branch.read', 'implemented': true, 'delegable': true}
      ],
    };
void main() {
  testWidgets(
      'owner chooses a central job type; server receives no permission selection',
      (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => StaffGrantEditor(
                              policy: policy(),
                              initialGrant: {'roleId': 'operational'}));
                    },
                    child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.textContaining('قبول الطلبات ورفضها'), findsOneWidget);
    await tester.tap(find.text('اعتماد النوع'));
    await tester.pumpAndSettle();
    expect(result, {'roleId': 'operational', 'expectedPolicyVersion': 7});
  });
  testWidgets('no type is selected implicitly', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: StaffGrantEditor(policy: policy())));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'اعتماد النوع'))
            .onPressed,
        isNull);
  });
  testWidgets('blocked or incomplete job package cannot be assigned',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: StaffGrantEditor(
            policy: policy(enabled: false),
            initialGrant: {'roleId': 'operational'})));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.textContaining('غير جاهز للتعيين'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'اعتماد النوع'))
            .onPressed,
        isNull);
  });
}
