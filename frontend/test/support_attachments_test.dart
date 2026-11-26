import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers/support_chat_fixture.dart';

void main() {
  late Directory temp;
  late File image;
  final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('support-images-');
    image = await File('${temp.path}/image.png').writeAsBytes(bytes);
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
      'upload sends authenticated bytes then a reference and waits for acknowledgement',
      () async {
    final f = Fixture(
        attachmentsApiUrl: 'https://support.invalid/images',
        imageClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer fixture-token');
          expect(request.headers['X-Support-User-Type'], 'merchant');
          final body = jsonDecode(request.body);
          expect(base64Decode(body['dataBase64']), bytes);
          expect(body['contentType'], 'image/png');
          return http.Response(
              jsonEncode({'attachmentId': body['uploadId']}), 200);
        }));
    await f.start();
    f.confirm();
    expect(await f.service.sendImageMessage(image, 'صورة الطلب'), true);
    final message = f.channels.single.sent.last;
    expect(message['action'], 'chat_message');
    expect(message['attachmentId'], message['clientMessageId']);
    expect(message.containsKey('dataBase64'), false);
    expect(f.service.messages.last.isUploading, false);
    expect(f.service.messages.last.deliveryStatus, 'pending');
    f.service.dispose();
  });

  for (final status in [403, 503]) {
    test('HTTP $status leaves a failed image without sending a chat message',
        () async {
      final f = Fixture(
          attachmentsApiUrl: 'https://support.invalid/images',
          imageClient: MockClient((_) async => http.Response('{}', status)));
      await f.start();
      f.confirm();
      final before = f.channels.single.sent.length;
      expect(await f.service.sendImageMessage(image, null), false);
      expect(f.channels.single.sent.length, before);
      expect(f.service.messages.last.deliveryStatus, 'failed');
      expect(f.service.messages.last.isUploading, false);
      f.service.dispose();
    });
  }

  test('leaving during upload prevents publication and clears the spinner',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    String? uploadId;
    final f = Fixture(
        attachmentsApiUrl: 'https://support.invalid/images',
        imageClient: MockClient((request) {
          uploadId = jsonDecode(request.body)['uploadId'];
          started.complete();
          return response.future;
        }));
    await f.start();
    f.confirm();
    final pending = f.service.sendImageMessage(image, null);
    await started.future;
    final channel = f.channels.single;
    final before = channel.sent.length;
    f.service.disconnect();
    response
        .complete(http.Response(jsonEncode({'attachmentId': uploadId}), 200));
    expect(await pending, false);
    expect(channel.sent.length, before);
    expect(f.service.messages.last.isUploading, false);
    f.service.dispose();
  });

  test(
      'download binds authenticated request to session and validates attachment identity',
      () async {
    var wrongIdentity = false;
    final f = Fixture(
        attachmentsApiUrl: 'https://support.invalid/images',
        imageClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['sessionId'], isNotEmpty);
          expect(request.headers['Authorization'], 'Bearer fixture-token');
          return http.Response(
              jsonEncode({
                'attachmentId': wrongIdentity ? 'other' : 'image-1',
                'contentType': 'image/png',
                'dataBase64': base64Encode(bytes)
              }),
              200);
        }));
    await f.start();
    f.confirm();
    expect(await f.service.loadAttachment('image-1'), bytes);
    wrongIdentity = true;
    await expectLater(f.service.loadAttachment('image-1'), throwsStateError);
    f.service.dispose();
  });

  test('download finishing after disconnect cannot expose stale session bytes',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final f = Fixture(
        attachmentsApiUrl: 'https://support.invalid/images',
        imageClient: MockClient((_) {
          started.complete();
          return response.future;
        }));
    await f.start();
    f.confirm();
    final pending = f.service.loadAttachment('image-1');
    final check = expectLater(pending, throwsStateError);
    await started.future;
    f.service.disconnect();
    response.complete(http.Response(
        jsonEncode({
          'attachmentId': 'image-1',
          'contentType': 'image/png',
          'dataBase64': base64Encode(bytes)
        }),
        200));
    await check;
    f.service.dispose();
  });
}
