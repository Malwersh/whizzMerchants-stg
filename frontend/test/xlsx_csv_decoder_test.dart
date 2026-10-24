import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/services/xlsx_csv_decoder.dart';

Uint8List workbook(String sheet, {String? shared}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet));
  if (shared != null) {
    archive.addFile(ArchiveFile.string('xl/sharedStrings.xml', shared));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('XLSX values preserve shared Arabic text, sparse cells and booleans',
      () {
    final bytes = workbook(
      '<worksheet><sheetData><row><c r="A1" t="s"><v>0</v></c><c r="C1" t="b"><v>1</v></c></row></sheetData></worksheet>',
      shared: '<sst><si><t>برغر، كبير</t></si></sst>',
    );
    expect(xlsxToCsv(bytes), 'برغر، كبير,,true');
  });

  test('XLSX formulas are rejected instead of being executed or imported', () {
    final bytes = Uint8List.fromList(workbook(
        '<worksheet><sheetData><row><c r="A1"><f>1+1</f><v>2</v></c></row></sheetData></worksheet>'));
    expect(() => xlsxToCsv(bytes), throwsFormatException);
  });
}
