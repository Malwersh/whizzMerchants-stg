import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';

class AuthSurface extends StatelessWidget {
  final Widget child;
  const AuthSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    // This surface is intentionally light. Inheriting a dark card/input theme
    // while overriding only text colors creates dark-on-dark controls.
    final base = DesignSystem.lightTheme;
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFDFE5EE)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFF182A43),
          iconColor: WhizzColors.secondary,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
        colorScheme: ColorScheme.light(
          primary: WhizzColors.secondary,
          secondary: WhizzColors.primary,
          onPrimary: Colors.white,
          onSecondary: WhizzColors.secondary,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: Colors.black87,
          displayColor: WhizzColors.secondary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: WhizzColors.secondary),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: WhizzColors.secondary,
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: WhizzColors.secondary,
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? WhizzColors.secondary
                : null,
          ),
          checkColor: const WidgetStatePropertyAll(Colors.white),
        ),
        expansionTileTheme: ExpansionTileThemeData(
          iconColor: WhizzColors.secondary,
          textColor: WhizzColors.secondary,
          collapsedIconColor: WhizzColors.secondary,
          collapsedTextColor: WhizzColors.secondary,
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          foregroundColor: WhizzColors.secondary,
          titleTextStyle: base.textTheme.titleLarge?.copyWith(
              color: WhizzColors.secondary, fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          labelStyle: TextStyle(color: WhizzColors.secondary),
          floatingLabelStyle: TextStyle(color: WhizzColors.secondary),
          hintStyle: const TextStyle(color: Colors.black54),
        ),
      ),
      child: child,
    );
  }
}
