import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double _mobileBreakpoint = 600;
  static const double _tabletBreakpoint = 1024;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < _mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= _mobileBreakpoint && width < _tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= _tabletBreakpoint;
  }

  static double getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return 16.0;
    } else if (isTablet(context)) {
      return 24.0;
    } else {
      return 32.0;
    }
  }

  static int getGridCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 3;
    }
  }

  static double getResponsiveWidth(
    BuildContext context, {
    double mobileWidth = 1.0,
    double tabletWidth = 0.8,
    double desktopWidth = 0.6,
  }) {
    double screenWidth = MediaQuery.of(context).size.width;

    if (isMobile(context)) {
      return screenWidth * mobileWidth;
    } else if (isTablet(context)) {
      return screenWidth * tabletWidth;
    } else {
      return screenWidth * desktopWidth;
    }
  }

  static EdgeInsets getResponsiveMargin(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(8.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }

  static double getResponsiveFontSize(
      BuildContext context, double baseFontSize) {
    if (isMobile(context)) {
      return baseFontSize;
    } else if (isTablet(context)) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize * 1.2;
    }
  }

  static double getSidebarWidth(BuildContext context) {
    if (isMobile(context)) {
      return 280.0;
    } else if (isTablet(context)) {
      return 300.0;
    } else {
      return 320.0;
    }
  }

  static bool shouldUseCompactLayout(BuildContext context) {
    return isMobile(context);
  }

  static double getResponsiveIconSize(BuildContext context,
      {double baseSize = 24.0}) {
    if (isMobile(context)) {
      return baseSize;
    } else if (isTablet(context)) {
      return baseSize * 1.1;
    } else {
      return baseSize * 1.2;
    }
  }

  static double getResponsiveHeight(BuildContext context, {
    double mobileHeight = 0.5,
    double tabletHeight = 0.6,
    double desktopHeight = 0.7,
  }) {
    double screenHeight = MediaQuery.of(context).size.height;
    
    if (isMobile(context)) {
      return screenHeight * mobileHeight;
    } else if (isTablet(context)) {
      return screenHeight * tabletHeight;
    } else {
      return screenHeight * desktopHeight;
    }
  }

  static int getResponsiveFlexValue(
    BuildContext context, {
    int mobileFlex = 1,
    int tabletFlex = 2,
    int desktopFlex = 3,
  }) {
    if (isMobile(context)) {
      return mobileFlex;
    } else if (isTablet(context)) {
      return tabletFlex;
    } else {
      return desktopFlex;
    }
  }
}
