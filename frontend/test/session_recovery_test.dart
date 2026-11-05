import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:whizz_merchants/services/session_identity_loader.dart';
import 'package:whizz_merchants/services/secure_token_storage.dart';
import 'package:whizz_merchants/services/branch_session_store.dart';
import 'package:whizz_merchants/providers/auth_provider_riverpod.dart';

String jwt(String subject, {bool expired = false}) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'sub': subject,
          'token_use': 'access',
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 +
              (expired ? -3600 : 3600),
        })))}.signature';
http.Response identity(String subject) => http.Response(
    jsonEncode({
      'UserAttributes': [
        {'Name': 'sub', 'Value': subject},
        {'Name': 'email', 'Value': 'fixture@example.test'},
      ]
    }),
    200);
http.Response rejected() =>
    http.Response('{"__type":"NotAuthorizedException"}', 400);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stored credentials and same-person branch survive recreation',
      () async {
    await SecureTokenStorage.setAccessToken(jwt('owner'));
    await SecureTokenStorage.setIdToken(jwt('owner'));
    await SecureTokenStorage.setRefreshToken('saved-refresh');
    await BranchSessionStore().save('branch-a', {'businessId': 'branch-a'});
    final restored = await SessionIdentityLoader(
      readAccessToken: SecureTokenStorage.getAccessToken,
      refreshAccessToken: () async => throw StateError('Unnecessary refresh'),
      fetchUser: (_) async => identity('owner'),
      signOut: () async => fail('Unexpected sign-out'),
    ).load();
    expect(restored?['sub'], 'owner');
    expect((await BranchSessionStore().read()).businessId, 'branch-a');
    expect(await SecureTokenStorage.getRefreshToken(), 'saved-refresh');
  });

  test('expired access token refreshes before identity request', () async {
    final refreshed = jwt('owner');
    var refreshes = 0;
    final result = await SessionIdentityLoader(
      readAccessToken: () async => jwt('owner', expired: true),
      refreshAccessToken: () async {
        refreshes++;
        return refreshed;
      },
      fetchUser: (token) async {
        expect(token, refreshed);
        return identity('owner');
      },
      signOut: () async => fail('Unexpected sign-out'),
    ).load();
    expect(result?['sub'], 'owner');
    expect(refreshes, 1);
  });

  test('missing token mirror can recover from durable Amplify session',
      () async {
    final result = await SessionIdentityLoader(
      readAccessToken: () async => null,
      refreshAccessToken: () async => jwt('owner'),
      fetchUser: (_) async => identity('owner'),
      signOut: () async => fail('Unexpected sign-out'),
    ).load();
    expect(result?['sub'], 'owner');
  });

  test('network failure during rejected-token refresh preserves saved session',
      () async {
    await SecureTokenStorage.setRefreshToken('saved-refresh');
    final loader = SessionIdentityLoader(
      readAccessToken: () async => jwt('owner'),
      refreshAccessToken: () async => throw TimeoutException('offline'),
      fetchUser: (_) async => rejected(),
      signOut: () async => fail('Must retain credentials'),
    );
    await expectLater(loader.load(), throwsA(isA<TimeoutException>()));
    expect(await SecureTokenStorage.getRefreshToken(), 'saved-refresh');
  });

  test('identity service outage remains retryable without sign-out', () async {
    await expectLater(
        SessionIdentityLoader(
          readAccessToken: () async => jwt('owner'),
          refreshAccessToken: () async => null,
          fetchUser: (_) async =>
              http.Response('{"__type":"InternalErrorException"}', 500),
          signOut: () async => fail('Must not sign out on service outage'),
        ).load(),
        throwsStateError);
  });

  test('rejection after one successful refresh signs out, without retry loop',
      () async {
    var refreshes = 0, requests = 0, signOuts = 0;
    final result = await SessionIdentityLoader(
      readAccessToken: () async => jwt('owner'),
      refreshAccessToken: () async {
        refreshes++;
        return jwt('owner');
      },
      fetchUser: (_) async {
        requests++;
        return rejected();
      },
      signOut: () async {
        signOuts++;
      },
    ).load();
    expect(result, isNull);
    expect(refreshes, 1);
    expect(requests, 2);
    expect(signOuts, 1);
  });

  test('revoked refresh token clears credentials after explicit rejection',
      () async {
    await SecureTokenStorage.setRefreshToken('revoked');
    final result = await SessionIdentityLoader(
      readAccessToken: () async => jwt('owner'),
      refreshAccessToken: () async => null,
      fetchUser: (_) async => rejected(),
      signOut: SecureTokenStorage.clearAll,
    ).load();
    expect(result, isNull);
    expect(await SecureTokenStorage.getRefreshToken(), isNull);
  });

  test('deleted Cognito account cannot restore authentication', () async {
    var signedOut = false;
    final result = await SessionIdentityLoader(
      readAccessToken: () async => jwt('owner'),
      refreshAccessToken: () async => null,
      fetchUser: (_) async =>
          http.Response('{"__type":"UserNotFoundException"}', 400),
      signOut: () async {
        signedOut = true;
      },
    ).load();
    expect(result, isNull);
    expect(signedOut, true);
  });

  test(
      'startup network failure offers retry and successful retry restores identity',
      () async {
    var online = false;
    final auth = AuthNotifier(
        isSignedInAction: () async => true,
        currentUserAction: () async {
          if (!online) throw TimeoutException('offline');
          return {'sub': 'owner'};
        },
        onRestored: (_) async {},
        signOutAction: () async => fail('Unexpected cleanup'));
    addTearDown(auth.dispose);
    await auth.initialize();
    expect(auth.state.isAuthenticated, false);
    expect(auth.state.errorMessage, isNotNull);
    expect(auth.state.isLoading, false);
    online = true;
    await auth.initialize();
    expect(auth.state.isAuthenticated, true);
    expect(auth.state.errorMessage, isNull);
    expect(auth.state.currentUser?['sub'], 'owner');
  });

  test(
      'startup refresh network failure is retryable, not a logged-out decision',
      () async {
    final auth = AuthNotifier(
        isSignedInAction: () async => throw TimeoutException('offline'),
        currentUserAction: () async => fail('No identity before refresh'),
        onRestored: (_) async {});
    addTearDown(auth.dispose);
    await auth.initialize();
    expect(auth.state.errorMessage, isNotNull);
    expect(auth.state.isLoading, false);
  });

  test('late restore cannot revive authentication after logout', () async {
    final identity = Completer<Map<String, dynamic>?>();
    final auth = AuthNotifier(
        isSignedInAction: () async => true,
        currentUserAction: () => identity.future,
        onRestored: (_) async {},
        signOutAction: () async {});
    addTearDown(auth.dispose);
    final restoring = auth.initialize();
    await Future<void>.delayed(Duration.zero);
    await auth.signOut();
    identity.complete({'sub': 'old-owner'});
    await restoring;
    expect(auth.state.isAuthenticated, false);
    expect(auth.state.currentUser, isNull);
  });
}
