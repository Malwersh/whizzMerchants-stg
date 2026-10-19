import '../services/merchant_order_alerts.dart';
import '../widgets/preparation_time_sheet.dart';
import 'order_return_screen.dart';
import 'order_cancellation_screen.dart';
import '../services/branch_employee_access.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/audio_notification_service.dart';
import '../services/kitchen_dispatch_service.dart';
import '../services/realtime_order_service.dart';
import '../services/order_cache_service.dart';
import '../services/push_notifications_service.dart';
import '../screens/auth/auth_screen.dart';
import '../widgets/order_card.dart';
import '../widgets/cancel_reason_bottom_sheet.dart';
import '../utils/responsive_helper.dart';
import '../providers/session_provider.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../utils/snackbar_helper.dart';
import '../core/utils/app_logger.dart';
import '../core/exceptions/auth_exceptions.dart';

class OrdersPage extends ConsumerStatefulWidget {
  final String? businessId;
  final String? focusOrderId;
  final BranchEmployeeAccess? employeeAccess;

  const OrdersPage({
    super.key,
    this.businessId,
    this.focusOrderId,
    this.employeeAccess,
  });

  @override
  _OrdersPageState createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final OrderService _orderService = OrderService();
  final RealtimeOrderService _realtimeService = RealtimeOrderService();
  List<Order> _orders = [];
  String _selectedFilter = 'confirmed'; // عرض الطلبات المؤكدة بشكل افتراضي
  bool _isInitializing = true;
  bool _isLoading = true;
  String? _soundSnapshotBusinessId;
  final Set<String> _observedOrderIds = {};
  StreamSubscription? _arrivalSubscription;
  StreamSubscription? _snapshotSubscription;
  int _snapshotRevision = 0;
  String? _queuedRefreshBusinessId;
  StreamSubscription? _newOrderSubscription;
  StreamSubscription? _orderUpdateSubscription;
  Timer? _smartPollingTimer; // 🎯 Smart polling للطلبات النشطة فقط
  bool _disposed = false; // track disposal to stop timers
  int _sessionWaitAttempts = 0; // attempts waiting for session readiness
  static const int _maxSessionWaitAttempts = 40; // ~40 * 150ms = 6s cap

