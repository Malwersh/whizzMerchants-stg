import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/widgets/circular_order_timer.dart';
void main(){
 testWidgets('display timer never expires an order from the phone',(tester)async{
  var rejected=0;final created=DateTime.now().subtract(const Duration(minutes:6));
  await tester.pumpWidget(MaterialApp(home:CircularOrderTimer(orderId:'o',createdAt:created,onAutoReject:(_)async{rejected++;})));
  await tester.pump(const Duration(seconds:2));expect(rejected,0);expect(find.text('00:00'),findsOneWidget);
  await tester.pumpWidget(const SizedBox.shrink());
 });
 testWidgets('absolute server deadline survives remounts',(tester)async{
  final created=DateTime.now().subtract(const Duration(minutes:4)),deadline=DateTime.now().add(const Duration(seconds:45));
  Widget timer()=>MaterialApp(home:CircularOrderTimer(orderId:'o',createdAt:created,deadlineAt:deadline));
  await tester.pumpWidget(timer());expect(find.textContaining('00:4'),findsOneWidget);
  await tester.pumpWidget(const SizedBox.shrink());await tester.pumpWidget(timer());expect(find.textContaining('00:4'),findsOneWidget);
  await tester.pumpWidget(const SizedBox.shrink());
 });
}
