import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/screens/order_cancellation_screen.dart';
import 'package:whizz_merchants/screens/order_return_screen.dart';
import 'package:whizz_merchants/services/order_returns_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('confirmed return displays independent pending merchant compensation case', (tester) async {
    final service=OrderReturnsService(token:() async=>'local-owner',client:MockClient((_) async=>http.Response(jsonEncode({'success':true,'orderId':'order1','status':'CONFIRMED','resolution':{'caseId':'OEX:case1','status':'SETTLEMENT_PENDING','nextStep':'تقييم مستحق المطعم وفق الاتفاقية والأدلة'}}),200,headers:{'content-type':'application/json; charset=utf-8'})));
    await tester.pumpWidget(MaterialApp(home:OrderReturnScreen(selectors:{'businessId':'branch1','orderId':'order1','offerId':'offer1','attempt':1},service:service)));
    await tester.pumpAndSettle();
    expect(find.text('قضية الاستثناء والمستحقات'),findsOneWidget);
    expect(find.text('مرجع القضية: OEX:case1'),findsOneWidget);
    expect(find.text('تأكيد استلام الأصناف ينهي العهدة ولا يعني اعتماد تعويض المطعم أو صرفه.'),findsOneWidget);
    expect(find.text('مراجعة وتأكيد الاستلام'),findsNothing);
  });
  testWidgets('damaged full receipt distinguishes completed driver task and held guarantee from partial custody', (tester) async {
    for (final state in [
      {'taskCompleted':true,'holdStatus':'ACTIVE','text':'استلمت الأصناف وانتهت مهمة الإرجاع؛ الحالة والضمان والحقوق قيد المراجعة'},
      {'taskCompleted':true,'holdStatus':'RELEASED','text':'انتهت مهمة الإرجاع وحُرر الضمان؛ مراجعة الحقوق مستمرة'},
      {'taskCompleted':false,'holdStatus':'ACTIVE','text':'الاستلام الجزئي أو العهدة قيد المراجعة؛ تواصل مع الدعم'},
    ]) {
      var writes=0;
      final service=OrderReturnsService(token:()async=>'owner',client:MockClient((request)async {
        if(request.method=='POST')writes++;
        return http.Response(jsonEncode({'success':true,'orderId':'order1','status':'REVIEW_REQUIRED','taskCompleted':state['taskCompleted'],'holdStatus':state['holdStatus']}),200,headers:{'content-type':'application/json; charset=utf-8'});
      }));
      await tester.pumpWidget(MaterialApp(home:OrderReturnScreen(key:UniqueKey(),selectors:{'businessId':'branch1','orderId':'order1','offerId':'offer1','attempt':1},service:service)));
      await tester.pumpAndSettle();expect(find.text(state['text'] as String),findsOneWidget);expect(find.text('مراجعة وتأكيد الاستلام'),findsNothing);expect(writes,0);
      await tester.pumpWidget(const SizedBox());
    }
  });
  test('default return credentials use scoped access token when ID token also exists', () async {
    String jwt(String use) => 'offline.${base64Url.encode(utf8.encode(jsonEncode({'token_use':use,'exp':DateTime.now().add(const Duration(hours:1)).millisecondsSinceEpoch~/1000}))).replaceAll('=', '')}.local';
    final access=jwt('access'), identity=jwt('id');
    FlutterSecureStorage.setMockInitialValues({'secure_access_token':access,'secure_id_token':identity});
    final requests=<http.Request>[];
    final service=OrderReturnsService(client:MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'],'Bearer $access');
      expect(request.headers['Authorization'],isNot('Bearer $identity'));
      return http.Response('{"success":true,"orderId":"order1"}',200);
    }));
    final scope={'businessId':'branch1','orderId':'order1','offerId':'offer1','attempt':1};
    await service.call(scope);
    await service.call(scope,receipt:{'expectedVersion':2});
    expect(requests.map((r)=>r.method),['GET','POST']);
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('branch readiness is separate from receipt and does not claim authorization',(tester)async{
   var posted=0,ready=false;
   final service=OrderReturnsService(token:()async=>'owner-access',client:MockClient((r)async{
    if(r.method=='POST'){posted++;final v=jsonDecode(r.body);expect(v['branchCanReceive'],true);expect(v['expectedVersion'],1);expect(v.containsKey('allItemsReceived'),false);ready=true;return http.Response(jsonEncode({'success':true,'orderId':'order1'}),200);}
    return http.Response(jsonEncode({'success':true,'orderId':'order1','status':'REQUESTED','returnId':'ret1','version':ready?2:1,if(ready)'branchReadiness':{'branchCanReceive':true}}),200,headers:{'content-type':'application/json; charset=utf-8'});
   }));
   await tester.pumpWidget(MaterialApp(home:OrderReturnScreen(selectors:{'businessId':'branch1','orderId':'order1','offerId':'offer1','attempt':1},service:service)));await tester.pumpAndSettle();
   expect(find.text('مراجعة وتأكيد الاستلام'),findsNothing);expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
   await tester.enterText(find.byType(TextField),'الفرع جاهز لاستقبال الأصناف');await tester.tap(find.byType(CheckboxListTile));await tester.pumpAndSettle();await tester.ensureVisible(find.byType(FilledButton));await tester.tap(find.byType(FilledButton));await tester.pumpAndSettle();await tester.drag(find.byType(ListView),const Offset(0,900));await tester.pumpAndSettle();
   expect(posted,1);expect(find.text('سُجل استعداد الفرع للاستقبال؛ لم يصدر تصريح العودة بعد.'),findsOneWidget);await tester.pumpWidget(const SizedBox());
  });
  final selectors = {
    'businessId': 'branch1',
    'orderId': 'order1',
    'offerId': 'offer1',
    'attempt': 1
  };
  test(
      'return receipt transmits exact version and rejects stale session replies',
      () async {
    String? token = 'owner1';
    final service = OrderReturnsService(
        token: () async => token,
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/auth/order-returns'));
          expect(request.body, contains('"expectedVersion":2'));
          expect(request.body, contains('"attempt":1'));
          token = 'other';
          return http.Response('{"success":true,"orderId":"order1"}', 200);
        }));
    await expectLater(service.call(selectors, receipt: {'expectedVersion': 2}),
        throwsException);
  });
  test('return states remain distinct from delivered and terminal returned',
      () {
    for (final entry in {
      'returning': OrderStatus.returning,
      'return_arrived': OrderStatus.returnArrived,
      'returned': OrderStatus.returned
    }.entries) {
      final order = Order.fromJson({
        'orderId': 'order1',
        'businessId': 'branch1',
        'items': [],
        'status': entry.key,
        'financialAssignment': {'offerId': 'offer1', 'attempt': 1}
      });
      expect(order.status, entry.value);
      expect(order.copyWith().financialAssignment?['attempt'], 1);
      expect(order.toJson()['financialAssignment'], isNotNull);
    }
  });
  testWidgets(
      'cancellation requires custody and no-cash declarations and explicit final confirmation',
      (tester) async {
    int calls = 0;
    final service = OrderReturnsService(
        token: () async => 'owner1',
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, endsWith('/auth/order-cancellation'));
          expect(r.body, contains('"goodsRetainedByBranch":true'));
          return http.Response('{"success":true,"orderId":"order1"}', 200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: OrderCancellationScreen(selectors: selectors, service: service)));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    for (final checkbox in find.byType(CheckboxListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(checkbox.widget));
      await tester.pump();
    }
    await tester.tap(find.text('مراجعة الإلغاء'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('تأكيد الإلغاء'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('أكد الخادم إلغاء الطلب وتحرير الحجز'), findsOneWidget);
  });
  testWidgets(
      'owner receipt requires all explicit choices and sends the displayed case version',
      (tester) async {
    bool confirmed = false;
    int writes = 0;
    final service = OrderReturnsService(
        token: () async => 'owner1',
        client: MockClient((r) async {
          if (r.method == 'POST') {
            writes++;
            expect(r.body, contains('"expectedVersion":2'));
            expect(r.body, contains('"allItemsReceived":true'));
            confirmed = true;
            return http.Response('{"success":true,"orderId":"order1"}', 200);
          }
          return http.Response(
              '{"success":true,"orderId":"order1","returnId":"ret1","version":2,"status":"${confirmed ? 'CONFIRMED' : 'ARRIVED_AT_BRANCH'}"}',
              200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: OrderReturnScreen(selectors: selectors, service: service)));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester
        .tap(find.byWidgetPredicate((w) => w is DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نعم، جميع الأصناف').last);
    await tester.pumpAndSettle();
    final fields =
        find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>);
    await tester.tap(fields.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('سليمة').last);
    await tester.pumpAndSettle();
    await tester.tap(fields.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('لا توجد ملاحظة على السائق').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('مراجعة وتأكيد الاستلام'));
    await tester.tap(find.text('مراجعة وتأكيد الاستلام'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('تأكيد الإقرار'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('تم تأكيد الاستلام وانتهت العودة'), findsOneWidget);
  });
  testWidgets('owner opts into automatic returns only after explicit confirmation and server acknowledgement',(tester)async{
    var enabled=false;final writes=<Map<String,dynamic>>[];
    final service=OrderReturnsService(token:()async=>'local-owner',client:MockClient((r)async{if(r.method=='POST'){final v=jsonDecode(r.body) as Map<String,dynamic>;writes.add(v);enabled=v['automaticReturnAcceptance']==true;}return http.Response(jsonEncode({'success':true,'orderId':'order1','status':'ARRIVED_AT_BRANCH','version':4,'automaticReturnAcceptance':{'enabled':enabled}}),200,headers:{'content-type':'application/json; charset=utf-8'});}));
    await tester.pumpWidget(MaterialApp(home:OrderReturnScreen(selectors:{'businessId':'branch1','orderId':'order1','offerId':'offer1','attempt':1},service:service)));
    await tester.pumpAndSettle();await tester.tap(find.byType(SwitchListTile));await tester.pumpAndSettle();expect(writes,isEmpty);await tester.tap(find.text('تأكيد'));await tester.pumpAndSettle();expect(writes.single['automaticReturnAcceptance'],true);expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,true);await tester.pumpWidget(const SizedBox());
  });

}
