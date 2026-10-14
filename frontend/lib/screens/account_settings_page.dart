import 'wallet_transfer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/business.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/image_upload_service.dart';
import '../providers/business_provider.dart';
import '../providers/session_provider.dart';
import 'login_page.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../utils/responsive_helper.dart';

class AccountSettingsPage extends ConsumerStatefulWidget {
  final Business business;

  const AccountSettingsPage({super.key, required this.business});

  @override
  ConsumerState<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  late TextEditingController _businessNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  late TextEditingController _websiteController;
  late TextEditingController _phoneController;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty text - will be populated after loading user data
    _businessNameController = TextEditingController();
    _ownerNameController = TextEditingController();
    _addressController = TextEditingController();
    _descriptionController = TextEditingController();
    _websiteController = TextEditingController();
    _phoneController = TextEditingController();

    _validateAuthenticationAndInitialize();
  }

  Future<void> _validateAuthenticationAndInitialize() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      _showAuthenticationRequiredDialog();
      return;
    }

    // Load user data after authentication is verified
    _loadUserData();
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(AppLocalizations.of(context)!.chooseFromGallery),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: Text(AppLocalizations.of(context)!.takePhoto),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImageFromCamera();
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.errorPickingImage,
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        await _uploadBusinessPhoto();
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.errorSelectingImage(e.toString()),
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        await _uploadBusinessPhoto();
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.errorTakingPhoto(e.toString()),
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _uploadBusinessPhoto() async {
    if (_image == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await ImageUploadService.uploadBusinessPhoto(_image!);

      if (result['success']) {
        final newImageUrl = result['imageUrl'];

        // Persist the new photo URL on the business profile
        final business = ref.read(businessProvider).value ?? widget.business;
        await ApiService().updateBusinessPhoto(business.id, newImageUrl);

        // Update the business object with the new photo URL
        setState(() {
          widget.business.businessPhotoUrl = newImageUrl;
          _isSaving = false;
        });

        // Keep the cached session business data in sync: businessProvider is
        // cache-first, so without this the refreshed provider would serve the
        // stale photo URL
        final session = ref.read(sessionProvider);
        if (session.businessData != null) {
          final updatedData = Map<String, dynamic>.from(session.businessData!)
            ..['businessPhotoUrl'] = newImageUrl;
          await ref
              .read(sessionProvider.notifier)
              .setSessionWithBusinessData(business.id, updatedData);
        }

        // Refresh providers so the new photo loads from the backend
        ref.invalidate(businessProvider);
        ref.invalidate(enhancedBusinessProvider);

        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          showAdaptiveSnackBar(
            context: context,
            message: loc.businessPhotoUpdatedSuccessfully,
            type: AdaptiveSnackBarType.success,
            duration: const Duration(seconds: 2),
          );
        }
      } else {
        setState(() {
          _isSaving = false;
          _image = null; // Clear the selected image on failure
        });

        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          showAdaptiveSnackBar(
            context: context,
            message: loc.failedToUploadPhoto(result['message'].toString()),
            type: AdaptiveSnackBarType.error,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _image = null; // Clear the selected image on error
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.errorUploadingPhoto(e.toString()),
          type: AdaptiveSnackBarType.error,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  // Add save business profile method
  Future<void> _saveBusinessProfile() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final session = ref.read(sessionProvider);
      if (!session.isAuthenticated) {
        _showAuthenticationRequiredDialog();
        return;
      }

      final businessAsyncValue = ref.read(businessProvider);
      final business = businessAsyncValue.value;

      if (business == null) {
        final loc = AppLocalizations.of(context)!;
        throw Exception(loc.noBusinessFound);
      }

      final apiService = ApiService();

      // Prepare update data
      final updateData = {
        'businessName': _businessNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'website': _websiteController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      // Update business profile via API
      await apiService.updateBusinessProfile(business.id, updateData);

      // Update the business object locally
      business.updateProfile(
        name: _businessNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        website: _websiteController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      // Refresh business provider to reflect changes
      ref.invalidate(businessProvider);

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.businessProfileUpdatedSuccessfully,
          type: AdaptiveSnackBarType.success,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.failedToUpdateProfile(e.toString()),
          type: AdaptiveSnackBarType.error,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  // Cancel edit mode
  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });

    // Reset controllers to original values
    final businessAsyncValue = ref.read(businessProvider);
    final business = businessAsyncValue.value;
    if (business != null) {
      _businessNameController.text = business.name;
      _ownerNameController.text = business.ownerName ?? '';
      _addressController.text = _formatAddress(business.address);
      _descriptionController.text = business.description ?? '';
      _websiteController.text = business.website ?? '';
      _phoneController.text = business.phone ?? '';
    }
  }

  void _showAuthenticationRequiredDialog() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(
          Icons.security,
          color: Color(0xFF00C1E8),
          size: 48,
        ),
        title: Text(
          loc.userNotLoggedIn,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF001133),
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          loc.pleaseSignInToAccessAccountSettings,
          style: TextStyle(
            color: const Color(0xFF001133).withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          IconButton(
              tooltip: 'محفظة المطعم',
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      WalletTransferScreen(businessId: widget.business.id)))),
          TextButton(
            onPressed: () => _navigateToLogin(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF00C1E8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(loc.signIn),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  Future<void> _loadUserData() async {
    // This method is now simplified since we use ref.watch(businessProvider) in build()
    // Just ensure the session is valid
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      _showAuthenticationRequiredDialog();
    }
  }

  String _formatAddress(dynamic address) {
    if (address == null) return '';
    // Plain string address
    if (address is String) return address;
    // DynamoDB atomic string
    if (address is Map<String, dynamic> && address.containsKey('S')) {
      return address['S']?.toString() ?? '';
    }
    // DynamoDB attribute map wrapper
    if (address is Map<String, dynamic> && address.containsKey('M')) {
      return _formatAddress(address['M']);
    }
    // Now address should be a map of components
    final Map<String, dynamic> addrMap =
        Map<String, dynamic>.from(address as Map);
    String extract(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      if (v is Map<String, dynamic> && v.containsKey('S')) {
        return v['S']?.toString() ?? '';
      }
      if (v is Map<String, dynamic> && v.containsKey('M')) {
        final m = Map<String, dynamic>.from(v['M'] as Map);
        if (m.containsKey('S')) return m['S']?.toString() ?? '';
        // Fallback: join nested values
        return m.values
            .map((e) => extract(e))
            .where((s) => s.isNotEmpty)
            .join(' ');
      }
      return v.toString();
    }

    final components = <String>[
      extract(addrMap['home_address']),
      extract(addrMap['street']),
      extract(addrMap['neighborhood']),
      extract(addrMap['district']),
      extract(addrMap['city']),
      extract(addrMap['country']),
    ].where((c) => c.isNotEmpty).toList();
    return components.join(', ');
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final businessAsyncValue = ref.watch(businessProvider);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: WhizzColors.grey50,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Material 3 App Bar with subtle secondary color accent
            _buildModernAppBar(context, l10n),

            // Content - Wide White Area with Responsive Constraints
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        isDesktop ? 1200 : (isTablet ? 900 : double.infinity),
                  ),
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 16,
                      8,
                      isMobile ? 12 : 16,
                      12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: WhizzColors.secondary.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                          ResponsiveHelper.getResponsivePadding(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Content
                          Consumer(
                            builder: (context, ref, child) {
                              // Watch both providers: enhanced for richer data, regular as fallback
                              final enhancedBusinessAsync =
                                  ref.watch(enhancedBusinessProvider);
                              final businessAsyncValue =
                                  ref.watch(businessProvider);

                              return enhancedBusinessAsync.when(
                                data: (enhancedBusiness) {
                                  // Use enhanced business data if available
                                  final business = enhancedBusiness ??
                                      businessAsyncValue.value;
                                  if (business == null) {
                                    return _buildErrorStateWithMessage(
                                        l10n,
                                        theme,
                                        l10n.noBusinessFoundForThisAccount);
                                  }

                                  // Update controllers with fresh business data
                                  if (_businessNameController.text !=
                                      business.name) {
                                    _businessNameController.text =
                                        business.name;
                                  }
                                  if (_ownerNameController.text !=
                                      (business.ownerName ?? '')) {
                                    _ownerNameController.text =
                                        business.ownerName ?? '';
                                  }
                                  if (_addressController.text !=
                                      _formatAddress(business.address)) {
                                    _addressController.text =
                                        _formatAddress(business.address);
                                  }
                                  if (_descriptionController.text !=
                                      (business.description ?? '')) {
                                    _descriptionController.text =
                                        business.description ?? '';
                                  }
                                  if (_websiteController.text !=
                                      (business.website ?? '')) {
                                    _websiteController.text =
                                        business.website ?? '';
                                  }
                                  if (_phoneController.text !=
                                      (business.phone ?? '')) {
                                    _phoneController.text =
                                        business.phone ?? '';
                                  }

                                  return _buildAccountContentWithBusiness(
                                      l10n, theme, business);
                                },
                                loading: () => _buildLoadingState(),
                                error: (error, stack) =>
                                    _buildErrorStateWithMessage(l10n, theme,
                                        'Error loading account: $error'),
                              );
                            },
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
      floatingActionButton: businessAsyncValue.maybeWhen(
        data: (business) => business != null
            ? FloatingActionButton(
                onPressed: _pickImage,
                backgroundColor: WhizzColors.primary,
                elevation: 8,
                child: Icon(Icons.camera_alt, color: WhizzColors.secondary),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  // Modern Material 3 App Bar with subtle secondary accent
  Widget _buildModernAppBar(BuildContext context, AppLocalizations loc) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 20,
        12,
        isMobile ? 16 : 20,
        isMobile ? 16 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          AdaptiveBackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.accountSettings,
                  style: TextStyle(
                    fontSize:
                        ResponsiveHelper.getResponsiveFontSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Edit/Save actions
          if (!_isEditing)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: WhizzColors.textSecondary.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.edit, color: WhizzColors.textSecondary),
                onPressed: _toggleEditMode,
              ),
            ),
          if (_isEditing) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: WhizzColors.textSecondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: WhizzColors.textSecondary),
                onPressed: _cancelEdit,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: WhizzColors.textSecondary.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isSaving
                    ? AdaptiveLoadingIndicator(
                        color: WhizzColors.textSecondary,
                        size: 20,
                      )
                    : Icon(Icons.check, color: WhizzColors.textSecondary),
                onPressed: _isSaving ? null : _saveBusinessProfile,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: WhizzColors.grey100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: AdaptiveLoadingIndicator(
              color: WhizzColors.secondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            loc.loadingAccountInformation,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStateWithMessage(
      AppLocalizations l10n, ThemeData theme, String message) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.errorLoadingAccount,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: WhizzColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(businessProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhizzColors.primary,
                  foregroundColor: WhizzColors.secondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountContentWithBusiness(
      AppLocalizations l10n, ThemeData theme, Business business) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account Overview Card with fresh business data
        _buildAccountOverviewCardWithBusiness(l10n, theme, business),

        const SizedBox(height: 20),

        // Personal Information Section
        _buildSectionHeader(l10n.personalInformation, Icons.person_rounded),
        const SizedBox(height: 12),
        _buildPersonalInfoCardWithBusiness(l10n, theme, business),

        const SizedBox(height: 20),

        // Business Information Section
        _buildSectionHeader(l10n.businessInformation, Icons.business_rounded),
        const SizedBox(height: 12),
        _buildBusinessInfoCardWithBusiness(l10n, theme, business),

        const SizedBox(height: 20),

        // Account Status Section
        _buildSectionHeader(l10n.accountStatus, Icons.verified_user_rounded),
        const SizedBox(height: 12),
        _buildAccountStatusCardWithBusiness(l10n, theme, business),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                WhizzColors.secondary,
                WhizzColors.secondary.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: WhizzColors.secondary.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: WhizzColors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: WhizzColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                height: 1.5,
                width: 30,
                decoration: BoxDecoration(
                  color: WhizzColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountOverviewCardWithBusiness(
      AppLocalizations l10n, ThemeData theme, Business business) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WhizzColors.textSecondary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.textSecondary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildCircularBusinessPhoto(business.businessPhotoUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: WhizzColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            WhizzColors.secondary,
                            WhizzColors.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: WhizzColors.secondary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        business.businessType.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: WhizzColors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(Icons.email, business.email),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                    Icons.phone, business.phone ?? l10n.notProvided),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: WhizzColors.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: WhizzColors.secondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WhizzColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCardWithBusiness(
      AppLocalizations l10n, ThemeData theme, Business business) {
    if (_isEditing) {
      return _buildModernCard([
        _buildEditableField(
          l10n.ownerName,
          _ownerNameController,
          Icons.person,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1,
          color: WhizzColors.secondary.withValues(alpha: 0.2),
        ),
        _buildInfoRow(l10n.emailAddress, business.email, Icons.email),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1,
          color: WhizzColors.secondary.withValues(alpha: 0.2),
        ),
        _buildEditableField(
          l10n.phoneNumber,
          _phoneController,
          Icons.phone,
        ),
      ]);
    }

    return _buildModernCard([
      _buildInfoRow(
          l10n.ownerName, business.ownerName ?? l10n.notProvided, Icons.person),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 1,
        color: WhizzColors.secondary.withValues(alpha: 0.2),
      ),
      _buildInfoRow(l10n.emailAddress, business.email, Icons.email),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 1,
        color: WhizzColors.secondary.withValues(alpha: 0.2),
      ),
      _buildInfoRow(
          l10n.phoneNumber, business.phone ?? l10n.notProvided, Icons.phone),
    ]);
  }

  Widget _buildBusinessInfoCardWithBusiness(
      AppLocalizations l10n, ThemeData theme, Business business) {
    if (_isEditing) {
      return _buildModernCard([
        _buildEditableField(
          l10n.businessName,
          _businessNameController,
          Icons.business,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1,
          color: WhizzColors.secondary.withValues(alpha: 0.2),
        ),
        _buildInfoRow(
            l10n.businessType, business.businessType.name, Icons.category),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1,
          color: WhizzColors.secondary.withValues(alpha: 0.2),
        ),
        _buildEditableField(
          l10n.description,
          _descriptionController,
          Icons.description,
          maxLines: 3,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1,
          color: WhizzColors.secondary.withValues(alpha: 0.2),
        ),
        _buildEditableField(
          l10n.website,
          _websiteController,
          Icons.language,
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1,
          color: WhizzColors.secondary.withValues(alpha: 0.2),
        ),
        _buildEditableField(
          l10n.addressLabel,
          _addressController,
          Icons.location_on,
          maxLines: 3,
        ),
      ]);
    }

    return _buildModernCard([
      _buildInfoRow(l10n.businessName, business.name, Icons.business),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 1,
        color: WhizzColors.secondary.withValues(alpha: 0.2),
      ),
      _buildInfoRow(
          l10n.businessType, business.businessType.name, Icons.category),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 1,
        color: WhizzColors.secondary.withValues(alpha: 0.2),
      ),
      _buildInfoRow(l10n.description, business.description ?? l10n.notProvided,
          Icons.description,
          isMultiline: true),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 1,
        color: WhizzColors.secondary.withValues(alpha: 0.2),
      ),
      _buildInfoRow(
          l10n.website, business.website ?? l10n.notProvided, Icons.language),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 1,
        color: WhizzColors.secondary.withValues(alpha: 0.2),
      ),
      _buildInfoRow(
          l10n.addressLabel,
          _formatAddress(business.address).isEmpty
              ? l10n.notProvided
              : _formatAddress(business.address),
          Icons.location_on,
          isMultiline: true),
    ]);
  }

  Widget _buildAccountStatusCardWithBusiness(
      AppLocalizations l10n, ThemeData theme, Business business) {
    return _buildModernCard([
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusIndicator(
            l10n.active,
            business.status == 'approved',
            Icons.check_circle,
            business.status == 'approved' ? Colors.green : Colors.orange,
          ),
          _buildStatusIndicator(
            l10n.verified,
            business.status == 'approved',
            Icons.verified,
            business.status == 'approved'
                ? const Color(0xFF007fff)
                : Colors.grey,
          ),
        ],
      ),
    ]); // End of previous method
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {bool isMultiline = false}) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: WhizzColors.secondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: WhizzColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : loc.notProvided,
                  style: TextStyle(
                    color: Colors.grey[900],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build circular business photo widget for header
  Widget _buildCircularBusinessPhoto(String? businessPhotoUrl) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: WhizzColors.secondary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: businessPhotoUrl != null && businessPhotoUrl.isNotEmpty
            ? Image.network(
                businessPhotoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to default icon if image fails to load
                  return _buildCircularDefaultIcon();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: AdaptiveLoadingIndicator(
                      color: WhizzColors.secondary,
                      size: 20,
                    ),
                  );
                },
              )
            : _buildCircularDefaultIcon(),
      ),
    );
  }

  // Build circular default business icon for header
  Widget _buildCircularDefaultIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: WhizzColors.secondary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.business,
        size: 30,
        color: WhizzColors.secondary,
      ),
    );
  }

  Widget _buildModernCard(List<Widget> children) {
    return Card(
      elevation: 8,
      shadowColor: WhizzColors.secondary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: WhizzColors.secondary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
      String label, bool isActive, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? color : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
      String label, TextEditingController controller, IconData icon,
      {int? maxLines}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WhizzColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: WhizzColors.secondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: WhizzColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                AdaptiveTextField(
                  controller: controller,
                  maxLines: maxLines ?? 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
