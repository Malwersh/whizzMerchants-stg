#!/usr/bin/env dart

/// Design System Checker
///
/// Scans all screen files for design system compliance issues:
/// - Hardcoded colors
/// - Hardcoded spacing/padding
/// - Direct font size usage
/// - Missing design system imports

import 'dart:io';

Future<void> main(List<String> arguments) async {
  print('🔍 Design System Compliance Checker');
  print('=' * 80);
  print('');

  final screensDir = Directory('lib/screens');
  if (!screensDir.existsSync()) {
    print('❌ Error: lib/screens directory not found');
    exit(1);
  }

  final results = <String, ComplianceResult>{};
  final files = await _getAllDartFiles(screensDir);

  print('📊 Scanning ${files.length} screen files...\n');

  for (final file in files) {
    final relativePath = file.path.replaceFirst(RegExp(r'^.*lib/'), 'lib/');
    final result = await _checkFile(file);
    results[relativePath] = result;
  }

  _printReport(results);
  _generateMarkdownReport(results);
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

Future<ComplianceResult> _checkFile(File file) async {
  final content = await file.readAsString();
  final lines = content.split('\n');

  final result = ComplianceResult();

  // Check for design system import
  result.hasDesignSystemImport = content.contains(
        "import 'package:whizz_merchants/core/design_system/design_system.dart'",
      ) ||
      content.contains(
        "import 'package:whizz_merchants/core/theme/whizz_colors.dart'",
      );

  // Check for hardcoded colors
  final colorPattern = RegExp(r'Color\s*\(\s*0x[0-9A-Fa-f]{8}\s*\)|'
      r'Colors\.\w+(?!\s*\.\s*withOpacity)|'
      r'Color\.fromRGBO|'
      r'Color\.fromARGB');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Skip comments and imports
    if (line.trim().startsWith('//') ||
        line.trim().startsWith('import ') ||
        line.trim().startsWith('* ')) {
      continue;
    }

    // Check for hardcoded colors
    if (colorPattern.hasMatch(line)) {
      result.hardcodedColors.add(Issue(
        line: i + 1,
        code: line.trim(),
        suggestion: 'Use WhizzColors instead (e.g., WhizzColors.brandYellow)',
      ));
    }

    // Check for hardcoded spacing
    final spacingPattern = RegExp(
      r'EdgeInsets\s*\.\s*(?:all|only|symmetric)\s*\(\s*(?:\w+:\s*)?(\d+(?:\.\d+)?)',
    );
    final paddingPattern = RegExp(r'padding:\s*(?:const\s+)?EdgeInsets');

    if (paddingPattern.hasMatch(line)) {
      final match = spacingPattern.firstMatch(line);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '');
        if (value != null && !_isDesignSystemSpacing(value)) {
          result.hardcodedSpacing.add(Issue(
            line: i + 1,
            code: line.trim(),
            suggestion: 'Use AppSpacing constants (e.g., AppSpacing.md)',
          ));
        }
      }
    }

    // Check for SizedBox with hardcoded values
    final sizedBoxPattern = RegExp(
      r'SizedBox\s*\(\s*(?:height|width):\s*(\d+(?:\.\d+)?)',
    );
    final sizedBoxMatch = sizedBoxPattern.firstMatch(line);
    if (sizedBoxMatch != null) {
      final value = double.tryParse(sizedBoxMatch.group(1) ?? '');
      if (value != null && !_isDesignSystemSpacing(value)) {
        result.hardcodedSpacing.add(Issue(
          line: i + 1,
          code: line.trim(),
          suggestion: 'Use AppSpacing constants in SizedBox',
        ));
      }
    }

    // Check for hardcoded font sizes
    final fontSizePattern = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
    final fontSizeMatch = fontSizePattern.firstMatch(line);
    if (fontSizeMatch != null) {
      result.hardcodedFontSizes.add(Issue(
        line: i + 1,
        code: line.trim(),
        suggestion: 'Use AppTypography styles (e.g., AppTypography.bodyLarge)',
      ));
    }

    // Check for hardcoded strings (potential localization issues)
    if (!line.contains('AppLocalizations.of(context)') &&
        !line.contains('l10n.') &&
        !line.trim().startsWith('//') &&
        !line.contains('import ')) {
      // Simple check for Text widgets with quoted strings
      if (line.contains('Text(') &&
          (line.contains('"') || line.contains("'"))) {
        final match =
            RegExp(r'''Text\s*\(\s*["']([^"']{4,})["']''').firstMatch(line);
        if (match != null) {
          final text = match.group(1) ?? '';
          if (!RegExp(r'^[\d\s\.\,\-\+\(\)]+$').hasMatch(text) &&
              !_isCommonTechnicalString(text)) {
            result.potentialLocalizationIssues.add(Issue(
              line: i + 1,
              code: line.trim(),
              suggestion: 'Consider using AppLocalizations for: "$text"',
            ));
          }
        }
      }
    }
  }

  return result;
}

