import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads values from the first XLSX worksheet. Formulas, encrypted files and
/// macro containers are intentionally outside the import contract.
String xlsxToCsv(Uint8List bytes, {int maxRows = 501, int maxColumns = 20}) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  if (archive.findFile('xl/vbaProject.bin') != null) {
    throw const FormatException('ملفات Excel التي تحتوي macros غير مسموحة');
  }

  XmlDocument readXml(String path) {
    final file = archive.findFile(path);
    if (file == null || file.size > 2 * 1024 * 1024) {
      throw const FormatException('بنية ملف Excel غير صالحة');
    }
    return XmlDocument.parse(utf8.decode(file.content));
  }

  final shared = <String>[];
  final sharedFile = archive.findFile('xl/sharedStrings.xml');
  if (sharedFile != null) {
    if (sharedFile.size > 2 * 1024 * 1024) {
      throw const FormatException('نصوص ملف Excel أكبر من الحد المسموح');
    }
    final document = XmlDocument.parse(utf8.decode(sharedFile.content));
    for (final item in document.findAllElements('si')) {
      shared.add(item.findAllElements('t').map((e) => e.innerText).join());
    }
  }

  final sheets = archive.files
      .where((f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (sheets.isEmpty) {
    throw const FormatException('ملف Excel لا يحتوي ورقة');
  }
  final document = readXml(sheets.first.name);
  final output = <String>[];
  for (final row in document.findAllElements('row')) {
    if (output.length >= maxRows) {
      throw const FormatException('الحد الأقصى 500 صف');
    }
    final values = <int, String>{};
    var fallbackColumn = 0;
    for (final cell in row.findElements('c')) {
      if (cell.findElements('f').isNotEmpty) {
        throw const FormatException('الصيغ غير مسموحة؛ حوّلها إلى قيم ثابتة');
      }
      final reference = cell.getAttribute('r');
      final letters = RegExp(r'^[A-Z]+', caseSensitive: false)
          .firstMatch(reference ?? '')
          ?.group(0);
      var column = fallbackColumn;
      if (letters != null) {
        column = 0;
        for (final code in letters.toUpperCase().codeUnits) {
          column = column * 26 + code - 64;
        }
        column--;
      }
      fallbackColumn = column + 1;
      if (column < 0 || column >= maxColumns) {
        throw const FormatException('عدد أعمدة ملف Excel أكبر من الحد المسموح');
      }
      final type = cell.getAttribute('t');
      String value;
      if (type == 'inlineStr') {
        value = cell.findAllElements('t').map((e) => e.innerText).join();
      } else {
        value = cell.findElements('v').firstOrNull?.innerText ?? '';
        if (type == 's' && value.isNotEmpty) {
          final index = int.tryParse(value);
          if (index == null || index < 0 || index >= shared.length) {
            throw const FormatException('مرجع نص غير صالح في ملف Excel');
          }
          value = shared[index];
        } else if (type == 'b') {
          value = value == '1' ? 'true' : 'false';
        }
      }
      values[column] = value;
    }
    final width =
        values.isEmpty ? 0 : values.keys.reduce((a, b) => a > b ? a : b) + 1;
    output
        .add(List.generate(width, (i) => _csvCell(values[i] ?? '')).join(','));
  }
  return output.join('\n');
}

String _csvCell(String value) => value.contains(RegExp('[,"\r\n]'))
    ? '"${value.replaceAll('"', '""')}"'
    : value;
