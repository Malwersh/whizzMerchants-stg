import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/design_system/material_theme.dart';

void main() {
  testWidgets('product toolbar tonal icons remain visible', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: MaterialTheme.lightTheme,
        home: Scaffold(
            body: IconButton.filledTonal(
                onPressed: () {}, icon: const Icon(Icons.upload_file)))));
    final icon = tester.element(find.byIcon(Icons.upload_file));
    final foreground = IconTheme.of(icon).color!;
    final background = MaterialTheme.lightColorScheme.secondaryContainer;
    final a = foreground.computeLuminance(), b = background.computeLuminance();
    expect(((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
        greaterThanOrEqualTo(3));
  });
}
