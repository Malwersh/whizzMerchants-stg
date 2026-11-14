import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/support_chat_service.dart';
import 'helpers/support_chat_fixture.dart';

void main() {
  testWidgets('explicit retry retains receipt and attachment identity',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    await f.service.sendMessage('مرة واحدة');
    final sent = f.channels.single.sent.last;
    await tester.pump(const Duration(seconds: 16));
    expect(f.service.retryMessage(sent['clientMessageId']), true);
    expect(f.channels.single.sent.last['clientMessageId'],
        sent['clientMessageId']);
    expect(f.service.messages.where((m) => m.senderType == 'merchant'),
        hasLength(1));
    f.service.dispose();
  });
  testWidgets(
      'old history page and error cannot replace current requested page',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    final first = f.channels.single.sent.last;
    await tester.pump(const Duration(seconds: 16));
    f.service.loadHistory();
    f.channels.single.receive({
      'type': 'session_messages',
      'sessionId': f.service.sessionId,
      'requestId': first['requestId'],
      'messages': [],
      'nextCursor': 'stale'
    });
    expect(f.service.historyLoading, true);
    expect(f.service.nextCursor, isNull);
    f.channels.single.receive({
      'type': 'history_error',
      'sessionId': f.service.sessionId,
      'requestId': first['requestId']
    });
    expect(f.service.historyError, isNull);
    f.service.dispose();
  });
  testWidgets(
      'sign-out invalidation clears old branch transcript and blocks late ACK',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    await f.service.sendMessage('خاصة');
    f.service.invalidateIdentity();
    expect(f.service.messages, isEmpty);
    expect(f.service.sessionId, isNull);
    expect(f.service.isConnected, false);
    expect(f.channels.single.input.isClosed, true);
    expect(f.service.messages, isEmpty);
    f.service.dispose();
  });

  testWidgets('ordinary support topics connect directly without an AI greeting',
      (tester) async {
    final f = Fixture();
    await f.service.startCategorizedChat(
        merchantId: 'business-42',
        merchantName: 'متجر',
        merchantEmail: '',
        category: 'order_management',
        categoryDescription: 'الطلبات');
    expect(f.channels, hasLength(1));
    expect(f.channels.single.sent.single['action'], 'chat_merchant_connect');
    expect(f.service.messages, isEmpty);
    expect(f.service.connectionStatus, 'waiting_for_confirmation');
    f.service.dispose();
  });
  testWidgets('default support entry connects directly without a bot',
      (tester) async {
    final f = Fixture();
    await f.service.connectToSupport(
        merchantId: 'business-42', merchantName: 'متجر', merchantEmail: '');
    expect(f.channels, hasLength(1));
    expect(f.service.messages, isEmpty);
    f.confirm();
    expect(f.service.isConnected, true);
    f.service.dispose();
  });
  testWidgets(
      'identity token and business ID stay separate; open socket is not session ready',
      (tester) async {
    final f = Fixture();
    await f.start();
    expect(f.uris.single.queryParameters['token'], 'fixture-token');
    expect(f.uris.single.queryParameters['userType'], 'merchant');
    expect(f.channels.single.sent.single['businessId'], 'business-42');
    expect(f.service.isConnected, false);
    expect(await f.service.sendMessage('احتفظ بهذا النص'), false);
    expect(
        f.service.messages.where((m) => m.senderType == 'merchant'), isEmpty);
    f.confirm();
    expect(f.service.isConnected, true);
    expect(f.channels.single.sent.last['type'], 'get_session_messages');
    f.service.dispose();
  });
  testWidgets('missing identity cannot create a connection', (tester) async {
    var connections = 0;
    final service = SupportChatService.forTesting(
        tokenProvider: () async => null,
        channelFactory: (_) {
          connections++;
          return FakeChannel();
        },
        websocketUrl: 'wss://support.invalid/staging');
    await service.startCategorizedChat(
        merchantId: 'business-42',
        merchantName: 'متجر',
        merchantEmail: '',
        category: 'human_agent',
        categoryDescription: 'مساعدة');
    expect(connections, 0);
    expect(service.isConnected, false);
    expect(service.connectionStatus, 'error');
    service.dispose();
  });
  testWidgets(
      'one action creates one message; echo and acknowledgement confirm it once',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    expect(await f.service.sendMessage('رد واحد'), true);
    final outbound = f.channels.single.sent.last;
    expect(outbound['action'], 'chat_message');
    expect(outbound['messageText'], 'رد واحد');
    expect(
        f.service.messages.where((m) => m.senderType == 'merchant').length, 1);
    expect(f.service.messages.last.deliveryStatus, 'pending');
    f.channels.single.receive({
      'type': 'chat_message',
      'sessionId': f.service.sessionId,
      'message': {
        'messageId': 'server-1',
        'clientMessageId': outbound['clientMessageId'],
        'senderType': 'merchant',
        'text': 'رد واحد',
        'createdAt': DateTime.now().toIso8601String(),
      }
    });
    f.channels.single.receive({
      'type': 'message_ack',
      'sessionId': f.service.sessionId,
      'clientMessageId': outbound['clientMessageId'],
      'messageId': 'server-1'
    });
    expect(
        f.service.messages.where((m) => m.senderType == 'merchant').length, 1);
    expect(f.service.messages.last.id, 'server-1');
    expect(f.service.messages.last.deliveryStatus, 'accepted');
    f.service.dispose();
  });
  testWidgets('failed send returns false without a successful-looking message',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    f.channels.single.fakeSink.failWrites = true;
    expect(await f.service.sendMessage('نص لم يرسل'), false);
    expect(
        f.service.messages.where((m) => m.senderType == 'merchant'), isEmpty);
    expect(f.service.isConnected, false);
    f.service.dispose();
  });
  testWidgets('timeout does not resend; history can confirm the reply later',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    await f.service.sendMessage('رسالة محفوظة');
    final request = f.channels.single.sent.last;
    final sentCount = f.channels.single.sent.length;
    await tester.pump(const Duration(seconds: 16));
    expect(f.service.messages.last.deliveryStatus, 'unknown');
    expect(f.channels.single.sent.length, sentCount);
    f.channels.single.receive({
      'type': 'session_messages',
      'requestId': f.channels.single.sent.firstWhere(
          (m) => m['action'] == 'get_session_messages')['requestId'],
      'sessionId': f.service.sessionId,
      'messages': [
        {
          'messageId': 'server-history',
          'senderType': 'merchant',
          'text': 'رسالة محفوظة',
          'createdAt': DateTime.now().toIso8601String(),
          'metadata': {'clientMessageId': request['clientMessageId']},
        }
      ]
    });
    expect(
        f.service.messages.where((m) => m.senderType == 'merchant').length, 1);
    expect(f.service.messages.last.deliveryStatus, 'accepted');
    f.service.dispose();
  });
  testWidgets(
      'reconnect refreshes identity, keeps the session and avoids a repeated greeting',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    final sessionId = f.service.sessionId;
    await f.service.sendMessage('لم يصل التأكيد');
    f.channels.single.input.close();
    await tester.pump();
    expect(f.service.messages.last.deliveryStatus, 'unknown');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(f.channels.length, 2,
        reason:
            "status=${f.service.connectionStatus}, tokens=${f.tokenReads}, error=${f.service.error}");
    expect(f.tokenReads, 2);
    expect(f.service.sessionId, sessionId);
    f.confirm();
    expect(
        f.service.messages.where((m) => m.id == 'connected_$sessionId').length,
        1);
    expect(f.channels.last.sent.where((m) => m['type'] == 'chat_message'),
        isEmpty);
    f.service.dispose();
  });
  testWidgets('close receipt is not closure; confirmed closure keeps history',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    await f.service.sendMessage('الرسالة');
    await f.service.endSession();
    final sid = f.service.sessionId;
    f.channels.single
        .receive({'type': 'chat_session_close_ack', 'sessionId': sid});
    expect(f.service.connectionStatus, 'connected');
    f.channels.single
        .receive({'type': 'session_closed', 'sessionId': 'foreign'});
    expect(f.service.connectionStatus, 'connected');
    f.channels.single.receive({'type': 'session_closed', 'sessionId': sid});
    expect(f.service.connectionStatus, 'session_ended');
    expect(f.service.messages.any((m) => m.text == 'الرسالة'), true);
    await tester.pump(const Duration(seconds: 20));
    expect(f.channels.length, 1);
    f.service.dispose();
  });
  testWidgets('disconnect cancels a pending token fetch', (tester) async {
    final token = Completer<String?>();
    var connections = 0;
    final service = SupportChatService.forTesting(
        tokenProvider: () => token.future,
        channelFactory: (_) {
          connections++;
          return FakeChannel();
        },
        websocketUrl: 'wss://support.invalid/staging');
    final opening = service.startCategorizedChat(
        merchantId: 'business-42',
        merchantName: 'متجر',
        merchantEmail: '',
        category: 'human_agent',
        categoryDescription: 'مساعدة');
    service.disconnect();
    token.complete('late-token');
    await opening;
    expect(connections, 0);
    expect(service.connectionStatus, 'paused');
    service.dispose();
  });
  testWidgets(
      'permission rejection stops reconnecting and retains pending messages',
      (tester) async {
    final f = Fixture();
    await f.start();
    f.confirm();
    await f.service.sendMessage('محفوظة محليًا');
    f.channels.single
        .receive({'type': 'error', 'code': 'BUSINESS_UNAVAILABLE'});
    expect(f.service.isConnected, false);
    expect(f.service.connectionStatus, 'error');
    expect(f.service.messages.last.text, 'محفوظة محليًا');
    expect(f.service.messages.last.deliveryStatus, 'unknown');
    await tester.pump(const Duration(seconds: 20));
    expect(f.channels.length, 1);
    f.service.dispose();
  });

  testWidgets(
      'changing branch discards a stale token callback and uses only the new branch',
      (tester) async {
    final firstToken = Completer<String?>();
    final channels = <FakeChannel>[];
    var tokenReads = 0;
    final service = SupportChatService.forTesting(
        tokenProvider: () =>
            ++tokenReads == 1 ? firstToken.future : Future.value('new-token'),
        channelFactory: (_) {
          final c = FakeChannel();
          channels.add(c);
          return c;
        },
        websocketUrl: 'wss://support.invalid/staging');
    final oldOpening = service.startCategorizedChat(
        merchantId: 'old-branch',
        merchantName: 'old',
        merchantEmail: '',
        category: 'human_agent',
        categoryDescription: '');
    await service.startCategorizedChat(
        merchantId: 'new-branch',
        merchantName: 'new',
        merchantEmail: '',
        category: 'human_agent',
        categoryDescription: '');
    firstToken.complete('stale-token');
    await oldOpening;
    expect(channels.length, 1);
    expect(channels.single.sent.single['businessId'], 'new-branch');
    service.dispose();
  });
}
