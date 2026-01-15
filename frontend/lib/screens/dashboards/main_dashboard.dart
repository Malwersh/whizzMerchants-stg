import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animations/animations.dart';
import '../../l10n/app_localizations.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/gradient_colors.dart';
import '../../core/adaptive/adaptive_widgets.dart';
import '../../providers/business_provider.dart';
import '../../providers/auth_provider_riverpod.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../auth/auth_screen.dart';
import '../products_management_screen.dart';
import '../examples/design_system_example_screen.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int selectedIndex = 0;
  bool _isValidatingSession = true;

  @override
  void initState() {
    super.initState();
    _validateSession();
  }

  /// Validate session on dashboard load
  Future<void> _validateSession() async {
    try {
      final sessionManager = SessionManager();
      final isValid = await sessionManager.isSessionValid();

      if (!mounted) return;

      if (!isValid) {
        // Session is invalid, redirect to login
        debugPrint(
            '⚠️ MainDashboard: Invalid session detected, redirecting to login');

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signin',
          (route) => false,
        );

        // Show message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Your session has expired. Please sign in again.'),
              backgroundColor: WhizzColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Session is valid, update activity
        await sessionManager.updateActivity();
        if (mounted) {
          setState(() {
            _isValidatingSession = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ MainDashboard: Session validation error: $e');
      // On error, show loading and allow navigation (fail-safe)
      if (mounted) {
        setState(() {
          _isValidatingSession = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while validating session
    if (_isValidatingSession) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AdaptiveLoadingIndicator(),
              SizedBox(height: AppSpacing.md),
              const Text(
                'Loading...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    final businessAsync = ref.watch(businessProvider);
    final localizations = AppLocalizations.of(context)!;

    return businessAsync.when(
      data: (business) {
        if (business == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppDimensions.iconSizeXXL,
                    color: WhizzColors.error,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(localizations.noBusinessDataAvailable),
                  SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(businessProvider),
                    child: Text(localizations.retry),
                  ),
                ],
              ),
            ),
          );
        }

        return _buildDashboard(context, business);
      },
      loading: () => Scaffold(
        body: Center(child: AdaptiveLoadingIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: AppDimensions.iconSizeXXL,
                color: WhizzColors.error,
              ),
              SizedBox(height: AppSpacing.md),
              Text('${localizations.error}: $error'),
              SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.invalidate(businessProvider),
                child: Text(localizations.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, business) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: WhizzColors.primary.withValues(alpha: 0.2),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusSM),
              ),
              child: Icon(
                Icons.dashboard_rounded,
                size: AppDimensions.iconSizeMD,
                color: WhizzColors.primary,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                localizations.wizzBusinessManager,
                style: AppTypography.headlineSmall.copyWith(
                  color: WhizzColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: WhizzColors.secondary,
        foregroundColor: WhizzColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: GradientColors.bluePurple,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: AppSpacing.xs),
            decoration: BoxDecoration(
              color: WhizzColors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_rounded),
              onPressed: () {
                showAdaptiveSnackBar(
                  context: context,
                  message: localizations.notificationsFeatureComingSoon,
                  type: AdaptiveSnackBarType.info,
                );
              },
            ),
          ),
          Container(
            margin: EdgeInsets.only(right: AppSpacing.xs),
            decoration: BoxDecoration(
              color: WhizzColors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () {
                showAdaptiveSnackBar(
                  context: context,
                  message: localizations.settingsFeatureComingSoon,
                  type: AdaptiveSnackBarType.info,
                );
              },
            ),
          ),
        ],
      ),
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation, secondaryAnimation) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          );
        },
        child: IndexedStack(
          index: selectedIndex,
          children: [
            const DashboardHomeTab(),
            const OrdersTab(),
            ProductsManagementScreen(business: business),
            const AnalyticsTab(),
            const ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: WhizzColors.white,
          boxShadow: [
            BoxShadow(
              color: WhizzColors.grey300.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: [
          NavigationDestination(
              icon: Opacity(
                opacity: 0.5,
                child: Icon(Icons.home_outlined),
              ),
              selectedIcon: Icon(Icons.home_outlined),
              label: '',
          ),
          NavigationDestination(
              icon: Opacity(
                opacity: 0.5,
                child: Icon(Icons.receipt_outlined),
              ),
              selectedIcon: Icon(Icons.receipt_outlined),
              label: '',
          ),
          NavigationDestination(
              icon: Opacity(
                opacity: 0.5,
                child: Icon(Icons.inventory_2_outlined),
              ),
              selectedIcon: Icon(Icons.inventory_2_outlined),
              label: '',
          ),
          NavigationDestination(
              icon: Opacity(
                opacity: 0.5,
                child: Icon(Icons.analytics_outlined),
              ),
              selectedIcon: Icon(Icons.analytics_outlined),
              label: '',
          ),
          NavigationDestination(
              icon: Opacity(
                opacity: 0.5,
                child: Icon(Icons.person_outlined),
              ),
              selectedIcon: Icon(Icons.person_outlined),
              label: '',
          ),
        ],
        ),
      ),
      floatingActionButton: selectedIndex == 0 ? FloatingActionButton(
              backgroundColor: WhizzColors.black,
              foregroundColor: WhizzColors.white,
              elevation: 4,
        onPressed: () {
                showAdaptiveSnackBar(
                  context: context,
                  message: localizations.quickOrderFeatureComingSoon,
                  type: AdaptiveSnackBarType.info,
          );
        },
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}

// Dashboard Home Tab
class DashboardHomeTab extends StatelessWidget {
  const DashboardHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.welcomeBack,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          
          // Stats Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            children: [
              _buildStatCard(localizations.todaysOrders, '24',
                  Icons.receipt_long, WhizzColors.secondary),
              _buildStatCard(localizations.revenue, '\$1,245',
                  Icons.attach_money, WhizzColors.primary),
              _buildStatCard(localizations.products, '156', Icons.inventory,
                  WhizzColors.statusReady),
              _buildStatCard(localizations.reviews, '4.8', Icons.star,
                  WhizzColors.statusPending),
            ],
          ),
          
          SizedBox(height: AppSpacing.xl),
          
          // Recent Orders
          Text(
            localizations.recentOrders,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          
          ...List.generate(3, (index) => _buildOrderCard(
                    '${localizations.order} #${1001 + index}',
                    '${localizations.customer} ${index + 1}',
            '\$${(25.50 + index * 10).toStringAsFixed(2)}',
                    index == 0
                        ? localizations.newOrder
                        : index == 1
                            ? localizations.preparing
                            : localizations.ready,
          )),
          
          SizedBox(height: AppSpacing.xl),
          
          // Color Palette Showcase
          Text(
            localizations.appColorPalette,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          _buildColorPalette(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppDimensions.iconSizeLG, color: color),
            SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: AppTypography.bodySmall.copyWith(
                color: WhizzColors.grey600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildColorPalette() {
    final colorData = [
      {
        'name': 'Primary (Yellow)',
        'color': WhizzColors.primary,
        'hex': '#FDC500'
      },
      {
        'name': 'Secondary (Gold)',
        'color': WhizzColors.primary,
        'hex': '#FFD500'
      },
      {'name': 'Success', 'color': WhizzColors.statusReady, 'hex': '#10B981'},
      {'name': 'Warning', 'color': WhizzColors.statusPending, 'hex': '#F59E0B'},
      {'name': 'Error', 'color': WhizzColors.error, 'hex': '#EF4444'},
      {'name': 'Info', 'color': WhizzColors.secondary, 'hex': '#00509D'},
    ];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            ...colorData.map((data) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                        width: 40,
                        height: 40,
                    decoration: BoxDecoration(
                      color: data['color'] as Color,
                              borderRadius:
                                  BorderRadius.circular(
                              AppDimensions.borderRadiusXS),
                      border: Border.all(
                            color: WhizzColors.grey300,
                        width: 1,
                      ),
                    ),
                  ),
                      SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] as String,
                              style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          data['hex'] as String,
                              style: AppTypography.bodySmall.copyWith(
                                color: WhizzColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(String orderNumber, String customer, String amount, String status) {
    // Determine status color based on status text (already localized)
    // Using contains() to handle localized strings flexibly
    Color statusColor = status.toLowerCase().contains('new') ||
            status.toLowerCase().contains('جديد')
        ? WhizzColors.secondary
        : status.toLowerCase().contains('prepar') ||
                status.toLowerCase().contains('تحضير')
            ? WhizzColors.statusPending
            : WhizzColors.statusReady;
    
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.xs),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(AppSpacing.md),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.receipt,
              color: statusColor, size: AppDimensions.iconSizeMD),
        ),
        title: Text(
          orderNumber,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          customer,
          style: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.grey600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs / 2,
              ),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusMD),
              ),
              child: Text(
                status,
                style: AppTypography.labelSmall.copyWith(
                  color: WhizzColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Orders Tab
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.orders,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          
          // Filter Tabs
          DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: localizations.allOrders),
                    Tab(text: localizations.newOrders),
                    Tab(text: localizations.preparingOrders),
                    Tab(text: localizations.readyOrders),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      _buildOrdersList([localizations.allOrdersShownHere]),
                      _buildOrdersList([localizations.newOrdersShownHere]),
                      _buildOrdersList([localizations.ordersBeingPrepared]),
                      _buildOrdersList([localizations.readyOrdersShownHere]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<String> orders) {
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            title: Text(orders[index]),
            subtitle: const Text('Demo order data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        );
      },
    );
  }
}

