import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'whizzme_service.dart';
import '../config/app_config.dart';

/// Chat Message Model
class ChatMessage {
  final String id;
  final String text;
  final String senderType; // 'merchant', 'agent', 'system'
  final DateTime timestamp;
  final String? senderName;
  final String? imageUrl; // URL for attached image
  final String? imageType; // 'image/jpeg', 'image/png', etc.
  final bool isUploading; // Track upload state

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderType,
    required this.timestamp,
    this.senderName,
    this.imageUrl,
    this.imageType,
    this.isUploading = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['messageId'] ?? json['id'] ?? '',
      text: json['text'] ?? '',
      senderType: json['senderType'] ?? 'merchant',
      timestamp:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      senderName: json['senderName'],
      imageUrl: json['imageUrl'],
      imageType: json['imageType'],
      isUploading: false,
    );
  }

  // Create copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? text,
    String? senderType,
    DateTime? timestamp,
    String? senderName,
    String? imageUrl,
    String? imageType,
    bool? isUploading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      senderType: senderType ?? this.senderType,
      timestamp: timestamp ?? this.timestamp,
      senderName: senderName ?? this.senderName,
      imageUrl: imageUrl ?? this.imageUrl,
      imageType: imageType ?? this.imageType,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

/// Support Chat Service for WhizzMerchants
/// Connects merchants to WizzCentral support agents via WebSocket
///
/// SINGLETON: Persists across navigation to maintain chat sessions
class SupportChatService extends ChangeNotifier {
  // Singleton instance
  static final SupportChatService _instance = SupportChatService._internal();
  factory SupportChatService() => _instance;
  SupportChatService._internal();

  // WebSocket Configuration
    static String get wsUrl => AppConfig.supportChatWebSocketUrl;

  // WebSocket channel
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // State
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _sessionEnded = false; // Track if session was explicitly ended
  String? _sessionId;
  String? _merchantId;
  String? _merchantName;
  String? _merchantEmail;
  List<ChatMessage> _messages = [];
  String? _error;
  String _connectionStatus = 'disconnected';

  // WhizzMe Integration
  final WhizzMeService _whizzMe = WhizzMeService();
  bool _whizzMeActive = true; // WhizzMe handles initial conversation
  bool _humanAgentRequested = false;

  // Add selected category tracking
  String? _selectedCategory;
  String? _categoryDescription;

  // Getters for category info
  String? get selectedCategory => _selectedCategory;
  String? get categoryDescription => _categoryDescription;

  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get sessionId => _sessionId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get error => _error;
  String get connectionStatus => _connectionStatus;
  bool get isWhizzMeActive => _whizzMeActive;
  bool get hasRequestedHuman => _humanAgentRequested;

  /// Check if there's an active session for this merchant
  bool hasActiveSession(String merchantId) {
    return _isConnected &&
        !_sessionEnded &&
        _merchantId == merchantId &&
        _sessionId != null;
  }

  /// Resume existing session (when navigating back to chat)
  void resumeSession() {
    debugPrint('🔄 Resuming existing session: $_sessionId');
    // Session is already active, just notify listeners to refresh UI
    notifyListeners();
  }

  /// Connect merchant to support chat
  /// Reuses existing session if available and not ended
  Future<void> connectToSupport({
    required String merchantId,
    required String merchantName,
    required String merchantEmail,
  }) async {
    // Check if we already have an active session for this merchant
    if (hasActiveSession(merchantId)) {
      debugPrint('✅ Reusing existing session: $_sessionId');
      resumeSession();
      return;
    }

    if (_isConnecting) {
      debugPrint('⚠️ Already connecting, please wait');
      return;
    }

    try {
      _isConnecting = true;
      _connectionStatus = 'connecting';
      _error = null;
      _sessionEnded = false;
      notifyListeners();

      _merchantId = merchantId;
      _merchantName = merchantName;
      _merchantEmail = merchantEmail;

      // Create new session ID only if no active session
      if (_sessionId == null || _sessionEnded) {
        _sessionId =
            'merchant_${DateTime.now().millisecondsSinceEpoch}_$merchantId';
        _messages.clear(); // Clear old messages when starting new session
        debugPrint('🆕 Creating new session: $_sessionId');
        
        // Initialize WhizzMe for new sessions
        await _initializeWhizzMe(merchantId, merchantName);
      }

      // If WhizzMe is handling the conversation, don't connect to WebSocket yet
      if (_whizzMeActive && !_humanAgentRequested) {
        debugPrint('🤖 WhizzMe is active - staying in AI mode');
        _isConnected = false; // Not connected to human agents yet
        _isConnecting = false;
        _connectionStatus = 'whizzme_active';
        notifyListeners();
        debugPrint('✅ WhizzMe chat session started');
        return;
      }

      // Connect to WebSocket only when human agent is needed
      _connectToHumanAgent();
    } catch (e) {
      _error = 'Failed to connect: $e';
      _isConnected = false;
      _isConnecting = false;
      _connectionStatus = 'error';
      notifyListeners();
      debugPrint('❌ Connection error: $e');
    }
  }