  @override
  void initState() {
    super.initState();
    _arrivalSubscription = MerchantOrderAlerts.events.listen((event) {
      final branch = widget.employeeAccess?.businessId ??
          widget.businessId ??
          ref.read(sessionProvider).businessId;
      if (event['businessId'] != branch || !mounted || _disposed) return;
      if (_isLoading && widget.employeeAccess == null) {
        _queuedRefreshBusinessId = branch;
        return;
      }
      unawaited(
          _loadOrders(branch!, preserveNewOrders: true).catchError((Object e) {
        AppLogger.error('Arrival refresh failed: $e');
      }));
    });
    _snapshotSubscription = MerchantOrderAlerts.snapshots.listen((snapshot) {
      final branch = widget.employeeAccess?.businessId ??
          widget.businessId ??
          ref.read(sessionProvider).businessId;
      if (snapshot.businessId != branch || !mounted || _disposed) return;
      _snapshotRevision++;
      _observedOrderIds.addAll(snapshot.orders.map((o) => o.id));
      setState(() {
        _orders = List<Order>.of(snapshot.orders);
      });
    });
    if (widget.employeeAccess != null) {
      _selectedFilter = 'pending';
      _loadEmployeeOrders();
      _smartPollingTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _loadEmployeeOrders());
      return;
    }
    _waitForSessionReadyAndInitialize(); // defer initialization until session.isReady
  }

  void _waitForSessionReadyAndInitialize() {
    if (_disposed) return;
    final session = ref.read(sessionProvider);
    final hasWidgetBusiness =
        widget.businessId != null && widget.businessId!.isNotEmpty;
    // FIX: proceed if authenticated + businessId present even if isReady not yet flipped.
    if (session.isAuthenticated &&
        (session.businessId != null || hasWidgetBusiness)) {
      _validateAuthenticationAndInitialize();
      return;
    }
    if ((session.isAuthenticated && session.businessId != null) ||
        hasWidgetBusiness) {
      _validateAuthenticationAndInitialize();
      return;
    }
    _sessionWaitAttempts++;
    if (_sessionWaitAttempts > _maxSessionWaitAttempts) {
      if (!session.isAuthenticated) {
        _showAuthenticationRequiredDialog();
      } else {
        setState(() {
          _isInitializing = true;
        });
      }
      return;
    }
    Future.delayed(
        const Duration(milliseconds: 150), _waitForSessionReadyAndInitialize);
  }

  @override
  void dispose() {
    _disposed = true;
    _arrivalSubscription?.cancel();
    _snapshotSubscription?.cancel();
    _smartPollingTimer?.cancel(); // 🎯 Cancel smart polling
    if (widget.employeeAccess != null) {
      super.dispose();
      return;
    }
    _realtimeService
        .setOrderRefreshCallback(null); // 🔥 Clear callback on dispose
    PushNotificationsService.instance
        .setOrderRefreshCallback(null); // 🔥 Clear push callback
    _cleanupRealtimeService();
    super.dispose();
  }

  void _initializeRealtimeService() {
    final loc = AppLocalizations.of(context)!;

    // 🔥 CRITICAL FIX: Register order refresh callback for push notifications and WebSocket
    final refreshCallback = () async {
      debugPrint('🔔 Order refresh triggered by push/WebSocket');
      final session = ref.read(sessionProvider);
      if (session.isAuthenticated && session.businessId != null) {
        await _loadOrders(session.businessId!, preserveNewOrders: true);
      }
    };

    // Register callback with both services
    _realtimeService.setOrderRefreshCallback(refreshCallback);
    PushNotificationsService.instance.setOrderRefreshCallback(refreshCallback);
    debugPrint(
        '✅ Order refresh callbacks registered with RealtimeService and PushNotificationsService');

    // Subscribe to new orders with IMMEDIATE processing
    _newOrderSubscription = _realtimeService.newOrderStream.listen((newOrder) {
      debugPrint(
          '🚨 IMMEDIATE NEW ORDER notification received: ${newOrder.id}');
      debugPrint(
          '🚨 Order details: ${newOrder.customerName}, Total: ${newOrder.totalAmount}');

      if (mounted) {
        // FIRST: Add the order to local list for IMMEDIATE UI update
        setState(() {
          // Check if order already exists to avoid duplicates
          final existingIndex =
              _orders.indexWhere((order) => order.id == newOrder.id);
          if (existingIndex == -1) {
            // Insert at the beginning so it appears at the top
            _orders.insert(0, newOrder);
            debugPrint(
                '🚨 IMMEDIATE: Order added to local list: ${newOrder.id}');
          } else {
            // Update existing order with new data
            _orders[existingIndex] = newOrder;
            debugPrint('🚨 IMMEDIATE: Updated existing order: ${newOrder.id}');
          }

          // Keep the merchant's current tab; the alert provides an explicit View action.
        });

        // The branch-scoped attention host presents a dismissible alert.

        // THIRD: Background server sync (delayed to not interfere with immediate UI)
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted) {
            final session = ref.read(sessionProvider);
            if (session.isAuthenticated && session.businessId != null) {
              debugPrint('🔄 Background sync: Refreshing from server');
              await _loadOrders(session.businessId!, preserveNewOrders: true);
            }
          }
        });
      }
    });

    // Subscribe to order updates
    _orderUpdateSubscription =
        _realtimeService.orderUpdateStream.listen((update) {
      if (mounted) {
        _handleRealtimeOrderUpdate(update);
      }
    });
  }

  void _cleanupRealtimeService() {
    // Cancel subscriptions safely
    _newOrderSubscription?.cancel();
    _orderUpdateSubscription?.cancel();

    // Reset subscription references
    _newOrderSubscription = null;
    _orderUpdateSubscription = null;

    // Disconnect but don't dispose the singleton service
    // The service handles its own lifecycle as a singleton
    if (!_isInitializing && _realtimeService.isConnected) {
      _realtimeService.disconnect();
    }
  }

  /// 🎯 Start smart polling - only polls active orders with drivers
  /// This reduces unnecessary API calls and updates only when needed
  void _startSmartPolling() {
    _smartPollingTimer?.cancel();
    _smartPollingTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_disposed || !mounted) {
        timer.cancel();
        return;
      }

      // Only poll when viewing "ready" or "delivered" tabs (where driver status matters)
      if (!['ready', 'delivered'].contains(_selectedFilter)) {
        return;
      }

      // Get active orders (orders with drivers OR orders that should have drivers)
      final activeOrders = _orders.where((order) {
        // Include orders that already have drivers and aren't completed
        final hasDriver = order.driverId != null &&
            order.status != OrderStatus.delivered &&
            order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled;

        // 🎯 ALSO include ready orders without drivers (waiting for assignment)
        final isReadyWaitingForDriver = [
              OrderStatus.ready,
              OrderStatus.readyForPickup
            ].contains(order.status) &&
            order.driverId == null;

        // 🎯 CRITICAL: Include ALL assigned orders (they MUST have drivers in backend)
        // Even if UI hasn't updated yet (driverId may still be null locally)
        final isAssigned = order.status == OrderStatus.assigned;

        final shouldPoll = hasDriver || isReadyWaitingForDriver || isAssigned;

        // 🔍 Debug logging for each order
        if (shouldPoll) {
          AppLogger.debug(
              '🎯 POLLING: Order ${order.orderNumber} - status=${order.status}, driverId=${order.driverId}, hasDriver=$hasDriver, isReady=$isReadyWaitingForDriver, isAssigned=$isAssigned');
        }

        return shouldPoll;
      }).toList();

      if (activeOrders.isEmpty) {
        // No active orders to poll
        return;
      }

      AppLogger.debug(
          '🎯 Smart polling: Checking ${activeOrders.length} active orders');

      // Refresh each active order with cache checking
      for (final order in activeOrders) {
        await _refreshSingleOrder(order.id);
      }
    });
    AppLogger.info('✅ Smart polling started (cache-based, every 3 seconds)');
  }

  void _handleRealtimeOrderUpdate(Map<String, dynamic> update) {
    final orderId = update['orderId'] as String?;
    final status = update['status'] as String?;

    AppLogger.info(
        '🔄 Real-time update received: orderId=$orderId, status=$status');

    if (orderId != null && status != null) {
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex != -1) {
        AppLogger.debug(
            '🔄 Order found in list, refreshing from API for latest data...');

        // ✅ الحل الأمثل: إعادة تحميل الطلب الواحد من API للحصول على أحدث البيانات
        _refreshSingleOrder(orderId);
      }
    }
  }

  /// 🔄 Refresh a single order from API to get latest driver info and status
  /// Uses cache to detect changes and only updates UI when needed
  Future<void> _refreshSingleOrder(String orderId) async {
    try {
      AppLogger.info('🔵 _refreshSingleOrder START for order: $orderId');

      final session = ref.read(sessionProvider);
      if (!session.isAuthenticated || session.businessId == null) {
        AppLogger.warning('Cannot refresh order: not authenticated');
        return;
      }

      AppLogger.debug('🔄 Fetching latest data for order: $orderId');

      // Fetch all orders (since we don't have a single-order endpoint)
      final orders = await _orderService.getMerchantOrders(
        session.businessId!,
        status: null, // Get all to find this specific order
      );

      // Find the updated order
      final updatedOrder = orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => throw Exception('Order not found'),
      );

      AppLogger.info('🔵 Order found, checking for changes...');

      // 🎯 Check if order actually changed using cache
      final hasChanged = await OrderCacheService.hasOrderChanged(updatedOrder);

      AppLogger.info('🔵 hasOrderChanged result: $hasChanged');

      if (!hasChanged && _orders.any((order) => order.id == orderId)) {
        // No changes detected - skip UI update
        AppLogger.debug('⏭️ Order $orderId unchanged - skipping UI update');
        return;
      }

      // 💾 Cache the new order data
      await OrderCacheService.cacheOrder(updatedOrder);
      AppLogger.info('🔄 Order $orderId CHANGED - updating UI');

      // ✅ Update UI only when there's actual change
      if (mounted) {
        setState(() {
          final orderIndex = _orders.indexWhere((order) => order.id == orderId);
          if (orderIndex != -1) {
            _orders[orderIndex] = updatedOrder;
            AppLogger.success('✅ Order $orderId refreshed with latest data');
            updatedOrder.logDriverInfo(); // Log driver info for debugging
          } else {
            _orders.insert(0, updatedOrder);
          }
        });
      }
    } catch (e) {
      AppLogger.debug('Failed to refresh order $orderId: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'canceled_by_user':
      case 'canceled_by_store':
      case 'canceled_by_system':
      case 'cancelled':
        return WhizzColors.error;
      case 'delivered':
        return WhizzColors.success;
      case 'expired':
        return WhizzColors.warning;
      case 'returned':
        return Colors.orange;
      default:
        return WhizzColors.secondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'canceled_by_user':
      case 'canceled_by_store':
      case 'canceled_by_system':
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'expired':
        return Icons.timer_off_rounded;
      case 'returned':
        return Icons.keyboard_return_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusDisplayName(String status) {
    final loc = AppLocalizations.of(context)!;
    switch (status.toLowerCase()) {
      case 'canceled_by_user':
        return loc.cancelled; // Using generic cancelled for now
      case 'canceled_by_store':
        return loc.cancelled; // Using generic cancelled for now
      case 'canceled_by_system':
        return loc.cancelled; // Using generic cancelled for now
      case 'cancelled':
        return loc.cancelled;
      case 'delivered':
        return loc.delivered;
      case 'expired':
        return loc.expired;
      case 'returned':
        return loc.orderReturned;
      case 'pending':
        return loc.pending;
      case 'confirmed':
        return loc.confirmed;
      case 'preparing':
        return loc.preparing;
      case 'ready':
        return loc.orderReady;
      case 'on_the_way':
        return loc.onTheWay;
      default:
        return status;
    }
  }

  Future<void> _validateAuthenticationAndInitialize() async {
    AppLogger.debug('_validateAuthenticationAndInitialize invoked');
    final session = ref.read(sessionProvider);

    // Use widget.businessId if provided (prevents race with session restoration)
    final effectiveBusinessId = widget.businessId ?? session.businessId;

    if (!session.isAuthenticated) {
      AppLogger.warning('Not authenticated, navigating to login (no dialog)');
      _navigateToLogin();
      return;
    }

    if (effectiveBusinessId == null) {
      AppLogger.debug(
          'BusinessId still null post readiness wait - retrying short grace loop');
      // Short grace retries before declaring failure
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (ref.read(sessionProvider).businessId != null) {
          AppLogger.success('BusinessId appeared during grace loop');
          break;
        }
      }
    }

    final finalBusinessId =
        widget.businessId ?? ref.read(sessionProvider).businessId;
    if (finalBusinessId == null) {
      AppLogger.error(
          'BusinessId missing after grace loop - showing authentication dialog');
      _showAuthenticationRequiredDialog();
      return;
    }

    AppLogger.success(
        'Proceeding with initialization using businessId: $finalBusinessId');
    try {
      setState(() {
        _isInitializing = true;
      });
      await _loadOrders(finalBusinessId, preserveNewOrders: false);
      await _realtimeService.initialize(finalBusinessId);
      _initializeRealtimeService();
      _startSmartPolling(); // 🎯 Start smart polling for active orders only
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        AppLogger.success('OrdersPage initialization complete');
      }
    } on AuthTokenExpiredException catch (e) {
      // Phase 4.3: Handle auth token expired
      AppLogger.error('Auth token expired during initialization: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        ref.read(sessionProvider.notifier).clearSession();
        _showAuthenticationRequiredDialog();
      }
    } on UnauthorizedException catch (e) {
      // Phase 4.3: Handle unauthorized access
      AppLogger.error('Unauthorized during initialization: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        ref.read(sessionProvider.notifier).clearSession();
        _showAuthenticationRequiredDialog();
      }
    } catch (e) {
      AppLogger.error('Initialization error: $e');
      if (mounted)
        setState(() {
          _isInitializing = false;
        });
      // Only show dialog if authentication actually failed
      if (!ref.read(sessionProvider).isAuthenticated) {
        _showAuthenticationRequiredDialog();
      }
    }
  }

  bool _employeeLoading = false;
  String? _employeeError;
  Future<void> _loadEmployeeOrders() async {
    if (_employeeLoading || !mounted) return;
    _employeeLoading = true;
    try {
      final orders = await widget.employeeAccess!.orders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _employeeError = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _orders = [];
          _employeeError = e.toString();
        });
    } finally {
      _employeeLoading = false;
      if (mounted)
        setState(() {
          _isLoading = false;
          _isInitializing = false;
        });
    }
  }

  Future<void> _loadOrders(String businessId,
      {bool preserveNewOrders = false}) async {
    if (widget.employeeAccess != null) {
      await _loadEmployeeOrders();
      return;
    }
    // Skip check for multiple simultaneous loads during initialization
    // Only prevent if we're not initializing and already loading
    if (_isLoading && !_isInitializing) {
      AppLogger.warning('Already loading orders, skipping duplicate request');

      return;
    }

    final snapshotRevision = _snapshotRevision;
    try {
      AppLogger.info(
          'Loading orders for businessId: $businessId, selectedFilter: $_selectedFilter');

      // Set loading state
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Load ALL orders without API-level filtering
      // We'll filter on the client side using _shouldShowInFilter
      // This ensures we get all statuses needed for combined filters
      // (e.g., 'delivered' filter needs both delivered AND completed statuses)
      AppLogger.debug(
          'Loading all orders - filtering will be done client-side');

      AppLogger.api('Calling _orderService.getMerchantOrders...');

      final orders =
          await _orderService.getMerchantOrders(businessId, status: null);
      AppLogger.info('Received ${orders.length} orders from API');
      unawaited(PushNotificationsService.instance
          .registerTokenIfPossible(businessId: businessId));
      if (!mounted || _disposed) return;
      if (snapshotRevision != _snapshotRevision) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      if (_soundSnapshotBusinessId == businessId) {
        for (final order in orders) {
          if (order.status == OrderStatus.pending &&
              !_observedOrderIds.contains(order.id)) {
            unawaited(
                AudioNotificationService().playNewOrderSoundOnce(order.id));
          }
        }
      } else {
        _soundSnapshotBusinessId = businessId;
        _observedOrderIds.clear();
      }
      _observedOrderIds.addAll(orders.map((order) => order.id));

      if (mounted) {
        setState(() {
          List<Order> processedOrders = orders;

          // Log order statuses for verification
          AppLogger.debug('Processing ${processedOrders.length} orders:');

          for (int i = 0; i < processedOrders.length && i < 5; i++) {
            final order = processedOrders[i];
            AppLogger.info(
                'Order ${i + 1}: ID=${order.id}, status=${order.status}, businessId=${order.businessId}');
          }

          // Filtering is done client-side using _shouldShowInFilter in build()
          // No need to filter here since we load all orders

          if (preserveNewOrders) {
            // Merge server orders with locally updated orders to prevent disappearance
            // This handles backend sync delays or temporary inconsistencies
            final serverOrderIds = processedOrders.map((o) => o.id).toSet();

            // Keep locally updated orders that aren't in the server response yet
            final localUpdatedOrders = _orders
                .where((order) => !serverOrderIds.contains(order.id))
                .toList();

            AppLogger.info(
                'Preserving ${localUpdatedOrders.length} local orders not yet in server response');

            // Add local orders to the beginning of the list
            processedOrders.insertAll(0, localUpdatedOrders);
          }

          _orders = processedOrders;
          _isLoading = false; // Clear loading state
          AppLogger.success(
              'Orders state updated with ${_orders.length} orders');

          // Log order count by status for monitoring
          final statusCounts = <String, int>{};
          for (final order in _orders) {
            final status = order.status.toString();
            statusCounts[status] = (statusCounts[status] ?? 0) + 1;
          }
          AppLogger.debug('Orders by status: $statusCounts');

          AppLogger.debug('Current filter: $_selectedFilter');

          // DON'T auto-select tabs - let user choose their filter
          // This prevents hiding orders from the user's chosen view
          AppLogger.debug('Keeping current filter: $_selectedFilter');

          // Log filtered orders count
          List<Order> currentFilteredOrders = _orders
              .where((o) => widget.focusOrderId != null
                  ? o.id == widget.focusOrderId
                  : _shouldShowInFilter(o, _selectedFilter))
              .toList();
          AppLogger.debug(
              'Filtered orders for $_selectedFilter: ${currentFilteredOrders.length}');
        });
      }
    } on AuthTokenExpiredException catch (e) {
      // Phase 4.3: Handle auth token expired
      AppLogger.error('Auth token expired while loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ref.read(sessionProvider.notifier).clearSession();
        _showAuthenticationRequiredDialog();
      }
    } on UnauthorizedException catch (e) {
      // Phase 4.3: Handle unauthorized access
      AppLogger.error('Unauthorized while loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ref.read(sessionProvider.notifier).clearSession();
        _showAuthenticationRequiredDialog();
      }
    } catch (e) {
      AppLogger.error('_loadOrders failed with error: $e');
      AppLogger.error('Error type: ${e.runtimeType}');

      // Clear loading state on error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      rethrow;
    } finally {
      final queued = _queuedRefreshBusinessId;
      _queuedRefreshBusinessId = null;
      if (queued != null && mounted && !_disposed) {
        final branch =
            widget.businessId ?? ref.read(sessionProvider).businessId;
        if (branch == queued)
          unawaited(_loadOrders(queued, preserveNewOrders: true)
              .catchError((Object e) {
            AppLogger.error('Queued arrival refresh failed: $e');
          }));
      }
    }
  }

  void _dispatchToKitchen(Order order) {
    KitchenDispatchService.dispatchAcceptedOrder(order).then((result) {
      if (result == null || !mounted) return;
      if (!result.allOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'تعذّر الإرسال للمطبخ: ${result.failures.join('، ')} — تحقق من إعدادات POS'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  Future<void> _handleOrderUpdate(String orderId, OrderStatus newStatus) async {
    int? preparationMinutes;
    final branchId = widget.employeeAccess?.businessId ??
        widget.businessId ??
        ref.read(sessionProvider).businessId;
    if (newStatus == OrderStatus.confirmed) {
      if (branchId == null) return;
      preparationMinutes = await choosePreparationMinutes(context, branchId);
      if (preparationMinutes == null || !mounted) return;
    }
    if (widget.employeeAccess != null) {
      try {
        String? reason;
        if (newStatus == OrderStatus.cancelled) {
          reason = await _showCancelReasonBottomSheet();
          if (reason == null) return;
        }
        await widget.employeeAccess!.update(orderId, newStatus,
            reason: reason, preparationMinutes: preparationMinutes ?? 20);
        if (preparationMinutes != null)
          await rememberPreparationMinutes(branchId!, preparationMinutes);
        await _loadEmployeeOrders();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    try {
      // If it's a cancellation, show bottom sheet to get reason first
      if (newStatus == OrderStatus.cancelled) {
        final reason = await _showCancelReasonBottomSheet();
        if (reason == null) {
          // User cancelled the dialog
          AppLogger.info('User cancelled rejection dialog');
          return;
        }
        // Continue with cancellation using the selected reason
        await _performOrderCancellation(orderId, reason);
        return;
      }

      // Server decides the winner. Do not show a successful acceptance before it commits.
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);

      // STEP 2: Make the backend API call to update order status
      if (newStatus == OrderStatus.confirmed) {
        // Accept order
        await _orderService.acceptMerchantOrder(orderId,
            preparationMinutes: preparationMinutes ?? 20, businessId: branchId);
        if (preparationMinutes != null)
          await rememberPreparationMinutes(branchId!, preparationMinutes);
        // Send to kitchen printers / kitchen display (non-blocking).
        if (orderIndex != -1) {
          _dispatchToKitchen(_orders[orderIndex]);
        }
      } else {
        // Convert OrderStatus enum to string for backend for other status updates
        String statusString = _convertOrderStatusToString(newStatus);
        await _orderService.updateMerchantOrderStatus(orderId, statusString);
      }

      // STEP 3: Send WebSocket notification to customers about order status update
      final session = ref.read(sessionProvider);
      if (session.isAuthenticated && session.businessId != null) {
        debugPrint(
            '📤 Sending order status update to customers: $orderId -> $newStatus');
        _realtimeService.sendOrderStatusUpdateToCustomers(
          orderId: orderId,
          status: _convertOrderStatusToString(newStatus),
          businessId: session.businessId!,
        );

        // STEP 4: Reload orders from server to sync with backend state
        // Keep locally updated orders to prevent them from disappearing
        // This protects against backend sync delays or issues
        await _loadOrders(session.businessId!, preserveNewOrders: true);
      }

      // STEP 5: Show success notification (without tab switching)
      if (mounted) {
        String statusDisplayName =
            _getStatusDisplayNameForNotification(newStatus);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: WhizzColors.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: WhizzColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '✅ تم تحديث الطلب #${orderId.substring(0, 8)} → $statusDisplayName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to update order: $e');

      // Show error message to user
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${loc.failedToUpdateOrder}: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<String?> _showCancelReasonBottomSheet() async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CancelReasonBottomSheet(),
    );
  }

  Future<void> _performOrderCancellation(String orderId, String reason) async {
    try {
      // A rejection is shown only after the server commits it.
      // STEP 2: Call unified OrderService to cancel order
      final session = ref.read(sessionProvider);
      final businessId = session.businessId;
      if (businessId == null) {
        throw Exception('Business ID not found');
      }

      await _orderService.rejectMerchantOrder(orderId, businessId,
          reason: reason);
      AppLogger.success('✅ Order cancelled via unified OrderService');

      // STEP 3: Reload orders from server
      await _loadOrders(businessId, preserveNewOrders: true);

      // STEP 4: Show success notification
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: WhizzColors.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: WhizzColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '✅ تم رفض الطلب #${orderId.substring(0, 8)}\nالسبب: $reason',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to cancel order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('فشل في رفض الطلب: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _convertOrderStatusToString(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready'; // ❌ deprecated - keep for backward compatibility
      case OrderStatus.readyForPickup:
        return 'ready_for_pickup'; // ✅ الحالة الصحيحة لنظام الموجات
      case OrderStatus.reassigning: // 🔄 Task 6: Driver unassignment
        return 'reassigning';
      // 🚗 حالات السائق - Driver states
      case OrderStatus.assigned:
        return 'assigned';
      case OrderStatus.headingToStore:
        return 'heading_to_store';
      case OrderStatus.arrivedAtStore:
        return 'arrived_at_store';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.headingToCustomer:
        return 'heading_to_customer';
      case OrderStatus.arrivedAtCustomer:
        return 'arrived_at_customer';
      case OrderStatus.onTheWay:
        return 'ontheway';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.returning:
        return 'returning';
      case OrderStatus.returnArrived:
        return 'return_arrived';
      case OrderStatus.returned:
        return 'returned';
      case OrderStatus.expired:
        return 'expired';
    }
  }

  /// Get the recommended filter tab for a given order status
  String? _getRecommendedFilterForStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing'; // Show preparing orders in their own tab
      case OrderStatus.ready:
        return 'ready'; // deprecated
      case OrderStatus.readyForPickup:
        return 'ready'; // ✅ نفس التاب للحالتين
      case OrderStatus
            .reassigning: // 🔄 Task 6: Show in ready tab while searching for new driver
        return 'ready'; // Stay in ready tab during reassignment
      // 🚗 حالات السائق - Driver states (don't auto-switch)
      case OrderStatus.assigned:
      case OrderStatus.headingToStore:
      case OrderStatus.arrivedAtStore:
      case OrderStatus.pickedUp:
      case OrderStatus.headingToCustomer:
      case OrderStatus.arrivedAtCustomer:
      case OrderStatus.onTheWay:
        return null; // Don't auto-switch for driver-managed statuses
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return null; // Don't auto-switch for completed orders
      case OrderStatus.cancelled:
        return null; // Don't auto-switch to archive tabs automatically
      case OrderStatus.returning:
      case OrderStatus.returnArrived:
      case OrderStatus.returned:
      case OrderStatus.expired:
        return null; // Don't auto-switch to archive tabs automatically
    }
  }

  /// Show notification about status update and tab switch
  void _showStatusUpdateNotification(
      String orderId, OrderStatus newStatus, String newFilter) {
    final loc = AppLocalizations.of(context)!;
    String statusDisplayName = _getStatusDisplayNameForNotification(newStatus);
    String filterDisplayName = _getFilterDisplayName(newFilter);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: WhizzColors.successContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: WhizzColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '✅ Order #${orderId.substring(0, 8)} updated to $statusDisplayName\nSwitched to $filterDisplayName tab',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: WhizzColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: loc.view,
          textColor: Colors.white,
          backgroundColor: WhizzColors.successContainer,
          onPressed: () {
            // Filter is already switched, just close the snackbar
          },
        ),
      ),
    );
  }

  /// Get display name for order status in notifications
  String _getStatusDisplayNameForNotification(OrderStatus status) {
    final loc = AppLocalizations.of(context)!;
    switch (status) {
      case OrderStatus.pending:
        return loc.pending;
      case OrderStatus.confirmed:
        return loc.confirmed;
      case OrderStatus.preparing:
        return loc.preparing;
      case OrderStatus.ready:
        return loc.orderReady;
      case OrderStatus.readyForPickup:
        return 'جاهز للاستلام'; // ✅ الحالة الصحيحة
      case OrderStatus.reassigning: // 🔄 Task 6
        return 'جاري البحث عن سائق بديل';
      // 🚗 حالات السائق - Driver states
      case OrderStatus.assigned:
        return 'تم تعيين سائق';
      case OrderStatus.headingToStore:
        return 'السائق في الطريق للمطعم';
      case OrderStatus.arrivedAtStore:
        return 'السائق وصل للمطعم';
      case OrderStatus.pickedUp:
        return 'تم استلام الطلب';
      case OrderStatus.headingToCustomer:
        return 'في الطريق للزبون';
      case OrderStatus.arrivedAtCustomer:
        return 'وصل إلى الزبون';
      case OrderStatus.onTheWay:
        return loc.onTheWay;
      case OrderStatus.delivered:
        return loc.delivered;
      case OrderStatus.completed:
        return loc.delivered; // Use delivered for completed
      case OrderStatus.cancelled:
        return loc.cancelled;
      case OrderStatus.returning:
        return 'جاري إرجاع الطلب';
      case OrderStatus.returnArrived:
        return 'بانتظار تأكيد استلام المرتجع';
      case OrderStatus.returned:
        return loc.orderReturned;
      case OrderStatus.expired:
        return loc.expired;
    }
  }

  /// Get display name for filter tabs
  String _getFilterDisplayName(String filter) {
    final loc = AppLocalizations.of(context)!;
    switch (filter.toLowerCase()) {
      case 'pending':
        return loc.pending;
      case 'confirmed':
        return loc.confirmed;
      case 'preparing':
        return loc.preparing;
      case 'ready':
        return loc.orderReady;
      case 'on_the_way':
        return loc.onTheWay;
      case 'cancelled':
        return loc.cancelled;
      case 'returned':
        return loc.orderReturned;
      case 'expired':
        return loc.expired;
      case 'delivered':
        return loc.delivered;
      default:
        return filter;
    }
  }

  void _showAuthenticationRequiredDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: WhizzColors.white,
        elevation: 6,
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WhizzColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.security_rounded,
            color: WhizzColors.secondary,
            size: 32,
          ),
        ),
        title: Text(
          loc.userNotLoggedIn,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: WhizzColors.textPrimary,
              ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Please sign in to view orders',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: WhizzColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => _navigateToLogin(),
            style: FilledButton.styleFrom(
              backgroundColor: WhizzColors.secondary,
              foregroundColor: WhizzColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.login_rounded),
            label: Text(loc.signIn),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
      (route) => false,
    );
  }

  /// Check if an order should appear in a specific filter tab
  /// ✅ الطلب يبقى في تبويب "جاهز" حتى يتم تسليمه (delivered)
  bool _shouldShowInFilter(Order order, String filterValue) {
    final filter = filterValue.toLowerCase();

    switch (filter) {
      case 'all':
        return true; // Show all orders

      case 'pending':
        return order.status == OrderStatus.pending;

      case 'confirmed':
        return order.status == OrderStatus.confirmed;

      case 'preparing':
        return order.status == OrderStatus.preparing;

      case 'ready': // ✅ تبويب "جاهز" يشمل جميع حالات السائق قبل التسليم
        return order.status == OrderStatus.readyForPickup ||
            order.status ==
                OrderStatus.reassigning || // 🔄 Task 6: البحث عن سائق بديل
            order.status == OrderStatus.assigned ||
            order.status == OrderStatus.headingToStore ||
            order.status == OrderStatus.arrivedAtStore ||
            order.status == OrderStatus.pickedUp ||
            order.status == OrderStatus.headingToCustomer ||
            order.status == OrderStatus.arrivedAtCustomer ||
            order.status == OrderStatus.returning ||
            order.status == OrderStatus.returnArrived;

      case 'delivered': // تبويب "تم التوصيل" في الأرشيف
        return order.status == OrderStatus.delivered ||
            order.status == OrderStatus.completed;

      case 'cancelled':
        return order.status == OrderStatus.cancelled;

      case 'returned':
        return order.status == OrderStatus.returned;

      case 'expired':
        return order.status == OrderStatus.expired;

      default:
        AppLogger.warning('Unknown filter: $filter');
        return false;
    }
  }

  OrderStatus? _getStatusFromString(String value) {
    switch (value.toLowerCase()) {
      case 'all':
        return null; // Return null for 'all' to indicate no filtering
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready': // Tab filter uses 'ready' but maps to readyForPickup
      case 'ready_for_pickup':
      case 'readyforpickup':
        return OrderStatus
            .readyForPickup; // ✅ All "ready" variants map to readyForPickup
      case 'on_the_way':
      case 'ontheway':
        return OrderStatus.onTheWay; // Keep parsing but don't show in filters
      case 'delivered':
        return OrderStatus.delivered;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled_by_user':
      case 'canceled_by_store':
      case 'canceled_by_system':
        return OrderStatus.cancelled;
      case 'returned':
        return OrderStatus.returned;
      case 'expired':
        return OrderStatus.expired;
      default:
        AppLogger.warning('Unknown order status: $value');

        return null;
    }
  }

  /// Manual refresh of orders and real-time connection
  Future<void> _refreshOrders() async {
    if (widget.employeeAccess != null) {
      await _loadEmployeeOrders();
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final session = ref.read(sessionProvider);
      if (session.isAuthenticated && session.businessId != null) {
        await _loadOrders(session.businessId!, preserveNewOrders: false);
      }

      // Try to refresh real-time connection
      await _realtimeService.refreshConnection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: WhizzColors.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.refresh_rounded,
                      color: WhizzColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Orders refreshed successfully',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: WhizzColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        SnackBarHelper.showError(
          context,
          message: '${loc.failedToRefreshOrders}: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showArchiveStatusMenu(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: WhizzColors.white,
      elevation: 8,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WhizzColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.archive_rounded,
                        color: WhizzColors.secondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        loc.archiveAndHistory,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: WhizzColors.textPrimary,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: WhizzColors.grey50,
                        foregroundColor: WhizzColors.textSecondary,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Archive status options
                _buildArchiveMenuItem(
                  context,
                  icon: Icons.cancel_rounded,
                  label: loc.cancelled,
                  subtitle: loc.viewCancelledOrders,
                  value: 'cancelled',
                  color: WhizzColors.error,
                ),
                const SizedBox(height: 16),
                _buildArchiveMenuItem(
                  context,
                  icon: Icons.check_circle_rounded,
                  label: loc.delivered,
                  subtitle: loc.viewDeliveredOrders,
                  value: 'delivered',
                  color: WhizzColors.success,
                ),
                const SizedBox(height: 16),
                _buildArchiveMenuItem(
                  context,
                  icon: Icons.keyboard_return_rounded,
                  label: loc.orderReturned,
                  subtitle: loc.viewReturnedOrders,
                  value: 'returned',
                  color: WhizzColors.warning,
                ),
                const SizedBox(height: 16),
                _buildArchiveMenuItem(
                  context,
                  icon: Icons.timer_off_rounded,
                  label: loc.expired,
                  subtitle: loc.viewExpiredOrders,
                  value: 'expired',
                  color: WhizzColors.textSecondary,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedFilter == value;

    return Card(
      elevation: isSelected ? 4 : 1,
      shadowColor: isSelected
          ? color.withValues(alpha: 0.2)
          : WhizzColors.textPrimary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : color.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          setState(() {
            _selectedFilter = value;
          });
          Navigator.pop(context);

          // Refresh through the employee transport before consulting owner state.
          if (widget.employeeAccess != null) {
            await _loadEmployeeOrders();
            return;
          }
          final session = ref.read(sessionProvider);
          if (session.isAuthenticated && session.businessId != null) {
            await _loadOrders(session.businessId!, preserveNewOrders: false);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? color : WhizzColors.textPrimary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: WhizzColors.textSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveMenuButton() {
    final loc = AppLocalizations.of(context)!;
    final isArchiveSelected = ['cancelled', 'delivered', 'returned', 'expired']
        .contains(_selectedFilter);

    // Use design system spacing
    final isMobile = ResponsiveHelper.isMobile(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: FilterChip(
        selected: isArchiveSelected,
        onSelected: (_) => _showArchiveStatusMenu(context),
        avatar: Icon(
          Icons.archive_rounded,
          color: isArchiveSelected ? WhizzColors.black : WhizzColors.grey700,
          size: AppDimensions.iconSizeMD,
        ),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.archive,
              style: AppTypography.labelLarge.copyWith(
                fontWeight:
                    isArchiveSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isArchiveSelected ? WhizzColors.black : WhizzColors.grey700,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color:
                  isArchiveSelected ? WhizzColors.black : WhizzColors.grey700,
              size: AppDimensions.iconSizeMD,
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? AppSpacing.lg : AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        backgroundColor: WhizzColors.white,
        selectedColor: WhizzColors.primary,
        side: BorderSide(
          color: isArchiveSelected ? WhizzColors.primary : WhizzColors.grey300,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
        ),
        labelStyle: AppTypography.labelLarge.copyWith(
          color: isArchiveSelected ? WhizzColors.black : WhizzColors.grey700,
        ),
        elevation: isArchiveSelected ? 4 : 0,
        shadowColor: isArchiveSelected
            ? WhizzColors.primary.withValues(alpha: 0.3)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session =
        widget.employeeAccess == null ? ref.watch(sessionProvider) : null;
    if (widget.employeeAccess != null && _employeeError != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_employeeError!),
        TextButton(
            onPressed: _loadEmployeeOrders,
            child: const Text('إعادة المحاولة')),
      ]));
    }
    // FIX: Only show preparing screen if unauthenticated and no widget businessId; otherwise allow initialization flow.
    if (widget.employeeAccess == null &&
        !session!.isAuthenticated &&
        (widget.businessId == null || widget.businessId!.isEmpty)) {
      return Scaffold(
        backgroundColor: WhizzColors.backgroundPrimary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Preparing your session...',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: WhizzColors.backgroundPrimary,
        body: Center(
          child: Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: WhizzColors.grey100,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusXL),
              border: Border.all(
                color: WhizzColors.borderPrimary,
                width: 1,
              ),
              boxShadow: WhizzColors.elevation(2),
            ),
            child: AdaptiveLoadingIndicator(
              color: WhizzColors.black,
              size: 40,
            ),
          ),
        ),
      );
    }

    final loc = AppLocalizations.of(context)!;

    // Apply filtering logic using _shouldShowInFilter
    List<Order> filteredOrders = _orders
        .where((o) => widget.focusOrderId != null
            ? o.id == widget.focusOrderId
            : _shouldShowInFilter(o, _selectedFilter))
        .toList();

    // Sort orders appropriately
    if (_selectedFilter == 'pending') {
      // Sort pending orders by creation time (oldest first) for priority handling
      filteredOrders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips with Material 3 design - Fixed height container
            Container(
              height: 67, // Increased height by 20% (56 * 1.2 = 67.2 ≈ 67)
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ), // Removed vertical padding and margin for no spacing
              decoration: BoxDecoration(
                color: WhizzColors.white,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusXL),
                border: Border.all(
                  color: WhizzColors.borderPrimary,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: WhizzColors.shadow.withValues(alpha: 0.04),
                    blurRadius: AppSpacing.lg,
                    offset: Offset(0, AppSpacing.xs),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(loc.pending, 'pending'),
                    const SizedBox(width: 12),
                    _buildFilterChip(loc.confirmed, 'confirmed'),
                    const SizedBox(width: 12),
                    _buildFilterChip(loc.preparing, 'preparing'),
                    const SizedBox(width: 12),
                    _buildFilterChip(loc.orderReady, 'ready'),
                    const SizedBox(width: 20),
                    _buildArchiveMenuButton(),
                  ],
                ),
              ),
            ),

            // Orders list - Properly constrained
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: WhizzColors.white,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.borderRadiusXL),
                          boxShadow: [
                            BoxShadow(
                              color: WhizzColors.shadow.withValues(alpha: 0.04),
                              blurRadius: AppSpacing.lg,
                              offset: Offset(0, AppSpacing.xs),
                            ),
                          ],
                        ),
                        child: AdaptiveLoadingIndicator(
                          color: WhizzColors.secondary,
                          size: 40,
                        ),
                      ),
                    )
                  : filteredOrders.isEmpty
                      ? Center(
                          child: Container(
                            margin: EdgeInsets.all(AppSpacing.lg),
                            padding: EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: WhizzColors.white,
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.borderRadiusXL),
                              border: Border.all(
                                color: WhizzColors.borderPrimary,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: WhizzColors.shadow
                                      .withValues(alpha: 0.04),
                                  blurRadius: AppSpacing.lg,
                                  offset: Offset(0, AppSpacing.xs),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: WhizzColors.secondary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusXL),
                                  ),
                                  child: Icon(
                                    Icons.inbox_outlined,
                                    size: AppSpacing.xxl,
                                    color: WhizzColors.secondary,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.lg),
                                Text(
                                  loc.noOrdersFoundFor(_selectedFilter),
                                  style: AppTypography.titleLarge.copyWith(
                                    color: WhizzColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: AppSpacing.sm),
                                Text(
                                  'When orders come in, they\'ll appear here',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: WhizzColors.textPrimary
                                        .withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refreshOrders,
                          color: WhizzColors.secondary,
                          backgroundColor: WhizzColors.white,
                          child: ResponsiveHelper.isTablet(context) ||
                                  ResponsiveHelper.isDesktop(context)
                              ? _buildGridLayout(filteredOrders)
                              : _buildListLayout(filteredOrders),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    // Calculate order count for this filter using _shouldShowInFilter
    int orderCount = _orders.where((o) => _shouldShowInFilter(o, value)).length;

    return GestureDetector(
      onTap: () async {
        setState(() => _selectedFilter = value);

        // Load orders immediately when switching filters for main tabs
        // Skip for archive status filters as they handle their own loading
        if (value != 'cancelled' &&
            value != 'delivered' &&
            value != 'returned' &&
            value != 'expired') {
          if (widget.employeeAccess != null) {
            await _loadEmployeeOrders();
            return;
          }
          final session = ref.read(sessionProvider);
          if (session.isAuthenticated && session.businessId != null) {
            AppLogger.info('Loading orders for filter: $value');

            await _loadOrders(session.businessId!, preserveNewOrders: false);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? WhizzColors.primary : WhizzColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusFull),
          border: Border.all(
            color: isSelected ? WhizzColors.primary : WhizzColors.grey300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: WhizzColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(
                Icons.check_circle,
                color: WhizzColors.black,
                size: 16,
              ),
              SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? WhizzColors.black : WhizzColors.grey800,
              ),
            ),
            if (orderCount > 0) ...[
              SizedBox(width: AppSpacing.xs),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? WhizzColors.black : WhizzColors.grey200,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusSM),
                ),
                child: Text(
                  orderCount.toString(),
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? WhizzColors.primary : WhizzColors.grey700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  VoidCallback? _returnAction(Order order) {
    final a = order.financialAssignment;
    if (widget.employeeAccess != null || a == null) return null;
    final selectors = {
      'businessId': order.businessId,
      'orderId': order.id,
      'offerId': a['offerId'],
      'attempt': a['attempt']
    };
    if (a['returnId'] != null)
      return () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderReturnScreen(selectors: selectors)));
    if ([
      OrderStatus.assigned,
      OrderStatus.headingToStore,
      OrderStatus.arrivedAtStore
    ].contains(order.status))
      return () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OrderCancellationScreen(selectors: selectors)));
    return null;
  }

  Widget _buildListLayout(List<Order> orders) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(AppSpacing.lg),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: OrderCard(
            order: order,
            onTap: _returnAction(order),
            actionLabel: _returnAction(order) == null
                ? null
                : order.financialAssignment?['returnId'] != null
                    ? 'متابعة واستلام المرتجع'
                    : 'إلغاء قبل استلام السائق',
            onOrderUpdated: _handleOrderUpdate,
            canUpdateStatus: widget.employeeAccess?.canUpdate,
          ),
        );
      },
    );
  }

  Widget _buildGridLayout(List<Order> orders) {
    final crossAxisCount = ResponsiveHelper.getGridCrossAxisCount(context);
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(AppSpacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: ResponsiveHelper.isDesktop(context) ? 1.2 : 0.85,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          order: order,
          onTap: _returnAction(order),
          actionLabel: _returnAction(order) == null
              ? null
              : order.financialAssignment?['returnId'] != null
                  ? 'متابعة واستلام المرتجع'
                  : 'إلغاء قبل استلام السائق',
          onOrderUpdated: _handleOrderUpdate,
          canUpdateStatus: widget.employeeAccess?.canUpdate,
        );
      },
    );
  }
}
