import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/order_alert_cadence.dart';
void main() {
  test('push socket and polling cannot produce adjacent sounds or early reminders', () {
    var now = DateTime.utc(2026,10,19);
    final cadence = OrderAlertCadence(now:()=>now);
    expect(cadence.reserve(const Duration(seconds:3)),true);
    expect(cadence.reserve(const Duration(seconds:3)),false);
    now=now.add(const Duration(seconds:2));
    expect(cadence.reserve(const Duration(seconds:3)),false);
    expect(cadence.ready(const Duration(seconds:45)),false);
    now=now.add(const Duration(seconds:43));
    expect(cadence.ready(const Duration(seconds:45)),true);
    expect(cadence.reserve(const Duration(seconds:3)),true);
    expect(cadence.ready(const Duration(seconds:45)),false);
  });
}
