import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'whizz_colors.dart';

/// Application theme configuration
class AppTheme {
  AppTheme._();

  /// Light theme configuration
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: WhizzColors.secondary,
      brightness: Brightness.light,
      primary: WhizzColors.secondary,
      secondary: WhizzColors.secondary,
      surface: WhizzColors.white,
      error: WhizzColors.error,
      onPrimary: WhizzColors.white,
      onSecondary: WhizzColors.white,
      onSurface: WhizzColors.black,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.robotoTextTheme(),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: WhizzColors.secondary,
        foregroundColor: WhizzColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: WhizzColors.white,
        ),
        iconTheme: const IconThemeData(
          color: WhizzColors.white,
        ),
      ),

      // Bottom Navigation Bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: WhizzColors.white,
        selectedItemColor: WhizzColors.secondary,
        unselectedItemColor: WhizzColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Navigation Bar theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WhizzColors.white,
        indicatorColor: WhizzColors.secondary.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: WhizzColors.secondary,
            );
          }
          return GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: WhizzColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: WhizzColors.secondary,
              size: 24,
            );
          }
          return const IconThemeData(
            color: WhizzColors.textSecondary,
            size: 24,
          );
        }),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: WhizzColors.white,
        shadowColor: WhizzColors.grey300.withValues(alpha: 0.3),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WhizzColors.secondary,
          foregroundColor: WhizzColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Outlined Button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WhizzColors.secondary,
          side: BorderSide(color: WhizzColors.secondary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text Button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WhizzColors.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: WhizzColors.secondary,
        foregroundColor: WhizzColors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),

      // Input Decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WhizzColors.grey50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: WhizzColors.borderPrimary, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: WhizzColors.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: WhizzColors.error),
        ),
        labelStyle: GoogleFonts.roboto(
          color: WhizzColors.textSecondary,
        ),
        hintStyle: GoogleFonts.roboto(
          color: WhizzColors.textSecondary.withValues(alpha: 0.6),
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: WhizzColors.grey100,
        selectedColor: WhizzColors.secondary.withValues(alpha: 0.1),
        labelStyle: GoogleFonts.roboto(
          color: WhizzColors.chipText, // Use centralized chip text color
        ),
        secondaryLabelStyle: GoogleFonts.roboto(
          color: WhizzColors.chipText, // Use centralized chip text color
        ),
        checkmarkColor: WhizzColors.chipIconSelected, // Checkmark color
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return WhizzColors.secondary;
          }
          return WhizzColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return WhizzColors.secondary.withValues(alpha: 0.5);
          }
          return WhizzColors.grey300;
        }),
      ),

      // Progress Indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: WhizzColors.secondary,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: WhizzColors.grey300.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: WhizzColors.secondary,
      brightness: Brightness.dark,
      primary: WhizzColors.secondary,
      secondary: WhizzColors.secondary,
      surface: const Color(0xFF121212),
      error: WhizzColors.error,
      onPrimary: WhizzColors.white,
      onSecondary: WhizzColors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),

      // Bottom Navigation Bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1F1F1F),
        selectedItemColor: WhizzColors.secondary,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: const Color(0xFF1F1F1F),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WhizzColors.secondary,
          foregroundColor: WhizzColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: WhizzColors.secondary,
        foregroundColor: WhizzColors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),
    );
  }

  /// Get appropriate text color for background
  static Color getTextColorForBackground(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? WhizzColors.black : Colors.white;
  }

  /// Get status color based on status type
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return WhizzColors.warning;
      case 'confirmed':
        return WhizzColors.info;
      case 'preparing':
        return WhizzColors.secondary;
      case 'ready':
        return WhizzColors.secondary;
      case 'delivered':
        return WhizzColors.success;
      case 'cancelled':
        return WhizzColors.error;
      default:
        return WhizzColors.textSecondary;
    }
  }
}
