/// Session-Aware Widget Wrapper
/// Automatically handles session state changes and shows appropriate UI

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_state.dart';
import '../providers/advanced_session_provider.dart';

class SessionAwareWrapper extends ConsumerWidget {
  final Widget child;
  final Widget Function(BuildContext context)? onSessionExpired;
  final Widget Function(BuildContext context, String message)? onSessionError;
  final Widget Function(BuildContext context)? onLoading;
  final bool showLoadingOverlay;
  final bool showErrorDialog;
  final bool autoNavigateOnExpired;

  const SessionAwareWrapper({
    super.key,
    required this.child,
    this.onSessionExpired,
    this.onSessionError,
    this.onLoading,
    this.showLoadingOverlay = true,
    this.showErrorDialog = true,
    this.autoNavigateOnExpired = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(currentSessionStateProvider);

    // Listen to session changes
    ref.listen<SessionState>(currentSessionStateProvider, (previous, next) {
      _handleSessionChange(context, previous, next);
    });

    return Stack(
      children: [
        child,
        
        // Loading overlay
        if (showLoadingOverlay && sessionState is SessionLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        sessionState.message ?? 'جاري التحميل...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
        // Refreshing overlay
        if (showLoadingOverlay && sessionState is SessionRefreshing)
          Container(
            color: Colors.black26,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'جاري تحديث الجلسة...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleSessionChange(BuildContext context, SessionState? previous, SessionState current) {
    // Handle session expired
    if (current is SessionExpired) {
      if (showErrorDialog) {
        _showExpiredDialog(context, current);
      }
      if (autoNavigateOnExpired && current.canRefresh == false) {
        _navigateToLogin(context);
      }
    }

    // Handle session error
    if (current is SessionError) {
      if (showErrorDialog) {
        _showErrorDialog(context, current);
      }
      if (current.requiresLogin) {
        _navigateToLogin(context);
      }
    }

    // Handle session terminated
    if (current is SessionTerminated) {
      if (autoNavigateOnExpired) {
        _navigateToLogin(context);
      }
    }
  }

  void _showExpiredDialog(BuildContext context, SessionExpired state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('انتهت الجلسة'),
          content: Text(
            state.reason ?? 'انتهت صلاحية جلستك. يرجى تسجيل الدخول مرة أخرى.',
          ),
          actions: [
            if (state.canRefresh)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Trigger refresh
                  // AdvancedSessionService.instance._refreshToken();
                },
                child: const Text('إعادة المحاولة'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLogin(context);
              },
              child: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );
    });
  }

  void _showErrorDialog(BuildContext context, SessionError state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('خطأ في الجلسة'),
          content: Text(state.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (state.requiresLogin) {
                  _navigateToLogin(context);
                }
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    });
  }

  void _navigateToLogin(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }
}

/// Session Timer Widget - shows remaining session time
class SessionTimerWidget extends ConsumerWidget {
  final TextStyle? style;
  final bool showIcon;

  const SessionTimerWidget({
    super.key,
    this.style,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(currentSessionStateProvider);
    
    if (sessionState is! SessionActive) {
      return const SizedBox.shrink();
    }

    final timeRemaining = sessionState.timeRemaining;
    if (timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final hours = timeRemaining.inHours;
    final minutes = timeRemaining.inMinutes.remainder(60);
    final isExpiringSoon = timeRemaining.inMinutes < 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon)
          Icon(
            Icons.access_time,
            size: 16,
            color: isExpiringSoon ? Colors.red : Colors.grey,
          ),
        if (showIcon) const SizedBox(width: 4),
        Text(
          hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}' : '$minutes دقيقة',
          style: style?.copyWith(
            color: isExpiringSoon ? Colors.red : null,
          ) ?? TextStyle(
            color: isExpiringSoon ? Colors.red : Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Activity Tracker - records user activity
class ActivityTracker extends ConsumerWidget {
  final Widget child;

  const ActivityTracker({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionService = ref.watch(advancedSessionServiceProvider);

    return GestureDetector(
      onTap: () => sessionService.recordActivity(),
      onPanUpdate: (_) => sessionService.recordActivity(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
