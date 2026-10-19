import '../order_reception_settings_page.dart';
import '../../widgets/merchant_order_attention.dart';
import '../../widgets/commercial_requests_banner.dart';
import '../branch_employee_discounts_screen.dart';
import '../../widgets/branch_employee_status_control.dart';
import '../branch_employee_wallet_screen.dart';
import '../../services/branch_employee_access.dart';
import '../branch_device_tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders_page.dart';
import '../products_management_screen.dart';
import '../analytics_page.dart';
import '../discount_management_page.dart';
import '../profile_settings_page.dart';
import '../../models/business.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/app_state.dart';
import '../../services/api_service.dart';
import '../../providers/session_provider.dart';
import '../../providers/business_provider.dart';
import '../../widgets/modern_navigation_rail.dart';
import '../../widgets/top_app_bar.dart';
import '../../widgets/modern_sidebar.dart';
import '../../utils/responsive_helper.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import '../../core/design_system/design_system.dart';
import '../../core/adaptive/adaptive_widgets.dart';
import '../../core/exceptions/auth_exceptions.dart';
import '../../services/token_refresh_service.dart';

class BusinessDashboard extends ConsumerStatefulWidget {
  final Business? initialBusiness;
  final BranchEmployeeAccess? employeeAccess;

  const BusinessDashboard({
    super.key,
    this.initialBusiness,
    this.employeeAccess,
  });

  @override
  ConsumerState<BusinessDashboard> createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends ConsumerState<BusinessDashboard>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isOnline = true;
  List<Order> _orders = [];
  bool _loadingOrders = false;

