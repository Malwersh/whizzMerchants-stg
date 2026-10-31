import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/audio_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('background announcement persists and the same order is recognized once',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect(
        await AudioNotificationService.markOrderSoundAnnounced(
            'unique-background-order'),
        false);
    expect(
        await AudioNotificationService.markOrderSoundAnnounced(
            'unique-background-order'),
        true);
    final prefs = await SharedPreferences.getInstance();
    final history =
        jsonDecode(prefs.getString('merchant_order_sound_history_v1')!);
    expect(history.containsKey('unique-background-order'), true);
  });
  test('expired announcement history is pruned', () async {
    SharedPreferences.setMockInitialValues({
      'merchant_order_sound_history_v1': jsonEncode(
          {'old-order': DateTime.now().millisecondsSinceEpoch - 7200000})
    });
    expect(await AudioNotificationService.markOrderSoundAnnounced('old-order'),
        false);
  });
}
