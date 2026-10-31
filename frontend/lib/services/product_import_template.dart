import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

const productTemplateHeaders = [
  'name',
  'price',
  'categoryId',
  'description',
  'imageFile',
  'stock'
];
String productTemplateCsv(String categoryId) =>
    'name,price,categoryId,description,imageFile,stock\nبرغر كلاسيك,6000,$categoryId,وصف اختياري,,';

/// A normal Excel workbook: editable cells, no macros, formulas or embedded images.
Uint8List productTemplateXlsx(String categoryId) {
  String escape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final rows = [
    productTemplateHeaders,
    ['برغر كلاسيك', '6000', categoryId, 'وصف اختياري', '', '']
  ];
  final sheet = rows
      .asMap()
      .entries
      .map((row) =>
          '<row r="${row.key + 1}">${row.value.asMap().entries.map((cell) => '<c r="${String.fromCharCode(65 + cell.key)}${row.key + 1}" t="inlineStr"><is><t>${escape(cell.value)}</t></is></c>').join()}</row>')
      .join();
  final files = <String, String>{
    '[Content_Types].xml':
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
    '_rels/.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml':
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Products" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
    'xl/worksheets/sheet1.xml':
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0" rightToLeft="1"/></sheetViews><sheetData>$sheet</sheetData></worksheet>',
  };
  final archive = Archive();
  for (final file in files.entries) {
    final bytes = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>${file.value}');
    archive.addFile(ArchiveFile(file.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
