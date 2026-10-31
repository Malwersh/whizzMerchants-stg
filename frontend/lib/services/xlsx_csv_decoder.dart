import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads values from the first XLSX worksheet. Formulas, encrypted files and
/// macro containers are intentionally outside the import contract.
String xlsxToCsv(Uint8List bytes, {int maxRows = 501, int maxColumns = 20}) {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('الملف فارغ أو أكبر من 5 MB');
  }
  final directory = ZipDirectory()..read(InputMemoryStream(bytes));
  var expanded = 0;
  final names = <String>{};
  if (directory.fileHeaders.isEmpty || directory.fileHeaders.length > 256) {
    throw const FormatException('بنية ملف Excel غير صالحة أو كبيرة جدًا');
  }
  for (final entry in directory.fileHeaders) {
    expanded += entry.uncompressedSize;
    if (entry.uncompressedSize > 2 * 1024 * 1024 ||
        expanded > 16 * 1024 * 1024 ||
        !names.add(entry.filename) ||
        entry.filename.split('/').contains('..') ||
        entry.filename.startsWith('/') ||
        ((entry.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
        (entry.generalPurposeBitFlag & 1) != 0) {
      throw const FormatException(
          'ملف Excel محمي أو يتجاوز حدود القراءة الآمنة');
    }
    if (entry.filename.toLowerCase().endsWith('vbaproject.bin')) {
      throw const FormatException('ملفات Excel التي تحتوي macros غير مسموحة');
    }
  }
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
  var sheetPath = sheets.first.name;
  if (archive.findFile('xl/workbook.xml') != null) {
    final workbook = readXml('xl/workbook.xml');
    final sheet = workbook.findAllElements('sheet').firstOrNull;
    final id = sheet?.getAttribute('id',
            namespace:
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships') ??
        sheet?.getAttribute('r:id');
    final relationships = readXml('xl/_rels/workbook.xml.rels');
    final relation = relationships
        .findAllElements('Relationship')
        .where((r) => r.getAttribute('Id') == id)
        .firstOrNull;
    final target = relation?.getAttribute('Target');
    if (target == null || relation?.getAttribute('TargetMode') == 'External') {
      throw const FormatException('مرجع ورقة Excel غير صالح');
    }
    sheetPath = target.startsWith('/xl/') ? target.substring(1) : 'xl/$target';
    if (!RegExp(r'^xl/worksheets/[^/]+\.xml$').hasMatch(sheetPath)) {
      throw const FormatException('مرجع ورقة Excel غير صالح');
    }
  }
  final document = readXml(sheetPath);
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