// Analytics Tab
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.analytics,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          
          // Sales Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales This Week', // TODO: Add localization key
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 3),
                              FlSpot(1, 1),
                              FlSpot(2, 4),
                              FlSpot(3, 2),
                              FlSpot(4, 5),
                              FlSpot(5, 3),
                              FlSpot(6, 4),
                            ],
                            isCurved: true,
                            color: Theme.of(context).primaryColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Performance Metrics
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Text(
                          '87%',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: WhizzColors.primary,
                          ),
                        ),
                        Text(localizations.successRate),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Text(
                          '12m',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: WhizzColors.secondary,
                          ),
                        ),
                        Text(localizations.avgPrepTime),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Profile Tab
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _showWorkingHours = false;
  bool _showChangePassword = false;
  bool _showAboutApp = false;
  bool _isSavingWorkingHours = false;
  
  // Password form controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // User attributes cache
  Map<String, dynamic> _userAttributes = {};
  bool _attributesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserAttributes();
    _loadWorkingHours();
  }
  
  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAttributes() async {
    if (!_attributesLoaded) {
      final authNotifier = ref.read(authProviderRiverpod.notifier);
      final attributes = await authNotifier.getUserAttributes();
      if (mounted) {
        setState(() {
          _userAttributes = attributes ?? {};
          _attributesLoaded = true;
        });
      }
    }
  }
  
  Future<void> _loadWorkingHours() async {
    final businessAsyncValue = ref.read(businessProvider);
    final business = businessAsyncValue.value;
    
    if (business == null) return;
    
    try {
      final apiService = ApiService();
      final response = await apiService.getBusinessWorkingHours(business.id);
      
      if (response['workingHours'] != null && mounted) {
        setState(() {
          // Convert backend format to frontend format
          final backendHours = response['workingHours'] as Map<String, dynamic>;
          
          for (String day in workingHours.keys) {
            if (backendHours.containsKey(day)) {
              final dayData = backendHours[day] as Map<String, dynamic>;
              workingHours[day] = {
                'isOpen': dayData['isOpen'] ?? false,
                'openTime': dayData['openTime'] ?? '09:00',
                'closeTime': dayData['closeTime'] ?? '17:00',
              };
            }
          }
        });
      }
    } catch (e) {
      // Keep default values if loading fails
    }
  }
  
  Future<void> _saveWorkingHours() async {
    final businessAsyncValue = ref.read(businessProvider);
    final business = businessAsyncValue.value;
    
    if (business == null) {
      final localizations = AppLocalizations.of(context)!;
      showAdaptiveSnackBar(
        context: context,
        message: localizations.noBusinessDataAvailable,
        type: AdaptiveSnackBarType.error,
      );
      return;
    }
    
    setState(() {
      _isSavingWorkingHours = true;
    });
    
    try {
      final apiService = ApiService();
      
      // Convert frontend format to backend format
      final backendFormat = <String, Map<String, dynamic>>{};
      
      for (String day in workingHours.keys) {
        final dayData = workingHours[day]!;
        backendFormat[day] = {
          'isOpen': dayData['isOpen'],
          'openTime': dayData['isOpen'] ? dayData['openTime'] : null,
          'closeTime': dayData['isOpen'] ? dayData['closeTime'] : null,
        };
      }
      
      final requestData = {
        'workingHours': backendFormat,
      };
      
      await apiService.updateBusinessWorkingHours(business.id, requestData);
      
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: localizations.workingHoursSaved,
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: localizations.failedToSaveWorkingHours(e.toString()),
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingWorkingHours = false;
        });
      }
    }
  }

  Map<String, Map<String, dynamic>> workingHours = {
    'Monday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
    'Tuesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
    'Wednesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
    'Thursday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
    'Friday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '23:00'},
    'Saturday': {'isOpen': true, 'openTime': '10:00', 'closeTime': '23:00'},
    'Sunday': {'isOpen': false, 'openTime': '10:00', 'closeTime': '21:00'},
  };

  @override
  Widget build(BuildContext context) {
    final businessAsyncValue = ref.watch(businessProvider);
    final authState = ref.watch(authProviderRiverpod);
    final currentUser = authState.currentUser;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Profile Header
          CircleAvatar(
            radius: 50,
            backgroundColor: WhizzColors.secondary,
            child: businessAsyncValue.when(
              data: (business) {
                if (business?.businessPhotoUrl != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.network(
                      business!.businessPhotoUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.restaurant,
                          size: AppDimensions.iconSizeXXL,
                          color: WhizzColors.white,
                        );
                      },
                    ),
                  );
                }
                return Icon(
                  Icons.restaurant,
                  size: AppDimensions.iconSizeXXL,
                  color: WhizzColors.white,
                );
              },
              loading: () => Icon(
                Icons.restaurant,
                size: AppDimensions.iconSizeXXL,
                color: WhizzColors.white,
              ),
              error: (_, __) => Icon(
                Icons.restaurant,
                size: AppDimensions.iconSizeXXL,
                color: WhizzColors.white,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          
          // Business Name
          businessAsyncValue.when(
            data: (business) => Text(
              business?.name ?? 
              _userAttributes['custom:business_name'] ?? 
              _userAttributes['name'] ?? 
              currentUser?['username'] ?? 
                  AppLocalizations.of(context)!.businessName,
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            loading: () => Text(
              _userAttributes['custom:business_name'] ?? 
              _userAttributes['name'] ?? 
                  '...',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            error: (error, _) => Text(
              _userAttributes['custom:business_name'] ?? 
              _userAttributes['name'] ?? 
              currentUser?['username'] ?? 
                  AppLocalizations.of(context)!.businessName,
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Business Email
          businessAsyncValue.when(
            data: (business) => Text(
              business?.email ?? 
              _userAttributes['email'] ?? 
              currentUser?['username'] ?? 
              'email@business.com',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            loading: () => Text(
              _userAttributes['email'] ?? 
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            error: (error, _) => Text(
              _userAttributes['email'] ?? 
              currentUser?['username'] ?? 
              'email@business.com',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Profile Menu Items
          _buildMenuItems(),
          
          // Working Hours Section (Expandable)
          if (_showWorkingHours) ...[
            const SizedBox(height: 16),
            _buildWorkingHoursSection(),
          ],
          
          // Change Password Section (Expandable)
          if (_showChangePassword) ...[
            const SizedBox(height: 16),
            _buildChangePasswordSection(),
          ],
          
          // About App Section (Expandable)
          if (_showAboutApp) ...[
            const SizedBox(height: 16),
            _buildAboutAppSection(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMenuItems() {
    final items = [
      {'icon': Icons.access_time, 'title': 'Working Hours'},
      {'icon': Icons.notifications, 'title': 'Notification Settings'},
      {'icon': Icons.lock, 'title': 'Change Password'},
      {
        'icon': Icons.palette,
        'title': 'Design System',
        'isDev': true
      }, // Developer tool
      {'icon': Icons.info_outline, 'title': 'About App'},
      {'icon': Icons.help, 'title': 'Help & Support'},
      {'icon': Icons.logout, 'title': 'Logout'},
    ];
    
    return Column(
      children: List.generate(items.length, (index) {
        final isLogout = items[index]['title'] == 'Logout';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isLogout ? WhizzColors.primary : null,
          shape: isLogout
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: WhizzColors.secondary,
                    width: 2,
                  ),
                )
              : null,
          child: ListTile(
            leading: Icon(
              items[index]['icon'] as IconData,
              color: isLogout ? WhizzColors.secondary : null,
            ),
            title: Text(
              items[index]['title'] as String,
              style: isLogout
                  ? TextStyle(
                      color: WhizzColors.secondary,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
            trailing: Icon(
              items[index]['title'] == 'Working Hours' && _showWorkingHours
                  ? Icons.expand_less
                  : items[index]['title'] == 'Change Password' && _showChangePassword
                      ? Icons.expand_less
                      : items[index]['title'] == 'About App' && _showAboutApp
                          ? Icons.expand_less
                          : Icons.chevron_right,
              color: isLogout ? WhizzColors.secondary : null,
            ),
            onTap: () {
              if (items[index]['title'] == 'Working Hours') {
                setState(() {
                  _showWorkingHours = !_showWorkingHours;
                  _showChangePassword = false; // Close other sections
                  _showAboutApp = false;
                });
              } else if (items[index]['title'] == 'Change Password') {
                setState(() {
                  _showChangePassword = !_showChangePassword;
                  _showWorkingHours = false; // Close other sections
                  _showAboutApp = false;
                });
              } else if (items[index]['title'] == 'About App') {
                setState(() {
                  _showAboutApp = !_showAboutApp;
                  _showWorkingHours = false; // Close other sections
                  _showChangePassword = false;
                });
              } else if (items[index]['title'] == 'Design System') {
                // Navigate to Design System Example
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DesignSystemExampleScreen(),
                  ),
                );
              } else if (items[index]['title'] == 'Logout') {
                _handleLogout();
              } else {
                showAdaptiveSnackBar(
                  context: context,
                  message: '${items[index]['title']} feature coming soon',
                  type: AdaptiveSnackBarType.info,
                );
              }
            },
          ),
        );
      }),
    );
  }
  
  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Sign Out',
                style: TextStyle(color: WhizzColors.secondary)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading indicator with shorter duration
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              AdaptiveLoadingIndicator(
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 16),
              Text('Signing out...'),
            ],
          ),
          duration: Duration(seconds: 5), // Reduced from 30 to 5 seconds
        ),
      );

      try {
        // Get AuthProvider and perform proper sign out
        final authNotifier = ref.read(authProviderRiverpod.notifier);
        await authNotifier.signOut();

        if (mounted) {
          // Hide loading snackbar immediately
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          // Show success message briefly
          showAdaptiveSnackBar(
            context: context,
            message: 'Signed out successfully',
            type: AdaptiveSnackBarType.success,
            duration: const Duration(seconds: 1),
          );
          
          // Small delay to show success message, then navigate
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Navigate back to auth screen and clear all routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          // Hide loading snackbar
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          // Show error message
          showAdaptiveSnackBar(
            context: context,
            message: 'Error signing out: ${e.toString()}',
            type: AdaptiveSnackBarType.error,
            duration: const Duration(seconds: 3),
          );
        }
      }
    }
  }

  Widget _buildWorkingHoursSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: WhizzColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Working Hours',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Day by day working hours
            ...workingHours.entries.map((entry) {
              String day = entry.key;
              Map<String, dynamic> hours = entry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    // Day name
                    SizedBox(
                      width: 80,
                      child: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    
                    // Open/Closed Switch
                    Switch(
                      value: hours['isOpen'],
                      onChanged: (value) {
                        setState(() {
                          workingHours[day]!['isOpen'] = value;
                        });
                      },
                      activeColor: WhizzColors.primary,
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Time fields (only show if open)
                    if (hours['isOpen']) ...[
                      Expanded(
                        child: Row(
                          children: [
                            // Open time
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectTime(context, day, 'openTime'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: WhizzColors.primary),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    hours['openTime'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: WhizzColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('-'),
                            ),
                            
                            // Close time
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectTime(context, day, 'closeTime'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: WhizzColors.primary),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    hours['closeTime'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: WhizzColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Text(
                          'Closed',
                          style: TextStyle(
                            color: WhizzColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            
            const SizedBox(height: 16),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    onPressed: () {
                      setState(() {
                        // Reset to default hours
                        workingHours = {
                          'Monday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
                          'Tuesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
                          'Wednesday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
                          'Thursday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '22:00'},
                          'Friday': {'isOpen': true, 'openTime': '09:00', 'closeTime': '23:00'},
                          'Saturday': {'isOpen': true, 'openTime': '10:00', 'closeTime': '23:00'},
                          'Sunday': {'isOpen': false, 'openTime': '10:00', 'closeTime': '21:00'},
                        };
                      });
                      
                      showAdaptiveSnackBar(
                        context: context,
                        message: 'Working hours reset to default',
                        type: AdaptiveSnackBarType.success,
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isSavingWorkingHours 
                        ? AdaptiveLoadingIndicator(
                            color: Colors.white,
                            size: 16,
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSavingWorkingHours ? 'Saving...' : 'Save'),
                    onPressed: _isSavingWorkingHours ? null : _saveWorkingHours,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectTime(BuildContext context, String day, String timeType) async {
    final currentTime = workingHours[day]![timeType];
    final timeParts = currentTime.split(':');
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: WhizzColors.primary,
                  secondary: WhizzColors.secondary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        workingHours[day]![timeType] = 
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }
  
  Widget _buildChangePasswordSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock, color: WhizzColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Current Password
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon:
                      Icon(Icons.lock_outline, color: WhizzColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                      color: WhizzColors.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // New Password
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock, color: WhizzColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                      color: WhizzColors.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                    return 'Password must contain uppercase, lowercase, and numbers';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon:
                      Icon(Icons.lock_reset, color: WhizzColors.primary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      color: WhizzColors.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              // Password Requirements
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WhizzColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password Requirements:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: WhizzColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordRequirement('At least 8 characters'),
                    _buildPasswordRequirement('At least one uppercase letter'),
                    _buildPasswordRequirement('At least one lowercase letter'),
                    _buildPasswordRequirement('At least one number'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      onPressed: () {
                        setState(() {
                          _currentPasswordController.clear();
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                        });
                        
                        showAdaptiveSnackBar(
                          context: context,
                          message: 'Form cleared',
                          type: AdaptiveSnackBarType.success,
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Change Password'),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // Simulate password change
                          showAdaptiveSnackBar(
                            context: context,
                            message: 'Password changed successfully!',
                            type: AdaptiveSnackBarType.success,
                          );
                          
                          // Clear form and close section
                          setState(() {
                            _currentPasswordController.clear();
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                            _showChangePassword = false;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPasswordRequirement(String requirement) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: WhizzColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            requirement,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAboutAppSection() {
    return Card(
      margin: const EdgeInsets.all(0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: WhizzColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'About App',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // App Version
            _buildInfoRow(
              icon: Icons.apps,
              title: 'App Version',
              value: '1.0.0',
            ),
            const SizedBox(height: 12),

            // Terms & Conditions
            _buildInfoRow(
              icon: Icons.description,
              title: 'Terms & Conditions',
              value: 'View',
              isLink: true,
              onTap: () {
                showAdaptiveSnackBar(
                  context: context,
                  message: 'Terms & Conditions feature coming soon',
                  type: AdaptiveSnackBarType.info,
                );
              },
            ),
            const SizedBox(height: 12),

            // Privacy Policy
            _buildInfoRow(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              value: 'View',
              isLink: true,
              onTap: () {
                showAdaptiveSnackBar(
                  context: context,
                  message: 'Privacy Policy feature coming soon',
                  type: AdaptiveSnackBarType.info,
                );
              },
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Delete Account Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WhizzColors.error.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: WhizzColors.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: WhizzColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: WhizzColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Once you delete your account, there is no going back. Please be certain.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon:
                          Icon(Icons.delete_forever, color: WhizzColors.error),
                      label: Text(
                        'Delete Account',
                        style: TextStyle(color: WhizzColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: WhizzColors.error),
                      ),
                      onPressed: _showDeleteAccountDialog,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              color: WhizzColors.grey600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isLink ? WhizzColors.primary : Colors.grey[800],
              ),
            ),
            if (isLink) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: WhizzColors.grey600,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: WhizzColors.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Delete Account?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action cannot be undone. This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDeleteWarningItem('Your business profile'),
            _buildDeleteWarningItem('All your products and menu items'),
            _buildDeleteWarningItem('Order history'),
            _buildDeleteWarningItem('Business analytics and reports'),
            _buildDeleteWarningItem('All associated data'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WhizzColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: WhizzColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is permanent and cannot be reversed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: WhizzColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _confirmAndDeleteAccount();
    }
  }

  Widget _buildDeleteWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: WhizzColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndDeleteAccount() async {
    final businessAsyncValue = ref.read(businessProvider);
    final business = businessAsyncValue.value;

    if (business == null) {
      showAdaptiveSnackBar(
        context: context,
        message: 'Unable to delete account. Business data not found.',
        type: AdaptiveSnackBarType.error,
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AdaptiveLoadingIndicator(),
              const SizedBox(height: 16),
              const Text('Deleting your account...'),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your request.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Call API to delete account
      final apiService = ApiService();
      await apiService.deleteBusinessAccount(business.id);

      // Sign out user
      final authNotifier = ref.read(authProviderRiverpod.notifier);
      await authNotifier.signOut();

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Navigate to auth screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signin',
          (route) => false,
        );

        // Show success message
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            showAdaptiveSnackBar(
              context: context,
              message: 'Your account has been successfully deleted.',
              type: AdaptiveSnackBarType.success,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        showAdaptiveSnackBar(
          context: context,
          message: 'Failed to delete account: ${e.toString()}',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }
}

