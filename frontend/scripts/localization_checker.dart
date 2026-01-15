#!/usr/bin/env dart

/// Localization Coverage Checker
///
/// Scans screen files for localization coverage:
/// - Finds hardcoded strings
/// - Checks if localization keys exist
/// - Verifies translations in all locales

import 'dart:io';
import 'dart:convert';

Future<void> main(List<String> arguments) async {
  print('🌍 Localization Coverage Checker');
  print('=' * 80);
  print('');

  // Load ARB files
  final enArb = await _loadArbFile('lib/l10n/app_en.arb');
  final arArb = await _loadArbFile('lib/l10n/app_ar.arb');

  if (enArb == null || arArb == null) {
    print('❌ Error: Could not load ARB files');
    exit(1);
  }

  final enKeys = enArb.keys.where((k) => !k.startsWith('@')).toSet();
  final arKeys = arArb.keys.where((k) => !k.startsWith('@')).toSet();

  print('📚 Loaded localization files:');
  print('   - English keys: ${enKeys.length}');
  print('   - Arabic keys: ${arKeys.length}');
  print('');

  // Check for missing translations
  final missingInArabic = enKeys.difference(arKeys);
  final missingInEnglish = arKeys.difference(enKeys);

  if (missingInArabic.isNotEmpty || missingInEnglish.isNotEmpty) {
    print('⚠️  Translation Sync Issues:');
    if (missingInArabic.isNotEmpty) {
      print('   Missing in Arabic: ${missingInArabic.length}');
      for (final key in missingInArabic.take(5)) {
        print('     - $key');
      }
      if (missingInArabic.length > 5) {
        print('     ... and ${missingInArabic.length - 5} more');
      }
    }
    if (missingInEnglish.isNotEmpty) {
      print('   Missing in English: ${missingInEnglish.length}');
      for (final key in missingInEnglish.take(5)) {
        print('     - $key');
      }
      if (missingInEnglish.length > 5) {
        print('     ... and ${missingInEnglish.length - 5} more');
      }
    }
    print('');
  } else {
    print('✅ All translations are in sync!');
    print('');
  }

  // Scan screens for hardcoded strings
  final screensDir = Directory('lib/screens');
  if (!screensDir.existsSync()) {
    print('❌ Error: lib/screens directory not found');
    exit(1);
  }

  final files = await _getAllDartFiles(screensDir);
  print('🔍 Scanning ${files.length} screen files for hardcoded strings...\n');

  final results = <String, LocalizationResult>{};

  for (final file in files) {
    final relativePath = file.path.replaceFirst(RegExp(r'^.*lib/'), 'lib/');
    final result = await _checkFileForLocalization(file);
    if (result.hardcodedStrings.isNotEmpty ||
        result.localizationUsage.isNotEmpty) {
      results[relativePath] = result;
    }
  }

  _printLocalizationReport(results);
  _generateLocalizationMarkdownReport(
      results, missingInArabic, missingInEnglish);
}

Future<Map<String, dynamic>?> _loadArbFile(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final content = await file.readAsString();
    return json.decode(content) as Map<String, dynamic>;
  } catch (e) {
    print('Error loading $path: $e');
    return null;
  }
}

Future<List<File>> _getAllDartFiles(Directory dir) async {
  final files = <File>[];
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
  return files;
}

Future<LocalizationResult> _checkFileForLocalization(File file) async {
  final content = await file.readAsString();
  final lines = content.split('\n');
  final result = LocalizationResult();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Skip comments and imports
    if (line.trim().startsWith('//') ||
        line.trim().startsWith('import ') ||
        line.trim().startsWith('* ')) {
      continue;
    }

    // Check for localization usage
    if (line.contains('AppLocalizations.of(context)') ||
        line.contains('l10n.')) {
      result.localizationUsage.add(LocalizationUsage(
        line: i + 1,
        code: line.trim(),
        type: 'USING_LOCALIZATION',
      ));
    }

    // Check for hardcoded strings in Text widgets
    if (line.contains('Text(') && (line.contains('"') || line.contains("'"))) {
      final textMatch =
          RegExp(r'''Text\s*\(\s*["']([^"']{4,})["']''').firstMatch(line);
      if (textMatch != null &&
          !line.contains('AppLocalizations.of(context)') &&
          !line.contains('l10n.')) {
        final text = textMatch.group(1) ?? '';

        // Filter out technical strings, variables, and short strings
        if (_shouldLocalize(text)) {
          result.hardcodedStrings.add(HardcodedString(
            line: i + 1,
            code: line.trim(),
            string: text,
            suggestion: _suggestLocalizationKey(text),
          ));
        }
      }
    }

    // Check for hardcoded strings in other widgets
    if (line.contains(':') && (line.contains('"') || line.contains("'"))) {
      final labelMatch = RegExp(
              r'''(?:label|hint|title|subtitle|message):\s*["']([^"']{4,})["']''')
          .firstMatch(line);
      if (labelMatch != null &&
          !line.contains('AppLocalizations.of(context)') &&
          !line.contains('l10n.')) {
        final text = labelMatch.group(1) ?? '';
        if (_shouldLocalize(text)) {
          result.hardcodedStrings.add(HardcodedString(
            line: i + 1,
            code: line.trim(),
            string: text,
            suggestion: _suggestLocalizationKey(text),
          ));
        }
      }
    }
  }

  return result;
}