  /// Send merchant connect handshake
  void _sendMerchantConnect() {
    final message = {
      'action': 'chat_merchant_connect',
      'type': 'chat_merchant_connect',
      'merchantId': _merchantId,
      'merchantName': _merchantName,
      'merchantEmail': _merchantEmail,
      'sessionId': _sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(message);
    debugPrint('📤 Sent merchant connect handshake');
  }

  /// Send a chat message
  Future<void> sendChatMessage(String text) async {
    if (!_isConnected || _sessionId == null) {
      _error = 'Not connected to support';
      notifyListeners();
      return;
    }

    if (text.trim().isEmpty) {
      return;
    }

    final messageId =
        'msg_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomId()}';
    final timestamp = DateTime.now();

    // Optimistic UI update
    final optimisticMessage = ChatMessage(
      id: messageId,
      text: text,
      senderType: 'merchant',
      timestamp: timestamp,
      senderName: _merchantName,
    );

    _messages.add(optimisticMessage);
    notifyListeners();

    // Send to server
    final message = {
      'action': 'chat_message',
      'type': 'chat_message',
      'sessionId': _sessionId,
      'message': text,
      'senderType': 'merchant',
      'merchantId': _merchantId,
      'merchantName': _merchantName,
      'merchantEmail': _merchantEmail,
      'timestamp': timestamp.toIso8601String(),
    };

    _sendMessage(message);
    debugPrint(
        '📤 Sent message: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
  }

  /// Send a chat message with image attachment
  Future<void> sendImageMessage(File imageFile, String? caption) async {
    if (!_isConnected || _sessionId == null) {
      _error = 'Not connected to support';
      notifyListeners();
      return;
    }

    final messageId =
        'msg_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomId()}';
    final timestamp = DateTime.now();

    // Create optimistic message with upload indicator
    final optimisticMessage = ChatMessage(
      id: messageId,
      text: caption ?? '📷 Image',
      senderType: 'merchant',
      timestamp: timestamp,
      senderName: _merchantName,
      isUploading: true,
    );

    _messages.add(optimisticMessage);
    notifyListeners();

    try {
      // Upload image to S3
      debugPrint('📤 Uploading image to S3...');
      final imageUrl = await _uploadImageToS3(imageFile, messageId);

      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      debugPrint('✅ Image uploaded: $imageUrl');

      // Update message with image URL
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          imageUrl: imageUrl,
          isUploading: false,
        );
        notifyListeners();
      }

      // Send message with image URL to server
      final message = {
        'action': 'chat_message',
        'type': 'chat_message',
        'sessionId': _sessionId,
        'message': caption ?? '📷 Image',
        'senderType': 'merchant',
        'merchantId': _merchantId,
        'merchantName': _merchantName,
        'merchantEmail': _merchantEmail,
        'timestamp': timestamp.toIso8601String(),
        'imageUrl': imageUrl,
        'imageType': imageFile.path.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg',
      };

      _sendMessage(message);
      debugPrint('📤 Sent image message');
    } catch (e) {
      debugPrint('❌ Error sending image: $e');
      _error = 'Failed to send image: $e';

      // Update message to show error
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          text: '❌ Failed to upload image',
          isUploading: false,
        );
        notifyListeners();
      }
    }
  }

  /// Upload image to S3 and return the URL
  Future<String?> _uploadImageToS3(File imageFile, String messageId) async {
    try {
      final extension = imageFile.path.split('.').last.toLowerCase();
      final fileName = '$messageId.$extension';

      // Step 1: Get presigned URL from backend
      // TODO: Switch back to AWS endpoint when Lambda is deployed
      final presignedUrlEndpoint = 'http://localhost:3000/support/upload-image';
      // Production: 'https://bx4snzqxpd.execute-api.us-east-1.amazonaws.com/ghayth/support/upload-image';

      final presignedResponse = await http.get(
        Uri.parse(presignedUrlEndpoint).replace(queryParameters: {
          'sessionId': _sessionId!,
          'merchantId': _merchantId!,
          'fileName': fileName,
        }),
      );

      if (presignedResponse.statusCode != 200) {
        debugPrint(
            '❌ Failed to get presigned URL: ${presignedResponse.statusCode}');
        debugPrint('Response: ${presignedResponse.body}');
        return null;
      }

      final presignedData = jsonDecode(presignedResponse.body);
      final presignedUrl = presignedData['presignedUrl'] as String?;
      final imageUrl = presignedData['imageUrl'] as String?;

      if (presignedUrl == null || imageUrl == null) {
        debugPrint('❌ Invalid presigned URL response');
        return null;
      }

      debugPrint('✅ Got presigned URL, uploading image...');

      // Step 2: Upload image directly to S3 using presigned URL
      final bytes = await imageFile.readAsBytes();
      final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

      final uploadResponse = await http.put(
        Uri.parse(presignedUrl),
        headers: {
          'Content-Type': contentType,
        },
        body: bytes,
      );

      if (uploadResponse.statusCode == 200) {
        debugPrint('✅ Image uploaded successfully: $imageUrl');
        return imageUrl;
      } else {
        debugPrint('❌ S3 upload failed: ${uploadResponse.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }

  /// Handle incoming WebSocket messages
  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      debugPrint('📥 Received message type: $type');

      switch (type) {
        case 'chat_session_created':
          _handleSessionCreated(json);
          break;
        case 'chat_message':
          _handleChatMessage(json);
          break;
        case 'agent_connected':
          _handleAgentConnected(json);
          break;
        case 'agent_typing':
          _handleAgentTyping(json);
          break;
        case 'session_closed':
        case 'chat_session_close_ack':
          _handleSessionClosed(json);
          break;
        case 'error':
          _error = json['message'] as String? ?? 'Unknown error';
          notifyListeners();
          break;
        default:
          debugPrint('⚠️ Unhandled message type: $type');
      }
    } catch (e) {
      debugPrint('❌ Error parsing message: $e');
    }
  }

  /// Handle session created confirmation
  void _handleSessionCreated(Map<String, dynamic> json) {
    _sessionId = json['sessionId'] as String?;
    final status = json['status'] as String? ?? 'waiting_for_agent';
    final message = json['message'] as String? ?? 'Connected to support';

    debugPrint('✅ Session created: $_sessionId');
    debugPrint('📊 Status: $status');

    // Add system message
    _messages.add(ChatMessage(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      text: message,
      senderType: 'system',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  /// Handle incoming chat message
  void _handleChatMessage(Map<String, dynamic> json) {
    debugPrint('🔍 Raw chat_message received: $json');

    // Handle two possible formats:
    // Format 1 (from backend): { type: 'chat_message', message: { text: '...', senderType: '...' } }
    // Format 2 (from dashboard): { type: 'chat_message', message: 'text', senderType: 'agent' }

    Map<String, dynamic> messageData;

    // Check if 'message' is an object or a string
    if (json['message'] is Map<String, dynamic>) {
      // Format 1: message is an object
      messageData = json['message'] as Map<String, dynamic>;
      debugPrint('📦 Format 1: message is object');
    } else if (json['message'] is String) {
      // Format 2: message is a string, construct the object
      messageData = {
        'text': json['message'],
        'senderType': json['senderType'] ?? 'agent',
        'senderName':
            json['agentName'] ?? json['senderName'] ?? 'Support Agent',
        'messageId':
            json['messageId'] ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': json['timestamp'] ?? DateTime.now().toIso8601String(),
      };
      debugPrint('📦 Format 2: constructed message object from string');
    } else {
      debugPrint(
          '⚠️ Invalid message format in chat_message: ${json['message']}');
      return;
    }

    if (messageData['text'] == null) {
      debugPrint('⚠️ No message text in chat_message');
      return;
    }

    final senderType = messageData['senderType'] as String? ?? 'agent';

    // Skip if it's our own message (optimistic update already added it)
    if (senderType == 'merchant') {
      debugPrint('⏭️ Skipping own message echo');
      return;
    }

    final message = ChatMessage.fromJson(messageData);
    _messages.add(message);
    notifyListeners();

    debugPrint(
        '💬 Received message from ${message.senderType}: ${message.text.substring(0, message.text.length > 30 ? 30 : message.text.length)}...');
  }

  /// Handle agent connected
  void _handleAgentConnected(Map<String, dynamic> json) {
    final agentName = json['agentName'] as String? ?? 'Support Agent';

    _messages.add(ChatMessage(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      text: '$agentName has joined the chat',
      senderType: 'system',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
    debugPrint('👨‍💼 Agent connected: $agentName');
  }

  /// Handle agent typing indicator
  void _handleAgentTyping(Map<String, dynamic> json) {
    final isTyping = json['typing'] as bool? ?? false;
    debugPrint('⌨️ Agent typing: $isTyping');
    // TODO: Implement typing indicator UI
  }

  /// Handle session closed (by agent or system)
  void _handleSessionClosed(Map<String, dynamic> json) {
    debugPrint('🔒 Session closed by: ${json['closedByUserType']}');

    _sessionEnded = true;
    _isConnected = false;
    _connectionStatus = 'session_ended';

    // Add system message
    _messages.add(ChatMessage(
      id: 'system_closed_${DateTime.now().millisecondsSinceEpoch}',
      text:
          'This chat session has been ended by the support team. Thank you for contacting us!',
      senderType: 'system',
      timestamp: DateTime.now(),
    ));

    notifyListeners();

    // Disconnect after short delay
    Future.delayed(const Duration(seconds: 2), () {
      disconnect();
    });
  }

  /// End session (merchant initiated)
  Future<void> endSession() async {
    if (_sessionId == null || !_isConnected) {
      debugPrint('⚠️ Cannot end session: not connected');
      return;
    }

    debugPrint('🔚 Merchant ending session: $_sessionId');

    final message = {
      'action': 'chat_session_close',
      'type': 'chat_session_close',
      'sessionId': _sessionId,
      'closedByUserType': 'merchant',
      'closedByUserId': _merchantId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(message);
    _sessionEnded = true;

    // Add local system message
    _messages.add(ChatMessage(
      id: 'system_merchant_closed_${DateTime.now().millisecondsSinceEpoch}',
      text: 'You ended this chat session',
      senderType: 'system',
      timestamp: DateTime.now(),
    ));

    notifyListeners();

    // Disconnect after sending close message
    Future.delayed(const Duration(milliseconds: 500), () {
      disconnect();
    });
  }

  /// Handle WebSocket errors
  void _onError(error) {
    _error = 'Connection error: $error';
    _isConnected = false;
    _connectionStatus = 'error';
    notifyListeners();
    debugPrint('❌ WebSocket error: $error');
  }

  /// Handle WebSocket disconnection
  void _onDone() {
    _isConnected = false;
    _connectionStatus = 'disconnected';
    notifyListeners();
    debugPrint('🔌 WebSocket disconnected');

    // Auto-reconnect after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected && _merchantId != null) {
        debugPrint('🔄 Attempting to reconnect...');
        connectToSupport(
          merchantId: _merchantId!,
          merchantName: _merchantName!,
          merchantEmail: _merchantEmail!,
        );
      }
    });
  }

  /// Send message through WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null) {
      debugPrint('❌ Cannot send message: WebSocket not connected');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
    }
  }

  /// Generate random ID
  String _generateRandomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (index) => chars[(random + index) % chars.length])
        .join();
  }

  /// Disconnect from support chat (but keep session alive unless explicitly ended)
  /// This allows navigating away and back without losing the session
  void disconnect() {
    if (_sessionEnded) {
      debugPrint('👋 Disconnecting and clearing session (session was ended)');
      _subscription?.cancel();
      _channel?.sink.close();
      _isConnected = false;
      _sessionId = null;
      _connectionStatus = 'disconnected';
      _messages.clear();
    } else {
      debugPrint('⏸️ Disconnecting WebSocket but keeping session alive');
      _subscription?.cancel();
      _channel?.sink.close();
      _isConnected = false;
      _connectionStatus = 'paused';
      // Keep _sessionId and _messages for resumption
    }
    notifyListeners();
  }

  /// Clear chat history
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// Send a message through the chat system (routes through WhizzMe first if active)
  Future<void> sendMessage(String messageText) async {
    if (messageText.trim().isEmpty) return;

    // Add merchant message to chat
    final merchantMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText,
      senderType: 'merchant',
      timestamp: DateTime.now(),
      senderName: _merchantName,
    );

    _messages.add(merchantMessage);
    notifyListeners();

    // Route through WhizzMe if active, otherwise send directly to agent
    if (_shouldUseWhizzMe()) {
      await _processWithWhizzMe(messageText);
    } else {
      _sendRegularMessage(messageText);
    }
  }

  // ============================================
  // WhizzMe AI Integration
  // ============================================

  /// Initialize WhizzMe for new chat sessions
  Future<void> _initializeWhizzMe(
      String merchantId, String merchantName) async {
    try {
      debugPrint('🤖 Initializing WhizzMe for $merchantName');
      debugPrint(
          '🤖 Category: $_selectedCategory, Description: $_categoryDescription');

      // Get WhizzMe welcome message with category context
      final greeting = await _whizzMe.initializeChat(
        merchantId: merchantId,
        merchantName: merchantName,
        businessType: 'restaurant', // Could be dynamic based on merchant data
        context: {
          'selectedCategory': _selectedCategory,
          'categoryDescription': _categoryDescription,
        },
      );

      if (greeting != null && greeting.isNotEmpty) {
        // Add WhizzMe greeting as first message
        final welcomeMessage = ChatMessage(
          id: 'whizzme_${DateTime.now().millisecondsSinceEpoch}',
          text: greeting,
          senderType: 'whizzme',
          timestamp: DateTime.now(),
          senderName: 'WhizzMe',
        );

        _messages.add(welcomeMessage);
        debugPrint(
            '✅ WhizzMe initialized with greeting: ${greeting.substring(0, greeting.length > 50 ? 50 : greeting.length)}...');
      } else {
        debugPrint(
            '⚠️ WhizzMe returned empty greeting, adding default message');
        final welcomeMessage = ChatMessage(
          id: 'whizzme_${DateTime.now().millisecondsSinceEpoch}',
          text:
              'Hi! I\'m WhizzMe, your AI assistant. How can I help you today?',
          senderType: 'whizzme',
          timestamp: DateTime.now(),
          senderName: 'WhizzMe',
        );
        _messages.add(welcomeMessage);
      }

      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('❌ WhizzMe initialization failed: $error');
      debugPrint('❌ Stack trace: $stackTrace');

      // Add fallback message so user isn't left with empty screen
      final fallbackMessage = ChatMessage(
        id: 'whizzme_${DateTime.now().millisecondsSinceEpoch}',
        text:
            'Hello! I\'m here to help you. Please describe your issue and I\'ll do my best to assist you.',
        senderType: 'whizzme',
        timestamp: DateTime.now(),
        senderName: 'WhizzMe',
      );
      _messages.add(fallbackMessage);
      notifyListeners();

      // Don't disable WhizzMe on initialization failure - let it try to process messages
      debugPrint('⚠️ Continuing with WhizzMe despite initialization error');
    }
  }

  /// Process message through WhizzMe first, then escalate if needed
  Future<void> _processWithWhizzMe(String messageText) async {
    if (!_whizzMeActive || _humanAgentRequested) {
      // WhizzMe is disabled or human was already requested, send directly to agent
      _sendRegularMessage(messageText);
      return;
    }

    try {
      debugPrint('🤖 Processing message with WhizzMe: $messageText');

      final response = await _whizzMe.processMessage(
        message: messageText,
        merchantId: _merchantId!,
        sessionId: _sessionId!,
      );

      // Add WhizzMe response
      final aiMessage = ChatMessage(
        id: 'whizzme_${DateTime.now().millisecondsSinceEpoch}',
        text: response.message,
        senderType: 'whizzme',
        timestamp: DateTime.now(),
        senderName: 'WhizzMe',
      );

      _messages.add(aiMessage);
      notifyListeners();

      // Check if should escalate to human
      if (response.shouldEscalate) {
        debugPrint('🔄 WhizzMe escalating to human agent');
        _humanAgentRequested = true;
        _whizzMeActive = false;

        // Add transition message
        final transitionMessage = ChatMessage(
          id: 'transition_${DateTime.now().millisecondsSinceEpoch}',
          text:
              "I'm connecting you with a human agent now. Please hold on! 👨‍💼",
          senderType: 'system',
          timestamp: DateTime.now(),
          senderName: 'System',
        );

        _messages.add(transitionMessage);
        notifyListeners();

        // Now connect to WebSocket for human agent
        _connectToHumanAgent();
      }
    } catch (error) {
      debugPrint('❌ WhizzMe processing failed: $error');
      // Fallback to human agent
      _escalateToHuman(
          'WhizzMe encountered an error. Connecting you to a human agent.');
    }
  }

  /// Connect to human agent via WebSocket
  void _connectToHumanAgent() {
    try {
      debugPrint('🔌 Connecting to human agent via WebSocket...');

      // Connect to WebSocket if not already connected
      if (!_isConnected) {
        // Connect WebSocket
        _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        _subscription = _channel!.stream.listen(
          _onMessage,
          onError: _onError,
          onDone: _onDone,
          cancelOnError: false,
        );

        _isConnected = true;
        _connectionStatus = 'connected';

        // Send merchant connect message
        Future.delayed(const Duration(milliseconds: 500), () {
          _sendMerchantConnect();
        });
      }

      notifyListeners();
    } catch (error) {
      debugPrint('❌ Failed to connect to human agent: $error');
      _error = 'Failed to connect to human support: $error';
      notifyListeners();
    }
  }

  /// Escalate to human with custom message
  void _escalateToHuman(String reason) {
    _whizzMeActive = false;
    _humanAgentRequested = true;

    final escalationMessage = ChatMessage(
      id: 'escalation_${DateTime.now().millisecondsSinceEpoch}',
      text: reason,
      senderType: 'system',
      timestamp: DateTime.now(),
      senderName: 'System',
    );

    _messages.add(escalationMessage);
    notifyListeners();

    _connectToHumanAgent();
  }

  /// Send regular message (to human agent)
  void _sendRegularMessage(String messageText) {
    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText,
      senderType: 'merchant',
      timestamp: DateTime.now(),
      senderName: _merchantName,
    );

    _messages.add(message);
    notifyListeners();

    // Send via WebSocket to human agent
    _sendMessage({
      'action': 'message',
      'sessionId': _sessionId,
      'merchantId': _merchantId,
      'merchantName': _merchantName,
      'merchantEmail': _merchantEmail,
      'text': messageText,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Check if WhizzMe should handle this message
  bool _shouldUseWhizzMe() {
    return _whizzMeActive && !_humanAgentRequested && _whizzMe.isEnabled;
  }

  /// Start a categorized chat session with WhizzMe based on selected category
  Future<void> startCategorizedChat({
    required String merchantId,
    required String merchantName,
    required String merchantEmail,
    required String category,
    required String categoryDescription,
  }) async {
    try {
      debugPrint('🎯 Starting categorized chat - Category: $category');

      // Store merchant information
      _merchantId = merchantId;
      _merchantName = merchantName;
      _merchantEmail = merchantEmail;

      // Store category information
      _selectedCategory = category;
      _categoryDescription = categoryDescription;

      // Create new session ID
      if (_sessionId == null || _sessionEnded) {
        _sessionId =
            'merchant_${DateTime.now().millisecondsSinceEpoch}_$merchantId';
        _messages.clear();
        debugPrint('🆕 Creating new session: $_sessionId');
      }

      // Check if category requires direct human connection
      if (category == 'human_agent') {
        debugPrint('🙋‍♂️ Direct human agent requested - bypassing WhizzMe');
        _whizzMeActive = false;
        _humanAgentRequested = true;
        _connectionStatus = 'connecting';
        notifyListeners();

        // Connect directly to human agent via WebSocket
        _connectToHumanAgent();
        return;
      }

      // Start with WhizzMe for all other categories
      debugPrint('🤖 Starting WhizzMe AI session for category: $category');
      _whizzMeActive = true;
      _humanAgentRequested = false;
      _isConnected = false;
      _connectionStatus = 'whizzme_active';
      _sessionEnded = false;
      _error = null;

      // Initialize WhizzMe and get welcome message
      await _initializeWhizzMe(merchantId, merchantName);

      debugPrint('✅ WhizzMe chat session started successfully');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Error starting categorized chat: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _error = 'Failed to start chat: $e';
      _connectionStatus = 'error';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
