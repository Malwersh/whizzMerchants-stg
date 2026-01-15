import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/floating_support_chat.dart';

/// Floating Chat Overlay Wrapper
/// This widget wraps the main app content and displays the floating chat
/// when activated through the FloatingChatProvider
class FloatingChatWrapper extends ConsumerWidget {
  final Widget child;

  const FloatingChatWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floatingChatState = ref.watch(floatingChatProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Main app content
          child,

          // Floating chat overlay
          if (floatingChatState.isVisible)
            FloatingSupportChat(
              onClose: () {
                ref.read(floatingChatProvider.notifier).hideFloatingChat();
              },
            ),
        ],
      ),
    );
  }
}
