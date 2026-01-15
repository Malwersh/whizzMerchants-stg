import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whizz_merchants/l10n/app_localizations.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../widgets/language_switcher.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/registration_form_screen.dart';
import '../screens/dashboards/business_dashboard.dart';
import '../services/app_auth_service.dart';
import '../providers/business_provider.dart';
import '../utils/responsive_helper.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loc = AppLocalizations.of(context)!;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await AppAuthService.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (result.success) {
          final business = await ref.read(businessProvider.future);
          if (mounted) {
            if (business != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessDashboard(),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.noBusinessFound),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    // Note: AdaptiveTextField doesn't support validator directly
    // Wrap in a Form field for validation
    return AdaptiveTextField(
      controller: controller,
      label: labelText,
      prefixIcon: Icon(prefixIcon, color: WhizzColors.grey600),
      keyboardType: keyboardType,
      obscureText: obscureText,
      suffixIcon: suffixIcon,
      inputFormatters: inputFormatters,
    );
  }

  PreferredSizeWidget _buildModernAppBar(
      BuildContext context, AppLocalizations loc) {
    return AdaptiveAppBar(
      title: Text(
        loc.login,
        style: AppTypography.headlineSmall.copyWith(
          color: WhizzColors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: WhizzColors.white,
      leading: Navigator.of(context).canPop()
          ? AdaptiveBackButton(
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
    );
  }

  Widget _buildLoginCard(
      BuildContext context, AppLocalizations loc, bool isTabletOrDesktop) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
              // Email Field
              _buildModernTextField(
                controller: _emailController,
                labelText: loc.email,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9@._-]'),
                  ),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterYourEmail;
                  }
                  return null;
                },
              ),
              SizedBox(height: AppSpacing.md),

              // Password Field
              _buildModernTextField(
                controller: _passwordController,
                labelText: loc.password,
                prefixIcon: Icons.lock_outlined,
                obscureText: !_isPasswordVisible,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9!@#$%^&*()_+=\-\[\]{}|;:,.<>?/~`]'),
                  ),
                ],
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: WhizzColors.black,
                    size: AppDimensions.iconSizeMD,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return loc.pleaseEnterYourPassword;
                  }
                  return null;
                },
              ),
              SizedBox(height: AppSpacing.lg),

              // Login Button
              _buildLoginButton(context, loc),
              SizedBox(height: AppSpacing.md),

              // Language Switcher (as text under login button)
              Center(
                child: LanguageSwitcher(
                  showText: true,
                  isDropdown: true,
                  textColor: WhizzColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.md),

              // Forgot Password Link
              _buildForgotPasswordLink(context, loc),
              SizedBox(height: AppSpacing.md),

              // Sign Up Link
              _buildSignUpLink(context, loc),
            ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLarge,
      child: AdaptiveButton.primary(
        onPressed: _isLoading ? null : _login,
        isLoading: _isLoading,
        child: Text(
          loc.login,
          style: AppTypography.labelLarge.copyWith(
            color: WhizzColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(BuildContext context, AppLocalizations loc) {
    return AdaptiveButton.text(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ForgotPasswordScreen(),
          ),
        );
      },
      child: Text(
        loc.forgotPasswordQuestion,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
          color: WhizzColors.black,
        ),
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context, AppLocalizations loc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          loc.dontHaveAnAccount,
          style: AppTypography.bodyMedium.copyWith(
            color: WhizzColors.textSecondary,
          ),
        ),
        AdaptiveButton.text(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistrationFormScreen(),
              ),
            );
          },
          child: Text(
            loc.register,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: WhizzColors.black,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isTabletOrDesktop = ResponsiveHelper.isTablet(context) ||
        ResponsiveHelper.isDesktop(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final formWidth = isTabletOrDesktop
        ? (ResponsiveHelper.isDesktop(context) ? 400.0 : 500.0)
        : screenWidth;

    return ColoredBox(
      color: WhizzColors.white,
      child: Scaffold(
        backgroundColor: WhizzColors.white,
        appBar: _buildModernAppBar(context, loc),
        body: ColoredBox(
          color: WhizzColors.white,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                      ResponsiveHelper.getResponsivePadding(context)),
                  child: SizedBox(
                    width: formWidth,
                    child: isTabletOrDesktop
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: _buildLoginCard(
                                context, loc, isTabletOrDesktop),
                          )
                        : _buildLoginCard(context, loc, isTabletOrDesktop),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
