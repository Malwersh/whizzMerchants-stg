import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:whizz_merchants/services/support_chat_service.dart';

class FakeSink implements WebSocketSink {
  FakeSink(this.channel);
  final FakeChannel channel;
  bool failWrites = false;
  @override
  void add(dynamic data) {
    if (failWrites) throw StateError('transport failed');
    channel.sent.add(jsonDecode(data as String) as Map<String, dynamic>);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!channel.input.isClosed) await channel.input.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChannel implements WebSocketChannel {
  final input = StreamController<dynamic>(sync: true);
  final sent = <Map<String, dynamic>>[];
  late final FakeSink fakeSink = FakeSink(this);
  @override
  Stream<dynamic> get stream => input.stream;
  @override
  WebSocketSink get sink => fakeSink;
  @override
  Future<void> get ready => Future<void>.value();
  void receive(Map<String, dynamic> message) => input.add(jsonEncode(message));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Fixture {
  Fixture({this.imageClient, this.attachmentsApiUrl});
  final http.Client? imageClient;
  final String? attachmentsApiUrl;
  final channels = <FakeChannel>[];
  final uris = <Uri>[];
  int tokenReads = 0;
  late final service = SupportChatService.forTesting(
    tokenProvider: () async {
      tokenReads++;
      return 'fixture-token';
    },
    channelFactory: (uri) {
      uris.add(uri);
      final c = FakeChannel();
      channels.add(c);
      return c;
    },
    websocketUrl: 'wss://support.invalid/staging',
    attachmentsApiUrl: attachmentsApiUrl,
    attachmentHttpClient: imageClient,
  );
  Future<void> start() => service.startCategorizedChat(
      merchantId: 'business-42',
      merchantName: 'متجر',
      merchantEmail: 'private@example.invalid',
      category: 'human_agent',
      categoryDescription: 'مساعدة');
  void confirm() => channels.last.receive(
      {'type': 'chat_session_created', 'sessionId': service.sessionId});
}
