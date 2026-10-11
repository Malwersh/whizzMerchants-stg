import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';

import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../widgets/wizz_business_button.dart';
import '../widgets/address_autofill_field.dart';
import '../services/app_auth_service.dart';
import '../services/image_upload_service.dart';
import '../services/document_upload_service.dart';
import '../services/region_service.dart';
import '../services/address_autofill_service.dart';
import '../models/business.dart';
import '../models/region.dart';
import '../screens/dashboards/business_dashboard.dart';
import '../screens/auth/auth_screen.dart';

class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  ConsumerState<RegistrationFormScreen> createState() =>
      _RegistrationFormScreenState();
}

class _RegistrationFormScreenState
    extends ConsumerState<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // User Information Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Business Information Controllers
  final _businessNameController = TextEditingController();
  final _businessStreetController = TextEditingController();
  final _businessAddressAutofillController = TextEditingController();
  final _businessAddressNotesController =
      TextEditingController(); // Additional notes field
  final _businessCountryController = TextEditingController();

  // Region Selection (replaces city/district text fields)
  Region? _selectedDistrict;
  Region? _selectedNeighborhood;
  String? _selectedRegionId;

  // Mapbox Address Autofill
  AddressComponents? _selectedAddress;

  // Verification
  final _verificationController = TextEditingController();

  // State Variables
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _selectedBusinessType = 'restaurant';
  int _currentPageIndex = 0;
  bool _agreedToTerms = false;

  // Document Files - Optional
  File? _licenseFile;
  File? _identityFile;
  File? _healthCertificateFile;
  File? _ownerPhotoFile;
  File? _businessPhotoFile;

  // Image picker instance
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _businessCountryController.text = 'Iraq';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessStreetController.dispose();
    _businessAddressAutofillController.dispose();
    _businessAddressNotesController.dispose();
    _businessCountryController.dispose();
    _verificationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: WhizzColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            _buildModernAppBar(context, loc),

            // Progress Indicator
            _buildModernProgressIndicator(),

            // Form Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPageIndex = index;
                  });
                },
                children: [
                  _buildUserInfoPage(loc),
                  _buildBusinessInfoPage(loc),
                  _buildDocumentsPage(loc),
                  _buildVerificationPage(loc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context, AppLocalizations loc) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: GoldenRatio.spacing16,
        vertical: GoldenRatio.spacing12,
      ),
      decoration: BoxDecoration(
        color: WhizzColors.white, // 60% white
        border: Border(
          bottom: BorderSide(
            color: WhizzColors.secondary.withOpacity(
              0.1,
            ), // 30% secondary (blue)
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_ios,
              color: WhizzColors.secondary,
            ), // 30% secondary
            padding: EdgeInsets.zero,
          ),
          SizedBox(width: GoldenRatio.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.registerYourBusiness,
                  style: TypographySystem.headlineSmall.copyWith(
                    color: WhizzColors.secondary, // 30% secondary (blue)
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  loc.stepXOfY(_currentPageIndex + 1, 4),
                  style: TypographySystem.bodyMedium.copyWith(
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WhizzColors.primary.withOpacity(
                0.1,
              ), // 10% primary (yellow) accent
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.business,
              color: WhizzColors.primary, // 10% primary highlight
              size: GoldenRatio.lg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(GoldenRatio.spacing16),
      margin: EdgeInsets.symmetric(horizontal: GoldenRatio.spacing16),
      decoration: BoxDecoration(
        color: WhizzColors.white, // 60% white
        borderRadius: BorderRadius.circular(GoldenRatio.spacing12),
        border: Border.all(
          color: WhizzColors.secondary.withOpacity(0.1), // 30% secondary
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentPageIndex;
          final isCompleted = index < _currentPageIndex;

          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: GoldenRatio.spacing4),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: isActive
                            ? WhizzColors
                                  .primary // 10% primary (yellow)
                            : WhizzColors.grey200,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  if (index < 3)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 24,
                      height: 24,
                      margin: EdgeInsets.symmetric(
                        horizontal: GoldenRatio.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted || isActive
                            ? WhizzColors
                                  .primary // 10% primary (yellow)
                            : WhizzColors.grey200,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: WhizzColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isCompleted
                          ? Icon(
                              Icons.check,
                              size: AppDimensions.iconSizeSM,
                              color: WhizzColors.secondary,
                            ) // 30% secondary
                          : Center(
                              child: Text(
                                '${index + 1}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: isActive
                                      ? WhizzColors
                                            .secondary // 30% secondary
                                      : WhizzColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUserInfoPage(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // First Name & Last Name Row
            Row(
              children: [
                Expanded(
                  child: _buildModernTextField(
                    controller: _firstNameController,
                    labelText: loc.firstName,
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.pleaseEnterFirstName;
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildModernTextField(
                    controller: _lastNameController,
                    labelText: loc.lastName,
                    prefixIcon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return loc.pleaseEnterLastName;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),

            // Phone Number (used for sign-in; a code is sent via SMS)
            _buildModernTextField(
              controller: _phoneController,
              labelText: loc.phoneNumber,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return loc.pleaseEnterPhoneNumber;
                }
                if (AppAuthService.normalizeIraqiPhone(value) == null) {
                  return loc.invalidIraqiPhone;
                }
                return null;
              },
            ),
            SizedBox(height: AppSpacing.md),

            // Email (optional contact)
            _buildModernTextField(
              controller: _emailController,
              labelText: loc.enterYourEmail,
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null; // optional for phone-based accounts
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value.trim())) {
                  return loc.pleaseEnterValidEmail;
                }
                return null;
              },
            ),
            SizedBox(height: AppSpacing.xl),

            // Next Button
            WizzBusinessButton(
              text: loc.next,
              isLoading: false,
              onPressed: () {
                if (_formKey.currentState?.validate() == true) {
                  _nextPage();
                }
              },
            ),
            SizedBox(height: AppSpacing.md),

            // Back to Login
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(loc.backToLogin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfoPage(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            loc.businessInformation,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: WhizzColors.secondary, // 30% secondary (blue)
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),

          // Business Name
          _buildModernTextField(
            controller: _businessNameController,
            labelText: loc.enterYourBusinessName,
            prefixIcon: Icons.business_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return loc.pleaseEnterBusinessName;
              }
              return null;
            },
          ),
          SizedBox(height: AppSpacing.md),

          // Business Type
          _buildBusinessTypeSelector(loc),
          SizedBox(height: AppSpacing.lg),

          // Mapbox Address Autofill Field
          AddressAutofillField(
            controller: _businessAddressAutofillController,
            labelText: loc.businessAddressLabel,
            hintText: 'ابحث عن العنوان (مثال: شارع الرشيد، بغداد)',
            onAddressSelected: (addressComponents) async {
              setState(() {
                _selectedAddress = addressComponents;
                // Update street controller with full address
                _businessStreetController.text = addressComponents.fullAddress;
              });

              // Try to auto-populate region selector from Mapbox data
              await _autoPopulateRegionFromMapbox(addressComponents);

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: WhizzColors.secondary,
                      ), // 30% secondary
                      SizedBox(width: 8),
                      Text(
                        'تم تحديد العنوان بنجاح',
                        style: TextStyle(
                          color: WhizzColors.secondary,
                        ), // 30% secondary
                      ),
                    ],
                  ),
                  backgroundColor: WhizzColors.primary, // 10% primary (yellow)
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.md),

          // Display selected address details with professional design
          if (_selectedAddress != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    WhizzColors.primary.withOpacity(
                      0.12,
                    ), // 10% primary (yellow) gradient
                    WhizzColors.white, // 60% white
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: WhizzColors.primary.withOpacity(
                    0.3,
                  ), // 10% primary border
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: WhizzColors.primary, // 10% primary (yellow)
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: WhizzColors
                              .secondary, // 30% secondary (blue) for contrast
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'العنوان المحدد',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: WhizzColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _selectedAddress!.fullAddress,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: WhizzColors
                                    .secondary, // 30% secondary (blue)
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_selectedAddress!.governorate != null ||
                      _selectedAddress!.district != null) ...[
                    SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey[300]),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        if (_selectedAddress!.governorate != null) ...[
                          Expanded(
                            child: _buildAddressDetailChip(
                              icon: Icons.location_city,
                              label: 'المحافظة',
                              value: _selectedAddress!.governorate!,
                            ),
                          ),
                        ],
                        if (_selectedAddress!.governorate != null &&
                            _selectedAddress!.district != null)
                          SizedBox(width: 8),
                        if (_selectedAddress!.district != null) ...[
                          Expanded(
                            child: _buildAddressDetailChip(
                              icon: Icons.map,
                              label: 'المنطقة',
                              value: _selectedAddress!.district!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
          ],

          // City (Read-only) - Auto-populated
          _buildReadOnlyTextField(
            labelText: 'المدينة',
            value: _selectedAddress?.city ?? 'لم يتم التحديد',
            prefixIcon: Icons.location_city_outlined,
            isEmpty: _selectedAddress?.city == null,
          ),
          SizedBox(height: AppSpacing.sm),

          // Neighborhood (Read-only) - Auto-populated
          _buildReadOnlyTextField(
            labelText: 'الحي',
            value: _selectedAddress?.neighborhood ?? 'لم يتم التحديد',
            prefixIcon: Icons.location_on_outlined,
            isEmpty: _selectedAddress?.neighborhood == null,
          ),
          SizedBox(height: AppSpacing.md),

          // Additional Address Notes (Manual Input) - Empty for customer to fill
          _buildModernTextFieldWithHint(
            controller: _businessAddressNotesController,
            labelText: 'ملاحظات إضافية على العنوان (اختياري)',
            hintText: 'مثال: بجانب مقهى الشابندر، الطابق الثاني، بناية رقم ٥',
            prefixIcon: Icons.note_outlined,
            maxLines: 3,
          ),
          SizedBox(height: AppSpacing.xl),

          // Required Business Photo
          _buildBusinessPhotoUpload(loc),
          SizedBox(height: AppSpacing.xl),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  child: Text(loc.previous),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: WizzBusinessButton(
                  text: loc.next,
                  isLoading: false,
                  onPressed: () async {
                    if (await _validateBusinessInfo()) {
                      _nextPage();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsPage(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            loc.businessDocuments,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: WhizzColors.secondary, // 30% secondary (blue)
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            loc.uploadOptionalDocumentsToVerifyBusiness,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: WhizzColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),

          // Optional Documents
          _buildDocumentUploadCard(
            title: loc.businessLicense,
            subtitle: loc.uploadBusinessLicenseDocument,
            icon: Icons.description_outlined,
            file: _licenseFile,
            onTap: () => _pickDocument('license'),
          ),
          SizedBox(height: AppSpacing.md),

          _buildDocumentUploadCard(
            title: loc.ownerIdentity,
            subtitle: loc.uploadOwnerIdentificationDocument,
            icon: Icons.badge_outlined,
            file: _identityFile,
            onTap: () => _pickDocument('identity'),
          ),
          SizedBox(height: AppSpacing.md),

          _buildDocumentUploadCard(
            title: loc.healthCertificate,
            subtitle: loc.uploadHealthCertificateIfApplicable,
            icon: Icons.health_and_safety_outlined,
            file: _healthCertificateFile,
            onTap: () => _pickDocument('health'),
          ),
          SizedBox(height: AppSpacing.md),

          _buildDocumentUploadCard(
            title: loc.ownerPhoto,
            subtitle: loc.uploadPhotoOfBusinessOwner,
            icon: Icons.person_outlined,
            file: _ownerPhotoFile,
            onTap: () => _pickDocument('owner'),
          ),
          SizedBox(height: AppSpacing.xl),

          // Terms and Conditions
          _buildTermsAndConditions(loc),
          SizedBox(height: AppSpacing.xl),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  child: Text(loc.previous),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: WizzBusinessButton(
                  text: loc.register,
                  isLoading: _isLoading,
                  onPressed: _agreedToTerms ? _register : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationPage(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Icon(
            Icons.email_outlined,
            size: AppDimensions.iconSizeXXXL,
            color: WhizzColors.primary, // 10% primary (yellow)
          ),
          SizedBox(height: AppSpacing.lg),

          Text(
            loc.checkYourEmail,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: WhizzColors.secondary, // 30% secondary (blue)
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md),

          Text(
            loc.verificationCodeSentToEmail,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: WhizzColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),

          // Verification Code Input
          _buildModernTextField(
            controller: _verificationController,
            labelText: loc.verificationCode,
            prefixIcon: Icons.security_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return loc.pleaseEnterVerificationCode;
              }
              if (value.trim().length != 6) {
                return loc.verificationCodeMustBeSixDigits;
              }
              return null;
            },
          ),
          SizedBox(height: AppSpacing.lg),

          // Verify Button
          WizzBusinessButton(
            text: loc.verifyAndComplete,
            isLoading: _isLoading,
            onPressed: _verifyRegistration,
          ),
          SizedBox(height: AppSpacing.md),

          // Resend Code
          TextButton(
            onPressed: _isLoading ? null : _resendVerificationCode,
            child: Text(loc.resendCode),
          ),
          SizedBox(height: AppSpacing.md),

          // Back to Previous Step
          TextButton(
            onPressed: _isLoading ? null : _previousPage,
            child: Text(loc.previous),
          ),
        ],
      ),
    );
  }

  // Address Detail Chip for governorate/district display
  Widget _buildAddressDetailChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: WhizzColors.white, // 60% white
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WhizzColors.primary.withOpacity(0.3), // 10% primary border
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: WhizzColors.primary, // 10% primary (yellow)
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: WhizzColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WhizzColors.secondary, // 30% secondary (blue)
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessTypeSelector(AppLocalizations loc) {
    final businessTypes = [
      {
        'value': 'restaurant',
        'label': loc.restaurant,
        'icon': Icons.restaurant,
      },
      {'value': 'cafe', 'label': loc.cafe, 'icon': Icons.local_cafe},
      {'value': 'bakery', 'label': loc.bakery, 'icon': Icons.cake},
      {
        'value': 'grocery',
        'label': loc.grocery,
        'icon': Icons.local_grocery_store,
      },
      {
        'value': 'pharmacy',
        'label': loc.pharmacy,
        'icon': Icons.local_pharmacy,
      },
      {'value': 'store', 'label': loc.store, 'icon': Icons.store},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.selectYourBusinessType,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: WhizzColors.secondary, // 30% secondary (blue)
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: businessTypes.map((type) {
            final isSelected = _selectedBusinessType == type['value'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedBusinessType = type['value'] as String;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            WhizzColors.primary, // 10% primary (yellow)
                            WhizzColors.primary.withOpacity(0.8),
                          ],
                        )
                      : null,
                  color: isSelected ? null : WhizzColors.white, // 60% white
                  border: Border.all(
                    color: isSelected
                        ? WhizzColors
                              .primary // 10% primary
                        : WhizzColors.grey200,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: WhizzColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      color: isSelected
                          ? WhizzColors
                                .secondary // 30% secondary (blue) for contrast
                          : WhizzColors.primary, // 10% primary
                      size: AppDimensions.iconSizeMD,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? WhizzColors
                                  .secondary // 30% secondary
                            : WhizzColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBusinessPhotoUpload(AppLocalizations loc) {
    return GestureDetector(
      onTap: () => _pickBusinessPhoto(),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: WhizzColors.white, // 60% white
          border: Border.all(
            color: _businessPhotoFile != null
                ? WhizzColors
                      .primary // 10% primary (yellow)
                : WhizzColors.grey200,
            width: _businessPhotoFile != null ? 2 : 1,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _businessPhotoFile != null
              ? [
                  BoxShadow(
                    color: WhizzColors.primary.withOpacity(0.2),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: _businessPhotoFile != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _businessPhotoFile!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: WhizzColors.primary, // 10% primary (yellow)
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: WhizzColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        color: WhizzColors.secondary, // 30% secondary (blue)
                        size: AppDimensions.iconSizeLG,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _businessPhotoFile = null;
                        });
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: AppDimensions.iconSizeLG,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: AppDimensions.iconSizeXXL,
                    color: WhizzColors.primary, // 10% primary (yellow)
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    loc.tapToUploadBusinessPhoto,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: WhizzColors.primary, // 10% primary
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    loc.requiredField,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.red),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: WhizzColors.white, // 60% white
          border: Border.all(
            color: file != null
                ? WhizzColors
                      .primary // 10% primary (yellow) when uploaded
                : WhizzColors.grey200,
            width: file != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: file != null
              ? [
                  BoxShadow(
                    color: WhizzColors.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: file != null
                    ? WhizzColors.primary.withOpacity(0.15) // 10% primary tint
                    : WhizzColors.grey50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: file != null
                    ? WhizzColors
                          .primary // 10% primary
                    : WhizzColors.grey400,
                size: AppDimensions.iconSizeLG,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: file != null
                          ? WhizzColors
                                .secondary // 30% secondary
                          : WhizzColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: WhizzColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (file != null)
              Container(
                padding: EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: WhizzColors.primary, // 10% primary (yellow)
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: WhizzColors
                      .secondary, // 30% secondary (blue) for contrast
                  size: AppDimensions.iconSizeSM,
                ),
              )
            else
              Icon(
                Icons.upload_outlined,
                color: WhizzColors.primary, // 10% primary
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndConditions(AppLocalizations loc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (value) {
            setState(() {
              _agreedToTerms = value ?? false;
            });
          },
          activeColor: const Color(0xFF4CAF50),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _agreedToTerms = !_agreedToTerms;
              });
            },
            child: Text.rich(
              TextSpan(
                text: loc.iAgreeToThe,
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: loc.termsAndConditions,
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: loc.and),
                  TextSpan(
                    text: loc.privacyPolicy,
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _nextPage() {
    if (_currentPageIndex < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ==================================================================
  // AUTO-POPULATE REGION FROM MAPBOX
  // ==================================================================

  /// Attempts to auto-populate region selector fields based on Mapbox address data
  Future<void> _autoPopulateRegionFromMapbox(AddressComponents address) async {
    try {
      // Get all active regions from the database
      final regionService = RegionService();
      final activeRegions = await regionService.getActiveRegions();

      // Try to match governorate (المحافظة)
      if (address.governorate != null) {
        final governorates = activeRegions
            .where((r) => r.regionType == 'PROVINCE')
            .toList();
        final matchedGovernorate = governorates.firstWhere(
          (region) =>
              region.nameAr.contains(address.governorate!) ||
              region.nameEn.toLowerCase().contains(
                address.governorate!.toLowerCase(),
              ) ||
              _normalizeArabicText(region.nameAr) ==
                  _normalizeArabicText(address.governorate!),
          orElse: () => governorates.first, // Fallback to first governorate
        );

        // Load districts for this governorate
        final districts = activeRegions
            .where(
              (r) =>
                  r.regionType == 'DISTRICT' &&
                  r.parentId == matchedGovernorate.regionId,
            )
            .toList();

        // Try to match district (المنطقة/القضاء)
        if (address.district != null && districts.isNotEmpty) {
          final matchedDistrict = districts.firstWhere(
            (region) =>
                region.nameAr.contains(address.district!) ||
                region.nameEn.toLowerCase().contains(
                  address.district!.toLowerCase(),
                ) ||
                _normalizeArabicText(region.nameAr) ==
                    _normalizeArabicText(address.district!),
            orElse: () => districts.first, // Fallback to first district
          );

          setState(() {
            _selectedDistrict = matchedDistrict;
          });

          // Load neighborhoods for this district
          final neighborhoods = activeRegions
              .where(
                (r) =>
                    r.regionType == 'NEIGHBORHOOD' &&
                    r.parentId == matchedDistrict.regionId,
              )
              .toList();

          // Try to match neighborhood (الحي)
          if (address.neighborhood != null && neighborhoods.isNotEmpty) {
            final matchedNeighborhood = neighborhoods.firstWhere(
              (region) =>
                  region.nameAr.contains(address.neighborhood!) ||
                  region.nameEn.toLowerCase().contains(
                    address.neighborhood!.toLowerCase(),
                  ) ||
                  _normalizeArabicText(region.nameAr) ==
                      _normalizeArabicText(address.neighborhood!),
              orElse: () =>
                  neighborhoods.first, // Fallback to first neighborhood
            );

            setState(() {
              _selectedNeighborhood = matchedNeighborhood;
              _selectedRegionId = matchedNeighborhood.regionId;
            });
          } else if (neighborhoods.isNotEmpty) {
            // No specific neighborhood matched, but we have the district
            setState(() {
              _selectedRegionId = matchedDistrict.regionId;
            });
          }
        } else if (districts.isNotEmpty) {
          // No district matched, but we have the governorate
          setState(() {
            _selectedRegionId = matchedGovernorate.regionId;
          });
        }

        debugPrint(
          '✅ Auto-populated region: ${matchedGovernorate.nameAr} → ${_selectedDistrict?.nameAr} → ${_selectedNeighborhood?.nameAr}',
        );

        // Show info to user about auto-population
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديد: ${matchedGovernorate.nameAr}${_selectedDistrict != null ? ' → ${_selectedDistrict!.nameAr}' : ''}${_selectedNeighborhood != null ? ' → ${_selectedNeighborhood!.nameAr}' : ''}',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to auto-populate region: $e');
      // Silently fail - user can manually select
    }
  }

  /// Normalizes Arabic text for better matching (removes diacritics, etc.)
  String _normalizeArabicText(String text) {
    return text
        .replaceAll(RegExp(r'[ًٌٍَُِّْ]'), '') // Remove Arabic diacritics
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .trim()
        .toLowerCase();
  }

  // ==================================================================
  // VALIDATION METHODS
  // ==================================================================

  Future<bool> _validateBusinessInfo() async {
    final loc = AppLocalizations.of(context)!;

    if (_businessNameController.text.trim().isEmpty) {
      _showErrorSnackBar(loc.pleaseEnterBusinessName);
      return false;
    }

    // Check if address is filled via Mapbox autofill OR manual entry
    if (_businessStreetController.text.trim().isEmpty) {
      _showErrorSnackBar(loc.pleaseEnterStreetAddress);
      return false;
    }

    // Validate region selection (can be from Mapbox autofill or manual selection)
    // If Mapbox address is selected, we have the address. If not, require manual region selection
    if (_selectedAddress == null &&
        (_selectedRegionId == null || _selectedNeighborhood == null)) {
      _showErrorSnackBar(
        '${loc.pleaseSelectNeighborhood} أو استخدم البحث التلقائي للعنوان',
      );
      return false;
    }

    // Validate region is active using RegionService (only if manual selection was used)
    if (_selectedRegionId != null) {
      final isActive = await RegionService().isRegionActive(_selectedRegionId!);
      if (!isActive) {
        _showErrorSnackBar(loc.serviceUnavailableInRegion);
        return false;
      }
    }

    if (_businessPhotoFile == null) {
      _showErrorSnackBar(loc.pleaseUploadBusinessPhoto);
      return false;
    }
    return true;
  }

  Future<void> _pickBusinessPhoto() async {
    final loc = AppLocalizations.of(context)!;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _businessPhotoFile = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('${loc.errorPickingImage}: ${e.toString()}');
    }
  }

  Future<void> _pickDocument(String type) async {
    final loc = AppLocalizations.of(context)!;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          switch (type) {
            case 'license':
              _licenseFile = File(image.path);
              break;
            case 'identity':
              _identityFile = File(image.path);
              break;
            case 'health':
              _healthCertificateFile = File(image.path);
              break;
            case 'owner':
              _ownerPhotoFile = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar(loc.errorPickingDocument(e.toString()));
    }
  }

  Future<void> _register() async {
    final loc = AppLocalizations.of(context)!;

    // Check if user agreed to terms
    if (!_agreedToTerms) {
      _showErrorSnackBar(loc.youMustAgreeToTerms);
      return;
    }

    // Validate all user info fields
    if (!_validateUserInfo()) {
      return;
    }

    // Validate business info including required business photo and region
    if (!await _validateBusinessInfo()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Check if email already exists
      final emailCheckResult = await AppAuthService.checkEmailExists(
        email: _emailController.text.trim(),
      );

      if (emailCheckResult.exists) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emailCheckResult.message),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: loc.loginInstead,
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      // Step 2: Upload documents during registration
      String? businessPhotoUrl;
      String? licenseUrl;
      String? identityUrl;
      String? healthCertificateUrl;
      String? ownerPhotoUrl;

      // Additional safety check for required business photo
      if (_businessPhotoFile == null) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(loc.businessPhotoIsRequired);
        return;
      }

      try {
        // Upload business photo (required)
        final businessPhotoUploadResult =
            await ImageUploadService.uploadBusinessPhoto(
              _businessPhotoFile!,
              isRegistration: true,
            );
        if (businessPhotoUploadResult['success'] == true) {
          businessPhotoUrl = businessPhotoUploadResult['imageUrl'];
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to upload business photo: ${businessPhotoUploadResult['message'].toString()}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Upload optional documents
        if (_licenseFile != null) {
          final licenseUploadResult =
              await DocumentUploadService.uploadBusinessLicense(
                _licenseFile!,
                isRegistration: true,
              );
          if (licenseUploadResult['success'] == true) {
            licenseUrl = licenseUploadResult['imageUrl'];
          }
        }

        if (_identityFile != null) {
          final identityUploadResult =
              await DocumentUploadService.uploadOwnerIdentity(
                _identityFile!,
                isRegistration: true,
              );
          if (identityUploadResult['success'] == true) {
            identityUrl = identityUploadResult['imageUrl'];
          }
        }

        if (_healthCertificateFile != null) {
          final healthUploadResult =
              await DocumentUploadService.uploadHealthCertificate(
                _healthCertificateFile!,
                isRegistration: true,
              );
          if (healthUploadResult['success'] == true) {
            healthCertificateUrl = healthUploadResult['imageUrl'];
          }
        }

        if (_ownerPhotoFile != null) {
          final ownerPhotoUploadResult =
              await DocumentUploadService.uploadOwnerPhoto(
                _ownerPhotoFile!,
                isRegistration: true,
              );
          if (ownerPhotoUploadResult['success'] == true) {
            ownerPhotoUrl = ownerPhotoUploadResult['imageUrl'];
          }
        }
      } catch (uploadError) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error uploading documents: ${uploadError.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final normalizedPhone =
          AppAuthService.normalizeIraqiPhone(_phoneController.text) ??
          _phoneController.text.trim();

      // Step 3: Register with business data including all document URLs and Google Places address
      final businessData = {
        'businessName': _businessNameController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'businessType': _selectedBusinessType,
        'phoneNumber': normalizedPhone,
        'address': {
          // Google Places API address components
          'city': _selectedAddress?.city,
          'neighborhood': _selectedAddress?.neighborhood,
          'governorate': _selectedAddress?.governorate,
          'district': _selectedAddress?.district,
          'country': _selectedAddress?.country ?? 'Iraq',
          'additionalNotes': _businessStreetController.text.trim(),
          'fullAddress': _selectedAddress?.fullAddress,
          // GPS coordinates from Google Places
          'coordinates': _selectedAddress != null
              ? {
                  'latitude': _selectedAddress!.latitude,
                  'longitude': _selectedAddress!.longitude,
                }
              : null,
        },
        'businessPhotoUrl': businessPhotoUrl, // Required document URL
        'licenseUrl': licenseUrl, // Optional document URL
        'identityUrl': identityUrl, // Optional document URL
        'healthCertificateUrl': healthCertificateUrl, // Optional document URL
        'ownerPhotoUrl': ownerPhotoUrl, // Optional document URL
      };

      final registerResult = await AppAuthService.registerWithBusiness(
        email: _emailController.text.trim(),
        password: '', // unused: account is phone-based and passwordless
        businessData: businessData,
      );

      setState(() => _isLoading = false);

      if (registerResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(registerResult.message),
              backgroundColor: Colors.green,
            ),
          );
          // Account is auto-confirmed; the merchant signs in with an SMS code.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(registerResult.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _verifyRegistration() async {
    final loc = AppLocalizations.of(context)!;

    if (_verificationController.text.trim().length != 6) {
      _showErrorSnackBar(loc.verificationCodeMustBeSixDigits);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final confirmResult = await AppAuthService.confirmRegistration(
        email: _emailController.text.trim(),
        confirmationCode: _verificationController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (confirmResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                confirmResult.message ?? loc.registrationCompletedSuccessfully,
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Check if we have user and business data for auto-navigation
        if (confirmResult.user != null && confirmResult.business != null) {
          // User verified successfully with business data - navigate to dashboard
          final businessData = Map<String, dynamic>.from(
            confirmResult.business as Map,
          );

          // Ensure email is included in business data
          businessData['email'] =
              businessData['email'] ??
              confirmResult.user!['email'] ??
              _emailController.text.trim();

          try {
            Business.fromJson(businessData); // Validate the data

            // Navigate to business dashboard
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessDashboard(),
                ),
              );
            }
          } catch (businessError) {
            // Fall back to login screen if business data is invalid
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
              );
            }
          }
        } else {
          // Original flow - navigate to login
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AuthScreen()),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(confirmResult.message ?? 'Verification failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resendVerificationCode() async {
    final loc = AppLocalizations.of(context)!;

    try {
      await AppAuthService.resendRegistrationCode(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.verificationCodeResent),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend code: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  bool _validateUserInfo() {
    final loc = AppLocalizations.of(context)!;

    if (_firstNameController.text.trim().isEmpty) {
      _showErrorSnackBar(loc.pleaseEnterYourFirstName);
      return false;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _showErrorSnackBar(loc.pleaseEnterYourLastName);
      return false;
    }
    // Phone-based account: phone is required, email optional, no password.
    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnackBar(loc.pleaseEnterPhoneNumber);
      return false;
    }
    if (AppAuthService.normalizeIraqiPhone(_phoneController.text) == null) {
      _showErrorSnackBar(loc.invalidIraqiPhone);
      return false;
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showErrorSnackBar(loc.pleaseEnterValidEmailAddress);
      return false;
    }
    return true;
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    bool enabled = true,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return AdaptiveTextField(
      controller: controller,
      label: labelText,
      prefixIcon: Icon(prefixIcon, color: WhizzColors.grey600),
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      suffixIcon: suffixIcon,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildModernTextFieldWithHint({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    bool enabled = true,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return AdaptiveTextField(
      controller: controller,
      label: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: WhizzColors.grey600),
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      suffixIcon: suffixIcon,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildReadOnlyTextField({
    required String labelText,
    required String value,
    required IconData prefixIcon,
    bool isEmpty = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isEmpty ? WhizzColors.grey50 : WhizzColors.white, // 60% white
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty
              ? WhizzColors.grey200
              : WhizzColors.primary, // 10% primary (yellow) when filled
          width: isEmpty ? 1 : 2,
        ),
        boxShadow: isEmpty
            ? []
            : [
                BoxShadow(
                  color: WhizzColors.primary.withOpacity(
                    0.15,
                  ), // 10% primary shadow
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isEmpty
                    ? WhizzColors.grey200
                    : WhizzColors.primary.withOpacity(0.15), // 10% primary tint
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                prefixIcon,
                color: isEmpty
                    ? WhizzColors.grey400
                    : WhizzColors.primary, // 10% primary
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: WhizzColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                      color: isEmpty
                          ? WhizzColors.grey400
                          : WhizzColors.secondary, // 30% secondary
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (!isEmpty)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: WhizzColors.primary, // 10% primary (yellow)
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: WhizzColors
                      .secondary, // 30% secondary (blue) for contrast
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
