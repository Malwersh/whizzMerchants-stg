import 'dart:convert';
import 'package:flutter/services.dart';

/// Saves only a freshly authorized CSV supplied by the statement endpoint.
/// No token, device credential, or personal account storage crosses this channel.
class StatementFileExportService {
  static const channel = MethodChannel('com.whizz.merchants/statement-export');
  Future<bool> save({required String filename, required String csv}) async {
    if (!RegExp(r'^branch-(statement|sales-report)-\d{4}-\d{2}-\d{2}-\d{4}-\d{2}-\d{2}\.csv$')
            .hasMatch(filename) ||
        filename.contains('\n') ||
        filename.contains('\r') ||
        csv.isEmpty ||
        utf8.encode(csv).length > 2 * 1024 * 1024) {
      throw const FormatException('Invalid statement export');
    }
    return await channel.invokeMethod<bool>('saveCsv', {
          'filename': filename,
          'bytes': Uint8List.fromList(utf8.encode(csv)),
        }) ==
        true;
  }
}