bool _isDesignSystemSpacing(double value) {
  // Design system spacing values (8pt grid)
  const validSpacing = [0, 4, 8, 12, 16, 24, 32, 48, 64];
  return validSpacing.contains(value);
}

bool _isCommonTechnicalString(String text) {
  const technical = [
    'OK',
    'Cancel',
    'Yes',
    'No',
    'Edit',
    'Delete',
    'Save',
    'http',
    'https',
    'www',
    '.com',
    '.dart',
    'TODO',
    'FIXME'
  ];
  return technical.any((t) => text.contains(t));
}

void _printReport(Map<String, ComplianceResult> results) {
  var totalFiles = results.length;
  var compliantFiles = 0;
  var totalIssues = 0;

  print('📈 COMPLIANCE REPORT');
  print('=' * 80);
  print('');

  for (final entry in results.entries) {
    final path = entry.key;
    final result = entry.value;
    final issueCount = result.totalIssues;

    totalIssues += issueCount;

    if (issueCount == 0) {
      compliantFiles++;
      print('✅ $path - COMPLIANT');
    } else {
      final severity = issueCount > 20
          ? '🔴'
          : issueCount > 10
              ? '🟡'
              : '🟠';
      print('$severity $path - $issueCount issues');

      if (result.hardcodedColors.isNotEmpty) {
        print('   └─ ${result.hardcodedColors.length} hardcoded colors');
      }
      if (result.hardcodedSpacing.isNotEmpty) {
        print(
            '   └─ ${result.hardcodedSpacing.length} hardcoded spacing values');
      }
      if (result.hardcodedFontSizes.isNotEmpty) {
        print('   └─ ${result.hardcodedFontSizes.length} hardcoded font sizes');
      }
      if (result.potentialLocalizationIssues.isNotEmpty) {
        print(
            '   └─ ${result.potentialLocalizationIssues.length} potential localization issues');
      }
    }
  }

  print('');
  print('=' * 80);
  print('📊 SUMMARY');
  print('');
  print('Total Files Scanned: $totalFiles');
  print(
      'Compliant Files: $compliantFiles (${(compliantFiles / totalFiles * 100).toStringAsFixed(1)}%)');
  print('Files with Issues: ${totalFiles - compliantFiles}');
  print('Total Issues Found: $totalIssues');
  print('');

  if (compliantFiles == totalFiles) {
    print('🎉 Congratulations! All screens are design system compliant!');
  } else {
    print(
        '⚠️  Action needed: ${totalFiles - compliantFiles} files need attention');
  }

  print('');
  print('📝 Detailed report saved to: design_system_compliance_report.md');
  print('');
}

