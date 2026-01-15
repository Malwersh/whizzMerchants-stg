import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../l10n/app_localizations.dart'; // added localization import
import '../models/product.dart';
import '../providers/product_provider_riverpod.dart';
import '../widgets/image_picker_widget.dart';
import '../services/image_upload_service.dart';
import '../services/product_service.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final Product product;

  const EditProductScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  
  String? _selectedCategoryId;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isAvailable = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController =
        TextEditingController(text: widget.product.description);
    _priceController =
        TextEditingController(text: widget.product.price.toString());
    _selectedCategoryId = widget.product.categoryId;
    // Initialize with first image if available
    if (widget.product.imageUrls.isNotEmpty) {
      // Note: This won't work for editing existing images, but sets up structure
    }
    _isAvailable = widget.product.isAvailable;
  }

  Future<void> _pickImage() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      // Handle error silently or with user feedback
    } finally {
      setState(() {
        _isUploading = false;
      });
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

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      height: kToolbarHeight + MediaQuery.of(context).padding.top,
      decoration: BoxDecoration(
        color: WhizzColors.white,
        boxShadow: WhizzColors.elevation(2),
      ),
      child: SafeArea(
        child: Row(
          children: [
            AdaptiveBackButton(
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Edit Product',
                    style: AppTypography.headlineSmall.copyWith(
                      color: WhizzColors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Update product information',
                    style: AppTypography.bodySmall.copyWith(
                      color: WhizzColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.only(right: AppSpacing.xs),
              child: TextButton.icon(
                onPressed: _deleteProduct,
                icon: Icon(Icons.delete_outline,
                    color: WhizzColors.error, size: 20),
                label: Text(
                  'Delete',
                  style: AppTypography.labelMedium.copyWith(
                    color: WhizzColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                    side: BorderSide(color: WhizzColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int? maxLines,
    Widget? prefixIcon,
    String? prefixText,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        style: AppTypography.bodyLarge.copyWith(
          color: WhizzColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon,
          prefixText: prefixText,
          labelStyle: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.textSecondary,
          ),
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.textSecondary.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            borderSide: BorderSide(
              color: WhizzColors.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            borderSide: BorderSide(
              color: WhizzColors.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            borderSide: BorderSide(
              color: WhizzColors.secondary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProviderRiverpod);
    
    // Load categories if they haven't been loaded yet
    if (productState.categories.isEmpty && !productState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(productProviderRiverpod.notifier).loadCategories('restaurant');
      });
    }
    
    return Scaffold(
      backgroundColor: WhizzColors.backgroundPrimary,
      body: Column(
          children: [
            _buildModernAppBar(context),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Header Section
                    Container(
                      margin: EdgeInsets.only(bottom: AppSpacing.xl),
                      padding: EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                      color: WhizzColors.white,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.md),
                      boxShadow: WhizzColors.elevation(1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: AppSpacing.xxl,
                            height: AppSpacing.xxl,
                            decoration: BoxDecoration(
                            color: WhizzColors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Product Information',
                                  style: AppTypography.titleMedium.copyWith(
                                  color: WhizzColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Update your product details and settings',
                                  style: AppTypography.bodyMedium.copyWith(
                                  color: WhizzColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Product Images Section
                    Container(
                      margin: EdgeInsets.only(bottom: AppSpacing.xl),
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(
                        color: WhizzColors.secondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product Images',
                            style: AppTypography.titleMedium.copyWith(
                            color: WhizzColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          ImagePickerWidget(
                            selectedImage: _selectedImage,
                            isUploading: _isUploading,
                            onPickImage: _pickImage,
                            onRemoveImage: _removeImage,
                          ),
                        ],
                      ),
                    ),

                    // Product Name
                    _buildModernTextField(
                      controller: _nameController,
                      labelText: 'Product Name',
                      hintText: 'Enter product name',
                      prefixIcon: Icon(
                        Icons.inventory_2_outlined,
                      color: WhizzColors.secondary,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter product name';
                        }
                        return null;
                      },
                    ),

                    // Description
                    _buildModernTextField(
                      controller: _descriptionController,
                      labelText: 'Description',
                      hintText: 'Enter product description',
                      maxLines: 3,
                      prefixIcon: Icon(
                        Icons.description_outlined,
                      color: WhizzColors.secondary,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter product description';
                        }
                        return null;
                      },
                    ),

                    // Category Dropdown
                    Container(
                      margin: EdgeInsets.only(bottom: AppSpacing.md),
                      child: DropdownButtonFormField<String>(
                      value: () {
                          // Ensure the selected value exists in the available categories
                          final Map<String, ProductCategory> uniqueCategories =
                              {};
                          for (final category in productState.categories) {
                            uniqueCategories[category.id] = category;
                          }

                          // Only return the selected category if it exists in the available categories
                          if (_selectedCategoryId != null &&
                              uniqueCategories
                                  .containsKey(_selectedCategoryId)) {
                            return _selectedCategoryId;
                          }

                          // If categories are loaded but selected category doesn't exist, return null
                          if (uniqueCategories.isNotEmpty) {
                            return null;
                          }

                          // If no categories loaded yet, return null
                          return null;
                        }(),
                        style: AppTypography.bodyLarge.copyWith(
                        color: WhizzColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                          color: WhizzColors.secondary,
                          ),
                          labelStyle: AppTypography.bodyMedium.copyWith(
                          color: WhizzColors.textSecondary,
                          ),
                          filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.8),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.sm),
                            borderSide: BorderSide(
                            color: WhizzColors.secondary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.sm),
                            borderSide: BorderSide(
                            color: WhizzColors.secondary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.sm),
                            borderSide: BorderSide(
                            color: WhizzColors.secondary,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                        items: () {
                          // Remove duplicate categories based on ID
                          final Map<String, ProductCategory> uniqueCategories =
                              {};
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
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                    ),

                    // Price
                    _buildModernTextField(
                      controller: _priceController,
                      labelText: 'Price',
                      hintText: 'Enter price',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icon(
                        Icons.attach_money,
                      color: WhizzColors.secondary,
                      ),
                      prefixText: '\$',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),

                    // Availability Toggle
                    Container(
                      margin: EdgeInsets.only(bottom: AppSpacing.xl),
                      decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(
                        color: WhizzColors.secondary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          'Product Available',
                          style: AppTypography.bodyLarge.copyWith(
                          color: WhizzColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _isAvailable
                              ? 'Product is visible to customers'
                              : 'Product is hidden from customers',
                          style: AppTypography.bodyMedium.copyWith(
                          color: WhizzColors.textSecondary,
                          ),
                        ),
                        value: _isAvailable,
                      activeColor: WhizzColors.secondary,
                        onChanged: (value) {
                          setState(() {
                            _isAvailable = value;
                          });
                        },
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                    ),

                    // Update Product Button
                    Container(
                      width: double.infinity,
                      height: GoldenRatio.xxl,
                      decoration: BoxDecoration(
                      color:
                          _isLoading ? WhizzColors.grey400 : WhizzColors.black,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.sm),
                      boxShadow: _isLoading ? null : WhizzColors.elevation(2),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _updateProduct,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.sm),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isLoading
                              ? AdaptiveLoadingIndicator(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 24,
                                  )
                                : Text(
                                    'Update Product',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = widget.product.imageUrls.isNotEmpty
          ? widget.product.imageUrls.first
          : null;
      
      // If new image selected, upload it first
      if (_selectedImage != null) {
        setState(() {
          _isUploading = true;
        });
        
        // Import and use ImageUploadService
        final uploadResult =
            await ImageUploadService.uploadProductImage(_selectedImage!);

        setState(() {
          _isUploading = false;
        });

        if (uploadResult['success']) {
          imageUrl = uploadResult['imageUrl'];
        } else {
          if (mounted) {
            showAdaptiveSnackBar(
              context: context,
              message: 'Image upload failed: ${uploadResult['message']}',
              type: AdaptiveSnackBarType.error,
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Update product with new data
      final result = await ProductService.updateProduct(
        productId: widget.product.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        categoryId: _selectedCategoryId!,
        imageUrl: imageUrl,
        isAvailable: _isAvailable,
      );

      if (result['success'] && mounted) {
        // Refresh products list
        await ref.read(productProviderRiverpod.notifier).loadProducts();

        Navigator.of(context).pop();
        showAdaptiveSnackBar(
          context: context,
          message: 'Product updated successfully!',
          type: AdaptiveSnackBarType.success,
        );
      } else if (mounted) {
        showAdaptiveSnackBar(
          context: context,
          message:
              'Failed to update product: ${result['message'] ?? 'Unknown error'}',
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
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        title: Row(
          children: [
            Container(
              width: GoldenRatio.lg,
              height: GoldenRatio.lg,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 24,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Delete Product',
              style: AppTypography.titleMedium.copyWith(
                color: WhizzColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this product? This action cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: WhizzColors.textSecondary,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
            ),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WhizzColors.error,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
            ),
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref
          .read(productProviderRiverpod.notifier)
          .deleteProduct(widget.product.id);

      if (success && mounted) {
        Navigator.of(context).pop();
        showAdaptiveSnackBar(
          context: context,
          message: 'Product deleted successfully!',
          type: AdaptiveSnackBarType.success,
        );
      } else if (mounted) {
        final error = ref.read(productProviderRiverpod).error;
        final localizedMessage = () {
          if (error?.isAuth == true) {
            return AppLocalizations.of(
                  context,
                )?.sessionExpiredPleaseLoginAgain ??
                'Session expired. Please login again.';
          }
          return 'Failed to delete product: ${error?.message ?? 'Unknown error'}';
        }();
        showAdaptiveSnackBar(
          context: context,
          message: localizedMessage,
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
