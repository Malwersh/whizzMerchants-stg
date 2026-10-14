import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../core/design_system/design_system.dart';

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
  late AnimationController _rotationController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
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
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double logoSize = (size.width * 0.62).clamp(150.0, 260.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFFDC500), // ✅ خلفية باللون الأساسي (أصفر)
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
                      // ✅ أيقونة WizBussiness (زرقاء PNG شفافة) - حجم أصغر ومتوسط الشاشة
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Image.asset(
                          'assets/images/WizBussinessico.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(height: AppSpacing.xl), // تقليل المسافة

                      // Loading indicator - نقله تحت اللوجو مباشرة
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
            child: _buildBusinessBadge(),
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

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر التحميل الدائري
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    WhizzColors.secondary, // ✅ أزرق للتباين على الخلفية الصفراء
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              // نص التحميل
              Text(
                'جاري التحميل...',
                style: AppTypography.bodyMedium.copyWith(
                  color: WhizzColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBusinessBadge() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return SafeArea(
          top: false,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(minHeight: 38),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: WhizzColors.secondary, // ✅ الأزرق (Secondary)
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Business',
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.primary, // ✅ الأصفر (Primary)
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
