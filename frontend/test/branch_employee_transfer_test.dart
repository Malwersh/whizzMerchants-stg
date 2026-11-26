import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/branch_employee_access.dart';
import 'package:whizz_merchants/services/branch_device_service.dart';
import 'package:whizz_merchants/services/branch_employee_transfer_service.dart';
import 'package:whizz_merchants/services/wallet_transfer_service.dart';
import 'package:whizz_merchants/screens/branch_employee_transfer_screen.dart';

BranchEmployeeAccess access(
        {String session = 'session', bool allowed = true}) =>
    BranchEmployeeAccess(
        api: BranchDeviceService(),
        token: 'branch:device:secret',
        session: session,
        businessId: 'branch',
        profile: {
          'staff': {'subjectId': 'employee'},
          'capabilities': {'transferFunds': allowed}
        },
        lock: () async {});
void main() {
  test(
      'server authorization rejection ends financial access while OTP step-up remains available',
      () async {
    final a = access();
    final denied = BranchEmployeeTransferService(
        expected: a,
        current: () => a,
        client: MockClient(
            (_) async => http.Response('{"message":"Unauthorized"}', 401)));
    await expectLater(
        denied.call('context'), throwsA(isA<WalletTransferException>()));
    expect(denied.check, throwsA(isA<WalletTransferException>()));
    final stepUp = BranchEmployeeTransferService(
        expected: a,
        current: () => a,
        client: MockClient((_) async => http.Response(
            '{"error":{"code":"REAUTH_REQUIRED","message":"OTP"}}', 403)));
    await expectLater(stepUp.call('request', body: {}),
        throwsA(isA<WalletTransferException>()));
    expect(stepUp.check, returnsNormally);
  });

  testWidgets(
      'resuming an uncertain transfer obtains employee OTP and keeps the same attempt through final acknowledgement',
      (t) async {
    final a = access();
    const key = 'branch_transfer_branch_device_employee';
    final intent = {
      'requestId': '00000000-0000-4000-8000-000000000001',
      'recipientWalletId': 'WALLET#DRIVER#other',
      'amount': 5000,
      'reason': 'اختبار التحويل'
    };
    FlutterSecureStorage.setMockInitialValues({key: jsonEncode(intent)});
    final posts = <Map<String, dynamic>>[];
    final api = BranchEmployeeTransferService(
        expected: a,
        current: () => a,
        client: MockClient((r) async {
          final action = r.url.path.split('/transfers/').last;
          if (r.method == 'POST') {
            final body = Map<String, dynamic>.from(jsonDecode(r.body));
            posts.add({'action': action, ...body});
            if (action == 'request' && body['verificationId'] == null) {
              return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'REAUTH_REQUIRED',
                      'message': 'تحقق مطلوب'
                    }
                  }),
                  403,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }
          }
          final data = switch (action) {
            'context' => {'available': 10000, 'dailyRemaining': 10000},
            'status' => {'status': 'NOT_FOUND'},
            'otp/send' => {
                'challengeId': 'challenge',
                'phoneHint': '••••1234',
                'resendAfter': 60
              },
            'otp/verify' => {'verificationId': 'verified-proof'},
            _ => {'status': 'COMPLETED'}
          };
          return http.Response(jsonEncode({'data': data}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await t.pumpWidget(MaterialApp(
        home: BranchEmployeeTransferScreen(
            initial: a, access: () => a, service: api)));
    await t.pumpAndSettle();
    await t.tap(find.text('التحقق بنفس المرجع والمتابعة'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(posts.map((p) => p['action']).toList(), ['request', 'otp/send'],
        reason: t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    expect(find.text('تأكيد التحويل برمز الهاتف'), findsOneWidget);
    await t.enterText(
        find.byKey(const Key('transfer_confirmation_code')), '123456');
    await t.tap(find.text('تأكيد وإكمال التحويل'));
    await t.pumpAndSettle();
    expect(posts.map((p) => p['action']).toList(),
        ['request', 'otp/send', 'otp/verify', 'request']);
    expect(posts.every((p) => p['requestId'] == intent['requestId']), true);
    expect(posts.last['verificationId'], 'verified-proof');
    expect(posts.last.containsKey('code'), false);
    expect(await const FlutterSecureStorage().read(key: key), isNull);
    expect(find.text('اكتمل التحويل.'), findsOneWidget);
  });
  testWidgets(
      'an uncertain cancellation preserves its attempt until server confirmation and never claims a completed transfer was cancelled',
      (t) async {
    final a = access();
    const key = 'branch_transfer_branch_device_employee';
    FlutterSecureStorage.setMockInitialValues({
      key: jsonEncode({
        'requestId': 'original',
        'recipientWalletId': 'WALLET#DRIVER#other',
        'amount': 5000,
        'reason': 'اختبار'
      })
    });
    int cancels = 0;
    final api = BranchEmployeeTransferService(
        expected: a,
        current: () => a,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/cancel')) {
            cancels++;
            if (cancels == 1) throw TimeoutException('synthetic timeout');
            return http.Response('{"data":{"status":"COMPLETED"}}', 200);
          }
          return http.Response(
              '{"data":{"available":10000,"dailyRemaining":10000}}', 200);
        }));
    await t.pumpWidget(MaterialApp(
        home: BranchEmployeeTransferScreen(
            initial: a, access: () => a, service: api)));
    await t.pumpAndSettle();
    await t.tap(find.text('إلغاء المحاولة إن لم تنفّذ'));
    await t.pumpAndSettle();
    expect(await const FlutterSecureStorage().read(key: key), isNotNull);
    await t.tap(find.text('إلغاء المحاولة إن لم تنفّذ'));
    await t.pumpAndSettle();
    expect(await const FlutterSecureStorage().read(key: key), isNull);
    expect(find.textContaining('التحويل نُفذ بالفعل'), findsOneWidget);
    expect(find.text('أُلغيت المحاولة دون خصم.'), findsNothing);
  });

  test(
      'transfer transport uses device/session only and rejects unsupported methods',
      () async {
    final a = access();
    final requests = <http.Request>[];
    final api = BranchEmployeeTransferService(
        expected: a,
        current: () => a,
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
              jsonEncode({
                'data': {'status': 'NOT_FOUND'}
              }),
              200);
        }));
    await api.call('status', query: {'requestId': 'attempt'});
    expect(requests.single.headers['Authorization'],
        'Bearer branch:device:secret');
    expect(requests.single.headers['X-Staff-Session'], 'session');
    expect(requests.single.url.path,
        '/staging/wallet/branch-device/transfers/status');
    expect(requests.single.url.queryParameters, {'requestId': 'attempt'});
    await expectLater(
        api.call('request'), throwsA(isA<WalletTransferException>()));
    expect(requests.length, 1);
  });
  test(
      'revoked or replaced session prevents sending and discards delayed responses',
      () async {
    final a = access();
    BranchEmployeeAccess? current = a;
    final pending = Completer<http.Response>();
    int calls = 0;
    final api = BranchEmployeeTransferService(
        expected: a,
        current: () => current,
        client: MockClient((r) {
          calls++;
          return pending.future;
        }));
    final request = api.call('context');
    await Future<void>.delayed(Duration.zero);
    current = access(session: 'other');
    pending.complete(http.Response('{"data":{"available":5000}}', 200));
    await expectLater(request, throwsA(isA<WalletTransferException>()));
    await expectLater(
        api.call('context'), throwsA(isA<WalletTransferException>()));
    expect(calls, 1);
  });
  testWidgets(
      'uncertain attempt is restored only from the same device/person scope and checked with its original reference',
      (t) async {
    final a = access();
    const key = 'branch_transfer_branch_device_employee';
    FlutterSecureStorage.setMockInitialValues({
      key: jsonEncode({
        'requestId': 'attempt-original',
        'recipientWalletId': 'WALLET#DRIVER#other',
        'amount': 5000,
        'reason': 'اختبار'
      })
    });
    final requests = <http.Request>[];
    final api = BranchEmployeeTransferService(
        expected: a,
        current: () => a,
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
              jsonEncode({
                'data': r.url.path.endsWith('/context')
                    ? {
                        'walletId': 'WALLET#MERCHANT#branch',
                        'available': 10000,
                        'dailyRemaining': 10000,
                        'minAmount': 1000,
                        'maxAmount': 10000,
                        'canTransfer': true
                      }
                    : {'status': 'COMPLETED'}
              }),
              200);
        }));
    await t.pumpWidget(MaterialApp(
        home: BranchEmployeeTransferScreen(
            initial: a, access: () => a, service: api)));
    await t.pumpAndSettle();
    expect(find.textContaining('attempt-original'), findsOneWidget);
    await t.tap(find.text('التحقق بنفس المرجع والمتابعة'));
    await t.pumpAndSettle();
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(requests.last.url.queryParameters['requestId'], 'attempt-original');
    expect(await const FlutterSecureStorage().read(key: key), isNull);
    expect(find.text('اكتمل التحويل.'), findsOneWidget);
  });
  testWidgets(
      'another employee cannot restore the previous employee transfer details',
      (t) async {
    FlutterSecureStorage.setMockInitialValues({
      'branch_transfer_branch_device_someone-else':
          jsonEncode({'requestId': 'private-attempt', 'amount': 9999})
    });
    final a = access();
    final api = BranchEmployeeTransferService(
        expected: a,
        current: () => a,
        client: MockClient((r) async => http.Response(
            jsonEncode({
              'data': {'available': 10000, 'dailyRemaining': 10000}
            }),
            200)));
    await t.pumpWidget(MaterialApp(
        home: BranchEmployeeTransferScreen(
            initial: a, access: () => a, service: api)));
    await t.pumpAndSettle();
    expect(find.textContaining('private-attempt'), findsNothing);
    expect(find.textContaining('9999'), findsNothing);
  });
}
