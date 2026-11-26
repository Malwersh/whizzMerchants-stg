String buildProductImportErrorCsv(List<Map<String, dynamic>> rows) {
  final output = <String>['rowId,productId,name,action,errors'];
  for (final row in rows) {
    final errors = List<dynamic>.from(row['errors'] ?? const []);
    if (errors.isEmpty) continue;
    output.add([
      row['rowId'],
      row['productId'],
      row['name'],
      row['action'],
      errors.join('|')
    ].map((value) => _cell(value?.toString() ?? '')).join(','));
  }
  return '\ufeff${output.join('\r\n')}';
}

String _cell(String value) {
  var safe = value;
  if (RegExp(r'^[\s]*[=+\-@]').hasMatch(safe)) safe = "'$safe";
  return safe.contains(RegExp('[,"\r\n]'))
      ? '"${safe.replaceAll('"', '""')}"'
      : safe;
}
