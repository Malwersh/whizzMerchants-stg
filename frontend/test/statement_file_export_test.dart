import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/statement_file_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const filename = 'branch-statement-2026-01-01-2026-01-02.csv';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(
      StatementFileExportService.channel, null));
  test(
      'export channel passes only the filename and UTF8 CSV, with explicit saved/cancelled outcomes',
      () async {
    final calls = <MethodCall>[];
    bool saved = true;
    messenger.setMockMethodCallHandler(StatementFileExportService.channel,
        (call) async {
      calls.add(call);
      return saved;
    });
    final service = StatementFileExportService();
    expect(
        await service.save(filename: filename, csv: '\ufeff"وصف","دينار"\r\n'),
        isTrue);
    expect(calls.single.method, 'saveCsv');
    expect(calls.single.arguments, {
      'filename': filename,
      'bytes': utf8.encode('\ufeff"وصف","دينار"\r\n')
    });
    saved = false;
    expect(await service.save(filename: filename, csv: 'csv'), isFalse);
  });
  test(
      'unsafe filenames, empty payload and oversized UTF8 are rejected before native access',
      () async {
    int calls = 0;
    messenger.setMockMethodCallHandler(StatementFileExportService.channel,
        (_) async {
      calls++;
      return true;
    });
    final service = StatementFileExportService();
    for (final name in [
      '../$filename',
      '/tmp/$filename',
      'statement.html',
      '$filename\n'
    ]) {
      await expectLater(
          service.save(filename: name, csv: 'csv'), throwsFormatException);
    }
    await expectLater(
        service.save(filename: filename, csv: ''), throwsFormatException);
    await expectLater(
        service.save(filename: filename, csv: 'ع' * (1024 * 1024 + 1)),
        throwsFormatException);
    expect(calls, 0);
  });
  test('native write failure never returns a successful save', () async {
    messenger.setMockMethodCallHandler(StatementFileExportService.channel,
        (_) async {
      throw PlatformException(code: 'EXPORT_FAILED');
    });
    await expectLater(
        StatementFileExportService().save(filename: filename, csv: 'csv'),
        throwsA(isA<PlatformException>()));
  });
  test('sales report filename is accepted by the byte-only export channel',
      () async {
    messenger.setMockMethodCallHandler(StatementFileExportService.channel,
        (call) async {
      expect((call.arguments as Map).keys.toSet(), {'filename', 'bytes'});
      expect(call.arguments['filename'],
          'branch-sales-report-2026-01-01-2026-01-02.csv');
      return true;
    });
    expect(
        await StatementFileExportService().save(
            filename: 'branch-sales-report-2026-01-01-2026-01-02.csv',
            csv: 'csv'),
        isTrue);
  });
}
