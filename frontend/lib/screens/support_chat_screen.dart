// filepath: lib/screens/support_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../core/design_system/design_system.dart';
import '../utils/responsive_helper.dart';
import '../providers/business_provider.dart';
import '../services/support_chat_service.dart';
import '../widgets/floating_support_chat.dart';
import '../widgets/support_category_selector.dart';

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

  // Category selection state
  bool _showCategorySelection = true;
  String? _selectedCategory;
  String? _categoryDescription;

  @override
  void initState() {
    super.initState();
    _chatService = SupportChatService();
    _chatService.addListener(_onServiceStateChanged);
    _loadBusinessData(); // Only load business data, don't auto-connect
  }

  /// Load business data without auto-connecting to chat
  Future<void> _loadBusinessData() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      debugPrint('🔍 SupportChat: Loading business data...');

      // Get business data from business provider
      final businessAsyncValue = ref.read(businessProvider);

      if (businessAsyncValue.isLoading) {
        debugPrint('🔍 SupportChat: Business data is loading, waiting...');
        await Future.delayed(const Duration(milliseconds: 500));
        return _loadBusinessData(); // Retry
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
          '✅ SupportChat: Business loaded - ID: $_businessId, Name: $_merchantName');
    } catch (e) {
      debugPrint('❌ SupportChat: Error loading business data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading business data: $e')),
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

  /// Handle category selection and start appropriate chat flow
  Future<void> _onCategorySelected(String category, String description) async {
    setState(() {
      _selectedCategory = category;
      _categoryDescription = description;
      _showCategorySelection = false;
      _isInitializing = true;
    });

    try {
      await _chatService.startCategorizedChat(
        merchantId: _businessId!,
        merchantName: _merchantName ?? 'Unknown Merchant',
        merchantEmail: _userEmail ?? 'no-email@merchant.com',
        category: category,
        categoryDescription: description,
      );

      debugPrint('✅ Categorized chat started with category: $category');
    } catch (e) {
      debugPrint('❌ Error starting categorized chat: $e');
      // Show error and return to category selection
      setState(() {
        _showCategorySelection = true;
        _isInitializing = false;
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
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
        return _initializeAndConnect(); // Retry
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
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    _chatService.sendMessage(text);
    _controller.clear();
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
      if (mounted) {
        // Navigate back after ending session
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
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
    final isMobile = ResponsiveHelper.isMobile(context);

    // Show category selection screen first
    if (_showCategorySelection) {
      return Scaffold(
        body: SupportCategorySelector(
          onCategorySelected: _onCategorySelected,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    }

    // Get state from service
    final isConnected = _chatService.isConnected;
    final isConnecting = _chatService.isConnecting;
    final messages = _chatService.messages;
    final connectionStatus = _chatService.connectionStatus;
    final error = _chatService.error;

    // Status text
    String statusText;
    if (_isInitializing) {
      statusText = 'Loading...';
    } else if (error != null) {
      statusText = 'Error: $error';
    } else if (connectionStatus == 'session_ended') {
      statusText = 'Session Ended';
    } else if (connectionStatus == 'whizzme_active') {
      statusText = 'WhizzMe AI Assistant';
    } else if (isConnecting) {
      statusText = 'Connecting...';
    } else if (isConnected) {
      statusText = 'Connected to Support';
    } else {
      statusText = 'Disconnected';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Support'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.minimize),
          tooltip: 'Minimize to Floating Chat',
          onPressed: _minimizeToFloatingChat,
        ),
        actions: [
          if (_businessId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: Text(
                  '${_merchantName ?? 'Merchant'} • ${_businessId ?? ''}',
                  style: AppTypography.labelSmall.copyWith(
                      color:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.8)),
                ),
              ),
            ),
          // End Session button
          if (isConnected && connectionStatus != 'session_ended')
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'End Chat Session',
              onPressed: _endSession,
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.sm),
            color: _getStatusColor(isConnected, isConnecting, connectionStatus)
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
                    label:
                        const Text('Reconnect', style: TextStyle(fontSize: 12)),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 64,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Chat with Support',
                          style: AppTypography.headlineSmall.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          _getChatEmptyStateText(connectionStatus, isConnected),
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                      final isWhizzMe = msg.senderType == 'whizzme';

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
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? 280 : 420,
                          ),
                          margin: EdgeInsets.only(
                            bottom: AppSpacing.sm,
                            left: isMe ? AppSpacing.xl : 0,
                            right: isMe ? 0 : AppSpacing.xl,
                          ),
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isMe
                                ? theme.colorScheme.primary
                                : isWhizzMe
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadiusLG,
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
                                      if (isWhizzMe)
                                        Icon(
                                          Icons.smart_toy,
                                          size: 16,
                                          color: Colors.blue.shade600,
                                        ),
                                      if (isWhizzMe) SizedBox(width: 4),
                                      Text(
                                        msg.senderName!,
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          color: isWhizzMe
                                              ? Colors.blue.shade600
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Show image if present
                              if (msg.imageUrl != null &&
                                  msg.imageUrl!.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    // Open image in full screen view
                                    _showImagePreview(context, msg.imageUrl!);
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 280,
                                      maxHeight: 280,
                                      minHeight: 150,
                                    ),
                                    margin:
                                        EdgeInsets.only(bottom: AppSpacing.xs),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Stack(
                                        children: [
                                          Image.network(
                                            msg.imageUrl!,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 200,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme
                                                      .surfaceVariant,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      color: theme
                                                          .colorScheme.primary,
                                                    ),
                                                    SizedBox(
                                                        height: AppSpacing.xs),
                                                    Text(
                                                      'Loading image...',
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                        color: theme.colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              debugPrint(
                                                  '❌ Image load error: $error');
                                              debugPrint(
                                                  'Image URL: ${msg.imageUrl}');
                                              return Container(
                                                height: 150,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      size: 48,
                                                      color: Colors.grey[600],
                                                    ),
                                                    SizedBox(
                                                        height: AppSpacing.xs),
                                                    Text(
                                                      'Failed to load image',
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        height: AppSpacing.xxs),
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        // Try to reload the image
                                                        setState(() {});
                                                      },
                                                      icon: Icon(
                                                        Icons.refresh,
                                                        size: 16,
                                                        color: theme.colorScheme
                                                            .primary,
                                                      ),
                                                      label: Text(
                                                        'Retry',
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          if (msg.isUploading)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors.white),
                                                    ),
                                                    SizedBox(
                                                        height: AppSpacing.xs),
                                                    Text(
                                                      'Uploading...',
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          // Tap indicator overlay
                                          if (!msg.isUploading)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Icon(
                                                  Icons.fullscreen,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (msg.imageUrl != null &&
                                  msg.text.isNotEmpty &&
                                  !msg.text.startsWith('📷'))
                                SizedBox(height: AppSpacing.xs),
                              // Show text if not empty or if no image
                              if (msg.text.isNotEmpty &&
                                  (msg.imageUrl == null ||
                                      !msg.text.startsWith('📷')))
                                Text(
                                  msg.text,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: isMe
                                        ? theme.colorScheme.onPrimary
                                        : isWhizzMe
                                            ? Colors.blue.shade800
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
                                              ? theme.colorScheme.onPrimary
                                              : isWhizzMe
                                                  ? Colors.blue.shade600
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
                                                  ? theme.colorScheme.onPrimary
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
              AppSpacing.sm + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
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
                  onPressed: _isChatAvailable() ? _showAttachmentOptions : null,
                  tooltip: 'Attach Image',
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      _isChatAvailable()
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceVariant,
                    ),
                  ),
                  icon: Icon(
                    Icons.attach_file,
                    color: _isChatAvailable()
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: _isChatAvailable(),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: connectionStatus == 'session_ended'
                          ? 'Session ended'
                          : 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusMD,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: _isChatAvailable()
                      ? _sendMessage
                      : null,
                  tooltip: 'Send Message',
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      _isChatAvailable()
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceVariant,
                    ),
                  ),
                  icon: Icon(
                    Icons.send_rounded,
                    color: _isChatAvailable()
                        ? theme.colorScheme.onPrimary
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
    if (status == 'whizzme_active') return Colors.blue;
    if (isConnected) return WhizzColors.success;
    if (isConnecting) return WhizzColors.warning;
    return WhizzColors.error;
  }

  IconData _getStatusIcon(bool isConnected, bool isConnecting, String status) {
    if (status == 'session_ended') return Icons.block;
    if (status == 'whizzme_active') return Icons.smart_toy;
    if (isConnected) return Icons.check_circle;
    if (isConnecting) return Icons.sync;
    return Icons.error_outline;
  }

  /// Check if chat is available for interaction (WhizzMe or human agent)
  bool _isChatAvailable() {
    final connectionStatus = _chatService.connectionStatus;
    return (connectionStatus == 'whizzme_active' || _chatService.isConnected) &&
        connectionStatus != 'session_ended';
  }

  String _getChatEmptyStateText(String connectionStatus, bool isConnected) {
    if (connectionStatus == 'whizzme_active') {
      return 'WhizzMe AI is ready to help! Send a message to get started.';
    } else if (isConnected) {
      return 'Send a message to start the conversation';
    } else {
      return 'Connecting to support...';
    }
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Show image in full screen preview
  void _showImagePreview(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ImagePreviewScreen(imageUrl: imageUrl),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

/// Full screen image preview widget
class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;

  const ImagePreviewScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Image Preview',
          style: AppTypography.headlineSmall.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Share functionality could be added here
            },
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Loading image...',
                      style: AppTypography.bodyMedium
                          .copyWith(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.white70,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Failed to load image',
                      style:
                          AppTypography.bodyLarge.copyWith(color: Colors.white),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: Text(
                        'Go Back',
                        style: AppTypography.bodyMedium
                            .copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