bool _shouldLocalize(String text) {
  // Ignore short strings
  if (text.length <= 2) return false;

  // Ignore numbers
  if (RegExp(r'^[\d\s\.\,\-\+\(\)]+$').hasMatch(text)) return false;

  // Ignore common technical strings
  const technical = [
    'http',
    'https',
    'www',
    '.com',
    '.org',
    '.net',
    'TODO',
    'FIXME',
    'DEBUG',
    'ERROR',
    'WARNING',
    'API',
    'JSON',
    'XML',
    'HTML',
    'CSS',
  ];
  if (technical.any((t) => text.toUpperCase().contains(t))) return false;

  // Ignore variable-like strings
  if (RegExp(r'^\$\{.*\}$').hasMatch(text)) return false;

  // Ignore paths and URLs
  if (text.contains('/') || text.contains('\\')) return false;

  return true;
}

String _suggestLocalizationKey(String text) {
  // Convert text to camelCase key suggestion
  final words = text
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  if (words.isEmpty) return 'unknownKey';

  final key = words[0] +
      words
          .skip(1)
          .map((w) => w.isNotEmpty ? (w[0].toUpperCase() + w.substring(1)) : '')
          .join('');

  return key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
}

void _printLocalizationReport(Map<String, LocalizationResult> results) {
  print('📊 LOCALIZATION REPORT');
  print('=' * 80);
  print('');

  var totalHardcodedStrings = 0;
  var filesWithLocalization = 0;

  for (final entry in results.entries) {
    final path = entry.key;
    final result = entry.value;

    totalHardcodedStrings += result.hardcodedStrings.length;

    if (result.localizationUsage.isNotEmpty) {
      filesWithLocalization++;
    }

    if (result.hardcodedStrings.isNotEmpty) {
      print('⚠️  $path');
      print('   └─ ${result.hardcodedStrings.length} hardcoded strings found');

      // Show first 3 examples
      for (final str in result.hardcodedStrings.take(3)) {
        print('      Line ${str.line}: "${str.string}"');
        print('      💡 Suggested key: ${str.suggestion}');
      }
      if (result.hardcodedStrings.length > 3) {
        print('      ... and ${result.hardcodedStrings.length - 3} more');
      }
      print('');
    }
  }

  print('=' * 80);
  print('📈 SUMMARY');
  print('');
  print('Files with Localization: $filesWithLocalization');
  print('Files with Hardcoded Strings: ${results.length}');
  print('Total Hardcoded Strings: $totalHardcodedStrings');
  print('');

  if (totalHardcodedStrings == 0) {
    print('🎉 Perfect! All strings are localized!');
  } else {
    print(
        '⚠️  Action needed: $totalHardcodedStrings strings need localization');
  }

  print('');
  print('📝 Detailed report saved to: localization_coverage_report.md');
  print('');
}

void _generateLocalizationMarkdownReport(
  Map<String, LocalizationResult> results,
  Set<String> missingInArabic,
  Set<String> missingInEnglish,
) {
  final buffer = StringBuffer();

  buffer.writeln('# Localization Coverage Report');
  buffer.writeln('');
  buffer.writeln('**Generated**: ${DateTime.now()}');
  buffer.writeln('');

  // Translation sync issues
  buffer.writeln('## Translation Sync Status');
  buffer.writeln('');

  if (missingInArabic.isEmpty && missingInEnglish.isEmpty) {
    buffer.writeln('✅ All translations are in sync!');
  } else {
    if (missingInArabic.isNotEmpty) {
      buffer.writeln('### Missing in Arabic (${missingInArabic.length})');
      buffer.writeln('');
      for (final key in missingInArabic) {
        buffer.writeln('- `$key`');
      }
      buffer.writeln('');
    }

    if (missingInEnglish.isNotEmpty) {
      buffer.writeln('### Missing in English (${missingInEnglish.length})');
      buffer.writeln('');
      for (final key in missingInEnglish) {
        buffer.writeln('- `$key`');
      }
      buffer.writeln('');
    }
  }

  // Hardcoded strings by file
  buffer.writeln('## Hardcoded Strings by File');
  buffer.writeln('');

  final sortedResults = results.entries.toList()
    ..sort((a, b) => b.value.hardcodedStrings.length
        .compareTo(a.value.hardcodedStrings.length));

  for (final entry in sortedResults) {
    if (entry.value.hardcodedStrings.isEmpty) continue;

    final path = entry.key;
    final result = entry.value;

    buffer.writeln('### `$path`');
    buffer.writeln('');
    buffer.writeln('**Hardcoded Strings**: ${result.hardcodedStrings.length}');
    buffer.writeln('');

    for (final str in result.hardcodedStrings) {
      buffer.writeln('- **Line ${str.line}**: "${str.string}"');
      buffer.writeln('  ```dart');
      buffer.writeln('  ${str.code}');
      buffer.writeln('  ```');
      buffer.writeln('  💡 **Suggested key**: `${str.suggestion}`');
      buffer.writeln('  ```dart');
      buffer.writeln('  AppLocalizations.of(context)!.${str.suggestion}');
      buffer.writeln('  ```');
      buffer.writeln('');
    }
  }

  buffer.writeln('---');
  buffer.writeln('');
  buffer.writeln('*Generated by localization_checker.dart*');

  File('localization_coverage_report.md').writeAsStringSync(buffer.toString());
}

class LocalizationResult {
  final List<HardcodedString> hardcodedStrings = [];
  final List<LocalizationUsage> localizationUsage = [];
}

class HardcodedString {
  final int line;
  final String code;
  final String string;
  final String suggestion;

  HardcodedString({
    required this.line,
    required this.code,
    required this.string,
    required this.suggestion,
  });
}

class LocalizationUsage {
  final int line;
  final String code;
  final String type;

  LocalizationUsage({
    required this.line,
    required this.code,
    required this.type,
  });
}
