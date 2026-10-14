import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/order.dart';
import '../models/delivery_address.dart';
import '../config/app_config.dart';
import 'order_service.dart';
import 'app_auth_service.dart';
import 'audio_notification_service.dart';
import 'merchant_notification_inbox.dart';
import 'secure_token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';

final realtimeOrderServiceProvider = Provider<RealtimeOrderService>((ref) {
  return RealtimeOrderService();
});

// Callback type for order refresh trigger
typedef OrderRefreshCallback = void Function();

/// Real-time order service for merchant notifications
/// Includes iOS/Android background support and app lifecycle management
class RealtimeOrderService with WidgetsBindingObserver {
  static final RealtimeOrderService _instance =
      RealtimeOrderService._internal();
  factory RealtimeOrderService() => _instance;
  RealtimeOrderService._internal() {
    // Register as lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  // Services
  final AudioNotificationService _audioService = AudioNotificationService();

  // WebSocket connection
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _heartbeatTimer; // ✅ Heartbeat timer for connection monitoring
  Timer? _reconnectTimer;
  Timer? _pollingTimer;
  bool _isConnected = false;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  String? _businessId;
  String? _authToken;
  bool _isDisposed = false;
  bool _isConnecting = false;
  Future<void>? _ongoingInitialize;
  bool _didSendSubscribe = false;

  // Sound notification tracking to prevent duplicates
  final Set<String> _soundPlayedForOrders = <String>{};
  Timer? _soundTrackingCleanupTimer;
  
  // Order refresh callback (set by order screen/provider)
  OrderRefreshCallback? _onOrdersNeedRefresh;

  // Stream controllers
  StreamController<Order>? _newOrderController;
  StreamController<Map<String, dynamic>>? _orderUpdateController;
  StreamController<bool>? _connectionController;

  // Services
  final OrderService _orderService = OrderService();

  // Configuration
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration pollingFallbackInterval = Duration(seconds: 15);

  // Streams - Initialize controllers on first access
  Stream<Order> get newOrderStream {
    _ensureControllersInitialized();
    return _newOrderController!.stream;
  }

  Stream<Map<String, dynamic>> get orderUpdateStream {
    _ensureControllersInitialized();
    return _orderUpdateController!.stream;
  }

  Stream<bool> get connectionStream {
    _ensureControllersInitialized();
    return _connectionController!.stream;
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get businessId => _businessId;

  /// Helper method to get platform safely across all platforms
  String _getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      return 'unknown';
    } catch (e) {
      return 'web'; // fallback للويب
    }
  }

  /// الحصول على Device ID مستقر للجهاز
  Future<String> _getStableDeviceId(String platform) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const deviceIdKey = 'stable_device_id_business';
      
      String? existingDeviceId = prefs.getString(deviceIdKey);
      
