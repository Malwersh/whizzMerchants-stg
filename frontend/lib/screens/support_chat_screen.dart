// filepath: lib/screens/support_chat_screen.dart
import '../widgets/support_attachment_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../core/design_system/design_system.dart';
import '../utils/responsive_helper.dart';
import '../providers/business_provider.dart';
import '../services/support_chat_service.dart';
import '../widgets/floating_support_chat.dart';

/// Support chat screen using singleton service
/// Maintains session across navigation - doesn't create new sessions unnecessarily
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  // Use singleton service instance
  late final SupportChatService _chatService;

  String? _businessId;
  String? _merchantName;
  String? _userEmail;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _chatService = SupportChatService();
    _chatService.addListener(_onServiceStateChanged);
    _initializeAndConnect();
  }

  /// Listen to service state changes and update UI
  void _onServiceStateChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when service state changes
      });
      _scrollToBottom();
    }
  }

  /// Scroll to bottom of messages
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Initialize business context and connect to support
  Future<void> _initializeAndConnect() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      debugPrint('🔍 SupportChat: Starting initialization...');

      // Get business data from business provider
      final businessAsyncValue = ref.read(businessProvider);

      debugPrint(
          '🔍 SupportChat: Business provider state - loading: ${businessAsyncValue.isLoading}, hasValue: ${businessAsyncValue.hasValue}, hasError: ${businessAsyncValue.hasError}');

      if (businessAsyncValue.isLoading) {
        debugPrint('🔍 SupportChat: Business data is loading, waiting...');
        // Wait for business data to load
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        return await _initializeAndConnect(); // Retry
      }

      if (businessAsyncValue.hasError) {
        debugPrint(
            '❌ SupportChat: Business provider error: ${businessAsyncValue.error}');
        throw Exception(
            'Failed to load business data: ${businessAsyncValue.error}');
      }

      final business = businessAsyncValue.value;

      if (business == null) {
        debugPrint('❌ SupportChat: No business data found');
        throw Exception('No business data found - please complete onboarding');
      }

      _businessId = business.id;
      _merchantName = business.name;
      _userEmail = business.email;

      debugPrint(
          '✅ SupportChat: Business loaded - ID: $_businessId, Name: $_merchantName, Email: $_userEmail');

      // Connect to support using service
      await _chatService.connectToSupport(
        merchantId: _businessId!,
        merchantName: _merchantName ?? 'Unknown Merchant',
        merchantEmail: _userEmail ?? 'no-email@merchant.com',
      );

      debugPrint('✅ SupportChat: Successfully connected to support');
    } catch (e) {
      debugPrint('❌ SupportChat: Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not load business info'),
            backgroundColor: WhizzColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// Send a message
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    final sent = await _chatService.sendMessage(text);
    if (sent && mounted && _controller.text.trim() == text) _controller.clear();
  }

  /// Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        await _sendImageMessage(File(image.path));
      }
    } catch (e) {
      debugPrint('❌ Error picking image from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  /// Take photo with camera
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (photo != null) {
        await _sendImageMessage(File(photo.path));
      }
    } catch (e) {
      debugPrint('❌ Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  /// Send image message
  Future<void> _sendImageMessage(File imageFile) async {
    // Show dialog to add optional caption
    final caption = await showDialog<String>(
      context: context,
      builder: (context) {
        final captionController = TextEditingController();
        return AlertDialog(
          title: const Text('Add Caption (Optional)'),
          content: TextField(
            controller: captionController,
            decoration: const InputDecoration(
              hintText: 'Enter caption...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, captionController.text),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (caption != null) {
      await _chatService.sendImageMessage(
        imageFile,
        caption.isEmpty ? null : caption,
      );
      _scrollToBottom();
    }
  }

  /// Show attachment options
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Minimize chat to floating widget
  void _minimizeToFloatingChat() {
    // Activate floating chat through provider
    ref.read(floatingChatProvider.notifier).showFloatingChat();

    // Close current screen
    Navigator.of(context).pop();
  }

  /// End the chat session
  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Chat Session?'),
        content: const Text(
          'Are you sure you want to end this chat session? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WhizzColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatService.endSession();
    }
  }

  @override
  void dispose() {
    _chatService.removeListener(_onServiceStateChanged);
    // Don't disconnect - let service persist for navigation
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final chatSurface = dark ? const Color(0xFF18181B) : Colors.white;
    final neutralFill =
        dark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
    final neutralInk = dark ? const Color(0xFFF4F4F5) : const Color(0xFF27272A);
    final actionColor =
        dark ? const Color(0xFFE4E4E7) : const Color(0xFF27272A);
    final actionInk = dark ? const Color(0xFF18181B) : Colors.white;
    final isMobile = ResponsiveHelper.isMobile(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String label(String ar, String en) => isArabic ? ar : en;

    // Get state from service
    final isConnected = _chatService.isConnected;
    final isConnecting = _chatService.isConnecting;
    final messages = _chatService.messages;
    final connectionStatus = _chatService.connectionStatus;
    final error = _chatService.error;

    // Status text
    String statusText;
    if (_isInitializing) {
      statusText = label('جارٍ تجهيز المحادثة', 'Preparing conversation');
    } else if (error != null) {
      statusText = error;
    } else if (connectionStatus == 'session_ended') {
      statusText = label('انتهت المحادثة', 'Conversation ended');
    } else if (isConnecting) {
      statusText = label('جارٍ الاتصال', 'Connecting');
    } else if (isConnected) {
      statusText = label('متصل بفريق الدعم', 'Connected to support');
    } else {
      statusText = label('غير متصل', 'Disconnected');
    }

    return Scaffold(
      backgroundColor: chatSurface,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: chatSurface,
        foregroundColor: theme.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: label('تصغير المحادثة', 'Minimize conversation'),
          onPressed: _minimizeToFloatingChat,
        ),
        title: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: neutralFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.support_agent_rounded, color: neutralInk),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label('فريق دعم ويز', 'Whizz support'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: _getStatusColor(
                            isConnected, isConnecting, connectionStatus),
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(
                        error != null
                            ? label('تعذر الاتصال', 'Connection unavailable')
                            : statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant))),
              ]),
            ],
          )),
        ]),
        actions: [
          if (isConnected && connectionStatus != 'session_ended')
            PopupMenuButton<String>(
              tooltip: label('خيارات المحادثة', 'Conversation options'),
              onSelected: (_) => _endSession(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'end',
                  child: Row(children: [
                    Icon(Icons.stop_circle_outlined,
                        color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 10),
                    Text(label('إنهاء المحادثة', 'End conversation')),
                  ]),
                )
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Keep connection problems visible without duplicating the header.
          if (!isConnected)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.sm),
              color:
                  _getStatusColor(isConnected, isConnecting, connectionStatus)
                      .withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(isConnected, isConnecting, connectionStatus),
                    size: 18,
                    color: _getStatusColor(
                        isConnected, isConnecting, connectionStatus),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: AppTypography.bodySmall.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (!isConnected &&
                      !isConnecting &&
                      !_isInitializing &&
                      connectionStatus != 'session_ended')
                    TextButton.icon(
                      onPressed: _initializeAndConnect,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(label('إعادة الاتصال', 'Reconnect'),
                          style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                ],
              ),
            ),
          // Messages area
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: chatSurface, shape: BoxShape.circle),
                            child: Icon(Icons.chat_bubble_outline_rounded,
                                size: 42, color: neutralInk),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            label('شلون نكدر نساعدك؟', 'How can we help?'),
                            style: AppTypography.headlineSmall.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            connectionStatus == 'session_ended'
                                ? label('انتهت هذه المحادثة',
                                    'This conversation has ended')
                                : isConnected
                                    ? label(
                                        'اكتب سؤالك أو أرفق صورة، وفريق الدعم يساعدك.',
                                        'Send your question or a photo to our support team.')
                                    : label('نجهّز اتصالك بفريق الدعم…',
                                        'Connecting you with our support team…'),
                            style: AppTypography.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderType == 'merchant';
                      final isSystem = msg.senderType == 'system';

                      // System messages (like session ended) - centered
                      if (isSystem) {
                        return Container(
                          margin: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: AppSpacing.md,
                          ),
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadiusLG,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  msg.text,
                                  style: AppTypography.bodySmall.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Regular messages
                      return Align(
                        alignment: isMe
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isMobile
                                ? MediaQuery.sizeOf(context).width * 0.78
                                : 480,
                          ),
                          margin: EdgeInsets.only(
                            bottom: AppSpacing.sm,
                            left: isMe ? AppSpacing.xl : 0,
                            right: isMe ? 0 : AppSpacing.xl,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: isMe
                                ? null
                                : Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5)),
                            color: isMe ? neutralFill : chatSurface,
                            borderRadius: BorderRadiusDirectional.only(
                              topStart: const Radius.circular(20),
                              topEnd: const Radius.circular(20),
                              bottomStart: Radius.circular(isMe ? 20 : 6),
                              bottomEnd: Radius.circular(isMe ? 6 : 20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe && msg.senderName != null)
                                Padding(
                                  padding:
                                      EdgeInsets.only(bottom: AppSpacing.xxs),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg.senderName!,
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Show image if present
                              if (msg.attachmentId != null &&
                                  !msg.isUploading &&
                                  !['pending', 'unknown', 'failed']
                                      .contains(msg.deliveryStatus))
                                SupportAttachmentImage(
                                  key: ValueKey(
                                      '${_chatService.sessionId}/${msg.attachmentId}'),
                                  load: () => _chatService
                                      .loadAttachment(msg.attachmentId!),
                                ),
                              // Show text if not empty or if no image
                              if (msg.text.isNotEmpty &&
                                  (msg.attachmentId == null ||
                                      !msg.text.startsWith('📷')))
                                Text(
                                  msg.text,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: isMe
                                        ? neutralInk
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              if (msg.deliveryStatus != null)
                                Text(
                                  switch (msg.deliveryStatus) {
                                    'pending' => 'بانتظار تأكيد الخدمة',
                                    'accepted' => 'حُفظت لدى الخدمة',
                                    'failed' => 'تعذر إرسال الصورة؛ لم تُرسل',
                                    _ =>
                                      'لم يتأكد الإرسال؛ تحقق قبل إعادة الإرسال',
                                  },
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isMe
                                        ? neutralInk
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              SizedBox(height: AppSpacing.xs),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTimestamp(msg.timestamp),
                                    style: AppTypography.labelSmall.copyWith(
                                      color: (isMe
                                              ? neutralInk
                                              : theme.colorScheme.onSurface)
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  if (msg.isUploading) ...[
                                    SizedBox(width: AppSpacing.xs),
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          (isMe
                                                  ? neutralInk
                                                  : theme.colorScheme.onSurface)
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Message input
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm +
                  (MediaQuery.viewInsetsOf(context).bottom > 0
                      ? 0
                      : MediaQuery.paddingOf(context).bottom),
            ),
            decoration: BoxDecoration(
              color: chatSurface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Attachment button - BEFORE text field for better visibility
                IconButton(
                  onPressed:
                      _chatService.isConnected ? _showAttachmentOptions : null,
                  tooltip: 'إرفاق صورة بعد الاتصال بموظف الدعم',
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      _isChatAvailable() ? neutralFill : neutralFill,
                    ),
                  ),
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: _isChatAvailable()
                        ? neutralInk
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: connectionStatus != 'session_ended',
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: connectionStatus == 'session_ended'
                          ? label('انتهت المحادثة', 'Conversation ended')
                          : label('اكتب رسالتك…', 'Write a message…'),
                      filled: true,
                      fillColor: neutralFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: neutralInk)),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: _isChatAvailable() ? _sendMessage : null,
                  tooltip: label('إرسال الرسالة', 'Send message'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      _isChatAvailable() ? actionColor : neutralFill,
                    ),
                  ),
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    color: _isChatAvailable()
                        ? actionInk
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(bool isConnected, bool isConnecting, String status) {
    if (status == 'session_ended') return WhizzColors.error;
    if (isConnected) return WhizzColors.success;
    if (isConnecting) return WhizzColors.warning;
    return WhizzColors.error;
  }

  IconData _getStatusIcon(bool isConnected, bool isConnecting, String status) {
    if (status == 'session_ended') return Icons.block;
    if (isConnected) return Icons.check_circle;
    if (isConnecting) return Icons.sync;
    return Icons.error_outline;
  }

  /// Check whether the support team connection is ready.
  bool _isChatAvailable() {
    final connectionStatus = _chatService.connectionStatus;
    return _chatService.isConnected && connectionStatus != 'session_ended';
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
