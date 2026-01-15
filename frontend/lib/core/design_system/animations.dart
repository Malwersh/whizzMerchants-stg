import 'package:flutter/material.dart';

/// Design System - Animation Constants
///
/// Standardized animation durations and curves for consistent motion design.
/// Based on Material Design motion guidelines.
class AppAnimations {
  AppAnimations._(); // Private constructor

  // ============================================================================
  // DURATION VALUES
  // ============================================================================

  /// Instant transition - 0ms
  /// Use for: Immediate changes, no animation
  static const Duration instant = Duration(milliseconds: 0);

  /// Extra fast duration - 50ms
  /// Use for: Very subtle micro-interactions
  static const Duration extraFast = Duration(milliseconds: 50);

  /// Fast duration - 100ms
  /// Use for: Quick transitions, hovers, micro-interactions
  static const Duration fast = Duration(milliseconds: 100);

  /// Normal duration - 200ms (Standard)
  /// Use for: Most UI transitions, button presses, fades
  static const Duration normal = Duration(milliseconds: 200);

  /// Moderate duration - 250ms
  /// Use for: Medium transitions, cards, menus
  static const Duration moderate = Duration(milliseconds: 250);

  /// Slow duration - 300ms
  /// Use for: Larger transitions, complex animations
  static const Duration slow = Duration(milliseconds: 300);

  /// Slower duration - 400ms
  /// Use for: Page transitions, large movements
  static const Duration slower = Duration(milliseconds: 400);

  /// Slowest duration - 500ms
  /// Use for: Major transitions, emphasis (use sparingly)
  static const Duration slowest = Duration(milliseconds: 500);

  // ============================================================================
  // SEMANTIC DURATIONS
  // ============================================================================

  /// Button press animation
  static const Duration buttonPress = fast;

  /// Page transition
  static const Duration pageTransition = slow;

  /// Dialog/Modal appear
  static const Duration dialogAppear = normal;

  /// Bottom sheet slide
  static const Duration bottomSheetSlide = moderate;

  /// Snackbar appear/disappear
  static const Duration snackbar = normal;

  /// Ripple effect
  static const Duration ripple = fast;

  /// Fade in/out
  static const Duration fade = normal;

  /// Slide transitions
  static const Duration slide = moderate;

  /// Scale transitions
  static const Duration scale = fast;

  /// Rotation
  static const Duration rotation = moderate;

  /// List item animation (stagger)
  static const Duration listItemStagger = Duration(milliseconds: 50);

  // ============================================================================
  // ANIMATION CURVES
  // ============================================================================

  /// Standard curve - Ease in and out (Default)
  /// Use for: Most animations
  static const Curve standard = Curves.easeInOut;

  /// Accelerate curve - Ease in
  /// Use for: Elements leaving the screen
  static const Curve accelerate = Curves.easeIn;

  /// Decelerate curve - Ease out
  /// Use for: Elements entering the screen
  static const Curve decelerate = Curves.easeOut;

  /// Emphasized curve - Material emphasized motion
  /// Use for: Emphasized transitions, important actions
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Emphasized decelerate - Material emphasized decelerate
  /// Use for: Elements entering with emphasis
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Emphasized accelerate - Material emphasized accelerate
  /// Use for: Elements leaving with emphasis
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Linear curve - No easing
  /// Use for: Continuous animations, loaders
  static const Curve linear = Curves.linear;

  /// Bounce curve
  /// Use for: Playful interactions (use sparingly)
  static const Curve bounce = Curves.bounceOut;

  /// Elastic curve
  /// Use for: Attention-grabbing animations (use sparingly)
  static const Curve elastic = Curves.elasticOut;

  // ============================================================================
  // PRESET ANIMATION CONFIGURATIONS
  // ============================================================================

  /// Fade in animation
  static AnimationController createFadeIn(TickerProvider vsync) {
    return AnimationController(
      duration: fade,
      vsync: vsync,
    );
  }

  /// Slide up animation
  static AnimationController createSlideUp(TickerProvider vsync) {
    return AnimationController(
      duration: slide,
      vsync: vsync,
    );
  }

  /// Scale animation
  static AnimationController createScale(TickerProvider vsync) {
    return AnimationController(
      duration: scale,
      vsync: vsync,
    );
  }

  // ============================================================================
  // TWEEN HELPERS
  // ============================================================================

  /// Fade tween (0.0 to 1.0)
  static Tween<double> get fadeTween => Tween<double>(begin: 0.0, end: 1.0);

  /// Scale tween (0.0 to 1.0)
  static Tween<double> get scaleTween => Tween<double>(begin: 0.0, end: 1.0);

  /// Slide from bottom tween
  static Tween<Offset> get slideFromBottomTween =>
      Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero);

  /// Slide from top tween
  static Tween<Offset> get slideFromTopTween =>
      Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero);

  /// Slide from right tween
  static Tween<Offset> get slideFromRightTween =>
      Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero);

  /// Slide from left tween
  static Tween<Offset> get slideFromLeftTween =>
      Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero);

  // ============================================================================
  // TRANSITION BUILDERS
  // ============================================================================

  /// Fade transition builder
  static Widget buildFadeTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  /// Scale transition builder
  static Widget buildScaleTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: animation,
      child: child,
    );
  }

  /// Slide transition builder (from bottom)
  static Widget buildSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    final offsetAnimation = slideFromBottomTween.animate(
      CurvedAnimation(parent: animation, curve: decelerate),
    );
    return SlideTransition(
      position: offsetAnimation,
      child: child,
    );
  }

  /// Combined fade and slide transition
  static Widget buildFadeSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    final offsetAnimation = slideFromBottomTween.animate(
      CurvedAnimation(parent: animation, curve: decelerate),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: offsetAnimation,
        child: child,
      ),
    );
  }

  /// Combined fade and scale transition
  static Widget buildFadeScaleTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: decelerate),
    );
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: child,
      ),
    );
  }

  // ============================================================================
  // PAGE ROUTE TRANSITIONS
  // ============================================================================

  /// Fade page route
  static Route fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: pageTransition,
    );
  }

  /// Slide page route (from right)
  static Route slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = slideFromRightTween.animate(
          CurvedAnimation(parent: animation, curve: decelerate),
        );
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: pageTransition,
    );
  }

  /// Scale page route
  static Route scaleRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: emphasizedDecelerate),
        );
        return ScaleTransition(scale: scaleAnimation, child: child);
      },
      transitionDuration: pageTransition,
    );
  }

  // ============================================================================
  // BEST PRACTICES
  // ============================================================================

  /// Maximum recommended duration for any animation
  static const Duration maxRecommendedDuration = slowest;

  /// Minimum recommended duration for perceivable animation
  static const Duration minRecommendedDuration = fast;

  /// Check if duration is within recommended range
  static bool isRecommendedDuration(Duration duration) {
    return duration >= minRecommendedDuration &&
        duration <= maxRecommendedDuration;
  }
}
