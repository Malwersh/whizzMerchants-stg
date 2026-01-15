import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import '../models/product.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../services/image_upload_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/product_provider_riverpod.dart';

// Provider for loading state
final addProductLoadingProvider = StateProvider<bool>((ref) => false);

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  
  String? _selectedCategoryId;
  File? _selectedImage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Load categories when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProviderRiverpod.notifier).loadCategories('restaurant');
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Error picking image: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            _buildModernAppBar(l10n),

            // Content
            Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final productState = ref.watch(productProviderRiverpod);
                    final isLoading = ref.watch(addProductLoadingProvider);

                    return Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Section
                          _buildHeaderSection(l10n),
                          SizedBox(height: AppSpacing.xl),
                            
                            // Product Image Section
                          _buildImageSection(l10n),
                          SizedBox(height: AppSpacing.xl),

                            // Product Details Section
                          _buildProductDetailsSection(productState, l10n),
                          SizedBox(height: AppSpacing.xl),

                            // Add Product Button
                          _buildAddProductButton(isLoading, l10n),
                            
                            // Bottom spacing
                          SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
      ),
    );
  }

  Future<void> _addProduct() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImage == null) {
      showAdaptiveSnackBar(
        context: context,
        message: l10n.pleaseAddProductImage,
        type: AdaptiveSnackBarType.error,
      );
      return;
    }

    ref.read(addProductLoadingProvider.notifier).state = true;

    try {
      // First upload the image
      final uploadResult = await ImageUploadService.uploadProductImage(_selectedImage!);
      
      if (!uploadResult['success']) {
        throw Exception(uploadResult['message'] ?? l10n.imageUploadFailed);
      }
      
      final imageUrl = uploadResult['imageUrl'] as String;

      final product = Product(
        id: '', // Will be set by backend
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        categoryId: _selectedCategoryId!,
        imageUrls: [imageUrl], // Use the uploaded image URL
        isAvailable: true,
        businessId: '', // Will be set by backend based on authenticated user
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success =
          await ref.read(productProviderRiverpod.notifier).addProduct(product);

      if (success && mounted) {
        Navigator.of(context).pop();
        showAdaptiveSnackBar(
          context: context,
          message: l10n.productAddedSuccessfully,
          type: AdaptiveSnackBarType.success,
        );
      } else if (mounted) {
        final currentState = ref.read(productProviderRiverpod);
        showAdaptiveSnackBar(
          context: context,
          message: currentState.error?.message ?? 'Unknown error',
          type: AdaptiveSnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message: 'Error: ${e.toString()}',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        ref.read(addProductLoadingProvider.notifier).state = false;
      }
    }
  }

  Widget _buildModernAppBar(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        boxShadow: [
          BoxShadow(
            color: WhizzColors.grey200.withValues(alpha: 0.5),
            blurRadius: AppSpacing.sm,
            offset: Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: WhizzColors.secondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.addProduct,
                  style: AppTypography.headlineMedium.copyWith(
                    color: WhizzColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.createNewProductForMenu,
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.grey200.withValues(alpha: 0.5),
            blurRadius: AppSpacing.xxs,
            offset: Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
            ),
            child: Icon(
              Icons.add_box_rounded,
              color: WhizzColors.secondary,
              size: AppDimensions.iconSizeLG,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.productInformation,
                  style: AppTypography.titleMedium.copyWith(
                    color: WhizzColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.addDetailsImagePricing,
                  style: AppTypography.bodyMedium.copyWith(
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: WhizzColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.grey200.withValues(alpha: 0.5),
            blurRadius: AppSpacing.xxs,
            offset: Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_rounded,
                color: WhizzColors.secondary,
                size: AppDimensions.iconSizeMD,
              ),
              SizedBox(width: AppSpacing.xxs),
              Text(
                l10n.productImage,
                style: AppTypography.bodyLarge.copyWith(
                  color: WhizzColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          if (_selectedImage != null) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusMD),
                border: Border.all(
                  color: WhizzColors.border,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusMD),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.edit_rounded,
                        size: AppDimensions.iconSizeSM),
                    label: Text(l10n.changeImage),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WhizzColors.secondary,
                      side: BorderSide(color: WhizzColors.secondary),
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeImage,
                    icon:
                        Icon(Icons.delete_rounded,
                        size: AppDimensions.iconSizeSM),
                    label: Text(l10n.remove),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WhizzColors.error,
                      side: BorderSide(color: WhizzColors.error),
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: WhizzColors.backgroundVariant,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusMD),
                  border: Border.all(
                    color: WhizzColors.border,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color:
                            WhizzColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_rounded,
                        color: WhizzColors.secondary,
                        size: AppDimensions.iconSizeXL,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.tapToAddProductImage,
                      style: AppTypography.bodyMedium.copyWith(
                        color: WhizzColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.imageFormat,
                      style: AppTypography.bodySmall.copyWith(
                        color: WhizzColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductDetailsSection(
      dynamic productState, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: WhizzColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        border: Border.all(
          color: WhizzColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.grey200.withValues(alpha: 0.5),
            blurRadius: AppSpacing.xxs,
            offset: Offset(0, AppSpacing.xs),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_rounded,
                color: WhizzColors.secondary,
                size: AppDimensions.iconSizeMD,
              ),
              SizedBox(width: AppSpacing.xxs),
              Text(
                l10n.productDetails,
                style: AppTypography.bodyLarge.copyWith(
                  color: WhizzColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          // Product Name
          _buildFormField(
            controller: _nameController,
            label: l10n.productName,
            hint: l10n.enterProductName,
            icon: Icons.shopping_bag_rounded,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.pleaseEnterProductName;
              }
              return null;
            },
          ),
          SizedBox(height: AppSpacing.lg),

          // Description
          _buildFormField(
            controller: _descriptionController,
            label: l10n.description,
            hint: l10n.enterProductDescription,
            icon: Icons.description_rounded,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.pleaseEnterProductDescription;
              }
              return null;
            },
          ),
          SizedBox(height: AppSpacing.lg),

          // Category
          _buildCategoryDropdown(productState, l10n),
          SizedBox(height: AppSpacing.lg),

          // Price
          _buildFormField(
            controller: _priceController,
            label: l10n.price,
            hint: l10n.enterPrice,
            icon: Icons.attach_money_rounded,
            keyboardType: TextInputType.number,
            prefixText: '\$',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.pleaseEnterPrice;
              }
              final price = double.tryParse(value);
              if (price == null || price <= 0) {
                return l10n.pleaseEnterValidPrice;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.xxs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTypography.bodyLarge.copyWith(
            color: WhizzColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixIcon: Icon(icon, color: WhizzColors.secondary),
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: WhizzColors.textSecondary,
            ),
            filled: true,
            fillColor: WhizzColors.backgroundVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide: BorderSide(color: WhizzColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide: BorderSide(color: WhizzColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide:
                  BorderSide(color: WhizzColors.secondary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide: BorderSide(color: WhizzColors.error),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(dynamic productState, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.category,
          style: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.xxs),
        DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          style: AppTypography.bodyLarge.copyWith(
            color: WhizzColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: l10n.selectCategory,
            prefixIcon: Icon(Icons.category_rounded,
                color: WhizzColors.secondary),
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: WhizzColors.textSecondary,
            ),
            filled: true,
            fillColor: WhizzColors.backgroundVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide: BorderSide(color: WhizzColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide: BorderSide(color: WhizzColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide:
                  BorderSide(color: WhizzColors.secondary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMD),
              borderSide: BorderSide(color: WhizzColors.error),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
          items: () {
            // Remove duplicate categories based on ID
            final Map<String, ProductCategory> uniqueCategories = {};
            for (final category in productState.categories) {
              uniqueCategories[category.id] = category;
            }
            return uniqueCategories.values.map((category) {
              return DropdownMenuItem<String>(
                value: category.id,
                child: Text(category.name),
              );
            }).toList();
          }(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.pleaseSelectCategory;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAddProductButton(bool isLoading, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      height: 56.0,
      decoration: BoxDecoration(
        color: WhizzColors.black,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
        boxShadow: WhizzColors.elevation(3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLG),
          onTap: isLoading ? null : _addProduct,
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? AdaptiveLoadingIndicator(
                    color: WhizzColors.white,
                    size: AppDimensions.iconSizeMD,
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: WhizzColors.white,
                        size: AppDimensions.iconSizeMD,
                      ),
                      SizedBox(width: AppSpacing.xxs),
                      Text(
                        l10n.addProduct,
                        style: AppTypography.bodyLarge.copyWith(
                          color: WhizzColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
