import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'token_refresh_service.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';

/// Chat Message Model
class ChatMessage {
  final String id;
  final String text;
  final String senderType; // 'merchant', 'agent', 'system'
  final DateTime timestamp;
  final String? senderName;
  final String? attachmentId;
  final String? imageUrl; // URL for attached image
  final String? imageType; // 'image/jpeg', 'image/png', etc.
  final bool isUploading; // Track upload state
  final String? clientMessageId;
  final String? deliveryStatus;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderType,
    required this.timestamp,
    this.senderName,
    this.attachmentId,
    this.imageUrl,
    this.imageType,
    this.isUploading = false,
    this.clientMessageId,
    this.deliveryStatus,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['messageId'] ?? json['id'] ?? '',
      text: json['text'] ?? '',
      senderType: json['senderType'] ?? 'merchant',
      timestamp: DateTime.tryParse(
              (json['createdAt'] ?? json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      senderName: json['senderName'],
      attachmentId: json['attachment'] is Map
          ? json['attachment']['attachmentId'] as String?
          : null,
      imageUrl: null,
      imageType: json['imageType'],
      isUploading: false,
      clientMessageId: json['clientMessageId'] ??
          (json['metadata'] is Map
              ? json['metadata']['clientMessageId']
              : null),
      deliveryStatus: json['senderType'] == 'merchant' ? 'accepted' : null,
    );
  }

  // Create copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? clientMessageId,
    String? deliveryStatus,
    String? text,
    String? senderType,
    DateTime? timestamp,
    String? senderName,
    String? attachmentId,
    String? imageUrl,
    String? imageType,
    bool? isUploading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      text: text ?? this.text,
      senderType: senderType ?? this.senderType,
      timestamp: timestamp ?? this.timestamp,
      senderName: senderName ?? this.senderName,
      attachmentId: attachmentId ?? this.attachmentId,
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
  SupportChatService._internal({
    Future<String?> Function()? tokenProvider,
    WebSocketChannel Function(Uri)? channelFactory,
    String? websocketUrl,
    String? attachmentsApiUrl,
    http.Client? attachmentHttpClient,
  })  : _tokenProvider =
            tokenProvider ?? TokenRefreshService.getValidUserAccessToken,
        _channelFactory = channelFactory ?? WebSocketChannel.connect,
        _websocketUrl = websocketUrl,
        _attachmentsApiUrl = attachmentsApiUrl,
        _attachmentHttpClient = attachmentHttpClient ?? http.Client();

  @visibleForTesting
  factory SupportChatService.forTesting({
    required Future<String?> Function() tokenProvider,
    required WebSocketChannel Function(Uri) channelFactory,
    required String websocketUrl,
    String? attachmentsApiUrl,
    http.Client? attachmentHttpClient,
  }) =>
      SupportChatService._internal(
          tokenProvider: tokenProvider,
          channelFactory: channelFactory,
          websocketUrl: websocketUrl,
          attachmentsApiUrl: attachmentsApiUrl,
          attachmentHttpClient: attachmentHttpClient);

  final Future<String?> Function() _tokenProvider;
  final WebSocketChannel Function(Uri) _channelFactory;
  final String? _websocketUrl;
  final String? _attachmentsApiUrl;
  final http.Client _attachmentHttpClient;
  static const _uuid = Uuid();
  int _connectionGeneration = 0;
  bool _humanConnecting = false;
  bool _disposed = false;
  bool _allowReconnect = false;
  bool _closing = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _handshakeTimer;
  Timer? _closeTimer;
  String? _confirmedSessionId;
  final Map<String, Timer> _ackTimers = {};

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
  final List<ChatMessage> _messages = [];
  String? _error;
  String _connectionStatus = 'disconnected';

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
  bool get hasRequestedHuman => true;

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
    if (_merchantId != null && _merchantId != merchantId) {
      disconnect();
      _sessionId = null;
      _confirmedSessionId = null;
      _messages.clear();
    }
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
      final needsNewSession =
          _sessionEnded || (_merchantId != null && _merchantId != merchantId);
      if (needsNewSession) {
        disconnect();
        _sessionId = null;
        _messages.clear();
      }
      _sessionEnded = false;
      notifyListeners();

      _merchantId = merchantId;
      _merchantName = merchantName;

