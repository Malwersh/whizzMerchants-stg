import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

/// A circular timer widget that displays order timeout with color-coded progress
class CircularOrderTimer extends StatefulWidget {
  final String orderId;
  final DateTime createdAt;
  final int totalMinutes; // Total timeout duration in minutes
  final double size; // Size of the circular timer
  final VoidCallback? onTimeUp; // Callback when timer reaches zero
  final Future<void> Function(String orderId)? onAutoReject; // Callback for auto-rejecting order
  final bool showText; // Whether to show time text in center
  final Color? backgroundColor; // Background circle color
  final double strokeWidth; // Width of the progress stroke

  const CircularOrderTimer({
    super.key,
    required this.orderId,
    required this.createdAt,
    this.totalMinutes = 10, // Default 10 minutes
    this.size = 60.0,
    this.onTimeUp,
    this.onAutoReject,
    this.showText = true,
    this.backgroundColor,
    this.strokeWidth = 4.0,
  });

  @override
  State<CircularOrderTimer> createState() => _CircularOrderTimerState();
}

class _CircularOrderTimerState extends State<CircularOrderTimer>
    with TickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _animationController;
  
  double _remainingSeconds = 0;
  double _totalSeconds = 0;
  bool _isTimeUp = false;

  @override
  void initState() {
    super.initState();
    
    _totalSeconds = widget.totalMinutes * 60.0; // Convert minutes to seconds
    _calculateRemainingTime();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: Duration(seconds: _remainingSeconds.toInt()),
      vsync: this,
    );
    
    // Start the countdown
    _startTimer();
    
    // Start the animation
    if (_remainingSeconds > 0) {
      _animationController.forward();
    }
  }

  void _calculateRemainingTime() {
    final elapsed = DateTime.now().difference(widget.createdAt);
    _remainingSeconds = _totalSeconds - elapsed.inSeconds;
    
    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      _isTimeUp = true;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _calculateRemainingTime();
        
        if (_isTimeUp) {
          timer.cancel();
          _animationController.stop();
          
          // Execute auto-reject callback if provided
          widget.onAutoReject?.call(widget.orderId);
          
          // Also call onTimeUp for backward compatibility
          widget.onTimeUp?.call();
        }
      });
    });
  }

  /// Get color based on remaining time percentage
  Color _getProgressColor() {
    final progress = _remainingSeconds / _totalSeconds;
    
    if (progress > 0.6) {
      // Green zone (60% - 100% remaining)
      return Colors.green;
    } else if (progress > 0.3) {
      // Yellow zone (30% - 60% remaining)
      return Colors.orange;
    } else if (progress > 0.1) {
      // Light red zone (10% - 30% remaining)
      return Colors.red.shade400;
    } else {
      // Dark red zone (0% - 10% remaining)
      return Colors.red.shade800;
    }
  }

  /// Format remaining time as MM:SS
  String _formatTime() {
    final minutes = (_remainingSeconds / 60).floor();
    final seconds = (_remainingSeconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get urgency level for visual effects
  int _getUrgencyLevel() {
    final progress = _remainingSeconds / _totalSeconds;
    
    if (progress > 0.6) return 0; // Normal
    if (progress > 0.3) return 1; // Warning
    if (progress > 0.1) return 2; // Urgent
    return 3; // Critical
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgencyLevel = _getUrgencyLevel();
    final progressColor = _getProgressColor();
    final progress = _isTimeUp ? 0.0 : _remainingSeconds / _totalSeconds;
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.backgroundColor ?? Colors.grey.shade200,
              boxShadow: urgencyLevel >= 2 ? [
                BoxShadow(
                  color: progressColor.withValues(alpha: 0.3),
                  blurRadius: urgencyLevel >= 3 ? 8.0 : 4.0,
                  spreadRadius: urgencyLevel >= 3 ? 2.0 : 1.0,
                ),
              ] : null,
            ),
          ),
          
          // Progress indicator
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: CircularTimerPainter(
              progress: progress,
              color: progressColor,
              backgroundColor: widget.backgroundColor ?? Colors.grey.shade200,
              strokeWidth: widget.strokeWidth,
              urgencyLevel: urgencyLevel,
            ),
          ),
          
          // Center content
          if (widget.showText) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Time text
                Text(
                  _formatTime(),
                  style: TextStyle(
                    fontSize: widget.size * 0.2, // Responsive font size
                    fontWeight: FontWeight.bold,
                    color: _isTimeUp ? Colors.red.shade800 : progressColor,
                  ),
                ),
                
                // Status indicator
                if (urgencyLevel >= 2)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: progressColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
          
          // Critical state overlay
          if (_isTimeUp)
            Icon(
              Icons.warning_rounded,
              color: Colors.red.shade800,
              size: widget.size * 0.4,
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the circular timer progress
class CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final int urgencyLevel;

  CircularTimerPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.urgencyLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);
    
    // Background circle paint
    final backgroundPaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    // Progress arc paint
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    // Add glow effect for urgent states
    if (urgencyLevel >= 2) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2
        ..strokeCap = StrokeCap.round;
      
      canvas.drawCircle(center, radius, glowPaint);
    }
    
    // Draw background circle
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw progress arc
    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress; // Sweep based on progress
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
    
    // Add pulsing effect for critical state
    if (urgencyLevel >= 3 && progress > 0) {
      final pulsePaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.5
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        pulsePaint,
      );
    }
  }

  @override
  bool shouldRepaint(CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.urgencyLevel != urgencyLevel;
  }
}