      if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
        debugPrint('WebSocket: استخدام Device ID موجود: $existingDeviceId');
        return existingDeviceId;
      }
      
      // إنشاء Device ID جديد مستقر
      final stableDeviceId = 'flutter_business_${platform}_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(deviceIdKey, stableDeviceId);
      
      debugPrint('WebSocket: إنشاء Device ID جديد مستقر: $stableDeviceId');
      return stableDeviceId;
      
    } catch (e) {
      debugPrint('WebSocket: خطأ في الحصول على Device ID مستقر: $e');
      // fallback إلى Device ID مؤقت
      return 'flutter_business_${platform}_temp_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Ensure stream controllers are initialized
  void _ensureControllersInitialized() {
    if (_newOrderController == null || _newOrderController!.isClosed) {
      _newOrderController = StreamController<Order>.broadcast();
    }
    if (_orderUpdateController == null || _orderUpdateController!.isClosed) {
      _orderUpdateController =
          StreamController<Map<String, dynamic>>.broadcast();
    }
    if (_connectionController == null || _connectionController!.isClosed) {
      _connectionController = StreamController<bool>.broadcast();
    }
  }

  // Safe methods to add to stream controllers
  void _safeAddToNewOrderController(Order order) {
    if (!_isDisposed &&
        _newOrderController != null &&
        !_newOrderController!.isClosed) {
      _newOrderController!.add(order);
      unawaited(MerchantNotificationInbox.recordPush({'businessId':order.businessId,'orderId':order.id,
        'action':'new_order','updatedAt':order.createdAt.toIso8601String()},
        title:'طلب جديد #${order.orderNumber ?? order.id}',body:order.customerName).catchError((Object _) {}));
      
      // Play sound notification for new order (with deduplication)
      _playNewOrderNotificationSoundOnce(order);
    }
  }

  void _safeAddToOrderUpdateController(Map<String, dynamic> update) {
    if (!_isDisposed &&
        _orderUpdateController != null &&
        !_orderUpdateController!.isClosed) {
      _orderUpdateController!.add(update);
      
      // Play sound notification for order updates
      _playOrderUpdateNotificationSound(update);
    }
  }

  void _safeAddToConnectionController(bool connected) {
    if (!_isDisposed &&
        _connectionController != null &&
        !_connectionController!.isClosed) {
      _connectionController!.add(connected);
    }
  }

  /// Play sound notification for new orders (with deduplication)
  void _playNewOrderNotificationSoundOnce(Order order) {
    try {
      // Check if we've already played sound for this order
      if (_soundPlayedForOrders.contains(order.id)) {
        debugPrint('🔇 Sound already played for order: ${order.id}, skipping');
        return;
      }

      // Mark this order as having sound played
      _soundPlayedForOrders.add(order.id);

      // Determine if order should be treated as urgent
      bool isUrgent = order.totalAmount > 100.0; // Orders over $100 are urgent

      // Play appropriate sound based on urgency
      _audioService.playNewOrderSoundOnce(order.id);

      debugPrint(
          '🔊 Sound notification played for order: ${order.id} (${isUrgent ? 'URGENT' : 'NORMAL'})');

      // Start cleanup timer if not already running
      _startSoundTrackingCleanup();
    } catch (e) {
      debugPrint('❌ Error playing sound notification: $e');
    }
  }

  /// Start cleanup timer to remove old order IDs from sound tracking
  void _startSoundTrackingCleanup() {
    _soundTrackingCleanupTimer?.cancel();
    _soundTrackingCleanupTimer =
        Timer.periodic(const Duration(minutes: 5), (_) {
      // Keep only recent order IDs (last 50 orders)
      if (_soundPlayedForOrders.length > 50) {
        final ordersToRemove = _soundPlayedForOrders.length - 50;
        final ordersList = _soundPlayedForOrders.toList();
        for (int i = 0; i < ordersToRemove; i++) {
          _soundPlayedForOrders.remove(ordersList[i]);
        }
        debugPrint(
            '🧹 Cleaned up ${ordersToRemove} old order IDs from sound tracking');
      }
    });
  }

  /// Play sound notification for order updates
  void _playOrderUpdateNotificationSound(Map<String, dynamic> update) {
    try {
      final status = update['status']?.toString() ?? '';
      final orderId = update['orderId']?.toString() ?? 'unknown';

      // Play different sounds based on update type
      switch (status.toLowerCase()) {
        case 'confirmed':
        case 'ready':
        case 'pickedup':
        case 'delivered':
          _audioService.playNotificationSound('order_update');
          debugPrint('🔊 Order update sound played for: $orderId ($status)');
          break;
        case 'cancelled':
        case 'returned':
          _audioService.playNotificationSound('order_update');
          debugPrint(
              '🔊 Order status change sound played for: $orderId ($status)');
          break;
        default:
          debugPrint('📝 Order update received (no sound): $orderId ($status)');
      }
    } catch (e) {
      debugPrint('❌ Error playing order update sound: $e');
    }
  }

  /// Initialize the service with business context
  Future<void> initialize(String? businessId) async {
    // If already connected to the same business, skip
    if (_isConnected && _businessId != null && _businessId == businessId) {
      debugPrint('ℹ️ RealtimeOrderService already connected for business $_businessId');
      return;
    }

    // Coalesce concurrent initialize calls
    if (_isConnecting) {
      debugPrint('ℹ️ Initialize already in progress, awaiting existing operation');
      await _ongoingInitialize;
      return;
    }

    _isConnecting = true;
    _ongoingInitialize = _initializeInternal(businessId);
    try {
      await _ongoingInitialize;
    } finally {
      _isConnecting = false;
      _ongoingInitialize = null;
    }
  }

  Future<void> _initializeInternal(String? businessId) async {
    _businessId = businessId;
    _authToken = await AppAuthService.getAccessToken();

    // Initialize audio service
    await _audioService.initialize();
    debugPrint('🔊 Audio notification service initialized');

    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('❌ No auth token available for WebSocket connection');
      _startPollingFallback();
      return;
    }

    debugPrint('✅ Initializing RealtimeOrderService with businessId: $_businessId');
    await _connectWebSocket();
    _startPollingFallback(); // Always have polling as backup
  }

  /// Connect to WebSocket
  Future<void> _connectWebSocket() async {
    if (_businessId == null || _businessId!.isEmpty) {
      debugPrint('❌ Cannot connect WebSocket: businessId is null or empty');
      return;
    }

    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('❌ Cannot connect WebSocket: auth token is null or empty');
      return;
    }

    if (_isDisposed) {
      debugPrint('❌ Cannot connect WebSocket: service is disposed');
      return;
    }

    // Note: Don't check or set _isConnecting here - it's managed by initialize()
    // This allows both initialize() and reconnect() to work correctly
    
    _didSendSubscribe = false; // reset before new connection

    // If an existing channel is present, ensure it is closed before reconnecting
    if (_channel != null) {
      try {
        await disconnect();
      } catch (_) {}
    }

    _manualDisconnect = false; // Reset manual disconnect flag on new connection attempt

    try {
      // ✅ Get JWT token for authentication and userId
      String? token;
      String? userId;
      
      try {
        token = await SecureTokenStorage.getIdToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('🔐 JWT Token obtained (${token.length} chars)');
          
          // ✅ Extract userId from JWT token (sub claim)
          try {
            final decodedToken = JwtDecoder.decode(token);
            userId = decodedToken['sub'] ?? decodedToken['cognito:username'];
            debugPrint('🆔 userId extracted from JWT: $userId');
          } catch (jwtError) {
            debugPrint('⚠️ Failed to decode JWT token: $jwtError');
          }
        } else {
          debugPrint('⚠️ JWT Token is null or empty');
        }
      } catch (e) {
        debugPrint('❌ Failed to get JWT token: $e');
      }
      
      // ✅ Use businessId as fallback userId if JWT decoding failed
      if (userId == null || userId.isEmpty) {
        debugPrint('⚠️ Using businessId as fallback userId for WebSocket connection');
        userId = _businessId;
      }

      debugPrint('🔍 AppConfig.webSocketUrl: ${AppConfig.webSocketUrl}');

      // ✅ إعداد معلومات الجهاز والتطبيق بطريقة آمنة للويب
      String platform = _getPlatform();
      const appVersion = '1.0.0';
      final deviceId = await _getStableDeviceId(platform);

      // ✅ بناء WebSocket URL الصحيح مع query parameters
      final baseUri = Uri.parse(AppConfig.webSocketUrl);
      final queryParams = {
        'businessId': _businessId!,
        'userId': userId,
        'entityType': 'business',
        'userType': 'merchant',
        'platform': platform,
        'appVersion': appVersion,
        'deviceId': deviceId,
      };
      
      // Add token if available
      if (token != null && token.isNotEmpty) {
        queryParams['token'] = token;
      }
      
      final wsUri = baseUri.replace(queryParameters: queryParams);
      
      debugPrint('🔌 Connecting to WebSocket with:');
      debugPrint('   businessId: $_businessId');
      debugPrint('   userId: $userId (${userId?.length ?? 0} chars)');
      debugPrint('   entityType: business');
      debugPrint('   userType: merchant');
      debugPrint('   platform: $platform');
      debugPrint('   appVersion: $appVersion');
      debugPrint('   deviceId: $deviceId');
      debugPrint('   token: ${token != null ? "✅ Present (${token.length} chars)" : "❌ Not available"}');
      debugPrint('🔗 Full WebSocket URL: ${wsUri.toString().replaceAll(RegExp(r'token=[^&]+'), 'token=***')}');
      debugPrint('🔗 URL scheme: ${wsUri.scheme}');
      debugPrint('🔗 URL host: ${wsUri.host}');
      
      // ✅ Use IOWebSocketChannel for iOS/Android - preserves wss:// scheme correctly
      try {
        debugPrint('WebSocket: إنشاء IOWebSocketChannel...');
        
        if (kIsWeb) {
          // Web platform
          _channel = WebSocketChannel.connect(wsUri);
        } else {
          // iOS/Android - Use IOWebSocketChannel to preserve wss:// scheme
          _channel = IOWebSocketChannel.connect(wsUri);
        }
        
        debugPrint('✅ WebSocket channel created successfully');
      } catch (e) {
        debugPrint('❌ WebSocket connection failed: $e');
        rethrow;
      }
      
      // Start manual ping for all platforms
      _startPing();
      
      // ✅ Start heartbeat timer for connection monitoring
      _startHeartbeatTimer();

      // Listen for messages
      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDisconnection,
      );

      // 🔥 CRITICAL FIX: Mark as connected immediately for iOS
      // iOS needs this flag set early to receive messages
      _isConnected = true;
      _reconnectAttempts = 0;
      _safeAddToConnectionController(true);

      debugPrint('🔌 WebSocket stream created, waiting for CONNECTION_ESTABLISHED...');

      // Wait a brief moment for the connection to fully establish
      await Future.delayed(const Duration(milliseconds: 500));

      if (!_isConnected || _manualDisconnect) {
        debugPrint('❌ Connection was closed during establishment');
        return;
      }

      debugPrint('✅ WebSocket connection stable, sending registration...');

      // First, register as merchant to override WizzUser default entityType
      _sendWebSocketMessage({
        'type': 'REGISTER_CONNECTION',
        'businessId': _businessId,
        'entityType': 'merchant',
        'userType': 'merchant',
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Wait for registration confirmation
      await Future.delayed(const Duration(milliseconds: 300));

      // Then send subscription request (only once per connection)
      if (!_didSendSubscribe && !_manualDisconnect) {
        debugPrint('📤 Sending SUBSCRIBE_ORDERS...');
        _sendWebSocketMessage({
          'type': 'SUBSCRIBE_ORDERS',
          'businessId': _businessId,
          'entityType': 'business',
          'userType': 'merchant',
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _didSendSubscribe = true;
        debugPrint('✅ SUBSCRIBE_ORDERS sent successfully');
      }
    } catch (error) {
      debugPrint('❌ WebSocket connection failed: $error');
      _handleWebSocketError(error);
    } finally {
      _isConnecting = false;
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic data) {
    if (_isDisposed) return;

    try {
      final message = json.decode(data);
      debugPrint('📦 Raw WebSocket message received: $message');
      
      // Handle different message structures from backend
      String? messageType;
      Map<String, dynamic>? payload;
      
      // Check for 'type' field (current backend format from order stream)
      if (message['type'] != null) {
        messageType = message['type'];
        payload = message['payload'] ?? message;
      }
      // Check for 'action' field (legacy format)
      else if (message['action'] != null) {
        messageType = message['action'];
        payload = message['payload'] ?? message;
      }
      // Check for direct message types
      else if (message['orderId'] != null || message['id'] != null) {
        messageType = 'NEW_ORDER';
        payload = message;
      }

      debugPrint('📦 WebSocket message type: $messageType');
      debugPrint('🔍 iOS Debug - Full message: $message');

      switch (messageType) {
        case 'NEW_ORDER':
        case 'actionable_order_notification':
        case 'new_order':
          debugPrint('🚨 NEW ORDER MESSAGE RECEIVED!');
          _handleNewOrder(payload ?? message);
          break;
        case 'ORDER_UPDATE':
        case 'order_update':
          debugPrint('📝 ORDER UPDATE RECEIVED');
          _safeAddToOrderUpdateController(payload ?? message);
          break;
        case 'order_status_update':
        case 'ORDER_STATUS_UPDATE':
          debugPrint('📝 ORDER STATUS UPDATE RECEIVED (OrderService format)');
          final statusData = payload ?? message;
          debugPrint('📝 Status update data: $statusData');
          
          final orderId = statusData['orderId'] ?? statusData['order_id'];
          final status = statusData['status'];
          
          if (orderId != null && status != null) {
            // Forward to order update stream
            _safeAddToOrderUpdateController({
              'orderId': orderId,
              'status': status,
              'cancelReason': statusData['cancelReason'] ?? statusData['message'],
              'timestamp': statusData['timestamp'] ?? DateTime.now().toIso8601String(),
            });
            
            debugPrint('✅ ORDER STATUS UPDATE processed for order: $orderId, status: $status');
          } else {
            debugPrint('⚠️ ORDER STATUS UPDATE missing orderId or status');
          }
          break;
        case 'ORDER_CANCELLED':
        case 'order_cancelled':
          debugPrint('🔴 ORDER CANCELLED NOTIFICATION RECEIVED');
          final orderData = payload ?? message;
          debugPrint('🔴 Cancelled order data: $orderData');
          
          // Extract order information
          final orderId = orderData['orderId'] ?? orderData['order_id'];
          final cancelReason = orderData['cancelReason'] ?? orderData['cancel_reason'] ?? 'Customer cancelled';
          
          if (orderId != null) {
            // Send update to order update stream
            _safeAddToOrderUpdateController({
              'orderId': orderId,
              'status': 'cancelled',
              'cancelReason': cancelReason,
              'timestamp': DateTime.now().toIso8601String(),
            });
            
            debugPrint('✅ ORDER CANCELLED notification processed for order: $orderId');
          } else {
            debugPrint('⚠️ ORDER CANCELLED notification missing orderId');
          }
          break;
        case 'BUSINESS_STATUS_UPDATED':
          try {
            final isActive = (payload ?? message)['isActive'] == true;
            // Sync UI state with server confirmation
            AppState().updateOnlineStatus(isActive);
            debugPrint('✅ Business status synced: $isActive');
          } catch (_) {}
          debugPrint('✅ Business status updated ack received.');
          break;
        case 'business_status_update':
          try {
            final data = payload ?? message;
            final isActive = data['isActive'];
            if (isActive is bool) {
              AppState().updateOnlineStatus(isActive);
              debugPrint('✅ business_status_update applied: isActive=$isActive');
            } else {
              debugPrint('ℹ️ business_status_update received (no isActive), ignoring');
            }
          } catch (e) {
            debugPrint('⚠️ Error handling business_status_update: $e');
          }
          break;
        case 'working_hours_update':
          // Not relevant to merchant order stream; acknowledge quietly
          debugPrint('🗓️ working_hours_update received (ignored in merchant app)');
          break;
        case 'CONNECTION_ESTABLISHED':
        case 'connection_established':
          debugPrint('🎉 CONNECTION_ESTABLISHED received from server!');
          break;
        case 'SUBSCRIBED':
          debugPrint('✅ SUBSCRIBED confirmation received from server!');
          break;
        case 'subscription_ack':
          debugPrint('✅ subscription_ack received');
          break;
        case 'REGISTERED':
          debugPrint('✅ REGISTERED confirmation received from server!');
          break;
        case 'PONG':
          debugPrint('🏓 Received PONG response (connection alive)');
          break;
        case 'pong':
          debugPrint('🏓 Received pong response (connection alive)');
          break;
        case 'HEARTBEAT_ACK':
          debugPrint('💓 Received HEARTBEAT_ACK');
          break;
        case 'heartbeat_ack':
          debugPrint('💓 Received heartbeat_ack');
          break;
        case 'unknown_message_ack':
          // Backend may respond with this for legacy/unknown frames (e.g., PING)
          debugPrint('ℹ️ Received unknown_message_ack (no action)');
          break;
        default:
          debugPrint('🤷 Unhandled WebSocket message type: $messageType');
          debugPrint('📄 Full message: $message');
      }
    } catch (e) {
      debugPrint('❌ Error processing WebSocket message: $e');
      debugPrint('Raw data: $data');
    }
  }
  
  /// Set callback for order refresh (called by order screen/provider)
  void setOrderRefreshCallback(OrderRefreshCallback? callback) {
    _onOrdersNeedRefresh = callback;
    debugPrint('🔔 Order refresh callback ${callback != null ? "registered" : "cleared"}');
  }
  
  /// Trigger immediate orders refresh (called from multiple sources)
  void _triggerOrdersRefresh() {
    debugPrint('🔄 Triggering immediate orders refresh...');
    // This method will be called by:
    // 1. WebSocket NEW_ORDER messages
    // 2. Push notifications (foreground)
    // 3. App resume from background
    
    // Notify listeners (order screen/provider) to refresh
    if (_onOrdersNeedRefresh != null) {
      debugPrint('✅ Calling order refresh callback');
      _onOrdersNeedRefresh!();
    } else {
      debugPrint('⚠️ No order refresh callback registered!');
    }
  }
  
  /// Handle new order messages
  void _handleNewOrder(Map<String, dynamic> message) {
    try {
      debugPrint('🔍 Processing new order notification: $message');
      
      // 🔥 CRITICAL FIX: Always trigger refresh first for immediate UI update
      _triggerOrdersRefresh();
      
      // Try different possible data structures
      Map<String, dynamic>? orderData;
      
      // First, try the 'data' field (current backend format from order stream)
      if (message['data'] is Map<String, dynamic>) {
        orderData = message['data'] as Map<String, dynamic>;
        debugPrint('📦 Found order data in "data" field');
      }
      // Try the 'payload.data' structure
      else if (message['payload'] is Map<String, dynamic>) {
        final payload = message['payload'] as Map<String, dynamic>;
        if (payload['data'] is Map<String, dynamic>) {
          orderData = payload['data'] as Map<String, dynamic>;
          debugPrint('📦 Found order data in "payload.data" field');
        } else {
          // payload itself might contain order data
          orderData = payload;
          debugPrint('📦 Using payload as order data');
        }
      }
      // Try the 'notification' field
      else if (message['notification'] is Map<String, dynamic>) {
        final notification = message['notification'] as Map<String, dynamic>;
        if (notification['data'] is Map<String, dynamic>) {
          orderData = notification['data'] as Map<String, dynamic>;
          debugPrint('📦 Found order data in "notification.data" field');
        }
      }
      // Try the message itself as order data
      else if (message.containsKey('orderId') || message.containsKey('id')) {
        orderData = message;
        debugPrint('📦 Using message root as order data');
      }

      if (orderData != null) {
        debugPrint('📋 Order data to process: $orderData');

        // For messages from order stream, we need to reconstruct the full order
        // The stream only sends orderId and businessId, we need the full order details
        if (orderData.containsKey('orderId') &&
            orderData.containsKey('businessId') &&
            !orderData.containsKey('customerName')) {
          debugPrint(
              '🔄 Detected order stream message, fetching full order details');
          // 🔥 CRITICAL FIX: Immediately trigger order refresh AND fetch details
          // This ensures UI updates even if WebSocket message is incomplete
          _triggerOrdersRefresh();
          _fetchAndAddOrder(orderData['orderId'], orderData['businessId']);
          return;
        }
        
        // Ensure we have the required fields for Order.fromJson
        if (!orderData.containsKey('orderId') && orderData.containsKey('id')) {
          orderData['orderId'] = orderData['id'];
        }
        
        try {
          final order = Order.fromJson(orderData);
          _safeAddToNewOrderController(order);
          debugPrint('✅ Successfully parsed new order: ${order.id}');
        } catch (parseError) {
          debugPrint('❌ Error parsing order data: $parseError');
          debugPrint('📄 Order data: $orderData');
          
          // Create a minimal order object as fallback
          final fallbackOrder = _createFallbackOrder(
              orderData, orderData['businessId']?.toString() ?? 'unknown');
          if (fallbackOrder != null) {
            _safeAddToNewOrderController(fallbackOrder);
            debugPrint('🔄 Created fallback order: ${fallbackOrder.id}');
          }
        }
      } else {
        debugPrint('❌ No valid order data found in message: $message');
      }
    } catch (error) {
      debugPrint('❌ Error handling new order notification: $error');
      debugPrint('📄 Original message: $message');
    }
  }

  /// Fetch full order details when we only have orderId from stream
  void _fetchAndAddOrder(String orderId, String businessId) async {
    try {
      debugPrint('🔍 Fetching full order details for: $orderId');

      // Fetch fresh orders from the server to get the new order
      final orders = await _orderService.getMerchantOrders(businessId);
      final newOrder = orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => throw Exception('Order not found'),
      );

      _safeAddToNewOrderController(newOrder);
      debugPrint('✅ Successfully fetched and added order: ${newOrder.id}');
    } catch (error) {
      debugPrint('❌ Error fetching order details: $error');

      // Create a minimal placeholder order
      final placeholderOrder = Order(
        id: orderId,
        businessId: businessId, // Add businessId parameter
        customerId: 'unknown',
        customerName: 'New Order (Loading...)',
        customerPhone: 'N/A',
        deliveryAddress: DeliveryAddress(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          street: 'Loading address...',
          city: 'Unknown',
          district: 'Unknown',
          country: 'Iraq',
          customerId: 'unknown',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        items: [],
        totalAmount: 0.0,
        createdAt: DateTime.now(),
        status: OrderStatus.pending,
        notes: 'Order details loading...',
      );

      _safeAddToNewOrderController(placeholderOrder);
      debugPrint('🔄 Added placeholder order, will refresh from server');

      // Trigger a refresh after a short delay
      Timer(const Duration(seconds: 2), () {
        _fetchAndAddOrder(orderId, businessId);
      });
    }
  }

  /// Create a fallback order when parsing fails
  Order? _createFallbackOrder(Map<String, dynamic> data, String businessId) {
    try {
      final orderId = data['orderId'] ?? data['id'] ?? 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      
      return Order(
        id: orderId.toString(),
        businessId: businessId, // Add businessId parameter
        customerId: data['customerId']?.toString() ?? 'unknown',
        customerName: data['customerName']?.toString() ?? 'Unknown Customer',
        customerPhone: data['customerPhone']?.toString() ?? 'N/A',
        deliveryAddress: DeliveryAddress(
          id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
          street: data['deliveryAddress']?['street']?.toString() ?? 'Unknown Address',
          city: data['deliveryAddress']?['city']?.toString() ?? 'Unknown City',
          district:
              data['deliveryAddress']?['district']?.toString() ?? 'Unknown',
          state: data['deliveryAddress']?['state']?.toString(),
          country: data['deliveryAddress']?['country']?.toString() ?? 'Iraq',
          customerId: (data['customerId']?.toString() ?? 'unknown'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        items: [], // Will be populated later when full order is fetched
        totalAmount: (data['totalAmount'] ?? data['total'] ?? 0).toDouble(),
        createdAt: DateTime.now(),
        status: OrderStatus.pending,
        notes: data['notes']?.toString(),
      );
    } catch (error) {
      debugPrint('❌ Error creating fallback order: $error');
      return null;
    }
  }

  /// Handle WebSocket error
  void _handleWebSocketError(dynamic error) {
    debugPrint('❌ WebSocket error: $error');
    _isConnected = false;
    _isConnecting = false;
    _didSendSubscribe = false;
    _safeAddToConnectionController(false);
    _stopPing();
    _stopHeartbeatTimer(); // ✅ Stop heartbeat timer on error
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnection
  void _handleWebSocketDisconnection() {
    debugPrint('🔌 WebSocket disconnected');
    _isConnected = false;
    _isConnecting = false;
    _didSendSubscribe = false;
    _safeAddToConnectionController(false);
    _stopPing();
    _stopHeartbeatTimer(); // ✅ Stop heartbeat timer on disconnection
    if (!_isDisposed && !_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  /// Send message through WebSocket
  void _sendWebSocketMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
        debugPrint('📤 WebSocket message sent: ${message['type']}');
      } catch (error) {
        debugPrint('❌ Error sending WebSocket message: $error');
      }
    }
  }

  /// Send merchant logout notification via WebSocket (public method)
  void sendMerchantLogout({required String businessId, required String userId}) {
    debugPrint('🔌 Sending merchant logout notification');
    _sendWebSocketMessage({
      'type': 'MERCHANT_LOGOUT',
      'businessId': businessId,
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'user_logout',
    });
  }

  /// Send business busy status update via WebSocket (public method)
  void sendBusinessBusyStatusUpdate(
      {required String businessId,
      required String userId,
      required bool isBusy}) {
    debugPrint(
        '🔌 Sending business busy status update: ${isBusy ? 'BUSY' : 'NOT BUSY'}');
    _sendWebSocketMessage({
      'type': 'BUSINESS_BUSY_STATUS_UPDATE',
      'businessId': businessId,
      'userId': userId,
      'isBusy': isBusy,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Send business status update (online/offline) for sidebar toggle
  void sendBusinessStatusUpdate({
    required String businessId,
    required String userId,
    required bool isActive,
  }) {
    debugPrint('🔌 Sending BUSINESS_STATUS_UPDATE: isActive=$isActive');
    _sendWebSocketMessage({
      'type': 'BUSINESS_STATUS_UPDATE',
      'businessId': businessId,
      'userId': userId,
      'isActive': isActive,
      'entityType': 'merchant',
      'userType': 'merchant',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Send custom WebSocket message (public method for toggle fix)
  void sendCustomMessage(Map<String, dynamic> message) {
    debugPrint('🔌 Sending custom WebSocket message: ${message['type']}');
    _sendWebSocketMessage(message);
  }

  /// Send heartbeat message to keep connection alive and update DynamoDB
  void sendHeartbeat() {
    if (_isConnected && _channel != null && _businessId != null) {
      final message = {
        'action': 'heartbeat',
        'type': 'heartbeat',  // ✅ Must be lowercase to match Route Selection Expression
        'businessId': _businessId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // ✅ Use _sendWebSocketMessage to ensure consistent message sending
      _sendWebSocketMessage(message);
      debugPrint('💓 Heartbeat sent at ${message['timestamp']}');
    }
  }

  /// Start heartbeat timer (15 second interval)
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      sendHeartbeat();
    });
    debugPrint('💓 Heartbeat timer started (15s interval)');
  }

  /// Stop heartbeat timer
  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('💓 Heartbeat timer stopped');
  }

  /// Start periodic ping to keep connection alive
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) {
      if (_isConnected) {
        _sendWebSocketMessage({
          'type': 'PING',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Stop ping timer
  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_isDisposed || _reconnectAttempts >= maxReconnectAttempts) {
      debugPrint(
          '❌ Max reconnection attempts reached or service disposed. Using polling fallback.');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectAttempts++;
      debugPrint('🔄 WebSocket reconnection attempt $_reconnectAttempts');
      _connectWebSocket();
    });
  }

  /// Start polling fallback for when WebSocket is not available
  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(pollingFallbackInterval, (_) async {
      if (!_isConnected && _businessId != null && !_isDisposed) {
        await _pollForNewOrders();
      }
    });
    debugPrint(
        '📊 Polling fallback started (${pollingFallbackInterval.inSeconds}s interval)');
  }

  /// Poll for new orders when WebSocket is not available
  List<String> _lastKnownOrderIds = [];

  Future<void> _pollForNewOrders() async {
    try {
      final orders = await _orderService.getMerchantOrders(_businessId);
      final currentOrderIds = orders.map((o) => o.id).toList();

      // Find new orders
      final newOrderIds = currentOrderIds
          .where((id) => !_lastKnownOrderIds.contains(id))
          .toList();

      for (final orderId in newOrderIds) {
        final order = orders.firstWhere((o) => o.id == orderId);
        if (order.status == OrderStatus.pending) {
          _safeAddToNewOrderController(order);
          debugPrint('🆕 New order found via polling: ${order.id}');
        }
      }

      _lastKnownOrderIds = currentOrderIds;
    } catch (error) {
      debugPrint('❌ Error polling for orders: $error');
    }
  }

  /// Refresh connection with new auth token
  Future<void> refreshConnection() async {
    _authToken = await AppAuthService.getAccessToken();
    if (_authToken != null && _businessId != null) {
      await disconnect();
      await _connectWebSocket();
    }
  }

  /// Disconnect WebSocket
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _channel?.sink.close();
    _stopPing();
    _stopHeartbeatTimer(); // ✅ Stop heartbeat timer
    _reconnectTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
    _didSendSubscribe = false;
    _safeAddToConnectionController(false);
    debugPrint('🔌 WebSocket disconnected manually');
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    debugPrint('🗑️ Disposing RealtimeOrderService...');
    _isDisposed = true;
    
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    disconnect();
    _newOrderController?.close();
    _orderUpdateController?.close();
    _connectionController?.close();
    _soundTrackingCleanupTimer?.cancel();
    _audioService.dispose();
    debugPrint('✅ RealtimeOrderService disposed');
  }

  /// Handle app lifecycle state changes (iOS background/foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 App Lifecycle State Changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground
        debugPrint('🟢 App resumed - Reconnecting WebSocket...');
        _handleAppResumed();
        break;
      
      case AppLifecycleState.paused:
        // App went to background
        debugPrint('⏸️ App paused - Keeping WebSocket alive for background notifications');
        _handleAppPaused();
        break;
      
      case AppLifecycleState.inactive:
        // App is inactive (transitioning)
        debugPrint('🟡 App inactive');
        break;
      
      case AppLifecycleState.detached:
        // App is being terminated
        debugPrint('🔴 App detached');
        break;
        
      case AppLifecycleState.hidden:
        // App window is hidden but still running
        debugPrint('👻 App hidden');
        break;
    }
  }

  /// Handle app resumed from background
  void _handleAppResumed() {
    // CRITICAL iOS FIX: Poll immediately when returning to foreground
    // This ensures we get any orders that arrived while in background
    if (_businessId != null && !_manualDisconnect) {
      debugPrint('⚡ Polling immediately after app resume...');
      _pollForNewOrders();
    }
    
    // Reconnect WebSocket if disconnected
    if (!_isConnected && _businessId != null && !_manualDisconnect) {
      debugPrint('🔄 Reconnecting WebSocket after app resume...');
      _connectWebSocket();
    }
    
    // Resume ping timer
    if (_isConnected && _pingTimer == null) {
      _startPing();
    }
    
    // Resume normal polling
    if (_pollingTimer == null || !_pollingTimer!.isActive) {
      _startPollingFallback();
    }
  }

  /// Handle app paused to background
  void _handleAppPaused() {
    // iOS BACKGROUND FIX: Poll immediately before going to background
    // This catches any last-second orders
    if (_businessId != null && !_manualDisconnect) {
      debugPrint('⚡ Polling immediately before background...');
      _pollForNewOrders();
    }
    
    // On iOS, WebSocket connections are suspended in background
    // We need to increase ping frequency to keep connection alive
    if (_isConnected) {
      debugPrint('📡 Adjusting WebSocket for background mode...');
      
      // Stop normal ping
      _stopPing();
      
      // Start aggressive ping for background (every 10 seconds)
      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (_isConnected && !_manualDisconnect) {
          _sendWebSocketMessage({
            'type': 'PING',
            'timestamp': DateTime.now().toIso8601String(),
            'background': true,
          });
        }
      });
    }
    
    // CRITICAL iOS FIX: Increase polling frequency to 5 seconds (was 10)
    // This provides faster order detection in background
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_businessId != null && !_manualDisconnect) {
        await _pollForNewOrders();
      }
    });
  }

  /// Send order status update to customers via WebSocket
  /// This notifies WizzUser app about order status changes
  void sendOrderStatusUpdateToCustomers({
    required String orderId,
    required String status,
    required String businessId,
  }) {
    try {
      if (!_isConnected) {
        debugPrint('⚠️ Cannot send order status update - WebSocket not connected');
        return;
      }

      final message = {
        'type': 'ORDER_STATUS_UPDATE',
        'orderId': orderId,
        'status': status,
        'businessId': businessId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendWebSocketMessage(message);
      debugPrint('📤 Sent order status update to customers: $orderId -> $status');
    } catch (e) {
      debugPrint('❌ Error sending order status update: $e');
    }
  }
}
