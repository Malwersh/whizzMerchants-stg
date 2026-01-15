import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../l10n/app_localizations.dart';

/// Unique Splash Screen for Whizz Merchant App
/// Features animated yellow accents and modern design
class SplashScreen extends ConsumerStatefulWidget {
  final Widget nextScreen;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.nextScreen,
    this.duration = const Duration(seconds: 3),
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startSplashSequence();
  }

  void _initializeAnimations() {
    // Main animation controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Pulse animation controller for glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    // Rotation controller for decorative elements
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    // Scale animation with bounce
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    // Slide animation for text
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    // Pulse animation for glow
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);
  }

  void _startSplashSequence() async {
    // Start main animation
    _mainController.forward();

    // Wait for duration then navigate
    await Future.delayed(widget.duration);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: WhizzColors.white,
      body: Stack(
        children: [
          // Animated background decorations
          _buildBackgroundDecorations(size),

          // Main content
          Center(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated logo/brand section
                      _buildAnimatedLogo(),

                      SizedBox(height: AppSpacing.xxl),

                      // App name with slide animation
                      Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: _buildAppName(),
                      ),

                      SizedBox(height: AppSpacing.md),

                      // Tagline with fade
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: _buildTagline(),
                      ),

                      SizedBox(height: AppSpacing.xxl * 2),

                      // Loading indicator
                      _buildLoadingIndicator(),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer
          Positioned(
            bottom: AppSpacing.xxl,
            left: 0,
            right: 0,
            child: _buildFooter(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations(Size size) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Top-right yellow circle
            Positioned(
              top: -size.height * 0.15,
              right: -size.width * 0.2,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        WhizzColors.primary.withValues(alpha: 0.15),
                        WhizzColors.primary.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom-left yellow circle
            Positioned(
              bottom: -size.height * 0.1,
              left: -size.width * 0.15,
              child: Transform.rotate(
                angle: -_rotationAnimation.value,
                child: Container(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        WhizzColors.primary.withValues(alpha: 0.2),
                        WhizzColors.primary.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating yellow accent squares
            ...List.generate(3, (index) {
              final angle =
                  _rotationAnimation.value + (index * math.pi * 2 / 3);
              final radius = size.width * 0.35;
              return Positioned(
                top: size.height / 2 + math.sin(angle) * radius - 15,
                left: size.width / 2 + math.cos(angle) * radius - 15,
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: WhizzColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: WhizzColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: WhizzColors.primary,
              boxShadow: [
                BoxShadow(
                  color: WhizzColors.primary
                      .withValues(alpha: 0.4 * _pulseAnimation.value),
                  blurRadius: 40 * _pulseAnimation.value,
                  spreadRadius: 10 * (_pulseAnimation.value - 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Image.asset(
                'assets/images/whizz_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppName() {
    return Column(
      children: [
        Text(
          'WHIZZ',
          style: AppTypography.displayMedium.copyWith(
            color: WhizzColors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: AppSpacing.xxs, // 4px
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: WhizzColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          ),
          child: Text(
            AppLocalizations.of(context)!.merchants,
            style: AppTypography.labelLarge.copyWith(
              color: WhizzColors.black,
              fontWeight: FontWeight.bold,
              letterSpacing: AppSpacing.xxs, // 4px (was 3)
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return Text(
      AppLocalizations.of(context)!.splashTagline,
      style: AppTypography.bodyMedium.copyWith(
        color: WhizzColors.grey600,
        // letterSpacing already handled by AppTypography
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: AdaptiveLoadingIndicator(
            color: WhizzColors.primary,
            size: 40,
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value * 0.6,
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)!.poweredByWhizz,
                style: AppTypography.bodySmall.copyWith(
                  color: WhizzColors.grey500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: AppSpacing.xxs, // 4px (was hardcoded)
                    height: AppSpacing.xxs, // 4px
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: WhizzColors.primary,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'v1.0.0', // Static version for now
                    style: AppTypography.bodySmall.copyWith(
                      color: WhizzColors.grey400,
                      // Removed hardcoded fontSize: 11
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