  final OrderService _orderService = OrderService();
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    if (widget.employeeAccess != null) return;
    _appState.addListener(_onAppStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    if (widget.employeeAccess == null)
      _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) {
      setState(() {
        // Sync local _isOnline with AppState.isOnline to ensure sidebar shows correct status
        _isOnline = _appState.isOnline;
      });
    }
  }

  Future<void> _initializeData() async {
    final session = ref.read(sessionProvider);
    if (session.isAuthenticated && session.businessId != null) {
      // Initialize online status from database to get the real current value
      await _appState.initializeOnlineStatusFromDatabase(session.businessId!);
      await _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    if (_loadingOrders) return;

    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated || session.businessId == null) return;

    setState(() {
      _loadingOrders = true;
    });

    try {
      final orders = await _orderService.getMerchantOrders(session.businessId!);
      if (mounted) {
        setState(() {
          _orders = orders;
        });
      }
    } on AuthTokenExpiredException catch (e) {
      await _handleAuthFailure('Loading orders (token expired)', e);
    } on UnauthorizedException catch (e) {
      await _handleAuthFailure('Loading orders (unauthorized)', e);
    } catch (e) {
      // Handle other errors (network, server, etc.)
      debugPrint('❌ Failed to load orders: $e');
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: AppLocalizations.of(context)!.failedToLoadOrdersPullToRetry,
          type: AdaptiveSnackBarType.error,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingOrders = false;
        });
      }
    }
  }

  void _onNavigate(int index) async {
    // 🔧 التحقق من صلاحية الجلسة عند تغيير التبويب
    debugPrint('🔄 Tab changed to index: $index - validating session...');
    final sessionNotifier = ref.read(sessionProvider.notifier);
    await sessionNotifier.onAppResumed();

    setState(() {
      _selectedIndex = index;
    });
  }

  /// Toggle online/offline status and update backend
  Future<void> _toggleOnlineStatus(bool isOnline) async {
    try {
      // Get current session data
      final session = ref.read(sessionProvider);
      if (!session.isAuthenticated || session.businessId == null) {
        _showSessionExpiredSnack();
        return;
      }

      // Create API service instance
      final apiService = ApiService();

      // Get current user info
      final user = await apiService.getMerchantDetails();

      // Call API to update online status
      await apiService.updateBusinessOnlineStatus(
        session.businessId!,
        user.id,
        isOnline,
      );

      // Update local state
      setState(() {
        _isOnline = isOnline;
      });

      // Update AppState
      _appState.updateOnlineStatus(isOnline);

      // Show success message
      if (!mounted) return;
      showAdaptiveSnackBar(
        context: context,
        message: isOnline
            ? AppLocalizations.of(context)!.businessNowOnline
            : AppLocalizations.of(context)!.businessNowOffline,
        type: isOnline
            ? AdaptiveSnackBarType.success
            : AdaptiveSnackBarType.warning,
        duration: const Duration(seconds: 2),
      );
    } on AuthTokenExpiredException catch (e) {
      await _handleAuthFailure('Toggling online status (token expired)', e);
    } on UnauthorizedException catch (e) {
      await _handleAuthFailure('Toggling online status (unauthorized)', e);
    } catch (error) {
      debugPrint('❌ Toggle status error: $error');

      // Show error message
      if (!mounted) return;
      showAdaptiveSnackBar(
        context: context,
        message: AppLocalizations.of(context)!
            .failedToUpdateRestaurantStatus(error.toString()),
        type: AdaptiveSnackBarType.error,
        duration: const Duration(seconds: 3),
      );
    }
  }

  /// Show return order feature message
  void _showReturnOrderFeature(BuildContext context) {
    showAdaptiveSnackBar(
      context: context,
      message: AppLocalizations.of(context)!.returnOrdersFeatureComingSoon,
      type: AdaptiveSnackBarType.info,
      duration: const Duration(seconds: 2),
    );
  }

  void _onOrderUpdated(String orderId, OrderStatus newStatus) {
    setState(() {
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(status: newStatus);
      }
    });
  }

  Future<void> _handleAuthFailure(String action, Object e) async {
    debugPrint('❌ $action auth failure: $e');
    debugPrint('❌ Error type: ${e.runtimeType}');

    // Only treat explicit auth exceptions as auth failures
    final msg = e.toString();
    final isAuth = e is UnauthorizedException ||
        e is AuthTokenExpiredException ||
        msg.contains('401') ||
        msg.contains('Unauthorized');
    if (!isAuth) {
      debugPrint('ℹ️ Non-auth error, NOT clearing session');
      showAdaptiveSnackBar(
        context: context,
        message: 'Temporary error: ${msg.split('\n').first}',
        type: AdaptiveSnackBarType.warning,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (!mounted) return;

    try {
      debugPrint('🔄 Attempting token refresh before clearing session...');
      final refreshResult = await TokenRefreshService.refreshTokens();
      if (refreshResult != null &&
          (refreshResult['idToken']?.isNotEmpty == true)) {
        debugPrint('✅ Token refresh successful, keeping session active');
        showAdaptiveSnackBar(
          context: context,
          message: 'Session refreshed',
          type: AdaptiveSnackBarType.info,
          duration: const Duration(seconds: 2),
        );
        return;
      }
    } catch (refreshError) {
      debugPrint('❌ Token refresh failed: $refreshError');
    }

    debugPrint('🧹 Clearing session after auth failure');
    ref.read(sessionProvider.notifier).clearSession();
    _showSessionExpiredSnack();
  }

  void _showSessionExpiredSnack() {
    if (!mounted) return;
    showAdaptiveSnackBar(
      context: context,
      message: AppLocalizations.of(context)!.sessionExpiredPleaseLoginAgain,
      type: AdaptiveSnackBarType.error,
      duration: const Duration(seconds: 4),
    );
  }

  Widget _buildDashboardBody(Business business) {
    switch (_selectedIndex) {
      case 0:
        return OrdersPage(businessId: business.id);
      case 1:
        return ProductsManagementScreen(business: business);
      case 2:
        return AnalyticsPage(
          business: business,
          orders: _orders,
          onNavigateToOrders: () => _onNavigate(0),
          onOrderUpdated: _onOrderUpdated,
        );
      case 3:
        return DiscountManagementPage(
          business: business,
          orders: _orders,
          onNavigateToOrders: () => _onNavigate(0),
          onOrderUpdated: _onOrderUpdated,
        );
      case 4:
        return ProfileSettingsPage(
          business: business,
          orders: _orders,
        );
      default:
        return OrdersPage(businessId: business.id);
    }
  }

  Widget _buildMobileLayout(Business business) {
    return Scaffold(
      appBar: TopAppBar(
        businessId: business.id,
        title: business.name,
        isOnline: _isOnline,
        onToggleStatus: (value) async => await _toggleOnlineStatus(value),
        onReturnOrder: () => _showReturnOrderFeature(context),
        onNavigate: (index) => _onNavigate(index),
        isLoading: _loadingOrders,
      ),
      body: Column(children: [CommercialRequestsBanner(businessId: business.id, businessName: business.name), Expanded(child: _buildDashboardBody(business))]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: WhizzColors.white,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              width: 2,
            ),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onNavigate,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: WhizzColors.secondary,
          unselectedItemColor: WhizzColors.grey600,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.shopping_bag_outlined,
                color: _selectedIndex == 0
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              activeIcon: Icon(
                Icons.shopping_bag_outlined,
                color: _selectedIndex == 0
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.inventory_2_outlined,
                color: _selectedIndex == 1
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              activeIcon: Icon(
                Icons.inventory_2_outlined,
                color: _selectedIndex == 1
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.analytics_outlined,
                color: _selectedIndex == 2
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              activeIcon: Icon(
                Icons.analytics_outlined,
                color: _selectedIndex == 2
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.local_offer_outlined,
                color: _selectedIndex == 3
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              activeIcon: Icon(
                Icons.local_offer_outlined,
                color: _selectedIndex == 3
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.settings_outlined,
                color: _selectedIndex == 4
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              activeIcon: Icon(
                Icons.settings_outlined,
                color: _selectedIndex == 4
                    ? WhizzColors.primary
                    : WhizzColors.secondary,
              ),
              label: '',
            ),
          ],
        ),
      ),
      // Removed endDrawer as we now have toggle in AppBar
    );
  }

  Widget _buildTabletLayout(Business business) {
    return Scaffold(
      body: Row(
        children: [
          ModernNavigationRail(
            selectedIndex: _selectedIndex,
            onNavigate: _onNavigate,
            isOnline: _isOnline,
            // Removed onToggleStatus - no toggle functionality
          ),
          Expanded(
            child: _buildDashboardBody(business),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Business business) {
    return Scaffold(
      body: Row(
        children: [
          ModernSidebar(
            isOnline: _isOnline,
            // Removed onToggleStatus - no toggle functionality
            onReturnOrder: () {},
            onNavigate: _onNavigate,
            onClose: () {},
          ),
          Expanded(
            child: _buildDashboardBody(business),
          ),
        ],
      ),
    );
  }

  Widget _employeeDashboard(BranchEmployeeAccess access) {
    final menu =
        (access.capabilities['readMenu'] ?? access.capabilities['editMenu']) ==
            true;
    final hours = (access.capabilities['readHours'] ??
            access.capabilities['editHours']) ==
        true;
    final wallet = access.capabilities['readWalletBalance'] == true ||
        access.capabilities['readWalletTransactions'] == true ||
        access.capabilities['readSalesReports'] == true;
    final destinations = <String>[
      if (access.canOrders) 'الطلبات',
      if (menu) 'المنتجات',
      if (wallet) 'المحفظة',
      if (access.capabilities['readDiscounts'] == true) 'الخصومات',
      'الإعدادات',
    ];
    final index = _selectedIndex < destinations.length ? _selectedIndex : 0;
    final selected = destinations[index];
    Widget tasks(String tab) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BranchDeviceTasks(
              key: ValueKey(tab),
              api: access.api,
              token: access.token,
              session: access.session,
              businessId: access.businessId,
              capabilities: access.capabilities,
              role: access.profile['staff']?['role'] ?? '',
              initialTab: tab,
              showTabs: false),
        );
    final settings = ListView(padding: const EdgeInsets.all(16), children: [
      Card(child:ListTile(leading:const Icon(Icons.tune_rounded),title:const Text('استقبال الطلبات والصوت'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OrderReceptionSettingsPage(businessId:access.businessId,access:access))))),
      if (hours)
        Card(
            child: ExpansionTile(
          leading: const Icon(Icons.schedule),
          title: const Text('ساعات العمل'),
          children: [tasks('hours')],
        )),
      Card(
          child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('قفل مهامي'),
              subtitle: const Text('يستمر الجهاز في استقبال الطلبات'),
              onTap: access.lock)),
    ]);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(access.profile['business']?['businessName'] ??
            access.profile['business']?['name'] ??
            'المطعم'),
        actions: [
          if (access.capabilities['editStatus'] == true)
            BranchEmployeeStatusControl(access: access),
          IconButton(
              onPressed: access.lock,
              tooltip: 'قفل مهامي',
              icon: const Icon(Icons.lock_outline))
        ],
      ),
      body: selected == 'الطلبات'
          ? OrdersPage(businessId: access.businessId, employeeAccess: access)
          : selected == 'المنتجات'
              ? tasks('menu')
              : selected == 'الخصومات'
                  ? BranchEmployeeDiscountsScreen(
                      key: ValueKey(access.businessId), access: access)
                  : selected == 'المحفظة'
                      ? BranchEmployeeWalletScreen(
                          key: ValueKey(access.businessId), access: access)
                      : settings,
      bottomNavigationBar: destinations.length < 2
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: index,
              onTap: (value) => setState(() => _selectedIndex = value),
              selectedItemColor: const Color(0xFF00296B),
              items: destinations
                  .map((label) => BottomNavigationBarItem(
                      icon: Icon(label == 'الطلبات'
                          ? Icons.receipt_long_outlined
                          : label == 'المنتجات'
                              ? Icons.inventory_2_outlined
                              : label == 'الخصومات'
                                  ? Icons.local_offer_outlined
                                  : label == 'المحفظة'
                                      ? Icons.account_balance_wallet_outlined
                                      : Icons.settings_outlined),
                      label: label))
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.employeeAccess != null)
      return widget.employeeAccess!.canOrders ? MerchantOrderAttention(key:ValueKey('attention_${widget.employeeAccess!.businessId}'),businessId:widget.employeeAccess!.businessId,load:widget.employeeAccess!.orders,open:(id)=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>OrdersPage(employeeAccess:widget.employeeAccess,focusOrderId:id))),child:_employeeDashboard(widget.employeeAccess!)) : _employeeDashboard(widget.employeeAccess!);
    final businessAsync = ref.watch(businessProvider);

    return businessAsync.when(
      data: (business) {
        if (business == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business,
                    size: AppDimensions.iconSizeXL,
                    color: WhizzColors.onSurfaceVariant,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    AppLocalizations.of(context)!.noBusinessFound,
                    style: AppTypography.headlineSmall.copyWith(
                      color: WhizzColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    AppLocalizations.of(context)!.contactSupport,
                    style: AppTypography.bodyMedium.copyWith(
                      color: WhizzColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return MerchantOrderAttention(
          key:ValueKey('attention_${business.id}'),businessId:business.id,
          load:()=>_orderService.getMerchantOrders(business.id),
          open:(id)=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>OrdersPage(businessId:business.id,focusOrderId:id))),
          child: ResponsiveHelper.isMobile(context)
            ? _buildMobileLayout(business)
            : ResponsiveHelper.isTablet(context)
                ? _buildTabletLayout(business)
                : _buildDesktopLayout(business));
      },
      loading: () => const Scaffold(
        body: Center(
          child: AdaptiveLoadingIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: AppDimensions.iconSizeXL,
                color: WhizzColors.error,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.of(context)!.error,
                style: AppTypography.headlineSmall.copyWith(
                  color: WhizzColors.error,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                error.toString(),
                style: AppTypography.bodyMedium.copyWith(
                  color: WhizzColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.invalidate(businessProvider),
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
