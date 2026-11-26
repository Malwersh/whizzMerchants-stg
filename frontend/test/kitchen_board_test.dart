import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/order.dart';
import 'package:whizz_merchants/widgets/kitchen_board.dart';

Order ticket(OrderStatus status, {Map<String,dynamic>? cancellation, Map<String,dynamic>? handover}) => Order(
 id:'ORD1',businessId:'branch',customerId:'c',customerName:'Private customer',
 items:[OrderItem(id:'p',name:'بيتزا',price:8000,quantity:2,modifiers:['كبير'],notes:'بدون بصل')],
 totalAmount:16000,deliveryFee:1500,status:status,createdAt:DateTime.now(),
 exceptionCancellation:cancellation,merchantHandover:handover);
Widget board(List<Order> orders, {bool allowed=true, Future<void> Function(String,OrderStatus)? update}) => MaterialApp(home: KitchenBoard(
 orders:orders,loading:false,canUpdate:(_)=>allowed,update:update ?? (_,__) async {},close:(){},refresh:() async {}));
void main(){
 test('only kitchen stages remain, delivered and handed over leave board',(){
  expect(kitchenStage(ticket(OrderStatus.confirmed)),0);
  expect(kitchenStage(ticket(OrderStatus.preparing)),1);
  expect(kitchenStage(ticket(OrderStatus.arrivedAtStore)),2);
  for(final status in [OrderStatus.pending,OrderStatus.cancelled,OrderStatus.expired,OrderStatus.pickedUp,OrderStatus.delivered]) {
   expect(kitchenStage(ticket(status)),isNull);
  }
  expect(kitchenStage(ticket(OrderStatus.readyForPickup,handover:{'state':'HANDED_TO_DRIVER'})),isNull);
 });
 testWidgets('ticket includes modifiers, no financial or customer data, prevents duplicate action',(tester) async {
  final done=Completer<void>(); int calls=0;
  await tester.pumpWidget(board([ticket(OrderStatus.confirmed)],update:(_,status){calls++;expect(status,OrderStatus.preparing);return done.future;}));
  expect(find.text('كبير'),findsNothing); // modifiers have a bullet
  expect(find.text('• كبير'),findsOneWidget);
  expect(find.text('بدون بصل'),findsOneWidget);
  expect(find.textContaining('16000'),findsNothing);
  expect(find.textContaining('Private customer'),findsNothing);
  await tester.tap(find.text('بدء التحضير')); await tester.pump();
  expect(find.text('جارٍ التحديث…'),findsOneWidget);expect(calls,1);
  done.complete();await tester.pumpAndSettle();
 });
 testWidgets('review blocks preparation and cancellation snapshot removes card',(tester) async {
  await tester.pumpWidget(board([ticket(OrderStatus.confirmed,cancellation:{'state':'REQUESTED'})]));
  expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
  await tester.pumpWidget(board([ticket(OrderStatus.cancelled)]));await tester.pump();
  expect(find.text('ORD1'),findsNothing);
 });
 testWidgets('employee permission enforced in UI',(tester) async {
  await tester.pumpWidget(board([ticket(OrderStatus.confirmed)],allowed:false));
  expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);
 });
 testWidgets('wide screen shows all three stages without overflow',(tester) async {
  tester.view.physicalSize=const Size(1200,800);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(board([ticket(OrderStatus.confirmed),ticket(OrderStatus.preparing),ticket(OrderStatus.readyForPickup)]));
  expect(find.text('ORD1'),findsNWidgets(3));expect(tester.takeException(),isNull);
 });
}
