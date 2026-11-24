import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/providers/auth_provider_riverpod.dart';
import 'package:whizz_merchants/providers/session_provider.dart';
import 'package:whizz_merchants/services/merchant_session_restore.dart';

String accessToken(int seconds) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + seconds,
    'sub': 'test-merchant',
    'token_use': 'access',
  })));
  return 'e30.$payload.test-signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unexpired saved token reopens the session after Cognito verifies it',
      () async {
    final token = accessToken(300);
    final user = await restoreMerchantSession(
      readAccessToken: () async => token,
      restoreAccessToken: ({required forceRefresh}) async =>
          throw StateError('Cognito session should not need a refresh.'),
      verifyUser: (value) async {
        expect(value, token);
        return {'sub': 'test-merchant'};
      },
    );
    expect(user?['sub'], 'test-merchant');
  });

  test('missing local copy can be recovered through the SDK', () async {
    final token = accessToken(300);
    final user = await restoreMerchantSession(
      readAccessToken: () async => null,
      restoreAccessToken: ({required forceRefresh}) async {
        expect(forceRefresh, false);
        return token;
      },
      verifyUser: (value) async {
        expect(value, token);
        return {'sub': 'test-merchant'};
      },
    );
    expect(user?['sub'], 'test-merchant');
  });

  test('expired or explicitly rejected tokens refresh before verification',
      () async {
    for (final original in [accessToken(-300), accessToken(180)]) {
      final fresh = accessToken(300);
      var didRefresh = false;
      final user = await restoreMerchantSession(
        readAccessToken: () async => original,
        restoreAccessToken: ({required forceRefresh}) async {
          expect(forceRefresh, true);
          didRefresh = true;
          return fresh;
        },
        verifyUser: (value) async =>
            value == fresh ? {'sub': 'test-merchant'} : null,
      );
      expect(didRefresh, true);
      expect(user?['sub'], 'test-merchant');
    }
  });

  test('network failure offers a retry and never opens protected screens',
      () async {
    var offline = true;
    var branchRestored = false;
    final notifier = AuthNotifier(
      restoreUser: () async {
        if (offline) throw TimeoutException('network');
        return {'sub': 'test-merchant'};
      },
      restoreBranch: () async => branchRestored = true,
    );
    addTearDown(notifier.dispose);
    await notifier.initialize();
    expect(notifier.state.isAuthenticated, false);
    expect(notifier.state.restorePending, true);
    expect(branchRestored, false);
    offline = false;
    await notifier.initialize();
    expect(notifier.state.isAuthenticated, true);
    expect(notifier.state.restorePending, false);
    expect(branchRestored, true);
  });

  test('a rejected session with no recovery returns to sign-in', () async {
    final user = await restoreMerchantSession(
      readAccessToken: () async => accessToken(600),
      restoreAccessToken: ({required forceRefresh}) async {
        expect(forceRefresh, true);
        return null;
      },
      verifyUser: (_) async => null,
    );
    expect(user, isNull);
  });

  test('logout wins over a late session restore', () async {
    final restored = Completer<Map<String, dynamic>?>();
    final notifier = AuthNotifier(
      restoreUser: () => restored.future,
      signOutAction: () async {},
    );
    addTearDown(notifier.dispose);
    final pending = notifier.initialize();
    await notifier.signOut();
    restored.complete({'sub': 'test-merchant'});
    await pending;
    expect(notifier.state.isAuthenticated, false);
    expect(notifier.state.restorePending, false);
  });

  test('an unreadable token copy does not erase a branch before recovery',
      () async {
    SharedPreferences.setMockInitialValues({
      'business_id': 'branch',
      'business_selection_subject': 'test-merchant',
    });
    FlutterSecureStorage.setMockInitialValues({});
    final notifier = SessionNotifier(restoreOnStart: false);
    addTearDown(notifier.dispose);
    await notifier.restoreBusinessId();
    expect(notifier.state.isAuthenticated, false);
    expect(notifier.state.businessId, isNull);
    expect((await SharedPreferences.getInstance()).getString('business_id'),
        'branch');

    FlutterSecureStorage.setMockInitialValues(
        {'secure_access_token': accessToken(300)});
    await notifier.restoreBusinessId();
    expect(notifier.state.isAuthenticated, true);
    expect(notifier.state.businessId, 'branch');
  });
}
