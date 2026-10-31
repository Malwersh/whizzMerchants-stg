import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/support_chat_service.dart';
import '../screens/support_chat_screen.dart';

/// Floating Support Chat Widget
/// Provides a minimized chat interface that can float over other screens
class FloatingSupportChat extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const FloatingSupportChat({
    Key? key,
    this.onClose,
  }) : super(key: key);

  @override
  ConsumerState<FloatingSupportChat> createState() =>
      _FloatingSupportChatState();
}

class _FloatingSupportChatState extends ConsumerState<FloatingSupportChat>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final SupportChatService _chatService = SupportChatService();

  bool _isExpanded = false;
  bool _isDragging = false;
  Offset _position = const Offset(20, 100); // Initial position

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _chatService.addListener(_onChatUpdate);
    _animationController.forward();
  }

  void _onChatUpdate() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when chat updates
      });
    }
  }

  @override
  void dispose() {
    _chatService.removeListener(_onChatUpdate);
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    if (_isExpanded) {
      // Minimize
      setState(() {
        _isExpanded = false;
      });
    } else {
      // Open full chat screen
      _openFullChat();
    }
  }

  void _openFullChat() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const SupportChatScreen(),
      ),
    )
        .then((_) {
      // When coming back from full chat, keep floating widget
      setState(() {});
    });
  }

  void _closeFloatingChat() {
    _animationController.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    // Get unread messages count
    final unreadCount = _chatService.messages
        .where((msg) => msg.senderType != 'merchant')
        .length;

    final hasUnreadMessages = unreadCount > 0;
    final isConnected = _chatService.isConnected;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _isDragging = true;
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    (_position.dx + details.delta.dx)
                        .clamp(0.0, screenSize.width - 60),
                    (_position.dy + details.delta.dy)
                        .clamp(0.0, screenSize.height - 60),
                  );
                });
              },
              onPanEnd: (details) {
                setState(() {
                  _isDragging = false;
                });

                // Snap to edges
                final centerX = screenSize.width / 2;
                final newX =
                    _position.dx < centerX ? 20.0 : screenSize.width - 80;

                setState(() {
                  _position = Offset(newX, _position.dy);
                });
              },
              onTap: _toggleExpanded,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Main icon
                    Center(
                      child: Icon(
                        Icons.support_agent,
                        color: theme.colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),

                    // Connection status indicator
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isConnected ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.onPrimary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    // Unread messages badge
                    if (hasUnreadMessages)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.onPrimary,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                    // Close button (show on long press or when dragging)
                    if (_isDragging)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: _closeFloatingChat,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Provider for managing floating chat state
final floatingChatProvider =
    StateNotifierProvider<FloatingChatNotifier, FloatingChatState>((ref) {
  return FloatingChatNotifier();
});

class FloatingChatState {
  final bool isVisible;
  final bool isMinimized;

  const FloatingChatState({
    this.isVisible = false,
    this.isMinimized = true,
  });

  FloatingChatState copyWith({
    bool? isVisible,
    bool? isMinimized,
  }) {
    return FloatingChatState(
      isVisible: isVisible ?? this.isVisible,
      isMinimized: isMinimized ?? this.isMinimized,
    );
  }
}

class FloatingChatNotifier extends StateNotifier<FloatingChatState> {
  FloatingChatNotifier() : super(const FloatingChatState());

  void showFloatingChat() {
    state = state.copyWith(isVisible: true, isMinimized: true);
  }

  void hideFloatingChat() {
    state = state.copyWith(isVisible: false);
  }

  void toggleMinimized() {
    state = state.copyWith(isMinimized: !state.isMinimized);
  }
}
