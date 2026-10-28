import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../models/business.dart';
import '../providers/product_provider_riverpod.dart';
import 'add_product_screen.dart';
import 'product_import_screen.dart';
import 'branch_categories_screen.dart';
import 'product_inventory_screen.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../widgets/whizz_search_bar.dart';
import '../services/product_service.dart';

class ProductsManagementScreen extends ConsumerStatefulWidget {
  final Business business;

  const ProductsManagementScreen({super.key, required this.business});

  @override
  ConsumerState<ProductsManagementScreen> createState() =>
      _ProductsManagementScreenState();
}

class _ProductsManagementScreenState
    extends ConsumerState<ProductsManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _menuBusy = false;
  Map<String, dynamic>? _activeMenu;
  List<Map<String, dynamic>> _menuVersions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProviderRiverpod.notifier).loadProducts();
      _loadMenuVersions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildPublishBar(),
            Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0B2E63)),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProductInventoryScreen(
                                businessId: widget.business.id))),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('كميات المخزون'))),
            _buildSearchSection(),
            Expanded(
              child: _buildProductContent(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Future<void> _loadMenuVersions() async {
    try {
      final result = await ProductService.getMenuVersions(widget.business.id);
      if (!mounted || result['success'] != true) return;
      setState(() {
        _activeMenu = result['active'] is Map
            ? Map<String, dynamic>.from(result['active'])
            : null;
        _menuVersions = (result['versions'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'تعذر تحميل حالة نشر القائمة. تحقق من الاتصال وأعد المحاولة.')));
    }
  }

  Future<void> _publishMenu() async {
    setState(() => _menuBusy = true);
    Map<String, dynamic> result;
    try {
      result = await ProductService.publishMenu(widget.business.id);
    } catch (_) {
      result = {
        'success': false,
        'message': 'تعذر نشر القائمة. تحقق من الاتصال وأعد المحاولة.'
      };
    }
    if (!mounted) return;
    setState(() => _menuBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true
            ? (result['active']?['unchanged'] == true
                ? 'القائمة المنشورة مطابقة لمسودة العمل'
                : 'تم نشر القائمة للعملاء بأمان')
            : '${result['message']}')));
    if (result['success'] == true) await _loadMenuVersions();
  }

  Future<void> _rollbackMenu(String version) async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('استرجاع نسخة سابقة؟'),
                    content: const Text(
                        'ستصبح هذه النسخة هي القائمة الظاهرة للعملاء فوراً.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('استرجاع'))
                    ])) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _menuBusy = true);
    final result =
        await ProductService.rollbackMenu(widget.business.id, version);
    if (!mounted) return;
    setState(() => _menuBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['success'] == true
            ? 'تم استرجاع النسخة'
            : '${result['message']}')));
    if (result['success'] == true) await _loadMenuVersions();
  }

  Widget _buildPublishBar() {
    final publishedAt = _activeMenu?['publishedAt']?.toString();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.cloud_done_outlined),
          const SizedBox(width: 10),
          Expanded(
              child: Text(publishedAt == null
                  ? 'ابدأ بنشر القائمة الحالية مرة واحدة قبل تعديل المنتجات أو استيرادها. بعدها تبقى التعديلات مسودة حتى تنشرها.'
                  : 'آخر نشر: ${publishedAt.replaceFirst('T', ' ').split('.').first}')),
          if (_menuVersions.length > 1)
            PopupMenuButton<String>(
                tooltip: 'سجل النسخ',
                icon: const Icon(Icons.history),
                onSelected: _rollbackMenu,
                itemBuilder: (_) => _menuVersions
                    .where((v) => v['status'] != 'ACTIVE')
                    .map((v) => PopupMenuItem(
                        value: v['version']?.toString(),
                        child: Text(
                            '${v['publishedAt']?.toString().replaceFirst('T', ' ').split('.').first ?? ''} · ${v['productCount'] ?? 0} منتج')))
                    .toList()),
          const SizedBox(width: 8),
          FilledButton.icon(
              onPressed: _menuBusy ? null : _publishMenu,
              icon: _menuBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.publish),
              label: const Text('نشر')),
        ]),
      ),
    );
  }

  Widget _buildSearchSection() {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
              child: WhizzSearchBar(
            controller: _searchController,
            hintText: loc.searchProducts,
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
            borderRadius: BorderRadius.circular(100),
            enableHapticFeedback: true,
          )),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'أقسام القائمة',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  BranchCategoriesScreen(businessId: widget.business.id),
            )),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'استيراد Excel أو CSV',
            icon: const Icon(Icons.upload_file),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductImportScreen(
                businessId: widget.business.id,
                onCompleted: () =>
                    ref.read(productProviderRiverpod.notifier).loadProducts(),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildProductContent() {
    return Consumer(
      builder: (context, ref, child) {
        final productState = ref.watch(productProviderRiverpod);

        if (productState.isLoading && productState.products.isEmpty) {
          return _buildLoadingState();
        }

        if (productState.error != null && productState.products.isEmpty) {
          return _buildErrorState(productState.error!);
        }

        final filteredProducts = productState.products.where((product) {
          return product.name.toLowerCase().contains(_searchQuery) ||
              product.description.toLowerCase().contains(_searchQuery);
        }).toList();

        if (filteredProducts.isEmpty) {
          return _buildEmptyState();
        }

        return _buildProductList(filteredProducts);
      },
    );
  }

  Widget _buildLoadingState() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Container(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: WhizzColors.secondary.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusXL),
              ),
              child: AdaptiveLoadingIndicator(
                color: WhizzColors.secondary,
                size: 40,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              loc.loadingProducts,
              style: AppTypography.bodyLarge.copyWith(
                color: WhizzColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ProductError error) {
    final loc = AppLocalizations.of(context)!;

    final isSessionExpired = error.isAuth;

    // Show snackbar for session expiry (don't clear session here, provider handles it)
    if (isSessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.sessionExpiredPleaseLoginAgain),
              backgroundColor: WhizzColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }

    String displayMessage = error.message;
    if (error.isAuth) {
      displayMessage = loc.sessionExpiredPleaseLoginAgain;
    } else if (error.isNetwork) {
      displayMessage = '${loc.oopsSomethingWentWrong}';
    } else if (error.isServer) {
      displayMessage = error.message;
    }

    return SingleChildScrollView(
        child: Center(
      child: Container(
        margin: EdgeInsets.all(AppSpacing.lg),
        padding: EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: WhizzColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          border: Border.all(
            color: WhizzColors.error.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: WhizzColors.error.withValues(alpha: 0.05),
              blurRadius: AppSpacing.lg,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: WhizzColors.error.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusMD),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: AppDimensions.iconSizeXXL,
                color: WhizzColors.error,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              loc.oopsSomethingWentWrong,
              style: AppTypography.headlineSmall.copyWith(
                color: WhizzColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              displayMessage,
              style: AppTypography.bodyMedium.copyWith(
                color: WhizzColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(productProviderRiverpod.notifier).loadProducts();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WhizzColors.black,
                foregroundColor: WhizzColors.white,
                minimumSize: Size(200, 56),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusSM),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(
                loc.tryAgain,
                style: AppTypography.labelLarge
                    .copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: EdgeInsets.all(GoldenRatio.lg),
          padding: EdgeInsets.all(GoldenRatio.xl),
          decoration: BoxDecoration(
            color: WhizzColors.white,
            borderRadius: BorderRadius.circular(GoldenRatio.xl),
            border: Border.all(
              color: WhizzColors.border,
              width: 1,
            ),
            boxShadow: WhizzColors.elevation(1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(GoldenRatio.lg),
                decoration: BoxDecoration(
                  color: WhizzColors.grey100,
                  borderRadius: BorderRadius.circular(GoldenRatio.lg),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: GoldenRatio.xxxl,
                  color: WhizzColors.black,
                ),
              ),
              SizedBox(height: GoldenRatio.lg),
              Text(
                _searchQuery.isEmpty
                    ? loc.yourProductCatalogAwaits
                    : loc.noProductsFound,
                style: TypographySystem.headlineSmall.copyWith(
                  color: WhizzColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: GoldenRatio.sm),
              Text(
                _searchQuery.isEmpty
                    ? loc.startBuildingYourMenu(
                        widget.business.businessType.name)
                    : loc.tryAdjustingYourSearchTerms,
                style: TypographySystem.bodyMedium.copyWith(
                  color: WhizzColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isEmpty) ...[
                SizedBox(height: GoldenRatio.lg),
                // Benefits section
                _buildBenefitCards(),
                SizedBox(height: GoldenRatio.xl),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddProductScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WhizzColors.primary,
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                    padding: EdgeInsets.symmetric(
                      horizontal: GoldenRatio.xl,
                      vertical: GoldenRatio.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GoldenRatio.md),
                    ),
                    elevation: 2,
                  ),
                  icon: Container(
                    padding: EdgeInsets.all(GoldenRatio.xs),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(GoldenRatio.xs),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: AppDimensions.iconSizeXL,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  label: Text(
                    loc.addYourFirstProduct,
                    style: TypographySystem.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitCards() {
    final loc = AppLocalizations.of(context)!;
    final benefits = [
      {
        'icon': Icons.visibility_rounded,
        'title': loc.showcaseMenu,
        'description': loc.displayYourOfferingsBeautifully,
      },
      {
        'icon': Icons.inventory_2_rounded,
        'title': loc.manageInventory,
        'description': loc.controlAvailabilityInRealTime,
      },
      {
        'icon': Icons.trending_up_rounded,
        'title': loc.trackPerformance,
        'description': loc.monitorSalesAndPopularity,
      },
    ];

    return Row(
      children: benefits.map((benefit) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: GoldenRatio.xs),
            padding: EdgeInsets.all(GoldenRatio.md),
            decoration: BoxDecoration(
              color: WhizzColors.white,
              borderRadius: BorderRadius.circular(GoldenRatio.md),
              boxShadow: WhizzColors.elevation(2),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(GoldenRatio.sm),
                  decoration: BoxDecoration(
                    color: WhizzColors.grey100,
                    borderRadius: BorderRadius.circular(GoldenRatio.sm),
                  ),
                  child: Icon(
                    benefit['icon'] as IconData,
                    color: WhizzColors.black,
                    size: GoldenRatio.lg,
                  ),
                ),
                SizedBox(height: GoldenRatio.sm),
                Text(
                  benefit['title'] as String,
                  style: TypographySystem.bodyMedium.copyWith(
                    color: WhizzColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: GoldenRatio.xs),
                Text(
                  benefit['description'] as String,
                  style: TypographySystem.bodySmall.copyWith(
                    color: WhizzColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductList(List<Product> products) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: GoldenRatio.lg),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildModernProductCard(product);
      },
    );
  }

  Widget _buildModernProductCard(Product product) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Container(
      margin: EdgeInsets.only(bottom: GoldenRatio.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.lg),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(GoldenRatio.lg),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(GoldenRatio.md),
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: (product.images.isNotEmpty || product.imageUrl != null)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(GoldenRatio.md - 1),
                        child: Image.network(
                          product.images.isNotEmpty
                              ? product.images.first
                              : product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported_rounded,
                              color: theme.colorScheme.primary,
                              size: GoldenRatio.xl,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.restaurant_menu_rounded,
                        color: theme.colorScheme.secondary,
                        size: GoldenRatio.xl,
                      ),
              ),
              SizedBox(width: GoldenRatio.md),
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TypographySystem.titleMedium.copyWith(
                        color: WhizzColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: GoldenRatio.xs),
                    Text(
                      product.description,
                      style: TypographySystem.bodyMedium.copyWith(
                        color: WhizzColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: GoldenRatio.sm),
                    Row(
                      children: [
                        // Price Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: GoldenRatio.sm,
                            vertical: GoldenRatio.xs,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(GoldenRatio.sm),
                          ),
                          child: Text(
                            'IQD ${product.price.toStringAsFixed(0)}',
                            style: TypographySystem.bodyMedium.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: GoldenRatio.sm),
                        // Availability Status
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: GoldenRatio.sm,
                            vertical: GoldenRatio.xs,
                          ),
                          decoration: BoxDecoration(
                            color: product.isAvailable
                                ? theme.colorScheme.secondary
                                    .withValues(alpha: 0.1)
                                : theme.colorScheme.error
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(GoldenRatio.sm),
                            border: Border.all(
                              color: product.isAvailable
                                  ? theme.colorScheme.secondary
                                      .withValues(alpha: 0.3)
                                  : theme.colorScheme.error
                                      .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                product.isAvailable
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: product.isAvailable
                                    ? theme.colorScheme.secondary
                                    : theme.colorScheme.error,
                                size: AppDimensions.iconSizeSM,
                              ),
                              SizedBox(width: GoldenRatio.xs),
                              Text(
                                product.isAvailable
                                    ? loc.available
                                    : loc.unavailable,
                                style: TypographySystem.bodySmall.copyWith(
                                  color: product.isAvailable
                                      ? theme.colorScheme.secondary
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Menu
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(GoldenRatio.sm),
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.secondary,
                    size: GoldenRatio.lg,
                  ),
                  surfaceTintColor: Colors.white,
                  color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GoldenRatio.md),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
                        _showEditProductDrawer(context, product);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(product, ref);
                        break;
                      case 'toggle_availability':
                        final success = await ref
                            .read(productProviderRiverpod.notifier)
                            .updateProduct(
                              product.copyWith(
                                isAvailable: !product.isAvailable,
                              ),
                            );
                        if (!success && mounted) {
                          showAdaptiveSnackBar(
                              context: this.context,
                              message: ref
                                      .read(productProviderRiverpod)
                                      .error
                                      ?.message ??
                                  loc.unknownError,
                              type: AdaptiveSnackBarType.error);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(
                          Icons.edit_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          loc.edit,
                          style: TypographySystem.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_availability',
                      child: ListTile(
                        leading: Icon(
                          product.isAvailable
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: theme.colorScheme.secondary,
                        ),
                        title: Text(
                          product.isAvailable
                              ? loc.makeUnavailable
                              : loc.makeAvailable,
                          style: TypographySystem.bodyMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_rounded,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          loc.delete,
                          style: TypographySystem.bodyMedium.copyWith(
                            color: WhizzColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernFAB() {
    return FloatingActionButton(
      backgroundColor: WhizzColors.primary,
      foregroundColor: Theme.of(context).colorScheme.secondary,
      elevation: 4,
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AddProductScreen(),
          ),
        );
      },
      child: Icon(
        Icons.add_rounded,
        size: GoldenRatio.lg * 2,
      ),
    );
  }

  void _showEditProductDrawer(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProductDrawer(product: product),
    );
  }

  void _showDeleteConfirmation(Product product, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xFF00C1E8).withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        icon: Container(
          padding: EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_rounded,
            color: Colors.red,
            size: AppDimensions.iconSizeXL,
          ),
        ),
        title: Text(
          loc.deleteProduct,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
        ),
        content: Text(
          loc.areYouSureYouWantToDeleteProduct(product.name),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(loc.cancel),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final success = await ref
                    .read(productProviderRiverpod.notifier)
                    .deleteProduct(product.id);
                if (success && mounted) {
                  showAdaptiveSnackBar(
                    context: context,
                    message: loc.productDeletedSuccessfully,
                    type: AdaptiveSnackBarType.success,
                  );
                } else if (mounted) {
                  final error =
                      ref.read(productProviderRiverpod).error?.message ??
                          loc.unknownError;
                  showAdaptiveSnackBar(
                    context: context,
                    message: loc.failedToDeleteProduct(error),
                    type: AdaptiveSnackBarType.error,
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(loc.delete),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceEvenly,
      ),
    );
  }
}

class _EditProductDrawer extends ConsumerStatefulWidget {
  final Product product;

  const _EditProductDrawer({required this.product});

  @override
  ConsumerState<_EditProductDrawer> createState() => _EditProductDrawerState();
}

class _EditProductDrawerState extends ConsumerState<_EditProductDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController =
        TextEditingController(text: widget.product.description);
    _priceController =
        TextEditingController(text: widget.product.price.toString());
    _selectedCategoryId = widget.product.categoryId;
    _isAvailable = widget.product.isAvailable;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(productProviderRiverpod).categories.isEmpty) {
        ref.read(productProviderRiverpod.notifier).loadCategories('restaurant');
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    final loc = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      showAdaptiveSnackBar(
        context: context,
        message: loc.pleaseSelectCategory,
        type: AdaptiveSnackBarType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedProduct = widget.product.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        categoryId: _selectedCategoryId,
        isAvailable: _isAvailable,
      );

      final success = await ref
          .read(productProviderRiverpod.notifier)
          .updateProduct(updatedProduct);

      if (success && mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: loc.productUpdatedSuccessfully,
          type: AdaptiveSnackBarType.success,
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        final error = ref.read(productProviderRiverpod).error?.message ??
            loc.unknownError;
        showAdaptiveSnackBar(
          context: context,
          message: loc.failedToUpdateProduct(error),
          type: AdaptiveSnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.errorOccurred}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final productState = ref.watch(productProviderRiverpod);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: WhizzColors.backgroundPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: GoldenRatio.spacing16, vertical: 8),
              child: Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(GoldenRatio.spacing16),
                  children: [
                    // Name field
                    _buildTextField(
                      controller: _nameController,
                      labelText: loc.productName,
                      hintText: loc.enterProductName,
                      prefixIcon: Icons.shopping_bag_rounded,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterProductName;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: GoldenRatio.spacing16),
                    // Description field
                    _buildTextField(
                      controller: _descriptionController,
                      labelText: loc.description,
                      hintText: loc.enterProductDescription,
                      prefixIcon: Icons.description_rounded,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterProductDescription;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: GoldenRatio.spacing16),
                    // Price field
                    _buildTextField(
                      controller: _priceController,
                      labelText: loc.priceLabel,
                      hintText: '0.00',
                      prefixIcon: Icons.attach_money_rounded,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return loc.pleaseEnterPrice;
                        }
                        if (double.tryParse(value) == null) {
                          return loc.pleaseEnterValidPrice;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: GoldenRatio.spacing16),
                    // Category dropdown
                    _buildCategoryDropdown(productState),
                    SizedBox(height: GoldenRatio.spacing16),
                    // Availability toggle
                    _buildAvailabilityToggle(theme),
                    SizedBox(height: GoldenRatio.spacing24),
                    // Save button
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      style:
          TypographySystem.bodyLarge.copyWith(color: WhizzColors.textPrimary),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: WhizzColors.secondary),
        labelStyle: TypographySystem.bodyMedium
            .copyWith(color: WhizzColors.textSecondary),
        hintStyle: TypographySystem.bodyMedium
            .copyWith(color: WhizzColors.textSecondary.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          borderSide: BorderSide(
              color: WhizzColors.secondary.withValues(alpha: 0.3), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          borderSide: BorderSide(
              color: WhizzColors.secondary.withValues(alpha: 0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          borderSide: BorderSide(color: WhizzColors.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          borderSide: BorderSide(color: WhizzColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          borderSide: BorderSide(color: WhizzColors.error, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: GoldenRatio.spacing16,
          vertical: GoldenRatio.spacing16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildCategoryDropdown(dynamic productState) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
        border: Border.all(
            color: WhizzColors.secondary.withValues(alpha: 0.3), width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: GoldenRatio.spacing16),
      child: DropdownButtonFormField<String>(
        value: productState.categories.any((c) => c.id == _selectedCategoryId)
            ? _selectedCategoryId
            : null,
        decoration: InputDecoration(
          labelText: loc.category,
          border: InputBorder.none,
          prefixIcon:
              Icon(Icons.category_rounded, color: WhizzColors.secondary),
        ),
        items:
            productState.categories.map<DropdownMenuItem<String>>((category) {
          return DropdownMenuItem<String>(
            value: category.id,
            child: Text(category.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCategoryId = value;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return loc.pleaseSelectCategory;
          }
          return null;
        },
      ),
    );
  }

  Widget _buildAvailabilityToggle(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
        border: Border.all(
            color: WhizzColors.secondary.withValues(alpha: 0.3), width: 1),
      ),
      padding: EdgeInsets.all(GoldenRatio.spacing16),
      child: Row(
        children: [
          Icon(Icons.store_rounded, color: WhizzColors.secondary),
          SizedBox(width: GoldenRatio.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toggle Availability',
                  style: TypographySystem.bodyLarge.copyWith(
                    color: WhizzColors.textPrimary,
                  ),
                ),
                Text(
                  'Toggle Availability',
                  style: TypographySystem.bodySmall.copyWith(
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (value) {
              setState(() {
                _isAvailable = value;
              });
            },
            activeColor: WhizzColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final loc = AppLocalizations.of(context)!;
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: WhizzColors.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? AdaptiveLoadingIndicator(
                color: Colors.white,
                size: 24,
              )
            : Text(
                loc.saveChanges,
                style: TypographySystem.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
