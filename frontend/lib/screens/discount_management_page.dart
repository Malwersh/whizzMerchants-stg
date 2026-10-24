import 'dart:io';
import '../widgets/merchant_discount_value_fields.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/merchant_discount_usage_fields.dart';
import '../l10n/app_localizations.dart';
import '../models/business.dart';
import '../models/discount.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../services/app_auth_service.dart';
import '../services/image_upload_service.dart';
import '../services/product_service.dart';
import '../screens/auth/auth_screen.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../core/utils/app_logger.dart';
import '../core/exceptions/auth_exceptions.dart';
import '../widgets/discount_funding_notice.dart';
import 'commercial_agreements_screen.dart';

/// Formats a discount value without unnecessary trailing zeros.
/// 10.0 -> "10", 10.5 -> "10.5".
String _formatDiscountValue(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

class DiscountManagementPage extends StatefulWidget {
  final Business business;
  final List<Order> orders;
  final VoidCallback? onNavigateToOrders;
  final Function(String, OrderStatus)? onOrderUpdated;

  const DiscountManagementPage({
    super.key,
    required this.business,
    required this.orders,
    this.onNavigateToOrders,
    this.onOrderUpdated,
  });

  @override
  _DiscountManagementPageState createState() => _DiscountManagementPageState();
}

class _DiscountManagementPageState extends State<DiscountManagementPage> {
  List<Discount> _discounts = [];
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  bool _isInitializing = true;
  bool _isLoading = false;
  String _selectedFilter = 'all'; // all, active, scheduled, expired

  List<Discount> get _filteredDiscounts {
    switch (_selectedFilter) {
      case 'active':
        return _discounts
            .where((d) => d.status == DiscountStatus.active)
            .toList();
      case 'scheduled':
        return _discounts
            .where((d) => d.status == DiscountStatus.scheduled)
            .toList();
      case 'expired':
        return _discounts
            .where((d) => d.status == DiscountStatus.expired)
            .toList();
      default:
        return _discounts;
    }
  }

  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onAppStateChanged);
    _validateAuthenticationAndInitialize();
  }

  @override
  void didUpdateWidget(covariant DiscountManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.id != widget.business.id) {
      _discounts = [];
      _products = [];
      _categories = [];
      _isInitializing = true;
      _isLoading = false;
      _validateAuthenticationAndInitialize();
    }
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<void> _validateAuthenticationAndInitialize() async {
    final businessId = widget.business.id;
    try {
      // Check if we have a valid business ID first
      if (widget.business.id == 'unknown-id' || widget.business.id.isEmpty) {
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          _showAuthenticationRequiredDialog(loc.authenticationFailedTitle,
              'Invalid business configuration. Please sign in again.');
        }
        return;
      }

      // Auth validation removed - API calls will handle auth errors via Phase 4 exception handling
      // If tokens are invalid, the API calls will throw AuthTokenExpiredException and clear session

      // Load all data in parallel
      await Future.wait([
        _loadDiscounts(),
        _loadProducts(),
        _loadCategories(),
      ]);

      if (mounted && widget.business.id == businessId) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        _showAuthenticationRequiredDialog(
            loc.authenticationFailedTitle, 'Failed to initialize: $e');
      }
    }
  }

  Future<void> _loadDiscounts() async {
    final businessId = widget.business.id;
    try {
      setState(() {
        _isLoading = true;
      });

      final discountsData =
          await _apiService.getDiscounts(businessId: businessId);
      if (!mounted || widget.business.id != businessId) return;
      final discounts =
          discountsData.map((data) => Discount.fromJson(data)).toList();

      setState(() {
        _discounts = discounts;
        _isLoading = false;
      });
    } on AuthTokenExpiredException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error('[DiscountManagement] Auth token expired: ${e.message}');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } on UnauthorizedException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error('[DiscountManagement] Unauthorized: ${e.message}');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Failed to load discounts: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    final businessId = widget.business.id;
    try {
      final result = await ProductService.getProducts(businessId: businessId);
      if (!mounted || widget.business.id != businessId) return;

      if (result['success'] && result['products'] != null) {
        final productsList = result['products'] as List;
        final products =
            productsList.map((json) => Product.fromJson(json)).toList();

        setState(() {
          _products = products;
        });
      } else {
        throw Exception(result['message'] ?? 'Failed to load products');
      }
    } on AuthTokenExpiredException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Auth token expired loading products: ${e.message}',
      );

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } on UnauthorizedException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Unauthorized loading products: ${e.message}',
      );

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message:
              'تعذر تحميل المنتجات: ${e.toString().replaceFirst('Exception: ', '')}',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _loadCategories() async {
    final businessId = widget.business.id;
    try {
      final businessTypeString =
          _getBusinessTypeString(widget.business.businessType);
      final result = await ProductService.getCategoriesForBusinessType(
          businessTypeString,
          businessId: businessId);
      if (!mounted || widget.business.id != businessId) return;

      if (result['success'] && result['categories'] != null) {
        final categoriesList = result['categories'] as List;
        final categories = categoriesList
            .map((json) => ProductCategory.fromJson(json))
            .toList();

        setState(() {
          _categories = categories;
        });

        // Show a message if using fallback categories
        if (result['source'] == 'fallback' && mounted) {
          showAdaptiveSnackBar(
            context: context,
            message: result['message'] ?? 'Using default categories',
            type: AdaptiveSnackBarType.info,
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to load categories');
      }
    } catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      // ✅ PERMANENT FIX: Check for session expiry after auto-refresh attempt
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('401') ||
          errorString.contains('unauthorized') ||
          errorString.contains('session may have expired')) {
        AppLogger.error(
          '[DiscountManagement] Session expired loading categories',
        );

        await AppAuthService.signOut();

        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          _showAuthenticationRequiredDialog(
            loc.sessionExpiredTitle,
            'Your session has expired. Please sign in again.',
          );
        }
        return;
      }

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Failed to load categories: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  String _getBusinessTypeString(dynamic businessType) {
    // Convert BusinessType enum to the correct API string
    final typeStr = businessType.toString().split('.').last.toLowerCase();

    switch (typeStr) {
      case 'kitchen':
        return 'restaurant'; // API expects 'restaurant' for kitchen businesses
      case 'cloudkitchen':
        return 'cloudkitchen';
      case 'store':
        return 'store';
      case 'pharmacy':
        return 'pharmacy';
      case 'caffe':
        return 'cafe'; // API expects 'cafe' not 'caffe'
      case 'bakery':
        return 'bakery';
      case 'herbalspices':
        return 'store'; // Fallback to store for unsupported types
      case 'cosmetics':
        return 'store'; // Fallback to store for unsupported types
      case 'betshop':
        return 'store'; // Fallback to store for unsupported types
      default:
        return 'restaurant'; // Default fallback
    }
  }

  Future<void> _createDiscount(Discount discount) async {
    final businessId = widget.business.id;
    final loc = AppLocalizations.of(context)!;
    try {
      setState(() {
        _isLoading = true;
      });

      final discountData = discount.toJson();

      final createdDiscountData = await _apiService.createDiscount(discountData,
          businessId: businessId);
      if (!mounted || widget.business.id != businessId) return;
      final createdDiscount = Discount.fromJson(createdDiscountData);

      setState(() {
        _discounts.add(createdDiscount);
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: loc.discountCreatedSuccessfully,
          type: AdaptiveSnackBarType.success,
        );
      }
    } on AuthTokenExpiredException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Auth token expired creating discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } on UnauthorizedException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Unauthorized creating discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.failedToCreateDiscount}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _updateDiscount(Discount discount) async {
    final businessId = widget.business.id;
    final loc = AppLocalizations.of(context)!;
    try {
      setState(() {
        _isLoading = true;
      });

      final discountData = discount.toJson();
      final updatedDiscountData = await _apiService.updateDiscount(
          discount.id, discountData,
          businessId: businessId, baseRevision: discount.revision);
      if (!mounted || widget.business.id != businessId) return;
      final updatedDiscount = Discount.fromJson(updatedDiscountData);

      setState(() {
        final index = _discounts.indexWhere((d) => d.id == discount.id);
        if (index != -1) {
          _discounts[index] = updatedDiscount;
        }
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: loc.discountUpdatedSuccessfully,
          type: AdaptiveSnackBarType.success,
        );
      }
    } on AuthTokenExpiredException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Auth token expired updating discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } on UnauthorizedException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Unauthorized updating discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.failedToUpdateDiscount}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _deleteDiscount(String discountId) async {
    final businessId = widget.business.id;
    String? baseRevision;
    for (final value in _discounts) {
      if (value.id == discountId) baseRevision = value.revision;
    }
    final loc = AppLocalizations.of(context)!;
    try {
      setState(() {
        _isLoading = true;
      });

      await _apiService.deleteDiscount(discountId,
          businessId: businessId, baseRevision: baseRevision);

      if (!mounted || widget.business.id != businessId) return;
      setState(() {
        _discounts.removeWhere((d) => d.id == discountId);
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: loc.discountDeletedSuccessfully,
          type: AdaptiveSnackBarType.success,
        );
      }
    } on AuthTokenExpiredException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Auth token expired deleting discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } on UnauthorizedException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Unauthorized deleting discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          loc.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.failedToDeleteDiscount}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _showSharedDiscountReplacement(Discount discount) async {
    final businessId = widget.business.id;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('خصم مشترك — الشروط مقفلة'),
              content: const Text(
                  'لا يمكن تعديل أو حذف شروط هذا الخصم بعد اعتماد المشاركة. يمكنك إيقافه وإنشاء خصم بديل يحتاج مشاركة وموافقة جديدتين. الطلبات السابقة تحتفظ بشروطها.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('رجوع')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('إيقاف الخصم وإنشاء بديل'))
              ],
            ));
    if (confirmed != true || !mounted || widget.business.id != businessId)
      return;
    try {
      if (discount.status != DiscountStatus.inactive) {
        await _apiService.updateDiscount(discount.id, {'status': 'inactive'},
            businessId: businessId, baseRevision: discount.revision);
      }
      if (!mounted || widget.business.id != businessId) return;
      await _loadDiscounts();
      if (!mounted || widget.business.id != businessId) return;
      _showDiscountDialog(seed: discount);
    } catch (_) {
      if (!mounted || widget.business.id != businessId) return;
      showAdaptiveSnackBar(
          context: context,
          message: 'تعذر إيقاف الخصم. أعد تحميل القائمة وحاول مجددًا.',
          type: AdaptiveSnackBarType.error);
    }
  }

  Future<void> _toggleDiscountStatus(Discount discount) async {
    if (discount.sharingLocked &&
        !discount.sharingCanActivate &&
        discount.status != DiscountStatus.active) {
      await _showSharedDiscountReplacement(discount);
      return;
    }
    final businessId = widget.business.id;
    try {
      setState(() {
        _isLoading = true;
      });

      await _apiService.toggleDiscountStatus(discount.id,
          businessId: businessId, baseRevision: discount.revision);
      if (!mounted || widget.business.id != businessId) return;
      await _loadDiscounts();
    } on AuthTokenExpiredException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Auth token expired toggling discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          AppLocalizations.of(context)!.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } on UnauthorizedException catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      AppLogger.error(
        '[DiscountManagement] Unauthorized toggling discount: ${e.message}',
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showAuthenticationRequiredDialog(
          AppLocalizations.of(context)!.sessionExpiredTitle,
          'Your session has expired. Please sign in again.',
        );
      }
    } catch (e) {
      if (!mounted || widget.business.id != businessId) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: '$e',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  void _showAuthenticationRequiredDialog(String title, String message) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: WhizzColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: _navigateToLogin,
            child: Text(loc.signIn),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Container(
            padding: EdgeInsets.all(GoldenRatio.spacing16),
            decoration: BoxDecoration(
              color: WhizzColors.white,
              borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
              boxShadow: WhizzColors.elevation(2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveLoadingIndicator(
                  color: WhizzColors.primary,
                  size: 40,
                ),
                SizedBox(height: GoldenRatio.spacing12),
                Text(
                  loc.loadingDiscountManagement,
                  style: TypographySystem.bodyLarge.copyWith(
                    color: WhizzColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Header Section with Statistics
                      _buildHeaderSection(loc),

                      // Discounts list
                      Expanded(
                        child: _filteredDiscounts.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                    horizontal: GoldenRatio.spacing12),
                                itemCount: _filteredDiscounts.length,
                                itemBuilder: (context, index) {
                                  final discount = _filteredDiscounts[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                        bottom: GoldenRatio.spacing12),
                                    child: DiscountCard(
                                      discount: discount,
                                      onEdit: () =>
                                          _showEditDiscountDialog(discount),
                                      onDelete: () => discount.sharingLocked
                                          ? _showSharedDiscountReplacement(
                                              discount)
                                          : _showDeleteConfirmationDialog(
                                              discount),
                                      onToggleStatus: () =>
                                          _toggleDiscountStatus(discount),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  // Loading overlay
                  if (_isLoading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusLg),
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(
                              GoldenRatio.spacing24 + GoldenRatio.spacing8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(GoldenRatio.radiusXl),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3),
                                blurRadius: GoldenRatio.spacing20,
                                offset: Offset(0, GoldenRatio.spacing8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AdaptiveLoadingIndicator(
                                color: Theme.of(context).colorScheme.primary,
                                size: 40,
                              ),
                              SizedBox(height: GoldenRatio.spacing16),
                              Text(
                                loc.processing,
                                style: TypographySystem.bodyLarge.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(GoldenRatio.spacing12),
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: GoldenRatio.spacing4,
            vertical: GoldenRatio.spacing8,
          ),
          padding: EdgeInsets.all(GoldenRatio.spacing16),
          decoration: BoxDecoration(
            color: WhizzColors.white,
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            border: Border.all(
              color: WhizzColors.borderPrimary,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: WhizzColors.shadow.withValues(alpha: 0.04),
                blurRadius: GoldenRatio.spacing12,
                offset: Offset(0, GoldenRatio.spacing4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(GoldenRatio.spacing16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
                ),
                child: Icon(
                  Icons.local_offer_outlined,
                  size: GoldenRatio.spacing24 * 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: GoldenRatio.spacing16),
              Text(
                loc.noDiscountsCreated,
                style: TypographySystem.headlineMedium.copyWith(
                  color: WhizzColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: GoldenRatio.spacing8),
              Text(
                loc.createYourFirstDiscount,
                textAlign: TextAlign.center,
                style: TypographySystem.bodyLarge.copyWith(
                  color: WhizzColors.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              SizedBox(height: GoldenRatio.spacing16),

              // Feature benefits
              Container(
                padding: EdgeInsets.all(GoldenRatio.spacing12),
                decoration: BoxDecoration(
                  color: WhizzColors.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
                  border: Border.all(
                    color: WhizzColors.borderPrimary,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'عروض تساعدك على زيادة الطلبات',
                      style: TypographySystem.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: WhizzColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: GoldenRatio.spacing8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBenefitItem(
                            icon: Icons.trending_up_rounded,
                            title: 'زيادة الطلبات',
                            subtitle: 'الوصول إلى زبائن أكثر',
                            color: WhizzColors.success,
                          ),
                        ),
                        SizedBox(width: GoldenRatio.spacing12),
                        Expanded(
                          child: _buildBenefitItem(
                            icon: Icons.favorite_rounded,
                            title: 'ولاء الزبائن',
                            subtitle: 'مكافأة الزبائن الدائمين',
                            color: WhizzColors.secondary,
                          ),
                        ),
                        SizedBox(width: GoldenRatio.spacing12),
                        Expanded(
                          child: _buildBenefitItem(
                            icon: Icons.schedule_rounded,
                            title: 'جدولة العروض',
                            subtitle: 'اختيار وقت بداية العرض ونهايته',
                            color: WhizzColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: GoldenRatio.spacing24),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
                  boxShadow: WhizzColors.elevation(2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showCreateDiscountDialog(),
                    borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: GoldenRatio.spacing24,
                        vertical: GoldenRatio.spacing16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding:
                                EdgeInsets.all(GoldenRatio.spacing8 * 0.75),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(GoldenRatio.spacing8),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: GoldenRatio.spacing18,
                            ),
                          ),
                          SizedBox(width: GoldenRatio.spacing12),
                          Text(
                            'إنشاء خصم',
                            style: TypographySystem.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ), // Close Container
      ), // Close Center
    ); // Close SingleChildScrollView
  } // Close _buildEmptyState method

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(GoldenRatio.spacing12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
          ),
          child: Icon(
            icon,
            color: color,
            size: GoldenRatio.spacing20,
          ),
        ),
        SizedBox(height: GoldenRatio.spacing8),
        Text(
          title,
          style: TypographySystem.labelMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: WhizzColors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: GoldenRatio.spacing4),
        Text(
          subtitle,
          style: TypographySystem.labelSmall.copyWith(
            color: WhizzColors.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showCreateDiscountDialog() {
    _showDiscountDialog();
  }

  void _showEditDiscountDialog(Discount discount) {
    if (discount.sharingLocked) {
      _showSharedDiscountReplacement(discount);
      return;
    }
    _showDiscountDialog(discount: discount);
  }

  void _showDeleteConfirmationDialog(Discount discount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WhizzColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.radiusXl),
          side: BorderSide(
              color: WhizzColors.error.withValues(alpha: 0.2), width: 2),
        ),
        title: Container(
          padding: EdgeInsets.all(GoldenRatio.spacing16),
          decoration: BoxDecoration(
            color: WhizzColors.errorContainer,
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(GoldenRatio.spacing8),
                decoration: BoxDecoration(
                  color: WhizzColors.error,
                  borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
                ),
                child: Icon(
                  Icons.delete_forever,
                  color: WhizzColors.onPrimary,
                  size: GoldenRatio.spacing20,
                ),
              ),
              SizedBox(width: GoldenRatio.spacing12),
              Text(
                AppLocalizations.of(context)!.deleteDiscount,
                style: TypographySystem.headlineSmall.copyWith(
                  color: WhizzColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: GoldenRatio.spacing16),
          child: Text(
            AppLocalizations.of(context)!.areYouSureYouWantToDeleteThisDiscount,
            style: TypographySystem.bodyLarge.copyWith(
              color: WhizzColors.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.all(GoldenRatio.spacing8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: WhizzColors.onSurfaceVariant,
                padding: EdgeInsets.symmetric(
                    horizontal: GoldenRatio.spacing24,
                    vertical: GoldenRatio.spacing12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
                  side: BorderSide(color: WhizzColors.border, width: 1),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TypographySystem.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.all(GoldenRatio.spacing8),
            decoration: BoxDecoration(
              color: WhizzColors.error,
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
              boxShadow: WhizzColors.elevation(1),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteDiscount(discount.id);
              },
              style: TextButton.styleFrom(
                foregroundColor: WhizzColors.white,
                padding: EdgeInsets.symmetric(
                    horizontal: GoldenRatio.spacing24,
                    vertical: GoldenRatio.spacing12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.delete,
                    style: TypographySystem.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: WhizzColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<T?> _showArabicOfferDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) =>
      showDialog<T>(
        context: context,
        builder: (routeContext) =>
            arabicMerchantDiscountContent(routeContext, builder),
      );

  void _showDiscountDialog({Discount? discount, Discount? seed}) {
    // The goods editor has no delivery policy controls. Preserve legacy delivery
    // offers instead of silently converting them into percentage discounts.
    if (discount?.type == DiscountType.freeDelivery) {
      showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
                content: SingleChildScrollView(
                    child: DiscountFundingNotice(
                        delivery: true,
                        onReview: () => Navigator.of(dialog).push(
                            MaterialPageRoute(
                                builder: (_) => CommercialAgreementsScreen(
                                    businessId: widget.business.id))))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(dialog).pop(),
                      child: Text(
                          MaterialLocalizations.of(dialog).closeButtonLabel))
                ],
              ));
      return;
    }
    final isEditing = discount != null;
    discount ??= seed;
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: discount?.title ?? '');
    final valueController = TextEditingController(
        text: discount != null ? _formatDiscountValue(discount.value) : '');
    final minOrderController = TextEditingController(
        text: discount?.minimumOrderAmount.toString() ?? '');

    final totalUsesController =
        TextEditingController(text: discount?.maxUsage?.toString() ?? '');
    final customerUsesController = TextEditingController(
        text: discount?.perCustomerLimit?.toString() ?? '');
    final discountCapController = TextEditingController(
        text: discount?.maxDiscountAmount == null
            ? ''
            : _formatDiscountValue(discount!.maxDiscountAmount!.toDouble()));

    // If editing a free delivery discount, default the main type to percentage
    var discountType = discount?.type == DiscountType.freeDelivery
        ? DiscountType.percentage
        : (discount?.type ?? DiscountType.percentage);
    if (discountType == DiscountType.percentage &&
        valueController.text.isEmpty) {
      valueController.text = '10';
    }

    // Handle discount applicability
    var applicability =
        discount?.applicability ?? DiscountApplicability.allItems;
    var selectedItemIds = List<String>.from(discount?.applicableItemIds ?? []);
    var selectedCategoryIds =
        List<String>.from(discount?.applicableCategoryIds ?? []);

    // Buy X Get Y specific variables
    final buyXQuantityController = TextEditingController(
        text:
            discount?.conditionalParameters?['buyQuantity']?.toString() ?? '1');
    final getYQuantityController = TextEditingController(
        text:
            discount?.conditionalParameters?['getQuantity']?.toString() ?? '1');
    var selectedBuyItemId =
        discount?.conditionalParameters?['buyItemId'] as String?;
    var selectedGetItemId =
        discount?.conditionalParameters?['getItemId'] as String?;

    var startDate = discount?.validFrom ?? DateTime.now();
    var endDate =
        discount?.validTo ?? DateTime.now().add(const Duration(days: 7));

    // Optional discount image state
    final imagePicker = ImagePicker();
    File? _pickedImage;
    String? _existingImageUrl = discount?.imageUrl;
    bool _uploadingImage = false;
    void Function(void Function())? sheetSetState;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: AppAnimations.bottomSheetSlide,
      ),
      builder: (routeContext) =>
          arabicMerchantDiscountContent(routeContext, (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return AnimatedContainer(
              duration: AppAnimations.normal,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              decoration: BoxDecoration(
                color: WhizzColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.borderRadiusXL),
                  topRight: Radius.circular(AppDimensions.borderRadiusXL),
                ),
                boxShadow: [
                  BoxShadow(
                    color: WhizzColors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WhizzColors.grey300,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusFull),
                    ),
                  ),
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: WhizzColors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: WhizzColors.grey200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                WhizzColors.primary,
                                WhizzColors.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadiusMD),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    WhizzColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_rounded : Icons.add_rounded,
                            color: WhizzColors.black,
                            size: AppDimensions.iconSizeMD,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            isEditing
                                ? AppLocalizations.of(context)!.editDiscount
                                : AppLocalizations.of(context)!.createDiscount,
                            style: AppTypography.titleLarge.copyWith(
                              color: WhizzColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.borderRadiusFull),
                            child: Container(
                              padding: EdgeInsets.all(AppSpacing.xs),
                              child: Icon(
                                Icons.close_rounded,
                                size: AppDimensions.iconSizeMD,
                                color: WhizzColors.grey600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        sheetSetState = setState;
                        return Form(
                          key: formKey,
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section: Basic Information
                                DiscountFundingNotice(
                                  editing: isEditing,
                                  delivery:
                                      discountType == DiscountType.freeDelivery,
                                  onReview: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              CommercialAgreementsScreen(
                                                  businessId:
                                                      widget.business.id))),
                                ),
                                Text(
                                  AppLocalizations.of(context)!
                                      .basicInformation,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: WhizzColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.sm),

                                // Title Field with modern styling
                                Container(
                                  decoration: BoxDecoration(
                                    color: WhizzColors.grey50,
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusMD),
                                    border: Border.all(
                                      color: WhizzColors.grey200,
                                      width: 1,
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: titleController,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: WhizzColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      labelText:
                                          AppLocalizations.of(context)!.title,
                                      labelStyle:
                                          AppTypography.bodyMedium.copyWith(
                                        color: WhizzColors.grey600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      floatingLabelStyle:
                                          AppTypography.bodySmall.copyWith(
                                        color: WhizzColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppDimensions.borderRadiusMD),
                                        borderSide: BorderSide(
                                          color: WhizzColors.primary,
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppDimensions.borderRadiusMD),
                                        borderSide: BorderSide(
                                          color: WhizzColors.error,
                                          width: 2,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppDimensions.borderRadiusMD),
                                        borderSide: BorderSide(
                                          color: WhizzColors.error,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.md,
                                      ),
                                      filled: false,
                                      prefixIcon: Icon(
                                        Icons.label_rounded,
                                        color: WhizzColors.grey600,
                                        size: AppDimensions.iconSizeMD,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return AppLocalizations.of(context)!
                                            .pleaseEnterTitle;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(height: AppSpacing.lg),

                                // Section: Discount Image (optional)
                                Text(
                                  AppLocalizations.of(context)!.uploadImage,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: WhizzColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.sm),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Preview of picked file or existing URL
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: WhizzColors.grey50,
                                        borderRadius: BorderRadius.circular(
                                            AppDimensions.borderRadiusMD),
                                        border: Border.all(
                                          color: WhizzColors.grey200,
                                          width: 1,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: _pickedImage != null
                                          ? Image.file(
                                              _pickedImage!,
                                              fit: BoxFit.cover,
                                              width: 72,
                                              height: 72,
                                            )
                                          : (_existingImageUrl != null &&
                                                  _existingImageUrl!.isNotEmpty)
                                              ? Image.network(
                                                  _existingImageUrl!,
                                                  fit: BoxFit.cover,
                                                  width: 72,
                                                  height: 72,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      Icon(
                                                    Icons.broken_image_outlined,
                                                    color: WhizzColors.grey400,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.image_outlined,
                                                  color: WhizzColors.grey400,
                                                  size:
                                                      AppDimensions.iconSizeLG,
                                                ),
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _uploadingImage
                                                ? null
                                                : () async {
                                                    try {
                                                      final XFile? pickedFile =
                                                          await imagePicker
                                                              .pickImage(
                                                        source:
                                                            ImageSource.gallery,
                                                        maxWidth: 1080,
                                                        maxHeight: 1080,
                                                        imageQuality: 85,
                                                      );
                                                      if (pickedFile != null) {
                                                        setState(() {
                                                          _pickedImage = File(
                                                              pickedFile.path);
                                                          _existingImageUrl =
                                                              null;
                                                        });
                                                      }
                                                    } catch (e) {
                                                      AppLogger.error(
                                                          '[DiscountManagement] Error picking image: $e');
                                                      if (context.mounted) {
                                                        showAdaptiveSnackBar(
                                                          context: context,
                                                          message:
                                                              '${AppLocalizations.of(context)!.errorPickingImage}: $e',
                                                          type:
                                                              AdaptiveSnackBarType
                                                                  .error,
                                                        );
                                                      }
                                                    }
                                                  },
                                            icon: Icon(
                                              Icons.photo_library_outlined,
                                              size: AppDimensions.iconSizeSM,
                                            ),
                                            label: Text(
                                              (_pickedImage != null ||
                                                      (_existingImageUrl !=
                                                              null &&
                                                          _existingImageUrl!
                                                              .isNotEmpty))
                                                  ? AppLocalizations.of(
                                                          context)!
                                                      .changeImage
                                                  : AppLocalizations.of(
                                                          context)!
                                                      .uploadImage,
                                            ),
                                          ),
                                          if (_pickedImage != null ||
                                              (_existingImageUrl != null &&
                                                  _existingImageUrl!
                                                      .isNotEmpty)) ...[
                                            SizedBox(height: AppSpacing.xs),
                                            TextButton.icon(
                                              onPressed: _uploadingImage
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _pickedImage = null;
                                                        _existingImageUrl =
                                                            null;
                                                      });
                                                    },
                                              icon: Icon(
                                                Icons.close_rounded,
                                                size: AppDimensions.iconSizeSM,
                                                color: WhizzColors.error,
                                              ),
                                              label: Text(
                                                AppLocalizations.of(context)!
                                                    .delete,
                                                style: TextStyle(
                                                    color: WhizzColors.error),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppSpacing.lg),
                                // Section: Discount Configuration
                                Text(
                                  AppLocalizations.of(context)!
                                      .discountConfiguration,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: WhizzColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.sm),

                                MerchantDiscountValueFields(
                                  type: discountType,
                                  controller: valueController,
                                  onTypeChanged: (value) => setState(() {
                                    discountType = value;
                                    valueController.text =
                                        value == DiscountType.percentage
                                            ? '10'
                                            : value == DiscountType.fixedAmount
                                                ? ''
                                                : '0';
                                  }),
                                ),
                                const SizedBox(height: 10),

                                // Buy X Get Y Configuration Section
                                if (discountType == DiscountType.buyXGetY ||
                                    discountType ==
                                        DiscountType.conditional) ...[
                                  SizedBox(height: AppSpacing.md),

                                  // Section Header
                                  Container(
                                    padding: EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          WhizzColors.primary
                                              .withValues(alpha: 0.1),
                                          WhizzColors.primary
                                              .withValues(alpha: 0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.borderRadiusMD),
                                      border: Border.all(
                                        color: WhizzColors.primary
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding:
                                              EdgeInsets.all(AppSpacing.xs),
                                          decoration: BoxDecoration(
                                            color: WhizzColors.primary,
                                            borderRadius: BorderRadius.circular(
                                                AppDimensions.borderRadiusSM),
                                            boxShadow: [
                                              BoxShadow(
                                                color: WhizzColors.primary
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.shopping_cart_rounded,
                                            color: WhizzColors.black,
                                            size: AppDimensions.iconSizeSM,
                                          ),
                                        ),
                                        SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            discountType ==
                                                    DiscountType.conditional
                                                ? AppLocalizations.of(context)!
                                                    .conditionalDiscountConfiguration
                                                : AppLocalizations.of(context)!
                                                    .buyXGetYConfiguration,
                                            style: AppTypography.titleSmall
                                                .copyWith(
                                              color: WhizzColors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: AppSpacing.md),

                                  // Configuration Card
                                  Container(
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: WhizzColors.white,
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.borderRadiusMD),
                                      border: Border.all(
                                        color: WhizzColors.grey200,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: WhizzColors.black
                                              .withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Buy X Configuration
                                        Text(
                                          AppLocalizations.of(context)!
                                              .buyConfiguration,
                                          style:
                                              AppTypography.titleSmall.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: WhizzColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: AppSpacing.sm),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: WhizzColors.grey50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppDimensions
                                                              .borderRadiusMD),
                                                  border: Border.all(
                                                    color: WhizzColors.grey200,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: TextFormField(
                                                  controller:
                                                      buyXQuantityController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  style: AppTypography.bodyLarge
                                                      .copyWith(
                                                    color:
                                                        WhizzColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText:
                                                        AppLocalizations.of(
                                                                context)!
                                                            .quantityShort,
                                                    labelStyle: AppTypography
                                                        .bodySmall
                                                        .copyWith(
                                                      color:
                                                          WhizzColors.grey600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    floatingLabelStyle:
                                                        AppTypography.bodySmall
                                                            .copyWith(
                                                      color:
                                                          WhizzColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    border: InputBorder.none,
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius: BorderRadius
                                                          .circular(AppDimensions
                                                              .borderRadiusMD),
                                                      borderSide: BorderSide(
                                                        color:
                                                            WhizzColors.primary,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    errorBorder:
                                                        OutlineInputBorder(
                                                      borderRadius: BorderRadius
                                                          .circular(AppDimensions
                                                              .borderRadiusMD),
                                                      borderSide: BorderSide(
                                                        color:
                                                            WhizzColors.error,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: AppSpacing.sm,
                                                      vertical: AppSpacing.sm,
                                                    ),
                                                    prefixIcon: Icon(
                                                      Icons
                                                          .format_list_numbered_rounded,
                                                      color:
                                                          WhizzColors.grey600,
                                                      size: AppDimensions
                                                          .iconSizeSM,
                                                    ),
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return AppLocalizations
                                                              .of(context)!
                                                          .required;
                                                    }
                                                    if (int.tryParse(value) ==
                                                            null ||
                                                        int.parse(value) <= 0) {
                                                      return AppLocalizations
                                                              .of(context)!
                                                          .enterValidQuantity;
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              flex: 2,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _showBuyItemSelectionDialog(
                                                        selectedBuyItemId,
                                                        (itemId) {
                                                  setState(() {
                                                    selectedBuyItemId = itemId;
                                                  });
                                                }),
                                                child: Container(
                                                  padding: EdgeInsets.all(
                                                      GoldenRatio.spacing12),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: WhizzColors
                                                            .borderPrimary),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            GoldenRatio
                                                                .radiusXs),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          selectedBuyItemId ==
                                                                  null
                                                              ? AppLocalizations
                                                                      .of(
                                                                          context)!
                                                                  .selectItem
                                                              : AppLocalizations
                                                                      .of(context)!
                                                                  .itemSelected,
                                                          style: TextStyle(
                                                            color: selectedBuyItemId ==
                                                                    null
                                                                ? WhizzColors
                                                                    .textSecondary
                                                                : WhizzColors
                                                                    .textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                      Icon(
                                                          Icons.arrow_drop_down,
                                                          color: WhizzColors
                                                              .textSecondary),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Get Y Configuration
                                        Text(
                                          AppLocalizations.of(context)!
                                              .getConfiguration,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: WhizzColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: TextFormField(
                                                controller:
                                                    getYQuantityController,
                                                decoration: InputDecoration(
                                                  labelText: 'الكمية',
                                                  border:
                                                      const OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                                keyboardType:
                                                    TextInputType.number,
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return AppLocalizations.of(
                                                            context)!
                                                        .required;
                                                  }
                                                  if (int.tryParse(value) ==
                                                          null ||
                                                      int.parse(value) <= 0) {
                                                    return AppLocalizations.of(
                                                            context)!
                                                        .enterValidQuantity;
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _showGetItemSelectionDialog(
                                                        selectedGetItemId,
                                                        (itemId) {
                                                  setState(() {
                                                    selectedGetItemId = itemId;
                                                  });
                                                }),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: WhizzColors
                                                            .borderPrimary),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          selectedGetItemId ==
                                                                  null
                                                              ? AppLocalizations
                                                                      .of(
                                                                          context)!
                                                                  .selectItem
                                                              : AppLocalizations
                                                                      .of(context)!
                                                                  .itemSelected,
                                                          style: TextStyle(
                                                            color: selectedGetItemId ==
                                                                    null
                                                                ? WhizzColors
                                                                    .textSecondary
                                                                : WhizzColors
                                                                    .textPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                      Icon(
                                                          Icons.arrow_drop_down,
                                                          color: WhizzColors
                                                              .textSecondary),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                // Discount Applicability Section
                                Opacity(
                                  opacity: (discountType ==
                                              DiscountType.conditional ||
                                          discountType == DiscountType.buyXGetY)
                                      ? 0.5
                                      : 1.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: (discountType ==
                                                  DiscountType.conditional ||
                                              discountType ==
                                                  DiscountType.buyXGetY)
                                          ? WhizzColors.secondary
                                              .withValues(alpha: 0.08)
                                          : WhizzColors.secondary
                                              .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: (discountType ==
                                                      DiscountType
                                                          .conditional ||
                                                  discountType ==
                                                      DiscountType.buyXGetY)
                                              ? WhizzColors.secondary
                                                  .withValues(alpha: 0.2)
                                              : WhizzColors.secondary
                                                  .withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.category,
                                                color: WhizzColors.secondary,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              AppLocalizations.of(context)!
                                                  .discountApplicability,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: WhizzColors.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<
                                            DiscountApplicability>(
                                          value: applicability,
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 8),
                                          ),
                                          isExpanded: true,
                                          items: DiscountApplicability.values
                                              .where((type) =>
                                                  type !=
                                                  DiscountApplicability
                                                      .minimumOrder)
                                              .map((applicabilityType) {
                                            String label;
                                            switch (applicabilityType) {
                                              case DiscountApplicability
                                                    .allItems:
                                                label = AppLocalizations.of(
                                                        context)!
                                                    .allItems;
                                                break;
                                              case DiscountApplicability
                                                    .specificItems:
                                                label = AppLocalizations.of(
                                                        context)!
                                                    .specificItems;
                                                break;
                                              case DiscountApplicability
                                                    .specificCategories:
                                                label = AppLocalizations.of(
                                                        context)!
                                                    .specificCategories;
                                                break;
                                              case DiscountApplicability
                                                    .minimumOrder:
                                                label = AppLocalizations.of(
                                                        context)!
                                                    .minimumOrder; // This won't be reached due to filter
                                                break;
                                            }
                                            return DropdownMenuItem<
                                                DiscountApplicability>(
                                              value: applicabilityType,
                                              child: Text(
                                                label,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            );
                                          }).toList(),
                                          // Disable for conditional and buyXGetY types
                                          onChanged: (discountType ==
                                                      DiscountType
                                                          .conditional ||
                                                  discountType ==
                                                      DiscountType.buyXGetY)
                                              ? null
                                              : (value) {
                                                  if (value != null) {
                                                    setState(() {
                                                      applicability = value;
                                                      // Clear selections when changing applicability
                                                      if (value !=
                                                          DiscountApplicability
                                                              .specificItems) {
                                                        selectedItemIds.clear();
                                                      }
                                                      if (value !=
                                                          DiscountApplicability
                                                              .specificCategories) {
                                                        selectedCategoryIds
                                                            .clear();
                                                      }
                                                    });
                                                  }
                                                },
                                        ),

                                        // Item Selection for Specific Items
                                        if (applicability ==
                                            DiscountApplicability
                                                .specificItems) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: WhizzColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: WhizzColors.border),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.shopping_basket,
                                                        size: 16,
                                                        color: WhizzColors
                                                            .textSecondary),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      AppLocalizations.of(
                                                              context)!
                                                          .selectItems,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: WhizzColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _showItemSelectionDialog(
                                                          selectedItemIds,
                                                          setState),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: WhizzColors
                                                              .border),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            selectedItemIds
                                                                    .isEmpty
                                                                ? AppLocalizations.of(
                                                                        context)!
                                                                    .noItemsSelected
                                                                : AppLocalizations.of(
                                                                        context)!
                                                                    .itemsSelected(
                                                                        selectedItemIds
                                                                            .length),
                                                            style: TextStyle(
                                                              color: selectedItemIds
                                                                      .isEmpty
                                                                  ? WhizzColors
                                                                      .textSecondary
                                                                  : WhizzColors
                                                                      .textPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                        Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            color: WhizzColors
                                                                .textSecondary),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        // Category Selection for Specific Categories
                                        if (applicability ==
                                            DiscountApplicability
                                                .specificCategories) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: WhizzColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: WhizzColors.border),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.folder,
                                                        size: 16,
                                                        color: WhizzColors
                                                            .textSecondary),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      AppLocalizations.of(
                                                              context)!
                                                          .selectCategories,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: WhizzColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _showCategorySelectionDialog(
                                                          selectedCategoryIds,
                                                          setState),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: WhizzColors
                                                              .border),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            selectedCategoryIds
                                                                    .isEmpty
                                                                ? AppLocalizations.of(
                                                                        context)!
                                                                    .noCategoriesSelected
                                                                : AppLocalizations.of(
                                                                        context)!
                                                                    .categoriesSelected(
                                                                        selectedCategoryIds
                                                                            .length),
                                                            style: TextStyle(
                                                              color: selectedCategoryIds
                                                                      .isEmpty
                                                                  ? WhizzColors
                                                                      .textSecondary
                                                                  : WhizzColors
                                                                      .textPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                        Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            color: WhizzColors
                                                                .textSecondary),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ), // Close Opacity widget

                                // Add notice for disabled applicability
                                if (discountType == DiscountType.conditional ||
                                    discountType == DiscountType.buyXGetY) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: WhizzColors.textSecondary,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            AppLocalizations.of(context)!
                                                .applicabilityNotConfigurable,
                                            style: TextStyle(
                                              color: WhizzColors.textSecondary,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                MerchantDiscountUsageFields(
                                    total: totalUsesController,
                                    customer: customerUsesController,
                                    cap: discountCapController,
                                    percentage: discountType ==
                                        DiscountType.percentage),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: minOrderController,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(context)!
                                        .minimumOrderAmount(''),
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value != null &&
                                        value.isNotEmpty &&
                                        double.tryParse(value) == null) {
                                      return AppLocalizations.of(context)!
                                          .pleaseEnterValidNumber;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final pickedDate =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: startDate,
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2101),
                                          );
                                          if (pickedDate != null) {
                                            setState(() {
                                              startDate = pickedDate;
                                            });
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText:
                                                AppLocalizations.of(context)!
                                                    .startDate,
                                            border: const OutlineInputBorder(),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text('${startDate.toLocal()}'
                                                .split(' ')[0]),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final pickedDate =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: endDate,
                                            firstDate: startDate,
                                            lastDate: DateTime(2101),
                                          );
                                          if (pickedDate != null) {
                                            setState(() {
                                              endDate = pickedDate;
                                            });
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText:
                                                AppLocalizations.of(context)!
                                                    .endDate,
                                            border: const OutlineInputBorder(),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text('${endDate.toLocal()}'
                                                .split(' ')[0]),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Bottom Action Buttons
                  Container(
                    decoration: BoxDecoration(
                      color: WhizzColors.white,
                      border: Border(
                        top: BorderSide(
                          color: WhizzColors.grey200,
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: WhizzColors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.borderRadiusMD),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: WhizzColors.grey100,
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusMD),
                                    border: Border.all(
                                      color: WhizzColors.grey300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.of(context)!.cancel,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: WhizzColors.grey700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  if (formKey.currentState!.validate()) {
                                    // Check for conflicting discounts
                                    if ((applicability ==
                                                DiscountApplicability
                                                    .specificItems &&
                                            selectedItemIds.isNotEmpty) ||
                                        (applicability ==
                                                DiscountApplicability
                                                    .specificCategories &&
                                            selectedCategoryIds.isNotEmpty)) {
                                      if (_hasConflictingDiscounts(
                                          selectedItemIds,
                                          selectedCategoryIds,
                                          discount?.id)) {
                                        _showArabicOfferDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                                AppLocalizations.of(context)!
                                                    .conflictingDiscountsTitle),
                                            content: Text(AppLocalizations.of(
                                                    context)!
                                                .someSelectedItemsAlreadyHaveDiscounts),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                child: Text(AppLocalizations.of(
                                                        context)!
                                                    .ok),
                                              ),
                                            ],
                                          ),
                                        );
                                        return;
                                      }
                                    }

                                    if (![
                                      DiscountType.percentage,
                                      DiscountType.fixedAmount,
                                      DiscountType.freeDelivery
                                    ].contains(discountType)) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'هذا النوع من العروض غير مدعوم حالياً.')));
                                      return;
                                    }
                                    // Prepare conditional parameters for Buy X Get Y and Conditional discounts
                                    Map<String, dynamic> conditionalParams = {};
                                    ConditionalDiscountRule? conditionalRule;

                                    if (discountType == DiscountType.buyXGetY ||
                                        discountType ==
                                            DiscountType.conditional) {
                                      if (selectedBuyItemId == null ||
                                          selectedGetItemId == null) {
                                        _showArabicOfferDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                                AppLocalizations.of(context)!
                                                    .missingItems),
                                            content: Text(AppLocalizations.of(
                                                    context)!
                                                .missingItemsMessage(
                                                    discountType ==
                                                            DiscountType
                                                                .conditional
                                                        ? AppLocalizations.of(
                                                                context)!
                                                            .conditional
                                                        : AppLocalizations.of(
                                                                context)!
                                                            .buyXGetY)),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                child: Text(AppLocalizations.of(
                                                        context)!
                                                    .ok),
                                              ),
                                            ],
                                          ),
                                        );
                                        return;
                                      }

                                      conditionalRule =
                                          ConditionalDiscountRule.buyXGetY;
                                      conditionalParams = {
                                        'buyItemId': selectedBuyItemId,
                                        'buyQuantity': int.parse(
                                            buyXQuantityController.text),
                                        'getItemId': selectedGetItemId,
                                        'getQuantity': int.parse(
                                            getYQuantityController.text),
                                      };
                                    }

                                    // Upload the picked image first (if any) so
                                    // the returned URL can be stored on the
                                    // discount record as imageUrl.
                                    String? imageUrl = _existingImageUrl;
                                    if (_pickedImage != null) {
                                      sheetSetState?.call(() {
                                        _uploadingImage = true;
                                      });
                                      final uploadResult =
                                          await ImageUploadService
                                              .uploadProductImage(
                                                  _pickedImage!);
                                      sheetSetState?.call(() {
                                        _uploadingImage = false;
                                      });
                                      if (uploadResult['success'] == true) {
                                        imageUrl =
                                            uploadResult['imageUrl'] as String?;
                                      } else {
                                        if (context.mounted) {
                                          showAdaptiveSnackBar(
                                            context: context,
                                            message:
                                                '${AppLocalizations.of(context)!.imageUploadFailed}: ${uploadResult['message']}',
                                            type: AdaptiveSnackBarType.error,
                                          );
                                        }
                                        return;
                                      }
                                    }

                                    final newDiscount = Discount(
                                      revision:
                                          isEditing ? discount?.revision : null,
                                      id: (isEditing ? discount?.id : null) ??
                                          DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString(),
                                      name: titleController.text,
                                      description:
                                          '', // Description field removed from creation
                                      type: discountType,
                                      value: double.parse(valueController.text),
                                      applicability: applicability,
                                      applicableItemIds: selectedItemIds,
                                      applicableCategoryIds:
                                          selectedCategoryIds,
                                      maxUsage:
                                          MerchantDiscountUsageFields.parse(
                                              totalUsesController.text),
                                      perCustomerLimit:
                                          MerchantDiscountUsageFields.parse(
                                              customerUsesController.text),
                                      maxDiscountAmount: discountType ==
                                              DiscountType.percentage
                                          ? MerchantDiscountUsageFields.parse(
                                              discountCapController.text)
                                          : null,
                                      minimumOrderAmount: double.tryParse(
                                              minOrderController.text) ??
                                          0.0,
                                      startDate: startDate,
                                      endDate: endDate,
                                      validFrom: startDate,
                                      validTo: endDate,
                                      businessId: widget.business.id,
                                      createdAt: (isEditing
                                              ? discount?.createdAt
                                              : null) ??
                                          DateTime.now(),
                                      updatedAt: DateTime.now(),
                                      status: seed != null
                                          ? DiscountStatus.inactive
                                          : DiscountStatus.active,
                                      conditionalRule: conditionalRule,
                                      conditionalParameters: conditionalParams,
                                      imageUrl: imageUrl,
                                    );

                                    Navigator.of(context).pop();

                                    // Call API methods to create or update the discount
                                    try {
                                      if (isEditing) {
                                        await _updateDiscount(newDiscount);
                                      } else {
                                        // Check for conflicting discounts before adding
                                        if (!_hasConflictingDiscounts(
                                            selectedItemIds,
                                            selectedCategoryIds,
                                            null)) {
                                          await _createDiscount(newDiscount);
                                        } else {
                                          // Show error message
                                          showAdaptiveSnackBar(
                                            context: context,
                                            message:
                                                AppLocalizations.of(context)!
                                                    .conflictingDiscounts,
                                            type: AdaptiveSnackBarType.error,
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      // Error handling is already done in the individual methods
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.borderRadiusMD),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        WhizzColors.primary,
                                        WhizzColors.primary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusMD),
                                    boxShadow: [
                                      BoxShadow(
                                        color: WhizzColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.md,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding:
                                              EdgeInsets.all(AppSpacing.xxs),
                                          decoration: BoxDecoration(
                                            color: WhizzColors.black
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                                AppDimensions.borderRadiusSM),
                                          ),
                                          child: Icon(
                                            isEditing
                                                ? Icons.save_rounded
                                                : Icons.add_rounded,
                                            color: WhizzColors.black,
                                            size: AppDimensions.iconSizeSM,
                                          ),
                                        ),
                                        SizedBox(width: AppSpacing.xs),
                                        Text(
                                          isEditing
                                              ? AppLocalizations.of(context)!
                                                  .saveChanges
                                              : AppLocalizations.of(context)!
                                                  .create,
                                          style: AppTypography.titleMedium
                                              .copyWith(
                                            color: WhizzColors.black,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  // Add validation method to check for conflicting discounts
  bool _hasConflictingDiscounts(List<String> selectedItemIds,
      List<String> selectedCategoryIds, String? currentDiscountId) {
    final existingDiscounts = _discounts.where((d) =>
        d.id != currentDiscountId &&
        d.status == DiscountStatus.active &&
        d.type != DiscountType.freeDelivery);

    for (final discount in existingDiscounts) {
      // Check for item conflicts
      if (discount.applicability == DiscountApplicability.specificItems) {
        for (final itemId in selectedItemIds) {
          if (discount.applicableItemIds.contains(itemId)) {
            return true;
          }
        }
      }

      // Check for category conflicts
      if (discount.applicability == DiscountApplicability.specificCategories) {
        for (final categoryId in selectedCategoryIds) {
          if (discount.applicableCategoryIds.contains(categoryId)) {
            return true;
          }
        }
      }

      // Check if existing discount applies to all items
      if (discount.applicability == DiscountApplicability.allItems &&
          (selectedItemIds.isNotEmpty || selectedCategoryIds.isNotEmpty)) {
        return true;
      }
    }

    return false;
  }

  void _showItemSelectionDialog(
      List<String> selectedItemIds, StateSetter setState) async {
    // Use the already loaded products instead of API call
    if (_products.isEmpty) {
      showAdaptiveSnackBar(
        context: context,
        message: AppLocalizations.of(context)!.noItemsFound,
        type: AdaptiveSnackBarType.info,
      );
      return;
    }

    // Flatten all items from all products
    List<Map<String, dynamic>> allItems = [];
    for (final product in _products) {
      // Find the category name for this product
      final category = _categories.firstWhere(
        (cat) => cat.id == product.categoryId,
        orElse: () => ProductCategory(
          id: '',
          name: 'بدون فئة',
          businessType: '',
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      allItems.add({
        'id': product.id,
        'name': product.name,
        'categoryName': category.name,
        'price': product.price,
      });
    }

    if (allItems.isEmpty) {
      showAdaptiveSnackBar(
        context: context,
        message: AppLocalizations.of(context)!.noItemsFound,
        type: AdaptiveSnackBarType.info,
      );
      return;
    }

    _showArabicOfferDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(selectedItemIds);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.selectItems),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Text(
                      '${tempSelected.length} ${AppLocalizations.of(context)!.items} selected',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          final isSelected = tempSelected.contains(item['id']);

                          return CheckboxListTile(
                            dense: true,
                            title: Text(item['name']),
                            subtitle: Text(AppLocalizations.of(context)!
                                .categoryAndPrice(
                                    item['categoryName'],
                                    AppLocalizations.of(context)!.kwd,
                                    item['price'].toStringAsFixed(2))),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelected.add(item['id']);
                                } else {
                                  tempSelected.remove(item['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedItemIds.clear();
                      selectedItemIds.addAll(tempSelected);
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00c1e8),
                    foregroundColor: WhizzColors.onPrimary,
                  ),
                  child: Text(AppLocalizations.of(context)!.ok),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCategorySelectionDialog(
      List<String> selectedCategoryIds, StateSetter setState) async {
    // Use the already loaded categories instead of API call
    if (_categories.isEmpty) {
      showAdaptiveSnackBar(
        context: context,
        message: AppLocalizations.of(context)!.noCategoriesFound,
        type: AdaptiveSnackBarType.info,
      );
      return;
    }

    _showArabicOfferDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(selectedCategoryIds);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.selectCategories),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Text(
                      '${tempSelected.length} ${AppLocalizations.of(context)!.categories} selected',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = tempSelected.contains(category.id);

                          return CheckboxListTile(
                            dense: true,
                            title: Text(category.name),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  tempSelected.add(category.id);
                                } else {
                                  tempSelected.remove(category.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCategoryIds.clear();
                      selectedCategoryIds.addAll(tempSelected);
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00c1e8),
                    foregroundColor: WhizzColors.onPrimary,
                  ),
                  child: Text(AppLocalizations.of(context)!.ok),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBuyItemSelectionDialog(
      String? selectedBuyItemId, Function(String?) onItemSelected) async {
    _showSingleItemSelectionDialog(
      selectedBuyItemId,
      AppLocalizations.of(context)!.selectBuyItem,
      onItemSelected,
    );
  }

  void _showGetItemSelectionDialog(
      String? selectedGetItemId, Function(String?) onItemSelected) async {
    _showSingleItemSelectionDialog(
      selectedGetItemId,
      AppLocalizations.of(context)!.selectGetItem,
      onItemSelected,
    );
  }

  void _showSingleItemSelectionDialog(
    String? selectedItemId,
    String title,
    Function(String?) onItemSelected,
  ) async {
    // Use the already loaded products instead of API call
    if (_products.isEmpty) {
      showAdaptiveSnackBar(
        context: context,
        message: AppLocalizations.of(context)!.noItemsFound,
        type: AdaptiveSnackBarType.info,
      );
      return;
    }

    // Flatten all items from all products
    List<Map<String, dynamic>> allItems = [];
    for (final product in _products) {
      // Find the category name for this product
      final category = _categories.firstWhere(
        (cat) => cat.id == product.categoryId,
        orElse: () => ProductCategory(
          id: '',
          name: 'بدون فئة',
          businessType: '',
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      allItems.add({
        'id': product.id,
        'name': product.name,
        'categoryName': category.name,
        'price': product.price,
      });
    }

    if (allItems.isEmpty) {
      showAdaptiveSnackBar(
        context: context,
        message: AppLocalizations.of(context)!.noItemsFound,
        type: AdaptiveSnackBarType.info,
      );
      return;
    }

    _showArabicOfferDialog(
      context: context,
      builder: (context) {
        String? tempSelected = selectedItemId;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Text(
                      tempSelected != null
                          ? AppLocalizations.of(context)!.itemSelected
                          : AppLocalizations.of(context)!.noItemSelected,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allItems.length,
                        itemBuilder: (context, index) {
                          final item = allItems[index];
                          return ListTile(
                            dense: true,
                            leading: Radio<String>(
                              value: item['id'],
                              groupValue: tempSelected,
                              onChanged: (String? value) {
                                setDialogState(() {
                                  tempSelected = value;
                                });
                              },
                            ),
                            title: Text(item['name']),
                            subtitle: Text(AppLocalizations.of(context)!
                                .categoryAndPrice(
                                    item['categoryName'],
                                    AppLocalizations.of(context)!.kwd,
                                    item['price'].toStringAsFixed(2))),
                            onTap: () {
                              setDialogState(() {
                                tempSelected = item['id'];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () {
                    onItemSelected(tempSelected);
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00c1e8),
                  ),
                  child: Text(AppLocalizations.of(context)!.ok),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderSection(AppLocalizations loc) {
    final activeCount =
        _discounts.where((d) => d.status == DiscountStatus.active).length;
    final scheduledCount =
        _discounts.where((d) => d.status == DiscountStatus.scheduled).length;
    final expiredCount =
        _discounts.where((d) => d.status == DiscountStatus.expired).length;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: GoldenRatio.spacing12,
        vertical: GoldenRatio.spacing8,
      ),
      padding: EdgeInsets.all(GoldenRatio.spacing12),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
        border: Border.all(
          color: WhizzColors.grey200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Filter chips
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _isLoading ? null : _showCreateDiscountDialog,
              icon: const Icon(Icons.add_rounded),
              label: Text('إنشاء خصم'),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: loc.allDiscounts,
                  count: _discounts.length,
                  isSelected: _selectedFilter == 'all',
                  onTap: () => setState(() => _selectedFilter = 'all'),
                ),
                SizedBox(width: AppSpacing.sm),
                _buildFilterChip(
                  label: loc.activeDiscounts,
                  count: activeCount,
                  isSelected: _selectedFilter == 'active',
                  onTap: () => setState(() => _selectedFilter = 'active'),
                ),
                SizedBox(width: AppSpacing.sm),
                _buildFilterChip(
                  label: loc.scheduledDiscounts,
                  count: scheduledCount,
                  isSelected: _selectedFilter == 'scheduled',
                  onTap: () => setState(() => _selectedFilter = 'scheduled'),
                ),
                SizedBox(width: AppSpacing.sm),
                _buildFilterChip(
                  label: loc.expiredDiscounts,
                  count: expiredCount,
                  isSelected: _selectedFilter == 'expired',
                  onTap: () => setState(() => _selectedFilter = 'expired'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                color: isSelected ? WhizzColors.black : WhizzColors.grey800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
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
                  count.toString(),
                  style: AppTypography.labelSmall.copyWith(
                    color:
                        isSelected ? WhizzColors.primary : WhizzColors.grey700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Top-level widget for individual discount cards
class DiscountCard extends StatelessWidget {
  final Discount discount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const DiscountCard({
    super.key,
    required this.discount,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(discount);
    final statusText = getStatusText(context, discount);

    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with secondary color accent
            Container(
              padding: EdgeInsets.all(4.8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(GoldenRatio.radiusLg),
                  topRight: Radius.circular(GoldenRatio.radiusLg),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge only
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.8,
                      vertical: 2.4,
                    ),
                    decoration: BoxDecoration(
                      color: WhizzColors.white,
                      borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 2.4,
                          height: 2.4,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 2.4),
                        Text(
                          statusText,
                          style: TypographySystem.labelSmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 4.8),
                  // Title and discount type section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Title without container - inherits header background (no borders)
                        Text(
                          discount.title,
                          style: TypographySystem.titleLarge.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                        SizedBox(height: 2.4),
                        // Discount value badge (no background, no border, right aligned)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9.6,
                            vertical: 4.8,
                          ),
                          child: Text(
                            discount.type == DiscountType.percentage
                                ? '${_formatDiscountValue(discount.value)}% ${AppLocalizations.of(context)!.off}'
                                : discount.type == DiscountType.freeDelivery
                                    ? AppLocalizations.of(context)!.freeDelivery
                                    : '${AppLocalizations.of(context)!.conditional} ${AppLocalizations.of(context)!.discount}',
                            style: TypographySystem.bodyLarge.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (discount.description.isNotEmpty) ...[
                          SizedBox(height: 2.4),
                          Text(
                            discount.description,
                            style: TypographySystem.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.7),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // White content area with discount details
            Padding(
              padding: EdgeInsets.all(GoldenRatio.spacing12),
              child: Column(
                children: [
                  // Details grid
                  DiscountFundingNotice(
                      delivery: discount.type == DiscountType.freeDelivery),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          context,
                          icon: Icons.category_outlined,
                          label:
                              getLocalizedApplicabilityText(context, discount),
                        ),
                      ),
                      SizedBox(width: GoldenRatio.spacing12),
                      if ((discount.minimumOrderAmount ?? 0) > 0)
                        Expanded(
                          child: _buildDetailItem(
                            context,
                            icon: Icons.shopping_cart_outlined,
                            label:
                                'الحد الأدنى: ${_formatDiscountValue(discount.minimumOrderAmount ?? 0)} د.ع',
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: GoldenRatio.spacing8),

                  // Date range
                  _buildDetailItem(
                    context,
                    icon: Icons.date_range_outlined,
                    label:
                        '${discount.validFrom.day}/${discount.validFrom.month}/${discount.validFrom.year} - ${discount.validTo.day}/${discount.validTo.month}/${discount.validTo.year}',
                  ),

                  SizedBox(height: GoldenRatio.spacing12),

                  if (discount.sharingLocked)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                            'خصم مشترك معتمد — الشروط مقفلة. لتغييرها أوقفه وأنشئ بديلًا.')),
                  Text(
                      'لكل زبون: ${discount.perCustomerLimit?.toString() ?? "بلا حد"} • إجمالي استخدامات العرض: ${discount.maxUsage?.toString() ?? "بلا حد"}'),
                  // Explicit actions for approved shared campaigns.
                  if (discount.sharingLocked)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (discount.status == DiscountStatus.active ||
                          discount.sharingCanActivate)
                        TextButton.icon(
                            onPressed: onToggleStatus,
                            icon: Icon(discount.status == DiscountStatus.active
                                ? Icons.pause
                                : Icons.play_arrow),
                            label: Text(discount.status == DiscountStatus.active
                                ? 'إيقاف الخصم'
                                : 'تشغيل الخصم')),
                      OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.copy_outlined),
                          label: Text(discount.status == DiscountStatus.active
                              ? 'إيقاف الخصم وإنشاء بديل'
                              : 'إنشاء خصم بديل')),
                    ]),
                  // Actions for independently funded discounts.
                  if (!discount.sharingLocked)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildActionButton(
                          icon: discount.status == DiscountStatus.inactive
                              ? Icons.play_arrow_outlined
                              : Icons.pause_outlined,
                          color: discount.status == DiscountStatus.inactive
                              ? Colors.green
                              : WhizzColors.secondary,
                          onPressed: onToggleStatus,
                        ),
                        SizedBox(width: GoldenRatio.spacing8),
                        _buildActionButton(
                          icon: discount.sharingLocked
                              ? Icons.copy_outlined
                              : Icons.edit_outlined,
                          color: WhizzColors.secondary,
                          onPressed: onEdit,
                        ),
                        SizedBox(width: GoldenRatio.spacing8),
                        _buildActionButton(
                          icon: discount.sharingLocked
                              ? Icons.stop_circle_outlined
                              : Icons.delete_outline,
                          color: WhizzColors.error,
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context,
      {required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.all(GoldenRatio.spacing8),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.radiusSm),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: WhizzColors.secondary.withValues(alpha: 0.7),
            size: GoldenRatio.spacing16,
          ),
          SizedBox(width: GoldenRatio.spacing4),
          Expanded(
            child: Text(
              label,
              style: TypographySystem.bodySmall.copyWith(
                color: WhizzColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: GoldenRatio.spacing18),
        onPressed: onPressed,
        padding: EdgeInsets.all(GoldenRatio.spacing8),
        constraints: BoxConstraints(),
      ),
    );
  }
}

String getLocalizedApplicabilityText(BuildContext context, Discount discount) {
  final loc = AppLocalizations.of(context)!;
  switch (discount.applicability) {
    case DiscountApplicability.allItems:
      return loc.appliesToAllItems;
    case DiscountApplicability.specificItems:
      return loc.appliesToSpecificItems(discount.applicableItemIds.length);
    case DiscountApplicability.specificCategories:
      return loc.appliesToCategories(discount.applicableCategoryIds.length);
    case DiscountApplicability.minimumOrder:
      return loc.appliesToMinimumOrder;
  }
}

String getApplicabilityText(Discount discount) {
  // This function needs context for localization, so it should be moved or refactored
  switch (discount.applicability) {
    case DiscountApplicability.allItems:
      return 'Applies to all items'; // Will be replaced with localized version
    case DiscountApplicability.specificItems:
      return 'Applies to ${discount.applicableItemIds.length} specific items'; // Will be replaced
    case DiscountApplicability.specificCategories:
      return 'Applies to ${discount.applicableCategoryIds.length} categories'; // Will be replaced
    case DiscountApplicability.minimumOrder:
      return 'Applies to orders above minimum amount'; // Will be replaced
  }
}

Color getStatusColor(Discount discount) {
  switch (discount.status) {
    case DiscountStatus.active:
      return WhizzColors.success; // Yellow for active
    case DiscountStatus.scheduled:
      return WhizzColors.warning; // Amber for scheduled
    case DiscountStatus.expired:
      return WhizzColors.error; // Red for expired
    default:
      return WhizzColors.onSurfaceVariant; // Grey for inactive
  }
}

String getStatusText(BuildContext context, Discount discount) {
  switch (discount.status) {
    case DiscountStatus.active:
      return AppLocalizations.of(context)!.active;
    case DiscountStatus.scheduled:
      return AppLocalizations.of(context)!.scheduled;
    case DiscountStatus.expired:
      return AppLocalizations.of(context)!.expired;
    default:
      return '';
  }
}

String getDiscountTypeText(BuildContext context, Discount discount) {
  final loc = AppLocalizations.of(context)!;
  switch (discount.type) {
    case DiscountType.percentage:
      return loc.percentage;
    case DiscountType.fixedAmount:
      return loc.fixedAmount;
    case DiscountType.conditional:
      return loc.conditional;
    case DiscountType.buyXGetY:
      return loc.buyXGetY;
    case DiscountType.freeDelivery:
      return loc.freeDelivery;
  }
}