void _generateMarkdownReport(Map<String, ComplianceResult> results) {
  final buffer = StringBuffer();

  buffer.writeln('# Design System Compliance Report');
  buffer.writeln('');
  buffer.writeln('**Generated**: ${DateTime.now()}');
  buffer.writeln('');

  var totalFiles = results.length;
  var compliantFiles = results.values.where((r) => r.totalIssues == 0).length;
  var totalIssues = results.values.fold(0, (sum, r) => sum + r.totalIssues);

  buffer.writeln('## Summary');
  buffer.writeln('');
  buffer.writeln('| Metric | Value |');
  buffer.writeln('|--------|-------|');
  buffer.writeln('| Total Files | $totalFiles |');
  buffer.writeln('| Compliant Files | $compliantFiles |');
  buffer.writeln(
      '| Compliance Rate | ${(compliantFiles / totalFiles * 100).toStringAsFixed(1)}% |');
  buffer.writeln('| Total Issues | $totalIssues |');
  buffer.writeln('');

  buffer.writeln('## Files with Issues');
  buffer.writeln('');

  final filesWithIssues = results.entries
      .where((e) => e.value.totalIssues > 0)
      .toList()
    ..sort((a, b) => b.value.totalIssues.compareTo(a.value.totalIssues));

  for (final entry in filesWithIssues) {
    final path = entry.key;
    final result = entry.value;

    buffer.writeln('### `$path`');
    buffer.writeln('');
    buffer.writeln('**Total Issues**: ${result.totalIssues}');
    buffer.writeln('');

    if (result.hardcodedColors.isNotEmpty) {
      buffer
          .writeln('#### Hardcoded Colors (${result.hardcodedColors.length})');
      buffer.writeln('');
      for (final issue in result.hardcodedColors) {
        buffer.writeln('- Line ${issue.line}: `${issue.code}`');
        buffer.writeln('  - 💡 ${issue.suggestion}');
      }
      buffer.writeln('');
    }

    if (result.hardcodedSpacing.isNotEmpty) {
      buffer.writeln(
          '#### Hardcoded Spacing (${result.hardcodedSpacing.length})');
      buffer.writeln('');
      for (final issue in result.hardcodedSpacing.take(5)) {
        buffer.writeln('- Line ${issue.line}: `${issue.code}`');
        buffer.writeln('  - 💡 ${issue.suggestion}');
      }
      if (result.hardcodedSpacing.length > 5) {
        buffer.writeln('- ... and ${result.hardcodedSpacing.length - 5} more');
      }
      buffer.writeln('');
    }

    if (result.hardcodedFontSizes.isNotEmpty) {
      buffer.writeln(
          '#### Hardcoded Font Sizes (${result.hardcodedFontSizes.length})');
      buffer.writeln('');
      for (final issue in result.hardcodedFontSizes.take(3)) {
        buffer.writeln('- Line ${issue.line}: `${issue.code}`');
        buffer.writeln('  - 💡 ${issue.suggestion}');
      }
      if (result.hardcodedFontSizes.length > 3) {
        buffer
            .writeln('- ... and ${result.hardcodedFontSizes.length - 3} more');
      }
      buffer.writeln('');
    }

    if (result.potentialLocalizationIssues.isNotEmpty) {
      buffer.writeln(
          '#### Potential Localization Issues (${result.potentialLocalizationIssues.length})');
      buffer.writeln('');
      for (final issue in result.potentialLocalizationIssues.take(5)) {
        buffer.writeln('- Line ${issue.line}: `${issue.code}`');
        buffer.writeln('  - 💡 ${issue.suggestion}');
      }
      if (result.potentialLocalizationIssues.length > 5) {
        buffer.writeln(
            '- ... and ${result.potentialLocalizationIssues.length - 5} more');
      }
      buffer.writeln('');
    }
  }

  buffer.writeln('## Compliant Files ✅');
  buffer.writeln('');

  final compliantFilesList = results.entries
      .where((e) => e.value.totalIssues == 0)
      .map((e) => e.key)
      .toList()
    ..sort();

  for (final path in compliantFilesList) {
    buffer.writeln('- `$path`');
  }

  buffer.writeln('');
  buffer.writeln('---');
  buffer.writeln('');
  buffer.writeln('*Generated by design_system_checker.dart*');

  File('design_system_compliance_report.md')
      .writeAsStringSync(buffer.toString());
}

class ComplianceResult {
  bool hasDesignSystemImport = false;
  final List<Issue> hardcodedColors = [];
  final List<Issue> hardcodedSpacing = [];
  final List<Issue> hardcodedFontSizes = [];
  final List<Issue> potentialLocalizationIssues = [];

  int get totalIssues =>
      hardcodedColors.length +
      hardcodedSpacing.length +
      hardcodedFontSizes.length +
      potentialLocalizationIssues.length;
}

class Issue {
  final int line;
  final String code;
  final String suggestion;

  Issue({
    required this.line,
    required this.code,
    required this.suggestion,
  });
}
