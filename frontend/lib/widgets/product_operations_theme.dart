import 'package:flutter/material.dart';

/// Keep operational text readable: navy on light surfaces, white on filled buttons.
class ProductOperationsTheme extends StatelessWidget {
  final Widget child;
  const ProductOperationsTheme({super.key, required this.child});
  static const navy = Color(0xFF0B2E63);
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: navy,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFEDF2FA),
          onPrimaryContainer: navy,
          secondary: const Color(0xFFFDC500),
          secondaryContainer: const Color(0xFFEDF2FA),
          onSecondaryContainer: navy,
          onSecondary: navy,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: navy),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: navy,
            minimumSize: const Size(0, 44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE4E8EF),
            disabledForegroundColor: const Color(0xFF65748A),
            minimumSize: const Size(0, 44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      child: child,
    );
  }
}