      // Create new session ID only if no active session
      if (_sessionId == null || _sessionEnded) {
        _sessionId = 'merchant_${_uuid.v4()}';
        _messages.clear(); // Clear old messages when starting new session
        debugPrint('🆕 Creating new session: $_sessionId');
      }

      await _connectToHumanAgent();
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
      'businessId': _merchantId,
      'merchantName': _merchantName,
      'sessionId': _sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _channel!.sink.add(jsonEncode(message));
  }

  /// Send a chat message
  Future<bool> sendChatMessage(String text,
      {bool addLocalMessage = true}) async {
    if (!_isConnected || _sessionId == null || _sessionEnded || _closing) {
      _error = 'الاتصال غير متاح؛ احتفظ بنص رسالتك وأعد المحاولة بعد الاتصال.';
      notifyListeners();
      return false;
    }
    text = text.trim();
    if (text.isEmpty) return false;
    if (text.length > 4000) {
      _error = 'الحد الأقصى للرسالة ٤٠٠٠ حرف.';
      notifyListeners();
      return false;
    }
    final existingIndex = addLocalMessage
        ? -1
        : _messages.lastIndexWhere(
            (m) => m.senderType == 'merchant' && m.text == text);
    final clientId = _uuid.v4();
    final optimistic = ChatMessage(
        id: clientId,
        clientMessageId: clientId,
        text: text,
        senderType: 'merchant',
        timestamp: DateTime.now(),
        senderName: _merchantName,
        deliveryStatus: 'pending');
    if (!_sendMessage({
      'action': 'chat_message',
      'type': 'chat_message',
      'sessionId': _sessionId,
      'messageText': text,
      'senderType': 'merchant',
      'clientMessageId': clientId,
    })) {
      return false;
    }
    if (existingIndex < 0) {
      _messages.add(optimistic);
    } else {
      _messages[existingIndex] = optimistic;
    }
    _error = null;
    _ackTimers[clientId] = Timer(
        const Duration(seconds: 15), () => _settleReply(clientId, 'unknown'));
    notifyListeners();
    return true;
  }

  void _settleReply(String clientId, String status, {String? serverId}) {
    _ackTimers.remove(clientId)?.cancel();
    final index = _messages.indexWhere((m) => m.clientMessageId == clientId);
    if (index < 0) return;
    _messages[index] =
        _messages[index].copyWith(id: serverId, deliveryStatus: status);
    notifyListeners();
  }

  /// Send a chat message with image attachment
  static const _maxImageBytes = 2 * 1024 * 1024;
  Uri _attachmentEndpoint() {
    final uri =
        Uri.parse(_attachmentsApiUrl ?? AppConfig.supportAttachmentsApiUrl);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('Attachments are not configured');
    }
    return uri;
  }

  Future<Map<String, String>> _attachmentHeaders() async {
    final token = await _tokenProvider().timeout(const Duration(seconds: 10));
    if (token == null || token.isEmpty) throw StateError('Missing identity');
    return {
      'Authorization': 'Bearer $token',
      'X-Support-User-Type': 'merchant',
      'Content-Type': 'application/json'
    };
  }

  Future<bool> sendImageMessage(File imageFile, String? caption) async {
    if (!_isConnected || _sessionId == null || _closing || _sessionEnded) {
      _error = 'الصور متاحة بعد الاتصال بموظف الدعم.';
      notifyListeners();
      return false;
    }
    final generation = _connectionGeneration;
    final sessionId = _sessionId!;
    final clientId = _uuid.v4();
    try {
      final endpoint = _attachmentEndpoint();
      if (await imageFile.length() > _maxImageBytes)
        throw StateError('Image exceeds 2 MiB');
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty ||
          bytes.length > _maxImageBytes ||
          (caption?.length ?? 0) > 4000) throw StateError('Invalid image size');
      final png = bytes.length >= 8 &&
          listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final jpeg = bytes.length >= 4 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[bytes.length - 2] == 255 &&
          bytes.last == 217;
      if (!png && !jpeg) throw StateError('Only JPEG and PNG are supported');
      if (generation != _connectionGeneration || _disposed) return false;
      final text =
          caption?.trim().isNotEmpty == true ? caption!.trim() : '📷 صورة';
      _messages.add(ChatMessage(
          id: clientId,
          clientMessageId: clientId,
          text: text,
          senderType: 'merchant',
          timestamp: DateTime.now(),
          isUploading: true,
          deliveryStatus: 'pending'));
      notifyListeners();
      final headers = await _attachmentHeaders();
      if (generation != _connectionGeneration || _disposed) return false;
      final response = await _attachmentHttpClient
          .post(endpoint,
              headers: headers,
              body: jsonEncode({
                'sessionId': sessionId,
                'uploadId': clientId,
                'contentType': png ? 'image/png' : 'image/jpeg',
                'dataBase64': base64Encode(bytes),
              }))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError('Upload rejected');
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (result['attachmentId'] != clientId)
        throw StateError('Unconfirmed image upload');
      if (generation != _connectionGeneration ||
          sessionId != _sessionId ||
          _disposed ||
          _closing) return false;
      if (!_sendMessage({
        'type': 'chat_message',
        'action': 'chat_message',
        'sessionId': sessionId,
        'messageText': text,
        'clientMessageId': clientId,
        'attachmentId': clientId
      })) {
        throw StateError('Message not sent');
      }
      final index = _messages.indexWhere((m) => m.clientMessageId == clientId);
      if (index >= 0)
        _messages[index] = _messages[index]
            .copyWith(attachmentId: clientId, isUploading: false);
      _ackTimers[clientId] = Timer(
          const Duration(seconds: 15), () => _settleReply(clientId, 'unknown'));
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      if (generation == _connectionGeneration && !_disposed) {
        _error =
            'تعذر إرسال الصورة. استخدم JPEG أو PNG بحجم لا يتجاوز ٢ ميغابايت، ثم حاول مجددًا.';
        final index =
            _messages.indexWhere((m) => m.clientMessageId == clientId);
        if (index >= 0)
          _messages[index] = _messages[index]
              .copyWith(isUploading: false, deliveryStatus: 'failed');
        notifyListeners();
      }
      return false;
    } finally {
      // No upload spinner survives leaving the session or an interrupted upload.
      final index = _messages.indexWhere((m) => m.clientMessageId == clientId);
      if (!_disposed && index >= 0 && _messages[index].isUploading) {
        _messages[index] = _messages[index]
            .copyWith(isUploading: false, deliveryStatus: 'failed');
        notifyListeners();
      }
    }
  }

  Future<Uint8List> loadAttachment(String attachmentId) async {
    final generation = _connectionGeneration;
    final sessionId = _sessionId;
    if (sessionId == null || _disposed) throw StateError('No support session');
    final endpoint = _attachmentEndpoint().replace(queryParameters: {
      'sessionId': sessionId,
      'attachmentId': attachmentId
    });
    final headers = await _attachmentHeaders();
    if (generation != _connectionGeneration || _disposed)
      throw StateError('Session changed');
    final response = await _attachmentHttpClient
        .get(endpoint, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (generation != _connectionGeneration ||
        _disposed ||
        response.statusCode != 200 ||
        response.body.length > 3 * 1024 * 1024)
      throw StateError('Attachment unavailable');
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (result['attachmentId'] != attachmentId ||
        !['image/png', 'image/jpeg'].contains(result['contentType']))
      throw StateError('Invalid attachment');
    final bytes = base64Decode(result['dataBase64'] as String);
    if (bytes.isEmpty || bytes.length > _maxImageBytes)
      throw StateError('Invalid attachment size');
    return bytes;
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
        case 'message_ack':
          if (json['sessionId'] == _sessionId &&
              json['clientMessageId'] is String) {
            _settleReply(json['clientMessageId'] as String, 'accepted',
                serverId: json['messageId'] as String?);
          }
          break;
        case 'session_messages':
          _handleHistory(json);
          break;
        case 'chat_session_close_ack':
          // A receipt is not proof that the close operation was saved.
          break;
        case 'session_closed':
          _handleSessionClosed(json);
          break;
        case 'error':
          if (json['code'] == 'SESSION_CLOSED') {
            _handleSessionClosed({'sessionId': _sessionId});
            break;
          }
          _error =
              'لم تقبل الخدمة الطلب؛ تحقق من صلاحية الحساب وحالة المحادثة.';
          _closing = false;
          _closeTimer?.cancel();
          if ([
            'AUTH_REQUIRED',
            'BUSINESS_UNAVAILABLE',
            'FORBIDDEN',
            'IDENTITY_MISMATCH'
          ].contains(json['code'])) {
            _stopTransport();
            _connectionStatus = 'error';
          }
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
    if (json['sessionId'] != _sessionId || _sessionEnded) return;
    _handshakeTimer?.cancel();
    _isConnected = true;
    _isConnecting = false;
    _humanConnecting = false;
    _reconnectAttempts = 0;
    _error = null;
    _connectionStatus = 'connected';
    if (_confirmedSessionId != _sessionId) {
      _messages.add(ChatMessage(
          id: 'connected_$_sessionId',
          text: 'تم الاتصال بالدعم.',
          senderType: 'system',
          timestamp: DateTime.now()));
    }
    _confirmedSessionId = _sessionId;
    _sendMessage({
      'action': 'get_session_messages',
      'type': 'get_session_messages',
      'sessionId': _sessionId,
      'limit': 40
    });
    notifyListeners();
  }

  void _mergeServerMessage(Map<String, dynamic> data) {
    final message = ChatMessage.fromJson(data);
    if (message.clientMessageId != null) {
      final index = _messages
          .indexWhere((m) => m.clientMessageId == message.clientMessageId);
      if (index >= 0) {
        _ackTimers.remove(message.clientMessageId)?.cancel();
        _messages[index] = _messages[index].copyWith(
            id: message.id,
            attachmentId: message.attachmentId,
            deliveryStatus: 'accepted');
        return;
      }
    }
    if (!_messages.any((m) => m.id == message.id)) _messages.add(message);
  }

  void _handleHistory(Map<String, dynamic> data) {
    if (data['sessionId'] != _sessionId || data['messages'] is! List) return;
    for (final row in (data['messages'] as List).reversed) {
      if (row is Map<String, dynamic>) _mergeServerMessage(row);
    }
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  /// Handle incoming chat message
  void _handleChatMessage(Map<String, dynamic> json) {
    final envelope = json['message'];
    final sessionId =
        json['sessionId'] ?? (envelope is Map ? envelope['sessionId'] : null);
    if (sessionId != _sessionId) return;
    final data = envelope is Map<String, dynamic>
        ? envelope
        : <String, dynamic>{
            'text': json['messageText'] ?? envelope ?? json['text'],
            'senderType': json['senderType'],
            'senderName': json['senderName'],
            'messageId': json['messageId'],
            'createdAt': json['timestamp'],
            'clientMessageId': json['clientMessageId'],
          };
    if (data['text'] is! String) return;
    _mergeServerMessage(data);
    notifyListeners();
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
    if (json['sessionId'] != _sessionId || _sessionEnded) return;
    _sessionEnded = true;
    _stopTransport();
    _connectionStatus = 'session_ended';
    _messages.add(ChatMessage(
        id: 'closed_$_sessionId',
        text: 'تم إغلاق المحادثة.',
        senderType: 'system',
        timestamp: DateTime.now()));
    // Keep the transcript available after closure.
    notifyListeners();
  }

  Future<void> endSession() async {
    if (_sessionId == null || !_isConnected || _closing) return;
    if (!_sendMessage({
      'action': 'chat_session_close',
      'type': 'chat_session_close',
      'sessionId': _sessionId
    })) {
      return;
    }
    _closing = true;
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(seconds: 15), () {
      _closing = false;
      _error = 'لم يتأكد إغلاق المحادثة؛ تحقق من حالتها قبل المحاولة مجددًا.';
      notifyListeners();
    });
    notifyListeners();
  }

  void _connectionLost() {
    _handshakeTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
    _humanConnecting = false;
    _closing = false;
    _closeTimer?.cancel();
    _detachTransport();
    _markPendingUnknown();
    _connectionStatus = 'disconnected';
    if (_allowReconnect &&
        !_sessionEnded &&
        !_disposed &&
        _reconnectTimer == null) {
      final seconds = 1 << (_reconnectAttempts < 4 ? _reconnectAttempts++ : 4);
      _reconnectTimer = Timer(Duration(seconds: seconds), () {
        _reconnectTimer = null;
        if (_allowReconnect && !_sessionEnded && !_disposed) {
          _connectToHumanAgent();
        }
      });
    }
    notifyListeners();
  }

  bool _sendMessage(Map<String, dynamic> message) {
    if (_channel == null || !_isConnected || _sessionEnded) return false;
    try {
      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (_) {
      _error = 'تعذر الإرسال؛ لم نحذف نص رسالتك.';
      _connectionLost();
      return false;
    }
  }

  void _markPendingUnknown() {
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].deliveryStatus == 'pending') {
        _messages[i] = _messages[i].copyWith(deliveryStatus: 'unknown');
      }
    }
  }

  void _detachTransport() {
    final subscription = _subscription;
    final channel = _channel;
    _subscription = null;
    _channel = null;
    // A failed/closed old socket must not delay a fresh connection.
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }
    if (channel != null) {
      try {
        unawaited(channel.sink
            .close()
            .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
      } catch (_) {/* already closed */}
    }
  }

  void _stopTransport() {
    _connectionGeneration++;
    _allowReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _handshakeTimer?.cancel();
    _closeTimer?.cancel();
    _detachTransport();
    _isConnected = false;
    _isConnecting = false;
    _humanConnecting = false;
    _closing = false;
    _markPendingUnknown();
  }

  /// Disconnect from support chat (but keep session alive unless explicitly ended)
  /// This allows navigating away and back without losing the session
  void disconnect() {
    _stopTransport();
    _connectionStatus = _sessionEnded ? 'session_ended' : 'paused';
    if (!_disposed) notifyListeners();
  }

  /// Clear chat history
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// Send directly to the support team using the authenticated transport.
  Future<bool> sendMessage(String messageText) => sendChatMessage(messageText);

  /// Connect to human agent via WebSocket
  Future<void> _connectToHumanAgent() async {
    if (_disposed || _sessionEnded || _humanConnecting || _isConnected) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _humanConnecting = true;
    _isConnecting = true;
    _allowReconnect = true;
    _connectionStatus = 'connecting';
    final generation = ++_connectionGeneration;
    notifyListeners();
    try {
      final base = Uri.parse(_websocketUrl ?? wsUrl);
      if (base.scheme != 'wss' || base.host.isEmpty || _merchantId == null) {
        throw StateError('Invalid support configuration');
      }
      final token = await _tokenProvider().timeout(const Duration(seconds: 10));
      if (generation != _connectionGeneration || _disposed) return;
      if (token == null || token.isEmpty) {
        throw StateError('Missing support identity');
      }
      _detachTransport();
      final uri = base.replace(queryParameters: {
        ...base.queryParameters,
        'token': token,
        'userType': 'merchant'
      });
      final channel = _channelFactory(uri);
      _channel = channel;
      _subscription = channel.stream.listen((data) {
        if (generation == _connectionGeneration && !_disposed) _onMessage(data);
      }, onError: (_) {
        if (generation == _connectionGeneration && !_disposed) {
          _connectionLost();
        }
      }, onDone: () {
        if (generation == _connectionGeneration && !_disposed) {
          _connectionLost();
        }
      });
      await channel.ready.timeout(const Duration(seconds: 10));
      if (generation != _connectionGeneration ||
          _disposed ||
          !_humanConnecting) {
        return;
      }
      _connectionStatus = 'waiting_for_confirmation';
      _handshakeTimer = Timer(const Duration(seconds: 10), () {
        if (generation == _connectionGeneration && !_isConnected) {
          _error = 'لم تؤكد الخدمة الاتصال. حاول مجددًا.';
          _stopTransport();
          _connectionStatus = 'error';
          notifyListeners();
        }
      });
      _sendMerchantConnect();
      notifyListeners();
    } catch (_) {
      if (generation != _connectionGeneration || _disposed) return;
      _error = 'تعذر الاتصال بالدعم؛ تحقق من تسجيل الدخول والاتصال بالإنترنت.';
      _stopTransport();
      _connectionStatus = 'error';
      notifyListeners();
    }
  }

  /// Preserve categorized callers while routing every topic to the support team.
  Future<void> startCategorizedChat({
    required String merchantId,
    required String merchantName,
    required String merchantEmail,
    required String category,
    required String categoryDescription,
  }) async {
    _selectedCategory = category;
    _categoryDescription = categoryDescription;
    await connectToSupport(
      merchantId: merchantId,
      merchantName: merchantName,
      merchantEmail: merchantEmail,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTransport();
    _attachmentHttpClient.close();
    super.dispose();
  }
}
