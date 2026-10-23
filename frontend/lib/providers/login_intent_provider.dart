import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navigation preference only. Server membership remains the authority.
enum LoginIntent { owner, employee }

final loginIntentProvider = StateProvider<LoginIntent?>((ref) => null);
final savedLoginIntentProvider = FutureProvider<LoginIntent>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('merchant_login_intent') == 'employee'
        ? LoginIntent.employee
        : LoginIntent.owner;
  } catch (_) {
    return LoginIntent.owner;
  }
});

Future<void> selectLoginIntent(WidgetRef ref, LoginIntent intent) async {
  ref.read(loginIntentProvider.notifier).state = intent;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('merchant_login_intent', intent.name);
  } catch (_) {
    // Preference storage never grants access or blocks phone authentication.
  }
}
