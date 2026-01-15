import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import '../core/utils/app_logger.dart';
import 'notification_service.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(
    ref: ref,
    onMessage: (data) {
      // Handle incoming messages globally or pass to another service
      AppLogger.info('Global WebSocket Message: $data');

    },
    onDone: () {
      AppLogger.info('Global WebSocket Closed');

    },
    onError: (error) {
      AppLogger.error('Global WebSocket Error: $error');

    },
  );
});

class WebSocketService {
  IOWebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final Function(dynamic) onMessage;
  final Function() onDone;
  final Function(dynamic) onError;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String? _lastUrl;
  String? _lastToken;
  final Ref ref;

  WebSocketService({
    required this.onMessage,
    required this.onDone,
    required this.onError,
    required this.ref,
  });

  void connect(String url, String token) {
    _lastUrl = url;
    _lastToken = token;
    _disconnect(); // Clean up previous connection state
    _connect();
  }

  void _connect() {
    if (_lastUrl == null || _lastToken == null) {
      AppLogger.info('WebSocket: URL or token not available for connection.');

      return;
    }
    AppLogger.info('WebSocket: Attempting to connect to $_lastUrl');

    final headers = {'Authorization': _lastToken!};
    _channel = IOWebSocketChannel.connect(
      Uri.parse(_lastUrl!),
      headers: headers,
      pingInterval: const Duration(seconds: 30),
    );
    AppLogger.info('WebSocket: Connection established.');

    _reconnectAttempts = 0; // Reset on successful connection

    _channelSubscription = _channel!.stream.listen(
      (message) {
        AppLogger.info('WebSocket: Message received: $message');

        final decodedMessage = jsonDecode(message);

        // Check if this is an actionable order notification
        if (decodedMessage['type'] == 'NEW_ORDER' &&
            decodedMessage['payload']?['data']?['actions'] != null) {
          final orderId = decodedMessage['payload']['data']['orderId'];
          final notificationService = ref.read(notificationServiceProvider);
          notificationService.addOrderNotification(
            title: 'New Order!',
            body: 'You have a new order: $orderId',
            orderId: orderId,
          );
        }

        // 🔄 Task 6: Handle order reassigning notification
        // When driver unassigns, merchant receives notification to show reassigning status
        if (decodedMessage['type'] == 'order_reassigning') {
          final orderId = decodedMessage['payload']?['orderId'];
          AppLogger.info(
              'WebSocket: Order $orderId is being reassigned - searching for new driver');
          
          final notificationService = ref.read(notificationServiceProvider);
          notificationService.addOrderNotification(
            title: 'جاري البحث عن سائق بديل',
            body: 'الطلب رقم $orderId - السائق السابق ألغى القبول',
            orderId: orderId,
          );
        }

        onMessage(decodedMessage);
      },
      onDone: () {
        AppLogger.info('WebSocket: Connection closed.');

        _channel = null;
        _channelSubscription = null;
        onDone();
        _scheduleReconnect();
      },
      onError: (error) {
        AppLogger.error('WebSocket: Error: $error');

        _channel = null;
        _channelSubscription = null;
        onError(error);
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    if (_reconnectAttempts >= 5) {
      AppLogger.info(
          'WebSocket: Max reconnection attempts reached. Giving up.');

      return;
    }
    final delay = Duration(seconds: 2 * (_reconnectAttempts + 1));
    _reconnectAttempts++;
    AppLogger.info(
        "WebSocket: Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds} seconds.");
    _reconnectTimer = Timer(delay, _connect);
  }

  void disconnect() {
    AppLogger.info('WebSocket: Disconnecting manually.');

    _disconnect();
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _channelSubscription = null;
  }

  /// Send merchant status update when toggle is changed
  void sendMerchantStatusUpdate({
    required String businessId,
    required String userId,
    required bool isOnline,
  }) {
    if (_channel?.sink == null) {
      AppLogger.info(
          'WebSocket: Cannot send status update - no active connection');

      return;
    }

    final message = {
      'type': 'BUSINESS_STATUS_UPDATE',
      'businessId': businessId,
      'userId': userId,
      'status': isOnline ? 'online' : 'offline',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      _channel!.sink.add(jsonEncode(message));
      AppLogger.info(
          'WebSocket: Merchant status update sent - $businessId: ${isOnline ? 'online' : 'offline'}');

    } catch (error) {
      AppLogger.error(
          'WebSocket: Error sending merchant status update: $error');

    }
  }

  /// Send business busy status update - NEW APPROACH for UI toggle
  void sendBusinessBusyStatusUpdate({
    required String businessId,
    required String userId,
    required bool isBusy,
  }) {
    if (_channel?.sink == null) {
      AppLogger.info(
          'WebSocket: Cannot send busy status update - no active connection');

      return;
    }

    final message = {
      'type': 'BUSINESS_BUSY_STATUS_UPDATE',
      'businessId': businessId,
      'userId': userId,
      'isBusy': isBusy,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      _channel!.sink.add(jsonEncode(message));
      AppLogger.info(
          "WebSocket: Business busy status update sent - $businessId: ${isBusy ? 'BUSY' : 'NOT BUSY'}");
    } catch (error) {
      AppLogger.error(
          'WebSocket: Error sending business busy status update: $error');

    }
  }

  /// Send merchant logout notification
  void sendMerchantLogout({
    required String businessId,
    required String userId,
  }) {
    if (_channel?.sink == null) {
      AppLogger.info(
          'WebSocket: Cannot send logout notification - no active connection');

      return;
    }

    final logoutMessage = {
      'type': 'MERCHANT_LOGOUT',
      'businessId': businessId,
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'user_logout',
    };

    try {
      _channel!.sink.add(jsonEncode(logoutMessage));
      AppLogger.info(
          'WebSocket: Merchant logout notification sent - $businessId');

      
      // Wait a moment for the message to be sent before disconnecting
      Future.delayed(const Duration(milliseconds: 500), () {
        disconnect();
      });
    } catch (error) {
      AppLogger.error('WebSocket: Error sending logout notification: $error');

      // Still disconnect even if message fails
      disconnect();
    }
  }

  /// Send heartbeat/ping message
  void sendHeartbeat() {
    if (_channel?.sink == null) return;

    final message = {
      'type': 'HEARTBEAT',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (error) {
      AppLogger.error('WebSocket: Error sending heartbeat: $error');

    }
  }
}
