import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WIZZ'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @createBusinessAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Business Account'**
  String get createBusinessAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get businessName;

  /// No description provided for @businessType.
  ///
  /// In en, this message translates to:
  /// **'Business Type'**
  String get businessType;

  /// No description provided for @businessPhoto.
  ///
  /// In en, this message translates to:
  /// **'Business Photo'**
  String get businessPhoto;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @neighborhood.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood'**
  String get neighborhood;

  /// No description provided for @streetName.
  ///
  /// In en, this message translates to:
  /// **'Street Name'**
  String get streetName;

  /// No description provided for @healthCertificate.
  ///
  /// In en, this message translates to:
  /// **'Health Certificate'**
  String get healthCertificate;

  /// No description provided for @additionalDocuments.
  ///
  /// In en, this message translates to:
  /// **'Additional Documents'**
  String get additionalDocuments;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @businessInformation.
  ///
  /// In en, this message translates to:
  /// **'Business Information'**
  String get businessInformation;

  /// No description provided for @businessAddress.
  ///
  /// In en, this message translates to:
  /// **'Business Address'**
  String get businessAddress;

  /// No description provided for @requiredDocuments.
  ///
  /// In en, this message translates to:
  /// **'Required Documents'**
  String get requiredDocuments;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToYourAccount;

  /// No description provided for @registerYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Register your business to get started'**
  String get registerYourBusiness;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @createBusinessAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Business Account'**
  String get createBusinessAccountButton;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @createAStrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a strong password'**
  String get createAStrongPassword;

  /// No description provided for @confirmYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmYourPassword;

  /// No description provided for @enterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourFullName;

  /// No description provided for @enterYourBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Enter your business name'**
  String get enterYourBusinessName;

  /// No description provided for @selectYourBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Select your business type'**
  String get selectYourBusinessType;

  /// No description provided for @uploadBusinessPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of your business'**
  String get uploadBusinessPhoto;

  /// No description provided for @enterYourCity.
  ///
  /// In en, this message translates to:
  /// **'Enter your city'**
  String get enterYourCity;

  /// No description provided for @enterYourNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Enter your neighborhood'**
  String get enterYourNeighborhood;

  /// No description provided for @enterYourStreetName.
  ///
  /// In en, this message translates to:
  /// **'Enter your street name'**
  String get enterYourStreetName;

  /// No description provided for @uploadHealthCertificate.
  ///
  /// In en, this message translates to:
  /// **'Upload your health certificate'**
  String get uploadHealthCertificate;

  /// No description provided for @uploadAdditionalDocuments.
  ///
  /// In en, this message translates to:
  /// **'Upload any additional business documents'**
  String get uploadAdditionalDocuments;

  /// No description provided for @confirmYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Confirm Your Account'**
  String get confirmYourAccount;

  /// No description provided for @confirmationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit confirmation code to:'**
  String get confirmationCodeSent;

  /// No description provided for @confirmationCode.
  ///
  /// In en, this message translates to:
  /// **'Confirmation Code'**
  String get confirmationCode;

  /// No description provided for @confirmationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'123456'**
  String get confirmationCodeHint;

  /// No description provided for @confirmAccount.
  ///
  /// In en, this message translates to:
  /// **'Confirm Account'**
  String get confirmAccount;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend Code in {seconds}s'**
  String resendCodeIn(Object seconds);

  /// No description provided for @backToSignUp.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign Up'**
  String get backToSignUp;

  /// No description provided for @confirmationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirmation code is required'**
  String get confirmationCodeRequired;

  /// No description provided for @confirmationCodeLength.
  ///
  /// In en, this message translates to:
  /// **'Code must be 6 digits'**
  String get confirmationCodeLength;

  /// No description provided for @confirmationCodeResent.
  ///
  /// In en, this message translates to:
  /// **'Confirmation code resent to {email}'**
  String confirmationCodeResent(Object email);

  /// No description provided for @invalidConfirmationCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid confirmation code. Please try again.'**
  String get invalidConfirmationCode;

  /// No description provided for @accountConfirmedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account confirmed successfully!'**
  String get accountConfirmedSuccess;

  /// No description provided for @enterRegisteredEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email'**
  String get enterRegisteredEmail;

  /// No description provided for @resetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get resetPasswordDescription;

  /// No description provided for @emailSentDescription.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a password reset link to your email address. Please check your inbox and follow the instructions.'**
  String get emailSentDescription;

  /// No description provided for @accountReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Your business information will be reviewed before activation.'**
  String get accountReviewNotice;

  /// No description provided for @termsAndConditionsNotice.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms of Service and Privacy Policy.'**
  String get termsAndConditionsNotice;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @dontHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAnAccount;

  /// No description provided for @joinOrderReceiver.
  ///
  /// In en, this message translates to:
  /// **'Join Order Receiver'**
  String get joinOrderReceiver;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your business account to start receiving orders'**
  String get signUpSubtitle;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account Security'**
  String get accountSecurity;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @iAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'I agree to the'**
  String get iAgreeToThe;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @takePicture.
  ///
  /// In en, this message translates to:
  /// **'Take Picture'**
  String get takePicture;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// No description provided for @verificationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Verification code is required'**
  String get verificationCodeRequired;

  /// No description provided for @verifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyYourEmail;

  /// No description provided for @pleaseEnterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// No description provided for @pleaseEnterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterYourPassword;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @failedToFetchProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch profile'**
  String get failedToFetchProfile;

  /// No description provided for @noBusinessFoundForUser.
  ///
  /// In en, this message translates to:
  /// **'No business found for user'**
  String get noBusinessFoundForUser;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @loginFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials.'**
  String get loginFailedMessage;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please check your credentials and try again.'**
  String get errorInvalidCredentials;

  /// No description provided for @sessionConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Already Signed In'**
  String get sessionConflictTitle;

  /// No description provided for @sessionConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'You are already signed in. Please choose an option below.'**
  String get sessionConflictMessage;

  /// No description provided for @continueCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'Continue with current session'**
  String get continueCurrentSession;

  /// No description provided for @signOutAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Sign out and try again'**
  String get signOutAndRetry;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmation;

  /// No description provided for @userAlreadySignedIn.
  ///
  /// In en, this message translates to:
  /// **'User is already signed in'**
  String get userAlreadySignedIn;

  /// No description provided for @userNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in'**
  String get userNotLoggedIn;

  /// No description provided for @forceSignInOption.
  ///
  /// In en, this message translates to:
  /// **'Force sign in'**
  String get forceSignInOption;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get sessionExpiredTitle;

  /// No description provided for @authenticationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication Failed'**
  String get authenticationFailedTitle;

  /// No description provided for @systemErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'System Error'**
  String get systemErrorTitle;

  /// No description provided for @tooManyAttemptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Too Many Attempts'**
  String get tooManyAttemptsTitle;

  /// No description provided for @userNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'User Not Found'**
  String get userNotFoundTitle;

  /// No description provided for @emailVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Verification Required'**
  String get emailVerificationTitle;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @discounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get discounts;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go Online'**
  String get goOnline;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Go Offline'**
  String get goOffline;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorPickingImage.
  ///
  /// In en, this message translates to:
  /// **'Error picking image'**
  String get errorPickingImage;

  /// No description provided for @errorPickingFile.
  ///
  /// In en, this message translates to:
  /// **'Error picking file'**
  String get errorPickingFile;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @businessIsNowOnline.
  ///
  /// In en, this message translates to:
  /// **'Business is now online'**
  String get businessIsNowOnline;

  /// No description provided for @businessIsNowOffline.
  ///
  /// In en, this message translates to:
  /// **'Business is now offline'**
  String get businessIsNowOffline;

  /// No description provided for @businessNowOnline.
  ///
  /// In en, this message translates to:
  /// **'Business is now online'**
  String get businessNowOnline;

  /// No description provided for @businessNowOffline.
  ///
  /// In en, this message translates to:
  /// **'Business is now offline'**
  String get businessNowOffline;

  /// No description provided for @errorUpdatingStatus.
  ///
  /// In en, this message translates to:
  /// **'Error updating status. Please try again.'**
  String get errorUpdatingStatus;

  /// No description provided for @returnOrderFeature.
  ///
  /// In en, this message translates to:
  /// **'Return order feature coming soon'**
  String get returnOrderFeature;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsTapped.
  ///
  /// In en, this message translates to:
  /// **'Notifications tapped'**
  String get notificationsTapped;

  /// No description provided for @returnAnOrder.
  ///
  /// In en, this message translates to:
  /// **'Return an Order'**
  String get returnAnOrder;

  /// No description provided for @manageDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Manage Discounts'**
  String get manageDiscounts;

  /// No description provided for @returnOrder.
  ///
  /// In en, this message translates to:
  /// **'Return Order'**
  String get returnOrder;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @posSettings.
  ///
  /// In en, this message translates to:
  /// **'POS Settings'**
  String get posSettings;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @locationSettings.
  ///
  /// In en, this message translates to:
  /// **'Location Settings'**
  String get locationSettings;

  /// No description provided for @workingHoursSettings.
  ///
  /// In en, this message translates to:
  /// **'Working Hours Settings'**
  String get workingHoursSettings;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @timeoutFirstAlert.
  ///
  /// In en, this message translates to:
  /// **'Auto-reject in {remainingTime}'**
  String timeoutFirstAlert(Object remainingTime);

  /// No description provided for @timeoutUrgentAlert.
  ///
  /// In en, this message translates to:
  /// **'URGENT: Reject in {remainingTime}'**
  String timeoutUrgentAlert(Object remainingTime);

  /// No description provided for @timeoutAutoReject.
  ///
  /// In en, this message translates to:
  /// **'Order will be auto-rejected'**
  String get timeoutAutoReject;

  /// No description provided for @openingTime.
  ///
  /// In en, this message translates to:
  /// **'Opening Time'**
  String get openingTime;

  /// No description provided for @closingTime.
  ///
  /// In en, this message translates to:
  /// **'Closing Time'**
  String get closingTime;

  /// No description provided for @setOpeningTime.
  ///
  /// In en, this message translates to:
  /// **'Set Opening Time'**
  String get setOpeningTime;

  /// No description provided for @setClosingTime.
  ///
  /// In en, this message translates to:
  /// **'Set Closing Time'**
  String get setClosingTime;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @workingHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'Working hours saved successfully'**
  String get workingHoursSaved;

  /// No description provided for @setBusinessHours.
  ///
  /// In en, this message translates to:
  /// **'Set your business hours'**
  String get setBusinessHours;

  /// No description provided for @loadingWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Loading working hours...'**
  String get loadingWorkingHours;

  /// No description provided for @quickPresets.
  ///
  /// In en, this message translates to:
  /// **'Quick Presets'**
  String get quickPresets;

  /// No description provided for @applySchedulesToAllDays.
  ///
  /// In en, this message translates to:
  /// **'Apply schedules to all days'**
  String get applySchedulesToAllDays;

  /// No description provided for @regularHours.
  ///
  /// In en, this message translates to:
  /// **'9AM-5PM'**
  String get regularHours;

  /// No description provided for @restaurantHours.
  ///
  /// In en, this message translates to:
  /// **'11AM-11PM'**
  String get restaurantHours;

  /// No description provided for @retailHours.
  ///
  /// In en, this message translates to:
  /// **'10AM-10PM'**
  String get retailHours;

  /// No description provided for @copyToAllDays.
  ///
  /// In en, this message translates to:
  /// **'Copy to all days'**
  String get copyToAllDays;

  /// No description provided for @opens.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get opens;

  /// No description provided for @closes.
  ///
  /// In en, this message translates to:
  /// **'Closes'**
  String get closes;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @saveWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Save Working Hours'**
  String get saveWorkingHours;

  /// No description provided for @appliedHoursToAllDays.
  ///
  /// In en, this message translates to:
  /// **'Applied {schedule} hours to all days'**
  String appliedHoursToAllDays(Object schedule);

  /// No description provided for @appliedDayHoursToAll.
  ///
  /// In en, this message translates to:
  /// **'Applied {dayName} hours to all days'**
  String appliedDayHoursToAll(Object dayName);

  /// No description provided for @failedToLoadWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Failed to load working hours: {error}'**
  String failedToLoadWorkingHours(Object error);

  /// No description provided for @businessManagement.
  ///
  /// In en, this message translates to:
  /// **'Business Management'**
  String get businessManagement;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @ownerName.
  ///
  /// In en, this message translates to:
  /// **'Owner Name'**
  String get ownerName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @businessAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Business Address'**
  String get businessAddressLabel;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @accountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account Status'**
  String get accountStatus;

  /// No description provided for @posSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'POS settings updated successfully'**
  String get posSettingsUpdated;

  /// No description provided for @connectionSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccessful;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @posSystemType.
  ///
  /// In en, this message translates to:
  /// **'POS System Type'**
  String get posSystemType;

  /// No description provided for @selectPosSystem.
  ///
  /// In en, this message translates to:
  /// **'Select POS System'**
  String get selectPosSystem;

  /// No description provided for @apiConfiguration.
  ///
  /// In en, this message translates to:
  /// **'API Configuration'**
  String get apiConfiguration;

  /// No description provided for @apiEndpoint.
  ///
  /// In en, this message translates to:
  /// **'API Endpoint'**
  String get apiEndpoint;

  /// No description provided for @pleaseEnterApiEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Please enter API endpoint'**
  String get pleaseEnterApiEndpoint;

  /// No description provided for @pleaseEnterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get pleaseEnterValidUrl;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @enterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Enter API Key'**
  String get enterApiKey;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @pleaseEnterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter API key'**
  String get pleaseEnterApiKey;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'Access Token'**
  String get accessToken;

  /// No description provided for @enterAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Enter Access Token'**
  String get enterAccessToken;

  /// No description provided for @locationId.
  ///
  /// In en, this message translates to:
  /// **'Location ID'**
  String get locationId;

  /// No description provided for @enterLocationId.
  ///
  /// In en, this message translates to:
  /// **'Enter Location ID'**
  String get enterLocationId;

  /// No description provided for @posIntegrationSettings.
  ///
  /// In en, this message translates to:
  /// **'POS Integration Settings'**
  String get posIntegrationSettings;

  /// No description provided for @enablePosIntegration.
  ///
  /// In en, this message translates to:
  /// **'Enable POS Integration'**
  String get enablePosIntegration;

  /// No description provided for @enablePosIntegrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync orders with your POS system'**
  String get enablePosIntegrationDescription;

  /// No description provided for @autoSendOrders.
  ///
  /// In en, this message translates to:
  /// **'Auto Send Orders'**
  String get autoSendOrders;

  /// No description provided for @autoSendOrdersDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically send new orders to POS'**
  String get autoSendOrdersDescription;

  /// No description provided for @connectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatus;

  /// No description provided for @posIntegrationEnabled.
  ///
  /// In en, this message translates to:
  /// **'POS Integration Enabled'**
  String get posIntegrationEnabled;

  /// No description provided for @posIntegrationDisabled.
  ///
  /// In en, this message translates to:
  /// **'POS Integration Disabled'**
  String get posIntegrationDisabled;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @endpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get endpoint;

  /// No description provided for @testing.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testing;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @posSyncLogs.
  ///
  /// In en, this message translates to:
  /// **'POS Sync Logs'**
  String get posSyncLogs;

  /// No description provided for @noSyncLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No sync logs found'**
  String get noSyncLogsFound;

  /// No description provided for @enablePosIntegrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable POS Integration'**
  String get enablePosIntegrationTitle;

  /// No description provided for @enablePosIntegrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with your point of sale system'**
  String get enablePosIntegrationSubtitle;

  /// No description provided for @posSystemTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'POS System Type'**
  String get posSystemTypeLabel;

  /// No description provided for @selectPosSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Select your POS system'**
  String get selectPosSystemHint;

  /// No description provided for @genericApi.
  ///
  /// In en, this message translates to:
  /// **'Generic API'**
  String get genericApi;

  /// No description provided for @squarePos.
  ///
  /// In en, this message translates to:
  /// **'Square POS'**
  String get squarePos;

  /// No description provided for @toastPos.
  ///
  /// In en, this message translates to:
  /// **'Toast POS'**
  String get toastPos;

  /// No description provided for @clover.
  ///
  /// In en, this message translates to:
  /// **'Clover'**
  String get clover;

  /// No description provided for @shopify.
  ///
  /// In en, this message translates to:
  /// **'Shopify'**
  String get shopify;

  /// No description provided for @woocommerce.
  ///
  /// In en, this message translates to:
  /// **'WooCommerce'**
  String get woocommerce;

  /// No description provided for @apiConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'API Configuration'**
  String get apiConfigurationTitle;

  /// No description provided for @apiEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'API Endpoint'**
  String get apiEndpointLabel;

  /// No description provided for @apiEndpointHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.yourpos.com/v1'**
  String get apiEndpointHint;

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKeyLabel;

  /// No description provided for @apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Your POS system API key'**
  String get apiKeyHint;

  /// No description provided for @locationIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Location ID (Optional)'**
  String get locationIdLabel;

  /// No description provided for @locationIdHint.
  ///
  /// In en, this message translates to:
  /// **'Location or store ID'**
  String get locationIdHint;

  /// No description provided for @posConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'POS Configuration'**
  String get posConfigurationTitle;

  /// No description provided for @testModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Mode'**
  String get testModeTitle;

  /// No description provided for @testModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use sandbox/test environment'**
  String get testModeSubtitle;

  /// No description provided for @autoSendOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Send Orders'**
  String get autoSendOrdersTitle;

  /// No description provided for @autoSendOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically send accepted orders to POS'**
  String get autoSendOrdersSubtitle;

  /// No description provided for @autoAcceptOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Accept Orders'**
  String get autoAcceptOrdersTitle;

  /// No description provided for @autoAcceptOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically accept all incoming orders'**
  String get autoAcceptOrdersSubtitle;

  /// No description provided for @connectionTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Timeout'**
  String get connectionTimeoutTitle;

  /// No description provided for @connectionTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{timeout} seconds'**
  String connectionTimeoutSubtitle(Object timeout);

  /// No description provided for @testConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnectionButton;

  /// No description provided for @saveSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettingsButton;

  /// No description provided for @posSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'POS settings saved successfully'**
  String get posSettingsSaved;

  /// No description provided for @failedToLoadPosSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to load POS settings'**
  String get failedToLoadPosSettings;

  /// No description provided for @failedToSavePosSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save POS settings'**
  String get failedToSavePosSettings;

  /// No description provided for @connectionTestSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Connection test successful!'**
  String get connectionTestSuccessful;

  /// No description provided for @connectionTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed'**
  String get connectionTestFailed;

  /// No description provided for @apiEndpointRequired.
  ///
  /// In en, this message translates to:
  /// **'API endpoint is required when POS is enabled'**
  String get apiEndpointRequired;

  /// No description provided for @apiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'API key is required when POS is enabled'**
  String get apiKeyRequired;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @posIntegration.
  ///
  /// In en, this message translates to:
  /// **'POS Integration'**
  String get posIntegration;

  /// No description provided for @noSyncLogsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No sync logs available'**
  String get noSyncLogsAvailable;

  /// No description provided for @syncSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get syncSettings;

  /// No description provided for @syncInterval.
  ///
  /// In en, this message translates to:
  /// **'Sync Interval'**
  String get syncInterval;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @successful.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get successful;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @syncLogDetails.
  ///
  /// In en, this message translates to:
  /// **'Sync Log Details'**
  String get syncLogDetails;

  /// No description provided for @syncTime.
  ///
  /// In en, this message translates to:
  /// **'Sync Time'**
  String get syncTime;

  /// No description provided for @posOrderId.
  ///
  /// In en, this message translates to:
  /// **'POS Order ID'**
  String get posOrderId;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error Message'**
  String get errorMessage;

  /// No description provided for @retrySync.
  ///
  /// In en, this message translates to:
  /// **'Retry Sync'**
  String get retrySync;

  /// No description provided for @orderSyncRetryInitiated.
  ///
  /// In en, this message translates to:
  /// **'Order sync retry initiated'**
  String get orderSyncRetryInitiated;

  /// No description provided for @webhookSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Webhook Setup Guide'**
  String get webhookSetupTitle;

  /// No description provided for @webhookSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow these steps to configure webhooks'**
  String get webhookSetupDescription;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @contactSupportDescription.
  ///
  /// In en, this message translates to:
  /// **'Need help with POS integration? Contact our support team'**
  String get contactSupportDescription;

  /// No description provided for @webhookConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Webhook Configuration'**
  String get webhookConfigTitle;

  /// No description provided for @webhookConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure webhook endpoints for real-time synchronization'**
  String get webhookConfigDescription;

  /// No description provided for @webhookStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Create webhook endpoint'**
  String get webhookStep1;

  /// No description provided for @webhookStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Configure authentication'**
  String get webhookStep2;

  /// No description provided for @webhookStep3.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Test connection'**
  String get webhookStep3;

  /// No description provided for @advancedConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Advanced Configuration'**
  String get advancedConfiguration;

  /// No description provided for @timeoutSeconds.
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get timeoutSeconds;

  /// No description provided for @retryAttempts.
  ///
  /// In en, this message translates to:
  /// **'Retry Attempts'**
  String get retryAttempts;

  /// No description provided for @testMode.
  ///
  /// In en, this message translates to:
  /// **'Test Mode'**
  String get testMode;

  /// No description provided for @testModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable test mode for development'**
  String get testModeDescription;

  /// No description provided for @webhooksIntegration.
  ///
  /// In en, this message translates to:
  /// **'Webhooks Integration'**
  String get webhooksIntegration;

  /// No description provided for @webhooksDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure webhooks for real-time notifications'**
  String get webhooksDescription;

  /// No description provided for @configureWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Configure Webhooks'**
  String get configureWebhooks;

  /// No description provided for @securitySettings.
  ///
  /// In en, this message translates to:
  /// **'Security Settings'**
  String get securitySettings;

  /// No description provided for @encryptionStatus.
  ///
  /// In en, this message translates to:
  /// **'Encryption Status'**
  String get encryptionStatus;

  /// No description provided for @encryptionEnabled.
  ///
  /// In en, this message translates to:
  /// **'Encryption Enabled'**
  String get encryptionEnabled;

  /// No description provided for @apiKeyRotation.
  ///
  /// In en, this message translates to:
  /// **'API Key Rotation'**
  String get apiKeyRotation;

  /// No description provided for @lastRotated.
  ///
  /// In en, this message translates to:
  /// **'Last Rotated'**
  String get lastRotated;

  /// No description provided for @rotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotate;

  /// No description provided for @systemSetupGuides.
  ///
  /// In en, this message translates to:
  /// **'System Setup Guides'**
  String get systemSetupGuides;

  /// No description provided for @setupGuide.
  ///
  /// In en, this message translates to:
  /// **'Setup Guide'**
  String get setupGuide;

  /// No description provided for @troubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get troubleshooting;

  /// No description provided for @connectionIssues.
  ///
  /// In en, this message translates to:
  /// **'Connection Issues'**
  String get connectionIssues;

  /// No description provided for @syncFailures.
  ///
  /// In en, this message translates to:
  /// **'Sync Failures'**
  String get syncFailures;

  /// No description provided for @apiErrors.
  ///
  /// In en, this message translates to:
  /// **'API Errors'**
  String get apiErrors;

  /// No description provided for @supportContact.
  ///
  /// In en, this message translates to:
  /// **'Support Contact'**
  String get supportContact;

  /// No description provided for @liveChat.
  ///
  /// In en, this message translates to:
  /// **'Live Chat'**
  String get liveChat;

  /// No description provided for @availableWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Available weekdays 9 AM - 5 PM'**
  String get availableWeekdays;

  /// No description provided for @emailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get emailSupport;

  /// No description provided for @liveChatComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Live chat coming soon'**
  String get liveChatComingSoon;

  /// No description provided for @emailSupportOpened.
  ///
  /// In en, this message translates to:
  /// **'Email support opened'**
  String get emailSupportOpened;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @syncLogs.
  ///
  /// In en, this message translates to:
  /// **'Sync Logs'**
  String get syncLogs;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @allDiscounts.
  ///
  /// In en, this message translates to:
  /// **'All Discounts'**
  String get allDiscounts;

  /// No description provided for @activeDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Active Discounts'**
  String get activeDiscounts;

  /// No description provided for @scheduledDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Discounts'**
  String get scheduledDiscounts;

  /// No description provided for @expiredDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Expired Discounts'**
  String get expiredDiscounts;

  /// No description provided for @createDiscount.
  ///
  /// In en, this message translates to:
  /// **'Create Discount'**
  String get createDiscount;

  /// No description provided for @noDiscountsCreated.
  ///
  /// In en, this message translates to:
  /// **'No discounts created yet'**
  String get noDiscountsCreated;

  /// No description provided for @createYourFirstDiscount.
  ///
  /// In en, this message translates to:
  /// **'Create your first discount to start attracting customers'**
  String get createYourFirstDiscount;

  /// No description provided for @deleteDiscount.
  ///
  /// In en, this message translates to:
  /// **'Delete Discount'**
  String get deleteDiscount;

  /// No description provided for @areYouSureYouWantToDeleteThisDiscount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this discount?'**
  String get areYouSureYouWantToDeleteThisDiscount;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @editDiscount.
  ///
  /// In en, this message translates to:
  /// **'Edit Discount'**
  String get editDiscount;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @pleaseEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// No description provided for @discountType.
  ///
  /// In en, this message translates to:
  /// **'Discount Type'**
  String get discountType;

  /// No description provided for @percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get percentage;

  /// No description provided for @fixedAmount.
  ///
  /// In en, this message translates to:
  /// **'Fixed Amount'**
  String get fixedAmount;

  /// No description provided for @conditional.
  ///
  /// In en, this message translates to:
  /// **'Conditional'**
  String get conditional;

  /// No description provided for @buyXGetY.
  ///
  /// In en, this message translates to:
  /// **'Buy X Get Y'**
  String get buyXGetY;

  /// No description provided for @freeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery'**
  String get freeDelivery;

  /// No description provided for @freeDeliveryValue.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery (0.0)'**
  String get freeDeliveryValue;

  /// No description provided for @buyXGetYValue.
  ///
  /// In en, this message translates to:
  /// **'Buy X Get Y (0.0)'**
  String get buyXGetYValue;

  /// No description provided for @conditionalValue.
  ///
  /// In en, this message translates to:
  /// **'Conditional (0.0)'**
  String get conditionalValue;

  /// No description provided for @freeDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery: {title}'**
  String freeDeliveryTitle(Object title);

  /// No description provided for @freeDeliveryIncludedWith.
  ///
  /// In en, this message translates to:
  /// **'Free delivery included with {title}'**
  String freeDeliveryIncludedWith(Object title);

  /// No description provided for @categoryAndPrice.
  ///
  /// In en, this message translates to:
  /// **'{category} • {currency} {price}'**
  String categoryAndPrice(Object category, Object currency, Object price);

  /// No description provided for @others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get others;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @pleaseEnterValue.
  ///
  /// In en, this message translates to:
  /// **'Please enter a value'**
  String get pleaseEnterValue;

  /// No description provided for @pleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// No description provided for @minimumOrderAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum order amount: {amount}'**
  String minimumOrderAmount(Object amount);

  /// No description provided for @minimumOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum Order'**
  String get minimumOrder;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get off;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'discount'**
  String get discount;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @validityPeriod.
  ///
  /// In en, this message translates to:
  /// **'Validity Period'**
  String get validityPeriod;

  /// No description provided for @unknownStatus.
  ///
  /// In en, this message translates to:
  /// **'Unknown Status'**
  String get unknownStatus;

  /// No description provided for @sampleItem.
  ///
  /// In en, this message translates to:
  /// **'Sample Item'**
  String get sampleItem;

  /// No description provided for @totalSales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get totalSales;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get totalOrders;

  /// No description provided for @averageOrderValue.
  ///
  /// In en, this message translates to:
  /// **'Average Order Value'**
  String get averageOrderValue;

  /// No description provided for @topSellingItems.
  ///
  /// In en, this message translates to:
  /// **'Top Selling Items'**
  String get topSellingItems;

  /// No description provided for @itemSoldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Sold: {quantity}'**
  String itemSoldQuantity(Object quantity);

  /// No description provided for @itemRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue: \${revenue}'**
  String itemRevenue(Object revenue);

  /// No description provided for @ordersByStatus.
  ///
  /// In en, this message translates to:
  /// **'Orders by Status'**
  String get ordersByStatus;

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatusPending;

  /// No description provided for @orderStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderStatusConfirmed;

  /// No description provided for @orderStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get orderStatusPreparing;

  /// No description provided for @orderStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get orderStatusReady;

  /// No description provided for @orderStatusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the Way'**
  String get orderStatusOnTheWay;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get orderStatusDelivered;

  /// No description provided for @orderStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get orderStatusPickedUp;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get orderStatusReturned;

  /// No description provided for @orderStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get orderStatusExpired;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderStatusCompleted;

  /// No description provided for @itemAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Item added successfully'**
  String get itemAddedSuccessfully;

  /// No description provided for @itemUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Item updated successfully'**
  String get itemUpdatedSuccessfully;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @currencyPrefix.
  ///
  /// In en, this message translates to:
  /// **'IQD '**
  String get currencyPrefix;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @deleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Item'**
  String get deleteItem;

  /// No description provided for @deleteItemConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this item?'**
  String get deleteItemConfirmation;

  /// No description provided for @itemDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Item deleted successfully'**
  String get itemDeletedSuccessfully;

  /// No description provided for @addNewItem.
  ///
  /// In en, this message translates to:
  /// **'Add New Item'**
  String get addNewItem;

  /// No description provided for @uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get uploadImage;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @pleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get pleaseSelectCategory;

  /// No description provided for @newCategoryName.
  ///
  /// In en, this message translates to:
  /// **'New Category Name'**
  String get newCategoryName;

  /// No description provided for @pleaseEnterCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Please enter category name'**
  String get pleaseEnterCategoryName;

  /// No description provided for @selectExistingCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Existing Category'**
  String get selectExistingCategory;

  /// No description provided for @addNewCategory.
  ///
  /// In en, this message translates to:
  /// **'Add New Category'**
  String get addNewCategory;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// No description provided for @pleaseEnterItemName.
  ///
  /// In en, this message translates to:
  /// **'Please enter item name'**
  String get pleaseEnterItemName;

  /// No description provided for @pleaseEnterPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter price'**
  String get pleaseEnterPrice;

  /// No description provided for @pleaseEnterValidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get pleaseEnterValidPrice;

  /// No description provided for @imageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrl;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @makeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Make Available'**
  String get makeAvailable;

  /// No description provided for @makeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Make Unavailable'**
  String get makeUnavailable;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get editItem;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @orderReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get orderReady;

  /// No description provided for @onTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the Way'**
  String get onTheWay;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @pickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get pickedUp;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @orderReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get orderReturned;

  /// No description provided for @noOrdersFoundFor.
  ///
  /// In en, this message translates to:
  /// **'No orders found for {filter}'**
  String noOrdersFoundFor(Object filter);

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @changeFile.
  ///
  /// In en, this message translates to:
  /// **'Change File'**
  String get changeFile;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select File'**
  String get selectFile;

  /// No description provided for @restaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get restaurant;

  /// No description provided for @store.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get store;

  /// No description provided for @pharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get pharmacy;

  /// No description provided for @cloudKitchen.
  ///
  /// In en, this message translates to:
  /// **'Cloud Kitchen'**
  String get cloudKitchen;

  /// No description provided for @cafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get cafe;

  /// No description provided for @bakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get bakery;

  /// No description provided for @herbalspices.
  ///
  /// In en, this message translates to:
  /// **'Herbal & Spices'**
  String get herbalspices;

  /// No description provided for @cosmetics.
  ///
  /// In en, this message translates to:
  /// **'Cosmetics'**
  String get cosmetics;

  /// No description provided for @betshop.
  ///
  /// In en, this message translates to:
  /// **'Bet Shop'**
  String get betshop;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @registrationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Registration Submitted'**
  String get registrationSubmitted;

  /// No description provided for @registrationSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your registration has been submitted for review'**
  String get registrationSubmittedMessage;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not Selected'**
  String get notSelected;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @districtLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get districtLabel;

  /// No description provided for @neighbourhoodLabel.
  ///
  /// In en, this message translates to:
  /// **'Neighbourhood'**
  String get neighbourhoodLabel;

  /// No description provided for @streetLabel.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get streetLabel;

  /// No description provided for @buildingHomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Building/Home'**
  String get buildingHomeLabel;

  /// No description provided for @zipCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Zip Code'**
  String get zipCodeLabel;

  /// No description provided for @businessOwnerInformation.
  ///
  /// In en, this message translates to:
  /// **'Business Owner Information'**
  String get businessOwnerInformation;

  /// No description provided for @nationalIdLabel.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get nationalIdLabel;

  /// No description provided for @dateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirthLabel;

  /// No description provided for @registrationSuccessLogin.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! You can now log in with your credentials.'**
  String get registrationSuccessLogin;

  /// No description provided for @gettingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting your location...'**
  String get gettingYourLocation;

  /// No description provided for @locationPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied permanently'**
  String get locationPermissionDeniedForever;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled'**
  String get locationServicesDisabled;

  /// No description provided for @couldNotDeterminePlacemark.
  ///
  /// In en, this message translates to:
  /// **'Could not determine placemark'**
  String get couldNotDeterminePlacemark;

  /// No description provided for @businessRegistration.
  ///
  /// In en, this message translates to:
  /// **'Business Registration'**
  String get businessRegistration;

  /// No description provided for @welcomeToHadhir.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Hadhir'**
  String get welcomeToHadhir;

  /// No description provided for @fillInTheFormBelowToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Fill in the form below to get started'**
  String get fillInTheFormBelowToGetStarted;

  /// No description provided for @createYourBusinessAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Your Business Account'**
  String get createYourBusinessAccount;

  /// No description provided for @tapToUpload.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload'**
  String get tapToUpload;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @businessAndOwnerInformation.
  ///
  /// In en, this message translates to:
  /// **'Business and Owner Information'**
  String get businessAndOwnerInformation;

  /// No description provided for @selectBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Please select a business type'**
  String get selectBusinessType;

  /// No description provided for @pleaseEnterBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Please enter business name'**
  String get pleaseEnterBusinessName;

  /// No description provided for @pleaseEnterOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Please enter owner name'**
  String get pleaseEnterOwnerName;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get firstNameRequired;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Last name is required'**
  String get lastNameRequired;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmailFormat;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberRequired;

  /// No description provided for @businessNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Business name is required'**
  String get businessNameRequired;

  /// No description provided for @pleaseEnterYourBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your business name'**
  String get pleaseEnterYourBusinessName;

  /// No description provided for @streetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street Address'**
  String get streetAddress;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State/Province'**
  String get state;

  /// No description provided for @zipCode.
  ///
  /// In en, this message translates to:
  /// **'ZIP/Postal Code'**
  String get zipCode;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @weakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak'**
  String get weakPassword;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @registrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registrationSuccess;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'Email address is already in use'**
  String get emailAlreadyInUse;

  /// No description provided for @passwordResetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your email'**
  String get passwordResetLinkSent;

  /// No description provided for @welcomeToOrderReceiver.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Order Receiver'**
  String get welcomeToOrderReceiver;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your business orders efficiently with our powerful order management system.'**
  String get welcomeDescription;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @testRegistrationForm.
  ///
  /// In en, this message translates to:
  /// **'Test Registration Form'**
  String get testRegistrationForm;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get networkError;

  /// No description provided for @returnOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Return Order'**
  String get returnOrderTitle;

  /// No description provided for @enterOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Order Number'**
  String get enterOrderNumber;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order Not Found'**
  String get orderNotFound;

  /// No description provided for @orderReturnedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Order Returned Successfully'**
  String get orderReturnedSuccessfully;

  /// No description provided for @locationSaved.
  ///
  /// In en, this message translates to:
  /// **'Location Saved'**
  String get locationSaved;

  /// No description provided for @businessLocation.
  ///
  /// In en, this message translates to:
  /// **'Business Location'**
  String get businessLocation;

  /// No description provided for @locationSet.
  ///
  /// In en, this message translates to:
  /// **'Location Set'**
  String get locationSet;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// No description provided for @updateLocation.
  ///
  /// In en, this message translates to:
  /// **'Update Location'**
  String get updateLocation;

  /// No description provided for @noLocationSet.
  ///
  /// In en, this message translates to:
  /// **'No Location Set'**
  String get noLocationSet;

  /// No description provided for @chooseLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Choose Location on Map'**
  String get chooseLocationOnMap;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// No description provided for @enableLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Enable Location Services'**
  String get enableLocationServices;

  /// No description provided for @locationNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Location Not Selected'**
  String get locationNotSelected;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocation;

  /// No description provided for @tapToSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to Select Location'**
  String get tapToSelectLocation;

  /// No description provided for @registrationDate.
  ///
  /// In en, this message translates to:
  /// **'Registration Date'**
  String get registrationDate;

  /// No description provided for @failedToSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Failed to save location'**
  String get failedToSaveLocation;

  /// No description provided for @businessLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Set your business location to help customers find you and improve delivery accuracy.'**
  String get businessLocationDescription;

  /// No description provided for @locationInformation.
  ///
  /// In en, this message translates to:
  /// **'Location Information'**
  String get locationInformation;

  /// No description provided for @customerVisibility.
  ///
  /// In en, this message translates to:
  /// **'Customer Visibility'**
  String get customerVisibility;

  /// No description provided for @customerVisibilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Your location will be shown to customers when they place orders'**
  String get customerVisibilityDescription;

  /// No description provided for @deliveryOptimization.
  ///
  /// In en, this message translates to:
  /// **'Delivery Optimization'**
  String get deliveryOptimization;

  /// No description provided for @deliveryOptimizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Accurate location helps optimize delivery routes and timing'**
  String get deliveryOptimizationDescription;

  /// No description provided for @privacyAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacyAndSecurity;

  /// No description provided for @privacyAndSecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'Your location data is encrypted and securely stored'**
  String get privacyAndSecurityDescription;

  /// No description provided for @pleaseSignInToAccessLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to access location settings'**
  String get pleaseSignInToAccessLocationSettings;

  /// No description provided for @smartBusinessControls.
  ///
  /// In en, this message translates to:
  /// **'Smart business controls'**
  String get smartBusinessControls;

  /// No description provided for @readyToReceiveOrders.
  ///
  /// In en, this message translates to:
  /// **'Ready to receive orders'**
  String get readyToReceiveOrders;

  /// No description provided for @ordersArePaused.
  ///
  /// In en, this message translates to:
  /// **'Orders are paused'**
  String get ordersArePaused;

  /// No description provided for @menuItemsAndCategories.
  ///
  /// In en, this message translates to:
  /// **'Menu items & categories'**
  String get menuItemsAndCategories;

  /// No description provided for @businessInsights.
  ///
  /// In en, this message translates to:
  /// **'Business Insights'**
  String get businessInsights;

  /// No description provided for @offersAndPromotions.
  ///
  /// In en, this message translates to:
  /// **'Offers & promotions'**
  String get offersAndPromotions;

  /// No description provided for @appConfiguration.
  ///
  /// In en, this message translates to:
  /// **'App configuration'**
  String get appConfiguration;

  /// No description provided for @changeAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get changeAppLanguage;

  /// No description provided for @cancelRecentOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel recent order'**
  String get cancelRecentOrder;

  /// No description provided for @tapOutsideOrPressEscToClose.
  ///
  /// In en, this message translates to:
  /// **'Tap outside or press ESC to close'**
  String get tapOutsideOrPressEscToClose;

  /// No description provided for @languageChangedToArabic.
  ///
  /// In en, this message translates to:
  /// **'تم تغيير اللغة إلى العربية'**
  String get languageChangedToArabic;

  /// No description provided for @languageChangedToEnglish.
  ///
  /// In en, this message translates to:
  /// **'Language changed to English'**
  String get languageChangedToEnglish;

  /// No description provided for @managePromotionalOffers.
  ///
  /// In en, this message translates to:
  /// **'Manage promotional offers'**
  String get managePromotionalOffers;

  /// No description provided for @viewBusinessInsights.
  ///
  /// In en, this message translates to:
  /// **'View business insights'**
  String get viewBusinessInsights;

  /// No description provided for @manageItemsAndCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage items & categories'**
  String get manageItemsAndCategories;

  /// No description provided for @platformIntegration.
  ///
  /// In en, this message translates to:
  /// **'Platform Integration'**
  String get platformIntegration;

  /// No description provided for @centralizedDeliveryPlatform.
  ///
  /// In en, this message translates to:
  /// **'Centralized delivery platform'**
  String get centralizedDeliveryPlatform;

  /// No description provided for @appAndAccountPreferences.
  ///
  /// In en, this message translates to:
  /// **'App & account preferences'**
  String get appAndAccountPreferences;

  /// No description provided for @keyboardShortcutsTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Use keyboard shortcuts for faster actions'**
  String get keyboardShortcutsTip;

  /// No description provided for @conditionalDiscountConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Conditional Discount Configuration'**
  String get conditionalDiscountConfiguration;

  /// No description provided for @buyXGetYConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Buy X Get Y Configuration'**
  String get buyXGetYConfiguration;

  /// No description provided for @buyConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Buy Configuration'**
  String get buyConfiguration;

  /// No description provided for @getConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Get Configuration'**
  String get getConfiguration;

  /// No description provided for @selectItem.
  ///
  /// In en, this message translates to:
  /// **'Select Item'**
  String get selectItem;

  /// No description provided for @itemSelected.
  ///
  /// In en, this message translates to:
  /// **'Item Selected'**
  String get itemSelected;

  /// No description provided for @enterValidQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter valid quantity'**
  String get enterValidQuantity;

  /// No description provided for @missingItems.
  ///
  /// In en, this message translates to:
  /// **'Missing Items'**
  String get missingItems;

  /// No description provided for @pleasSelectBothBuyAndGetItems.
  ///
  /// In en, this message translates to:
  /// **'Please select both buy and get items for {discountType} discount.'**
  String pleasSelectBothBuyAndGetItems(Object discountType);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @addFreeDeliveryToDiscount.
  ///
  /// In en, this message translates to:
  /// **'Add free delivery to this discount'**
  String get addFreeDeliveryToDiscount;

  /// No description provided for @conflictingDiscountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conflicting Discounts'**
  String get conflictingDiscountsTitle;

  /// No description provided for @someSelectedItemsAlreadyHaveDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Some selected items or categories already have active discounts. Each item can only have one discount at a time.'**
  String get someSelectedItemsAlreadyHaveDiscounts;

  /// No description provided for @applicabilityNotConfigurable.
  ///
  /// In en, this message translates to:
  /// **'Applicability is not configurable for this discount type as items are already specified in the configuration above.'**
  String get applicabilityNotConfigurable;

  /// No description provided for @noItemSelected.
  ///
  /// In en, this message translates to:
  /// **'No item selected'**
  String get noItemSelected;

  /// No description provided for @appliesToAllItems.
  ///
  /// In en, this message translates to:
  /// **'Applies to all items'**
  String get appliesToAllItems;

  /// No description provided for @appliesToSpecificItems.
  ///
  /// In en, this message translates to:
  /// **'Applies to {count} specific items'**
  String appliesToSpecificItems(Object count);

  /// No description provided for @appliesToCategories.
  ///
  /// In en, this message translates to:
  /// **'Applies to {count} categories'**
  String appliesToCategories(Object count);

  /// No description provided for @appliesToOrdersAboveMinimum.
  ///
  /// In en, this message translates to:
  /// **'Applies to orders above minimum amount'**
  String get appliesToOrdersAboveMinimum;

  /// No description provided for @validFromTo.
  ///
  /// In en, this message translates to:
  /// **'Valid: {startDay}/{startMonth}/{startYear} - {endDay}/{endMonth}/{endYear}'**
  String validFromTo(Object endDay, Object endMonth, Object endYear,
      Object startDay, Object startMonth, Object startYear);

  /// No description provided for @minAmount.
  ///
  /// In en, this message translates to:
  /// **'Min: \${amount}'**
  String minAmount(Object amount);

  /// No description provided for @categoriesSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} categories selected'**
  String categoriesSelected(Object count);

  /// No description provided for @itemsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} items selected'**
  String itemsSelected(Object count);

  /// No description provided for @missingItemsMessage.
  ///
  /// In en, this message translates to:
  /// **'Please select both buy and get items for {discountType} discount.'**
  String missingItemsMessage(Object discountType);

  /// No description provided for @selectBuyItem.
  ///
  /// In en, this message translates to:
  /// **'Select Buy Item'**
  String get selectBuyItem;

  /// No description provided for @selectGetItem.
  ///
  /// In en, this message translates to:
  /// **'Select Get Item'**
  String get selectGetItem;

  /// No description provided for @noCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found. Please add categories first.'**
  String get noCategoriesFound;

  /// No description provided for @appliesToMinimumOrder.
  ///
  /// In en, this message translates to:
  /// **'Applies to orders above minimum amount'**
  String get appliesToMinimumOrder;

  /// No description provided for @startSimulation.
  ///
  /// In en, this message translates to:
  /// **'Start Simulation'**
  String get startSimulation;

  /// No description provided for @stopSimulation.
  ///
  /// In en, this message translates to:
  /// **'Stop Simulation'**
  String get stopSimulation;

  /// No description provided for @simulateNewOrder.
  ///
  /// In en, this message translates to:
  /// **'Simulate New Order'**
  String get simulateNewOrder;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get newOrder;

  /// No description provided for @newOrderArrived.
  ///
  /// In en, this message translates to:
  /// **'NEW ORDER ARRIVED!'**
  String get newOrderArrived;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @failedToUpdateOrder.
  ///
  /// In en, this message translates to:
  /// **'Failed to update order'**
  String get failedToUpdateOrder;

  /// No description provided for @orderRejectedByMerchant.
  ///
  /// In en, this message translates to:
  /// **'Order rejected by merchant'**
  String get orderRejectedByMerchant;

  /// No description provided for @orderHashtag.
  ///
  /// In en, this message translates to:
  /// **'Order #'**
  String get orderHashtag;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @sendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get sendTestNotification;

  /// No description provided for @showLocalNotifications.
  ///
  /// In en, this message translates to:
  /// **'Show Local Notifications'**
  String get showLocalNotifications;

  /// No description provided for @showLocalNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Display notifications on this device'**
  String get showLocalNotificationsDescription;

  /// No description provided for @playNotificationSounds.
  ///
  /// In en, this message translates to:
  /// **'Play Notification Sounds'**
  String get playNotificationSounds;

  /// No description provided for @playNotificationSoundsDescription.
  ///
  /// In en, this message translates to:
  /// **'Play sounds when notifications are received'**
  String get playNotificationSoundsDescription;

  /// No description provided for @testNotifications.
  ///
  /// In en, this message translates to:
  /// **'Test Notifications'**
  String get testNotifications;

  /// No description provided for @testNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification to verify settings'**
  String get testNotificationDescription;

  /// No description provided for @notConnectedToNotifications.
  ///
  /// In en, this message translates to:
  /// **'Not connected to real-time notifications'**
  String get notConnectedToNotifications;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @highPriority.
  ///
  /// In en, this message translates to:
  /// **'High Priority'**
  String get highPriority;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @newOrderNotificationsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'New order notifications will appear here'**
  String get newOrderNotificationsAppearHere;

  /// No description provided for @clearAllNotifications.
  ///
  /// In en, this message translates to:
  /// **'Clear All Notifications'**
  String get clearAllNotifications;

  /// No description provided for @testNotificationSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent successfully'**
  String get testNotificationSentSuccessfully;

  /// No description provided for @failedToSendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Failed to send test notification: {error}'**
  String failedToSendTestNotification(Object error);

  /// No description provided for @failedToConnectToNotifications.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to notifications: {error}'**
  String failedToConnectToNotifications(Object error);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @urgent.
  ///
  /// In en, this message translates to:
  /// **'urgent'**
  String get urgent;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'high'**
  String get high;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'normal'**
  String get normal;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get low;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(Object minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(Object hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(Object days);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @reviewsAndInsights.
  ///
  /// In en, this message translates to:
  /// **'Reviews & Insights'**
  String get reviewsAndInsights;

  /// No description provided for @customerReviews.
  ///
  /// In en, this message translates to:
  /// **'Customer Reviews'**
  String get customerReviews;

  /// No description provided for @leastOrderedItems.
  ///
  /// In en, this message translates to:
  /// **'Least Ordered Items'**
  String get leastOrderedItems;

  /// No description provided for @leastOrderedItemsDescription.
  ///
  /// In en, this message translates to:
  /// **'Items that need more attention or promotion'**
  String get leastOrderedItemsDescription;

  /// No description provided for @growingPopularity.
  ///
  /// In en, this message translates to:
  /// **'Growing Popularity'**
  String get growingPopularity;

  /// No description provided for @customerSatisfaction.
  ///
  /// In en, this message translates to:
  /// **'Customer Satisfaction'**
  String get customerSatisfaction;

  /// No description provided for @efficientService.
  ///
  /// In en, this message translates to:
  /// **'Efficient Service'**
  String get efficientService;

  /// No description provided for @customerBase.
  ///
  /// In en, this message translates to:
  /// **'Customer Base'**
  String get customerBase;

  /// No description provided for @bestPerformer.
  ///
  /// In en, this message translates to:
  /// **'Best Performer'**
  String get bestPerformer;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get needsAttention;

  /// No description provided for @revenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenueLabel;

  /// No description provided for @growingPopularityDescription.
  ///
  /// In en, this message translates to:
  /// **'Your business has a {growthRate}% growth rate this month'**
  String growingPopularityDescription(Object growthRate);

  /// No description provided for @customerSatisfactionDescription.
  ///
  /// In en, this message translates to:
  /// **'Average rating of {averageRating}/5.0 from {totalReviews} reviews'**
  String customerSatisfactionDescription(
      Object averageRating, Object totalReviews);

  /// No description provided for @efficientServiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Average preparation time: {averagePreparationTime} minutes'**
  String efficientServiceDescription(Object averagePreparationTime);

  /// No description provided for @customerBaseDescription.
  ///
  /// In en, this message translates to:
  /// **'Served {customersServed} customers with {cancellationRate}% cancellation rate'**
  String customerBaseDescription(
      Object cancellationRate, Object customersServed);

  /// No description provided for @quickInsightSoldCount.
  ///
  /// In en, this message translates to:
  /// **'{quantity} sold'**
  String quickInsightSoldCount(Object quantity);

  /// No description provided for @onlySoldCount.
  ///
  /// In en, this message translates to:
  /// **'Only {quantity} sold'**
  String onlySoldCount(Object quantity);

  /// No description provided for @revenueTrend.
  ///
  /// In en, this message translates to:
  /// **'Revenue Trend'**
  String get revenueTrend;

  /// No description provided for @quickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick Stats'**
  String get quickStats;

  /// No description provided for @revenueBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Revenue Breakdown'**
  String get revenueBreakdown;

  /// No description provided for @dailyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Daily Revenue'**
  String get dailyRevenue;

  /// No description provided for @weeklyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Weekly Revenue'**
  String get weeklyRevenue;

  /// No description provided for @monthlyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly Revenue'**
  String get monthlyRevenue;

  /// No description provided for @performanceMetrics.
  ///
  /// In en, this message translates to:
  /// **'Performance Metrics'**
  String get performanceMetrics;

  /// No description provided for @avgPrepTime.
  ///
  /// In en, this message translates to:
  /// **'Avg. Prep Time'**
  String get avgPrepTime;

  /// No description provided for @successRate.
  ///
  /// In en, this message translates to:
  /// **'Success Rate'**
  String get successRate;

  /// No description provided for @specialDish.
  ///
  /// In en, this message translates to:
  /// **'Special Dish'**
  String get specialDish;

  /// No description provided for @popularItem.
  ///
  /// In en, this message translates to:
  /// **'Popular Item'**
  String get popularItem;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// No description provided for @todaysRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Revenue'**
  String get todaysRevenue;

  /// No description provided for @avgOrderValue.
  ///
  /// In en, this message translates to:
  /// **'Avg. Order Value'**
  String get avgOrderValue;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @tapToSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Tap to select file'**
  String get tapToSelectFile;

  /// No description provided for @requiredPleaseAddAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Required. Please add a photo.'**
  String get requiredPleaseAddAPhoto;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @pleaseFillInAllRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields.'**
  String get pleaseFillInAllRequiredFields;

  /// No description provided for @businessPhotoIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Business photo is required.'**
  String get businessPhotoIsRequired;

  /// No description provided for @businessLicenseRequired.
  ///
  /// In en, this message translates to:
  /// **'Business license is required.'**
  String get businessLicenseRequired;

  /// No description provided for @ownerIdentityRequired.
  ///
  /// In en, this message translates to:
  /// **'Owner identity is required.'**
  String get ownerIdentityRequired;

  /// No description provided for @healthCertificateRequired.
  ///
  /// In en, this message translates to:
  /// **'Health certificate is required.'**
  String get healthCertificateRequired;

  /// No description provided for @ownerPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Owner photo is required.'**
  String get ownerPhotoRequired;

  /// No description provided for @loginInstead.
  ///
  /// In en, this message translates to:
  /// **'Login Instead'**
  String get loginInstead;

  /// No description provided for @failedToUploadBusinessPhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload business photo'**
  String get failedToUploadBusinessPhoto;

  /// No description provided for @errorUploadingBusinessPhoto.
  ///
  /// In en, this message translates to:
  /// **'Error uploading business photo'**
  String get errorUploadingBusinessPhoto;

  /// No description provided for @failedToUploadBusinessLicense.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload business license'**
  String get failedToUploadBusinessLicense;

  /// No description provided for @failedToUploadOwnerIdentity.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload owner identity'**
  String get failedToUploadOwnerIdentity;

  /// No description provided for @failedToUploadHealthCertificate.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload health certificate'**
  String get failedToUploadHealthCertificate;

  /// No description provided for @failedToUploadOwnerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload owner photo'**
  String get failedToUploadOwnerPhoto;

  /// No description provided for @errorUploadingDocuments.
  ///
  /// In en, this message translates to:
  /// **'Error uploading documents'**
  String get errorUploadingDocuments;

  /// No description provided for @registrationInitiated.
  ///
  /// In en, this message translates to:
  /// **'Registration initiated'**
  String get registrationInitiated;

  /// No description provided for @registrationCompletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Registration completed successfully'**
  String get registrationCompletedSuccessfully;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get verificationFailed;

  /// No description provided for @selectImageSource.
  ///
  /// In en, this message translates to:
  /// **'Select Image Source'**
  String get selectImageSource;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @verificationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to {email}'**
  String verificationCodeSentTo(Object email);

  /// No description provided for @applicationPending.
  ///
  /// In en, this message translates to:
  /// **'Application Pending'**
  String get applicationPending;

  /// No description provided for @applicationPendingDescription.
  ///
  /// In en, this message translates to:
  /// **'Your application is pending approval.'**
  String get applicationPendingDescription;

  /// No description provided for @applicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Application Approved'**
  String get applicationApproved;

  /// No description provided for @applicationApprovedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your application has been approved.'**
  String get applicationApprovedDescription;

  /// No description provided for @applicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application Rejected'**
  String get applicationRejected;

  /// No description provided for @applicationRejectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your application has been rejected.'**
  String get applicationRejectedDescription;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get underReview;

  /// No description provided for @underReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Your application is under review.'**
  String get underReviewDescription;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status Unknown'**
  String get statusUnknown;

  /// No description provided for @statusUnknownDescription.
  ///
  /// In en, this message translates to:
  /// **'The status of your application is unknown.'**
  String get statusUnknownDescription;

  /// No description provided for @applicationStatus.
  ///
  /// In en, this message translates to:
  /// **'Application Status'**
  String get applicationStatus;

  /// No description provided for @accountApproved.
  ///
  /// In en, this message translates to:
  /// **'Account Approved'**
  String get accountApproved;

  /// No description provided for @accountSuspended.
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get accountSuspended;

  /// No description provided for @accountApprovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your merchant account has been approved. You can now start using the platform.'**
  String get accountApprovedMessage;

  /// No description provided for @applicationPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your application is being reviewed. We will notify you once the review is complete.'**
  String get applicationPendingMessage;

  /// No description provided for @applicationRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your application has been rejected. Please contact support for more information.'**
  String get applicationRejectedMessage;

  /// No description provided for @accountSuspendedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been suspended. Please contact support to resolve this issue.'**
  String get accountSuspendedMessage;

  /// No description provided for @unknownStatusMessage.
  ///
  /// In en, this message translates to:
  /// **'Unknown status detected. Please contact support.'**
  String get unknownStatusMessage;

  /// No description provided for @needHelp.
  ///
  /// In en, this message translates to:
  /// **'Need Help?'**
  String get needHelp;

  /// No description provided for @contactSupportMessage.
  ///
  /// In en, this message translates to:
  /// **'Contact our support team if you have any questions.'**
  String get contactSupportMessage;

  /// No description provided for @chatWithSupport.
  ///
  /// In en, this message translates to:
  /// **'Chat with Support'**
  String get chatWithSupport;

  /// No description provided for @supportInformation.
  ///
  /// In en, this message translates to:
  /// **'Support Information'**
  String get supportInformation;

  /// No description provided for @completeRegistrationForChat.
  ///
  /// In en, this message translates to:
  /// **'To access live chat support, please complete your merchant registration and login.'**
  String get completeRegistrationForChat;

  /// No description provided for @forImmediateAssistance.
  ///
  /// In en, this message translates to:
  /// **'For immediate assistance, please contact:'**
  String get forImmediateAssistance;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'wizzappdev@outlook.com'**
  String get supportEmail;

  /// No description provided for @supportPhone.
  ///
  /// In en, this message translates to:
  /// **'07831367435'**
  String get supportPhone;

  /// No description provided for @discountApplicability.
  ///
  /// In en, this message translates to:
  /// **'Discount Applicability'**
  String get discountApplicability;

  /// No description provided for @allItems.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get allItems;

  /// No description provided for @specificItems.
  ///
  /// In en, this message translates to:
  /// **'Specific Items'**
  String get specificItems;

  /// No description provided for @specificCategories.
  ///
  /// In en, this message translates to:
  /// **'Specific Categories'**
  String get specificCategories;

  /// No description provided for @selectItems.
  ///
  /// In en, this message translates to:
  /// **'Select Items'**
  String get selectItems;

  /// No description provided for @noItemsSelected.
  ///
  /// In en, this message translates to:
  /// **'No items selected'**
  String get noItemsSelected;

  /// No description provided for @selectCategories.
  ///
  /// In en, this message translates to:
  /// **'Select Categories'**
  String get selectCategories;

  /// No description provided for @noCategoriesSelected.
  ///
  /// In en, this message translates to:
  /// **'No categories selected'**
  String get noCategoriesSelected;

  /// No description provided for @conflictingDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Conflicting Discounts'**
  String get conflictingDiscounts;

  /// No description provided for @kwd.
  ///
  /// In en, this message translates to:
  /// **'KWD'**
  String get kwd;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'categories'**
  String get categories;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not Specified'**
  String get notSpecified;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @viewAndManageOrders.
  ///
  /// In en, this message translates to:
  /// **'View and manage orders'**
  String get viewAndManageOrders;

  /// No description provided for @businessDashboardVersion.
  ///
  /// In en, this message translates to:
  /// **'Business Dashboard Version'**
  String get businessDashboardVersion;

  /// No description provided for @modernMaterialDesign.
  ///
  /// In en, this message translates to:
  /// **'Modern Material Design'**
  String get modernMaterialDesign;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @businessLicense.
  ///
  /// In en, this message translates to:
  /// **'Business License'**
  String get businessLicense;

  /// No description provided for @ownerIdentity.
  ///
  /// In en, this message translates to:
  /// **'Owner Identity'**
  String get ownerIdentity;

  /// No description provided for @ownerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Owner Photo'**
  String get ownerPhoto;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @kitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get kitchen;

  /// No description provided for @chooseFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose from Files'**
  String get chooseFromFiles;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// No description provided for @pleaseEnterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterAValidEmail;

  /// No description provided for @passwordMustBeAtLeast8Chars.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMustBeAtLeast8Chars;

  /// No description provided for @reEnterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get reEnterYourPassword;

  /// No description provided for @enterOwnerName.
  ///
  /// In en, this message translates to:
  /// **'Enter owner name'**
  String get enterOwnerName;

  /// No description provided for @ownerFirstName.
  ///
  /// In en, this message translates to:
  /// **'Owner First Name'**
  String get ownerFirstName;

  /// No description provided for @enterOwnerFirstName.
  ///
  /// In en, this message translates to:
  /// **'Enter owner first name'**
  String get enterOwnerFirstName;

  /// No description provided for @pleaseEnterOwnerFirstName.
  ///
  /// In en, this message translates to:
  /// **'Please enter owner first name'**
  String get pleaseEnterOwnerFirstName;

  /// No description provided for @ownerLastName.
  ///
  /// In en, this message translates to:
  /// **'Owner Last Name'**
  String get ownerLastName;

  /// No description provided for @enterOwnerLastName.
  ///
  /// In en, this message translates to:
  /// **'Enter owner last name'**
  String get enterOwnerLastName;

  /// No description provided for @pleaseEnterOwnerLastName.
  ///
  /// In en, this message translates to:
  /// **'Please enter owner last name'**
  String get pleaseEnterOwnerLastName;

  /// No description provided for @enterYourBusinessPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your business phone'**
  String get enterYourBusinessPhone;

  /// No description provided for @pleaseEnterYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterYourPhoneNumber;

  /// No description provided for @addAPhotoToShowcaseYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Add a photo to showcase your business'**
  String get addAPhotoToShowcaseYourBusiness;

  /// No description provided for @pleaseEnterYourCity.
  ///
  /// In en, this message translates to:
  /// **'Please enter your city'**
  String get pleaseEnterYourCity;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @enterYourDistrict.
  ///
  /// In en, this message translates to:
  /// **'Enter your district'**
  String get enterYourDistrict;

  /// No description provided for @pleaseEnterYourDistrict.
  ///
  /// In en, this message translates to:
  /// **'Please enter your district'**
  String get pleaseEnterYourDistrict;

  /// No description provided for @enterYourStreetAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your street address'**
  String get enterYourStreetAddress;

  /// No description provided for @pleaseEnterYourStreetAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your street address'**
  String get pleaseEnterYourStreetAddress;

  /// No description provided for @documentsRequired.
  ///
  /// In en, this message translates to:
  /// **'Documents Required'**
  String get documentsRequired;

  /// No description provided for @pleaseUploadAllRequiredDocuments.
  ///
  /// In en, this message translates to:
  /// **'Please upload all required documents'**
  String get pleaseUploadAllRequiredDocuments;

  /// No description provided for @emailVerification.
  ///
  /// In en, this message translates to:
  /// **'Email Verification'**
  String get emailVerification;

  /// No description provided for @enterTheCodeSentToYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to your email'**
  String get enterTheCodeSentToYourEmail;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get changeEmail;

  /// No description provided for @enter6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get enter6DigitCode;

  /// No description provided for @enterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get enterVerificationCode;

  /// No description provided for @pleaseEnterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter verification code'**
  String get pleaseEnterVerificationCode;

  /// No description provided for @pleaseEnterTheVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code'**
  String get pleaseEnterTheVerificationCode;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to your email'**
  String get verificationCodeSent;

  /// No description provided for @resendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Verification Code'**
  String get resendVerificationCode;

  /// No description provided for @failedToResendCode.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend verification code'**
  String get failedToResendCode;

  /// No description provided for @troubleshootingSection.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get troubleshootingSection;

  /// No description provided for @passwordChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccessfully;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @business.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get business;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get createYourAccount;

  /// No description provided for @enterAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter your account details to get started'**
  String get enterAccountDetails;

  /// No description provided for @tellUsAboutYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your business'**
  String get tellUsAboutYourBusiness;

  /// No description provided for @whereIsYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Where is your business located?'**
  String get whereIsYourBusiness;

  /// No description provided for @uploadDocumentsOptional.
  ///
  /// In en, this message translates to:
  /// **'Upload documents to verify your business (optional)'**
  String get uploadDocumentsOptional;

  /// No description provided for @selectSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Select Subcategory (Optional)'**
  String get selectSubcategory;

  /// No description provided for @businessSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Business Subcategory (Optional)'**
  String get businessSubcategory;

  /// No description provided for @uploadBusinessLicense.
  ///
  /// In en, this message translates to:
  /// **'Upload your business license'**
  String get uploadBusinessLicense;

  /// No description provided for @identityDocument.
  ///
  /// In en, this message translates to:
  /// **'Identity Document'**
  String get identityDocument;

  /// No description provided for @uploadIdentityDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload your identity document'**
  String get uploadIdentityDocument;

  /// No description provided for @uploadOwnerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of the owner'**
  String get uploadOwnerPhoto;

  /// No description provided for @enterCountry.
  ///
  /// In en, this message translates to:
  /// **'Enter your country'**
  String get enterCountry;

  /// No description provided for @pleaseEnterCountry.
  ///
  /// In en, this message translates to:
  /// **'Please enter your country'**
  String get pleaseEnterCountry;

  /// No description provided for @enterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter your city'**
  String get enterCity;

  /// No description provided for @pleaseEnterCity.
  ///
  /// In en, this message translates to:
  /// **'Please enter your city'**
  String get pleaseEnterCity;

  /// No description provided for @enterDistrict.
  ///
  /// In en, this message translates to:
  /// **'Enter your district'**
  String get enterDistrict;

  /// No description provided for @pleaseEnterDistrict.
  ///
  /// In en, this message translates to:
  /// **'Please enter your district'**
  String get pleaseEnterDistrict;

  /// No description provided for @enterStreetAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your street address'**
  String get enterStreetAddress;

  /// No description provided for @pleaseEnterStreetAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your street address'**
  String get pleaseEnterStreetAddress;

  /// No description provided for @registrationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Welcome to Hadhir Business.'**
  String get registrationSuccessful;

  /// No description provided for @registrationVerifiedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Registration verified successfully!'**
  String get registrationVerifiedSuccessfully;

  /// No description provided for @verificationFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {reason}'**
  String verificationFailedWithReason(Object reason);

  /// No description provided for @verificationCodeSentToEmail.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to your email'**
  String get verificationCodeSentToEmail;

  /// No description provided for @registrationFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {reason}'**
  String registrationFailedWithReason(Object reason);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @didntReceiveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code?'**
  String get didntReceiveCode;

  /// No description provided for @wrongEmailChangeIt.
  ///
  /// In en, this message translates to:
  /// **'Wrong email? Change it'**
  String get wrongEmailChangeIt;

  /// No description provided for @verificationCodeMustBe6Digits.
  ///
  /// In en, this message translates to:
  /// **'Verification code must be 6 digits'**
  String get verificationCodeMustBe6Digits;

  /// No description provided for @accountAlreadyVerifiedPleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Account already verified. Please sign in.'**
  String get accountAlreadyVerifiedPleaseSignIn;

  /// No description provided for @tooManyAttemptsPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get tooManyAttemptsPleaseWait;

  /// No description provided for @noAccountFoundForThisEmail.
  ///
  /// In en, this message translates to:
  /// **'No account found for this email.'**
  String get noAccountFoundForThisEmail;

  /// No description provided for @mustAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the terms and conditions'**
  String get mustAgreeToTerms;

  /// No description provided for @passwordRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Password Requirements'**
  String get passwordRequirementsTitle;

  /// No description provided for @passwordRequirementsBullets.
  ///
  /// In en, this message translates to:
  /// **'• At least 8 characters\\n• Include uppercase, lowercase, numbers, and a special character'**
  String get passwordRequirementsBullets;

  /// No description provided for @changeEmailAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Email Address'**
  String get changeEmailAddressTitle;

  /// No description provided for @changeEmailAddressMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to change your email address? This will take you back to the sign-up screen.'**
  String get changeEmailAddressMessage;

  /// No description provided for @invalidIraqiPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid Iraqi number (77X/78X/79X for mobile)'**
  String get invalidIraqiPhoneNumber;

  /// No description provided for @centralizedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Centralized Platform'**
  String get centralizedPlatform;

  /// No description provided for @platformConnection.
  ///
  /// In en, this message translates to:
  /// **'Platform Connection'**
  String get platformConnection;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get syncStatus;

  /// No description provided for @platformApps.
  ///
  /// In en, this message translates to:
  /// **'Platform Apps'**
  String get platformApps;

  /// No description provided for @localBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Local Businesses'**
  String get localBusinesses;

  /// No description provided for @syncRecommended.
  ///
  /// In en, this message translates to:
  /// **'Sync Recommended'**
  String get syncRecommended;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @setupPlatform.
  ///
  /// In en, this message translates to:
  /// **'Setup Platform'**
  String get setupPlatform;

  /// No description provided for @syncAllBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Sync All Businesses'**
  String get syncAllBusinesses;

  /// No description provided for @refreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh Status'**
  String get refreshStatus;

  /// No description provided for @failedToLoadPlatformStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to load platform status'**
  String get failedToLoadPlatformStatus;

  /// No description provided for @platformSetupCompletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Platform setup completed successfully'**
  String get platformSetupCompletedSuccessfully;

  /// No description provided for @platformSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Platform setup failed'**
  String get platformSetupFailed;

  /// No description provided for @errorSettingUpPlatform.
  ///
  /// In en, this message translates to:
  /// **'Error setting up platform'**
  String get errorSettingUpPlatform;

  /// No description provided for @allBusinessesSyncedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'All businesses synced successfully'**
  String get allBusinessesSyncedSuccessfully;

  /// No description provided for @failedToSyncAllBusinessesToPlatform.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync all businesses to platform'**
  String get failedToSyncAllBusinessesToPlatform;

  /// No description provided for @errorSyncingBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Error syncing businesses'**
  String get errorSyncingBusinesses;

  /// No description provided for @noAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No apps found'**
  String get noAppsFound;

  /// No description provided for @businessDetails.
  ///
  /// In en, this message translates to:
  /// **'Business Details'**
  String get businessDetails;

  /// No description provided for @manageYourBusinessProfileAndInformation.
  ///
  /// In en, this message translates to:
  /// **'Manage your business profile and information'**
  String get manageYourBusinessProfileAndInformation;

  /// No description provided for @manageYourPersonalInformation.
  ///
  /// In en, this message translates to:
  /// **'Manage your personal information'**
  String get manageYourPersonalInformation;

  /// No description provided for @updateYourPasswordAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'Update your password and security'**
  String get updateYourPasswordAndSecurity;

  /// No description provided for @changeAppLanguagePreference.
  ///
  /// In en, this message translates to:
  /// **'Change app language preference'**
  String get changeAppLanguagePreference;

  /// No description provided for @selectYourPreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get selectYourPreferredLanguage;

  /// No description provided for @languageChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Language changed successfully'**
  String get languageChangedSuccessfully;

  /// No description provided for @configurePointOfSaleIntegration.
  ///
  /// In en, this message translates to:
  /// **'Configure point of sale integration'**
  String get configurePointOfSaleIntegration;

  /// No description provided for @soundNotifications.
  ///
  /// In en, this message translates to:
  /// **'Sound Notifications'**
  String get soundNotifications;

  /// No description provided for @configureSoundAlertsForNewOrdersAndUpdates.
  ///
  /// In en, this message translates to:
  /// **'Configure sound alerts for new orders and updates'**
  String get configureSoundAlertsForNewOrdersAndUpdates;

  /// No description provided for @manageNotificationPreferencesAndDeliveryMethods.
  ///
  /// In en, this message translates to:
  /// **'Manage notification preferences and delivery methods'**
  String get manageNotificationPreferencesAndDeliveryMethods;

  /// No description provided for @manageBusinessLocationAndGpsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Manage business location and GPS coordinates'**
  String get manageBusinessLocationAndGpsCoordinates;

  /// No description provided for @setUpOpeningAndClosingHoursForYourBusiness.
  ///
  /// In en, this message translates to:
  /// **'Set up opening and closing hours for your business'**
  String get setUpOpeningAndClosingHoursForYourBusiness;

  /// No description provided for @discountManagement.
  ///
  /// In en, this message translates to:
  /// **'Discount Management'**
  String get discountManagement;

  /// No description provided for @createAndManageYourDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your discounts'**
  String get createAndManageYourDiscounts;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @joinThousandsOfBusinessOwners.
  ///
  /// In en, this message translates to:
  /// **'Join thousands of business owners who trust our platform to manage their orders and grow their business.'**
  String get joinThousandsOfBusinessOwners;

  /// No description provided for @startBusinessRegistration.
  ///
  /// In en, this message translates to:
  /// **'Start Business Registration'**
  String get startBusinessRegistration;

  /// No description provided for @completeBusinessRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Business Registration'**
  String get completeBusinessRegistration;

  /// No description provided for @setUpYourBusinessProfileWithAllNecessaryInformationAndDocuments.
  ///
  /// In en, this message translates to:
  /// **'Set up your business profile with all necessary information and documents'**
  String get setUpYourBusinessProfileWithAllNecessaryInformationAndDocuments;

  /// No description provided for @secureAndVerified.
  ///
  /// In en, this message translates to:
  /// **'Secure & Verified'**
  String get secureAndVerified;

  /// No description provided for @yourBusinessWillBeVerifiedBeforeActivationForSecurityAndTrust.
  ///
  /// In en, this message translates to:
  /// **'Your business will be verified before activation for security and trust'**
  String get yourBusinessWillBeVerifiedBeforeActivationForSecurityAndTrust;

  /// No description provided for @fullDashboardAccess.
  ///
  /// In en, this message translates to:
  /// **'Full Dashboard Access'**
  String get fullDashboardAccess;

  /// No description provided for @manageOrdersProductsAnalyticsAndBusinessSettingsInOnePlace.
  ///
  /// In en, this message translates to:
  /// **'Manage orders, products, analytics, and business settings in one place'**
  String get manageOrdersProductsAnalyticsAndBusinessSettingsInOnePlace;

  /// No description provided for @byCreatingAnAccountYouAgreeToOurTermsOfServiceAndPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms of Service and Privacy Policy. Your business information will be reviewed before activation.'**
  String get byCreatingAnAccountYouAgreeToOurTermsOfServiceAndPrivacyPolicy;

  /// No description provided for @businessDocuments.
  ///
  /// In en, this message translates to:
  /// **'Business Documents'**
  String get businessDocuments;

  /// No description provided for @uploadOptionalDocumentsToVerifyBusiness.
  ///
  /// In en, this message translates to:
  /// **'Upload optional documents to verify your business'**
  String get uploadOptionalDocumentsToVerifyBusiness;

  /// No description provided for @uploadBusinessLicenseDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload your business license document'**
  String get uploadBusinessLicenseDocument;

  /// No description provided for @uploadOwnerIdentificationDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload owner identification document'**
  String get uploadOwnerIdentificationDocument;

  /// No description provided for @uploadHealthCertificateIfApplicable.
  ///
  /// In en, this message translates to:
  /// **'Upload health certificate if applicable'**
  String get uploadHealthCertificateIfApplicable;

  /// No description provided for @uploadPhotoOfBusinessOwner.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of the business owner'**
  String get uploadPhotoOfBusinessOwner;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @merchantStatusApplicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Application Approved!'**
  String get merchantStatusApplicationApproved;

  /// No description provided for @merchantStatusApplicationUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Application Under Review'**
  String get merchantStatusApplicationUnderReview;

  /// No description provided for @merchantStatusApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application Rejected'**
  String get merchantStatusApplicationRejected;

  /// No description provided for @merchantStatusAccountSuspended.
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get merchantStatusAccountSuspended;

  /// No description provided for @merchantStatusApplicationStatus.
  ///
  /// In en, this message translates to:
  /// **'Application Status'**
  String get merchantStatusApplicationStatus;

  /// No description provided for @merchantStatusApprovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! Your merchant application has been approved. You can now start receiving orders.'**
  String get merchantStatusApprovedMessage;

  /// No description provided for @merchantStatusPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you for submitting your application. We are currently reviewing your information and will notify you once the process is complete.'**
  String get merchantStatusPendingMessage;

  /// No description provided for @merchantStatusRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unfortunately, your application has been rejected. Please review the requirements and consider reapplying.'**
  String get merchantStatusRejectedMessage;

  /// No description provided for @merchantStatusSuspendedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your merchant account has been suspended. Please contact our support team for more information.'**
  String get merchantStatusSuspendedMessage;

  /// No description provided for @merchantStatusDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Please contact support for more information about your application status.'**
  String get merchantStatusDefaultMessage;

  /// No description provided for @merchantStatusWhatHappensNext.
  ///
  /// In en, this message translates to:
  /// **'What happens next?'**
  String get merchantStatusWhatHappensNext;

  /// No description provided for @merchantStatusWhatHappensNextDescription.
  ///
  /// In en, this message translates to:
  /// **'Our team will review your application within 1-2 business days. We may contact you if additional information is needed.'**
  String get merchantStatusWhatHappensNextDescription;

  /// No description provided for @merchantStatusWhyRejected.
  ///
  /// In en, this message translates to:
  /// **'Why was my application rejected?'**
  String get merchantStatusWhyRejected;

  /// No description provided for @merchantStatusWhyRejectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Common reasons include incomplete documentation, business verification issues, or policy violations. Contact support for details.'**
  String get merchantStatusWhyRejectedDescription;

  /// No description provided for @merchantStatusAccountSuspendedInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get merchantStatusAccountSuspendedInfo;

  /// No description provided for @merchantStatusAccountSuspendedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your account has been temporarily suspended. This may be due to policy violations or security concerns. Contact support for assistance.'**
  String get merchantStatusAccountSuspendedDescription;

  /// No description provided for @merchantStatusReapply.
  ///
  /// In en, this message translates to:
  /// **'Reapply'**
  String get merchantStatusReapply;

  /// No description provided for @merchantStatusContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get merchantStatusContactSupport;

  /// No description provided for @merchantStatusBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get merchantStatusBackToLogin;

  /// No description provided for @merchantStatusSupportFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Support contact feature coming soon!'**
  String get merchantStatusSupportFeatureComingSoon;

  /// No description provided for @recaptchaVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify reCAPTCHA. Please try again.'**
  String get recaptchaVerificationFailed;

  /// No description provided for @recaptchaVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying security...'**
  String get recaptchaVerifying;

  /// No description provided for @recaptchaWebToken.
  ///
  /// In en, this message translates to:
  /// **'web-token'**
  String get recaptchaWebToken;

  /// No description provided for @recaptchaMobileToken.
  ///
  /// In en, this message translates to:
  /// **'mobile-stub-token'**
  String get recaptchaMobileToken;

  /// No description provided for @recaptchaMobilePlatformToken.
  ///
  /// In en, this message translates to:
  /// **'mobile-platform-token'**
  String get recaptchaMobilePlatformToken;

  /// No description provided for @failedToSaveWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Failed to save working hours: {error}'**
  String failedToSaveWorkingHours(Object error);

  /// No description provided for @errorCreatingBusiness.
  ///
  /// In en, this message translates to:
  /// **'Error creating business: {error}'**
  String errorCreatingBusiness(Object error);

  /// No description provided for @noBusinessAssociated.
  ///
  /// In en, this message translates to:
  /// **'No business associated with this account. Please contact support.'**
  String get noBusinessAssociated;

  /// No description provided for @accountNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Your account is not verified. Please check your email for the verification code.'**
  String get accountNotVerified;

  /// No description provided for @accountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Your account has been disabled. Please contact support for assistance.'**
  String get accountDisabled;

  /// No description provided for @tooManyLoginAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many login attempts. Please wait a few minutes and try again.'**
  String get tooManyLoginAttempts;

  /// No description provided for @networkConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your internet connection and try again.'**
  String get networkConnectionError;

  /// No description provided for @serverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server is temporarily unavailable. Please try again later.'**
  String get serverUnavailable;

  /// No description provided for @stepXOfY.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepXOfY(Object current, Object total);

  /// No description provided for @fillFormToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Fill in the form below to get started'**
  String get fillFormToGetStarted;

  /// No description provided for @pleaseEnterFirstName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your first name'**
  String get pleaseEnterFirstName;

  /// No description provided for @pleaseEnterLastName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your last name'**
  String get pleaseEnterLastName;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @pleaseEnterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterPhoneNumber;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordComplexity.
  ///
  /// In en, this message translates to:
  /// **'Password must contain uppercase, lowercase and numbers'**
  String get passwordComplexity;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmPassword;

  /// No description provided for @grocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get grocery;

  /// No description provided for @tapToUploadBusinessPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload business photo'**
  String get tapToUploadBusinessPhoto;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required field'**
  String get requiredField;

  /// No description provided for @pleaseEnterNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Please enter neighborhood'**
  String get pleaseEnterNeighborhood;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @verificationCodeMustBeSixDigits.
  ///
  /// In en, this message translates to:
  /// **'Verification code must be 6 digits'**
  String get verificationCodeMustBeSixDigits;

  /// No description provided for @verifyAndComplete.
  ///
  /// In en, this message translates to:
  /// **'Verify & Complete'**
  String get verifyAndComplete;

  /// No description provided for @youMustAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the terms and conditions'**
  String get youMustAgreeToTerms;

  /// No description provided for @verificationCodeResent.
  ///
  /// In en, this message translates to:
  /// **'Verification code resent'**
  String get verificationCodeResent;

  /// No description provided for @pleaseEnterYourFirstName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your first name'**
  String get pleaseEnterYourFirstName;

  /// No description provided for @pleaseEnterYourLastName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your last name'**
  String get pleaseEnterYourLastName;

  /// No description provided for @pleaseEnterValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get pleaseEnterValidEmailAddress;

  /// No description provided for @pleaseEnterAPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get pleaseEnterAPassword;

  /// No description provided for @passwordMustContainUpperLowerNumber.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one uppercase letter, one lowercase letter, and one number'**
  String get passwordMustContainUpperLowerNumber;

  /// No description provided for @errorPickingDocument.
  ///
  /// In en, this message translates to:
  /// **'Error picking document: {error}'**
  String errorPickingDocument(Object error);

  /// No description provided for @pleaseUploadBusinessPhoto.
  ///
  /// In en, this message translates to:
  /// **'Please upload business photo'**
  String get pleaseUploadBusinessPhoto;

  /// No description provided for @recoverYourAccountAccess.
  ///
  /// In en, this message translates to:
  /// **'Recover your account access'**
  String get recoverYourAccountAccess;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Code'**
  String get sendResetCode;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// No description provided for @verificationCodeSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Code Sent!'**
  String get verificationCodeSentTitle;

  /// No description provided for @checkSpamFolder.
  ///
  /// In en, this message translates to:
  /// **'Check your spam folder if you don\'t see the code in your inbox.'**
  String get checkSpamFolder;

  /// No description provided for @continueToVerification.
  ///
  /// In en, this message translates to:
  /// **'Continue to Verification'**
  String get continueToVerification;

  /// No description provided for @rememberYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember your password? '**
  String get rememberYourPassword;

  /// No description provided for @verificationCodeSentAgain.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent again!'**
  String get verificationCodeSentAgain;

  /// No description provided for @failedToResend.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend code'**
  String get failedToResend;

  /// No description provided for @enterVerificationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to:'**
  String get enterVerificationCodeSentTo;

  /// No description provided for @codeMustBeSixDigits.
  ///
  /// In en, this message translates to:
  /// **'Code must be 6 digits'**
  String get codeMustBeSixDigits;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @enterYourNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password'**
  String get enterYourNewPassword;

  /// No description provided for @pleaseEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password'**
  String get pleaseEnterNewPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new password'**
  String get confirmNewPassword;

  /// No description provided for @passwordResetSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password has been reset successfully!'**
  String get passwordResetSuccessfully;

  /// No description provided for @loadingDiscountManagement.
  ///
  /// In en, this message translates to:
  /// **'Loading discount management...'**
  String get loadingDiscountManagement;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @discountCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Discount created successfully'**
  String get discountCreatedSuccessfully;

  /// No description provided for @discountUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Discount updated successfully'**
  String get discountUpdatedSuccessfully;

  /// No description provided for @discountDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Discount deleted successfully'**
  String get discountDeletedSuccessfully;

  /// No description provided for @failedToCreateDiscount.
  ///
  /// In en, this message translates to:
  /// **'Failed to create discount'**
  String get failedToCreateDiscount;

  /// No description provided for @failedToUpdateDiscount.
  ///
  /// In en, this message translates to:
  /// **'Failed to update discount'**
  String get failedToUpdateDiscount;

  /// No description provided for @failedToDeleteDiscount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete discount'**
  String get failedToDeleteDiscount;

  /// No description provided for @archiveAndHistory.
  ///
  /// In en, this message translates to:
  /// **'Archive & History'**
  String get archiveAndHistory;

  /// No description provided for @viewCancelledOrders.
  ///
  /// In en, this message translates to:
  /// **'View Cancelled Orders'**
  String get viewCancelledOrders;

  /// No description provided for @viewDeliveredOrders.
  ///
  /// In en, this message translates to:
  /// **'View Delivered Orders'**
  String get viewDeliveredOrders;

  /// No description provided for @viewReturnedOrders.
  ///
  /// In en, this message translates to:
  /// **'View Returned Orders'**
  String get viewReturnedOrders;

  /// No description provided for @viewExpiredOrders.
  ///
  /// In en, this message translates to:
  /// **'View Expired Orders'**
  String get viewExpiredOrders;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @createNewProductForMenu.
  ///
  /// In en, this message translates to:
  /// **'Create a new product for your menu'**
  String get createNewProductForMenu;

  /// No description provided for @productInformation.
  ///
  /// In en, this message translates to:
  /// **'Product Information'**
  String get productInformation;

  /// No description provided for @addDetailsImagePricing.
  ///
  /// In en, this message translates to:
  /// **'Add details, image, and pricing for your new product'**
  String get addDetailsImagePricing;

  /// No description provided for @productImage.
  ///
  /// In en, this message translates to:
  /// **'Product Image'**
  String get productImage;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get changeImage;

  /// No description provided for @tapToAddProductImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to add product image'**
  String get tapToAddProductImage;

  /// No description provided for @imageFormat.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG • Max 5MB'**
  String get imageFormat;

  /// No description provided for @productDetails.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productDetails;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productName;

  /// No description provided for @enterProductName.
  ///
  /// In en, this message translates to:
  /// **'Enter product name'**
  String get enterProductName;

  /// No description provided for @enterProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter product description'**
  String get enterProductDescription;

  /// No description provided for @pleaseEnterProductName.
  ///
  /// In en, this message translates to:
  /// **'Please enter product name'**
  String get pleaseEnterProductName;

  /// No description provided for @pleaseEnterProductDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter product description'**
  String get pleaseEnterProductDescription;

  /// No description provided for @pleaseAddProductImage.
  ///
  /// In en, this message translates to:
  /// **'Please add a product image'**
  String get pleaseAddProductImage;

  /// No description provided for @productAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product added successfully!'**
  String get productAddedSuccessfully;

  /// No description provided for @failedToAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Failed to add product: {error}'**
  String failedToAddProduct(Object error);

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(Object error);

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get imageUploadFailed;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @enterPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter price'**
  String get enterPrice;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @pleaseSignInToViewOrders.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view orders'**
  String get pleaseSignInToViewOrders;

  /// No description provided for @whenOrdersComeInTheyWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'When orders come in, they\'ll appear here'**
  String get whenOrdersComeInTheyWillAppearHere;

  /// No description provided for @ordersRefreshedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Orders refreshed successfully'**
  String get ordersRefreshedSuccessfully;

  /// No description provided for @failedToRefreshOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh orders'**
  String get failedToRefreshOrders;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @viewNow.
  ///
  /// In en, this message translates to:
  /// **'VIEW NOW'**
  String get viewNow;

  /// No description provided for @viewInArchive.
  ///
  /// In en, this message translates to:
  /// **'VIEW IN ARCHIVE'**
  String get viewInArchive;

  /// No description provided for @activeProducts.
  ///
  /// In en, this message translates to:
  /// **'Active Products'**
  String get activeProducts;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get enterCurrentPassword;

  /// No description provided for @updateAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get updateAccountPassword;

  /// No description provided for @currentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Current password is required'**
  String get currentPasswordRequired;

  /// No description provided for @newPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password'**
  String get newPasswordRequired;

  /// No description provided for @passwordMustBeDifferent.
  ///
  /// In en, this message translates to:
  /// **'New password must be different from current password'**
  String get passwordMustBeDifferent;

  /// No description provided for @failedToChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get failedToChangePassword;

  /// No description provided for @changingPassword.
  ///
  /// In en, this message translates to:
  /// **'Changing Password...'**
  String get changingPassword;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get enterValidEmail;

  /// No description provided for @restaurantManagementSystem.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Management System'**
  String get restaurantManagementSystem;

  /// No description provided for @resetCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Reset code sent to your email'**
  String get resetCodeSent;

  /// No description provided for @invalidResetCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid reset code'**
  String get invalidResetCode;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successfully'**
  String get passwordResetSuccess;

  /// No description provided for @resetCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Reset code is required'**
  String get resetCodeRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful!'**
  String get loginSuccess;

  /// No description provided for @wizzBusinessManager.
  ///
  /// In en, this message translates to:
  /// **'WIZZ Business Manager'**
  String get wizzBusinessManager;

  /// No description provided for @noBusinessDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No business data available'**
  String get noBusinessDataAvailable;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @notificationsFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications feature coming soon'**
  String get notificationsFeatureComingSoon;

  /// No description provided for @settingsFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Settings feature coming soon'**
  String get settingsFeatureComingSoon;

  /// No description provided for @quickOrderFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Quick order feature coming soon'**
  String get quickOrderFeatureComingSoon;

  /// No description provided for @todaysOrders.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Orders'**
  String get todaysOrders;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @recentOrders.
  ///
  /// In en, this message translates to:
  /// **'Recent Orders'**
  String get recentOrders;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @appColorPalette.
  ///
  /// In en, this message translates to:
  /// **'App Color Palette'**
  String get appColorPalette;

  /// No description provided for @primaryYellow.
  ///
  /// In en, this message translates to:
  /// **'Primary (Yellow)'**
  String get primaryYellow;

  /// No description provided for @secondaryGold.
  ///
  /// In en, this message translates to:
  /// **'Secondary (Gold)'**
  String get secondaryGold;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @allOrders.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allOrders;

  /// No description provided for @newOrders.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newOrders;

  /// No description provided for @preparingOrders.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparingOrders;

  /// No description provided for @readyOrders.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readyOrders;

  /// No description provided for @allOrdersShownHere.
  ///
  /// In en, this message translates to:
  /// **'All orders shown here'**
  String get allOrdersShownHere;

  /// No description provided for @newOrdersShownHere.
  ///
  /// In en, this message translates to:
  /// **'New orders shown here'**
  String get newOrdersShownHere;

  /// No description provided for @ordersBeingPrepared.
  ///
  /// In en, this message translates to:
  /// **'Orders being prepared'**
  String get ordersBeingPrepared;

  /// No description provided for @readyOrdersShownHere.
  ///
  /// In en, this message translates to:
  /// **'Ready orders'**
  String get readyOrdersShownHere;

  /// No description provided for @confirmAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Account'**
  String get confirmAccountButton;

  /// No description provided for @basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// No description provided for @discountConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Discount Configuration'**
  String get discountConfiguration;

  /// No description provided for @quantityShort.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantityShort;

  /// No description provided for @merchants.
  ///
  /// In en, this message translates to:
  /// **'Merchants'**
  String get merchants;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Manage your business efficiently'**
  String get splashTagline;

  /// No description provided for @poweredByWhizz.
  ///
  /// In en, this message translates to:
  /// **'Powered by Whizz'**
  String get poweredByWhizz;

  /// No description provided for @versionNumber.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionNumber(Object version);

  /// No description provided for @accountConfirmedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account confirmed successfully! Welcome to WIZZ Business Manager.'**
  String get accountConfirmedSuccessfully;

  /// No description provided for @confirmationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit confirmation code to:'**
  String get confirmationCodeSentTo;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @loadingProducts.
  ///
  /// In en, this message translates to:
  /// **'Loading products...'**
  String get loadingProducts;

  /// No description provided for @oopsSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get oopsSomethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @yourProductCatalogAwaits.
  ///
  /// In en, this message translates to:
  /// **'Your Product Catalog Awaits!'**
  String get yourProductCatalogAwaits;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No Products Found'**
  String get noProductsFound;

  /// No description provided for @startBuildingYourMenu.
  ///
  /// In en, this message translates to:
  /// **'Start building your menu by adding your first product. Showcase what makes your {businessType} special!'**
  String startBuildingYourMenu(Object businessType);

  /// No description provided for @tryAdjustingYourSearchTerms.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search terms or check the spelling.'**
  String get tryAdjustingYourSearchTerms;

  /// No description provided for @addYourFirstProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Product'**
  String get addYourFirstProduct;

  /// No description provided for @showcaseMenu.
  ///
  /// In en, this message translates to:
  /// **'Showcase Menu'**
  String get showcaseMenu;

  /// No description provided for @displayYourOfferingsBeautifully.
  ///
  /// In en, this message translates to:
  /// **'Display your offerings beautifully'**
  String get displayYourOfferingsBeautifully;

  /// No description provided for @manageInventory.
  ///
  /// In en, this message translates to:
  /// **'Manage Inventory'**
  String get manageInventory;

  /// No description provided for @controlAvailabilityInRealTime.
  ///
  /// In en, this message translates to:
  /// **'Control availability in real-time'**
  String get controlAvailabilityInRealTime;

  /// No description provided for @trackPerformance.
  ///
  /// In en, this message translates to:
  /// **'Track Performance'**
  String get trackPerformance;

  /// No description provided for @monitorSalesAndPopularity.
  ///
  /// In en, this message translates to:
  /// **'Monitor sales and popularity'**
  String get monitorSalesAndPopularity;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @areYouSureYouWantToDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{productName}\"? This action cannot be undone.'**
  String areYouSureYouWantToDeleteProduct(Object productName);

  /// No description provided for @productDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product deleted successfully'**
  String get productDeletedSuccessfully;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @failedToDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete product: {error}'**
  String failedToDeleteProduct(Object error);

  /// No description provided for @productUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product updated successfully'**
  String get productUpdatedSuccessfully;

  /// No description provided for @failedToUpdateProduct.
  ///
  /// In en, this message translates to:
  /// **'Failed to update product: {error}'**
  String failedToUpdateProduct(Object error);

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @productIsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Product is available'**
  String get productIsAvailable;

  /// No description provided for @productIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Product is unavailable'**
  String get productIsUnavailable;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @errorSelectingImage.
  ///
  /// In en, this message translates to:
  /// **'Error selecting image: {error}'**
  String errorSelectingImage(Object error);

  /// No description provided for @errorTakingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Error taking photo: {error}'**
  String errorTakingPhoto(Object error);

  /// No description provided for @businessPhotoUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Business photo updated successfully!'**
  String get businessPhotoUpdatedSuccessfully;

  /// No description provided for @failedToUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload photo: {message}'**
  String failedToUploadPhoto(Object message);

  /// No description provided for @errorUploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Error uploading photo: {error}'**
  String errorUploadingPhoto(Object error);

  /// No description provided for @noBusinessFound.
  ///
  /// In en, this message translates to:
  /// **'No business found'**
  String get noBusinessFound;

  /// No description provided for @businessProfileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Business profile updated successfully!'**
  String get businessProfileUpdatedSuccessfully;

  /// No description provided for @failedToUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile: {error}'**
  String failedToUpdateProfile(Object error);

  /// No description provided for @pleaseSignInToAccessAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to access account settings'**
  String get pleaseSignInToAccessAccountSettings;

  /// No description provided for @loadingAccountInformation.
  ///
  /// In en, this message translates to:
  /// **'Loading account information...'**
  String get loadingAccountInformation;

  /// No description provided for @errorLoadingAccount.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Account'**
  String get errorLoadingAccount;

  /// No description provided for @noBusinessFoundForThisAccount.
  ///
  /// In en, this message translates to:
  /// **'No business found for this account'**
  String get noBusinessFoundForThisAccount;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @deliveryMethods.
  ///
  /// In en, this message translates to:
  /// **'Delivery Methods'**
  String get deliveryMethods;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @receiveNotificationsOnYourDevice.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications on your device'**
  String get receiveNotificationsOnYourDevice;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// No description provided for @receiveNotificationsViaEmail.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications via email'**
  String get receiveNotificationsViaEmail;

  /// No description provided for @smsNotifications.
  ///
  /// In en, this message translates to:
  /// **'SMS Notifications'**
  String get smsNotifications;

  /// No description provided for @receiveNotificationsViaSMS.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications via SMS (charges may apply)'**
  String get receiveNotificationsViaSMS;

  /// No description provided for @orderNotifications.
  ///
  /// In en, this message translates to:
  /// **'Order Notifications'**
  String get orderNotifications;

  /// No description provided for @getNotifiedWhenNewOrdersArrive.
  ///
  /// In en, this message translates to:
  /// **'Get notified when new orders arrive'**
  String get getNotifiedWhenNewOrdersArrive;

  /// No description provided for @orderStatusUpdates.
  ///
  /// In en, this message translates to:
  /// **'Order Status Updates'**
  String get orderStatusUpdates;

  /// No description provided for @getNotifiedWhenOrderStatusChanges.
  ///
  /// In en, this message translates to:
  /// **'Get notified when order status changes'**
  String get getNotifiedWhenOrderStatusChanges;

  /// No description provided for @paymentNotifications.
  ///
  /// In en, this message translates to:
  /// **'Payment Notifications'**
  String get paymentNotifications;

  /// No description provided for @getNotifiedAboutPaymentUpdates.
  ///
  /// In en, this message translates to:
  /// **'Get notified about payment updates'**
  String get getNotifiedAboutPaymentUpdates;

  /// No description provided for @settingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully!'**
  String get settingsSavedSuccessfully;

  /// No description provided for @failedToSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings: {error}'**
  String failedToSaveSettings(Object error);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @soundSettings.
  ///
  /// In en, this message translates to:
  /// **'Sound Settings'**
  String get soundSettings;

  /// No description provided for @enableSound.
  ///
  /// In en, this message translates to:
  /// **'Enable Sound'**
  String get enableSound;

  /// No description provided for @notificationSound.
  ///
  /// In en, this message translates to:
  /// **'Notification Sound'**
  String get notificationSound;

  /// No description provided for @defaultNotification.
  ///
  /// In en, this message translates to:
  /// **'Default Notification'**
  String get defaultNotification;

  /// No description provided for @notificationChime.
  ///
  /// In en, this message translates to:
  /// **'Notification Chime'**
  String get notificationChime;

  /// No description provided for @bell.
  ///
  /// In en, this message translates to:
  /// **'Bell'**
  String get bell;

  /// No description provided for @ding.
  ///
  /// In en, this message translates to:
  /// **'Ding'**
  String get ding;

  /// No description provided for @tone.
  ///
  /// In en, this message translates to:
  /// **'Tone'**
  String get tone;

  /// No description provided for @newOrderNotifications.
  ///
  /// In en, this message translates to:
  /// **'New Order Notifications'**
  String get newOrderNotifications;

  /// No description provided for @playSoundWhenNewOrdersArrive.
  ///
  /// In en, this message translates to:
  /// **'Play sound when new orders arrive'**
  String get playSoundWhenNewOrdersArrive;

  /// No description provided for @playSoundForOrderStatusChanges.
  ///
  /// In en, this message translates to:
  /// **'Play sound for order status changes'**
  String get playSoundForOrderStatusChanges;

  /// No description provided for @systemNotifications.
  ///
  /// In en, this message translates to:
  /// **'System Notifications'**
  String get systemNotifications;

  /// No description provided for @playSoundForSystemAlerts.
  ///
  /// In en, this message translates to:
  /// **'Play sound for system alerts and errors'**
  String get playSoundForSystemAlerts;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @vibrateDeviceForNewOrders.
  ///
  /// In en, this message translates to:
  /// **'Vibrate device for new orders'**
  String get vibrateDeviceForNewOrders;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume: {percent}%'**
  String volume(Object percent);

  /// No description provided for @testSound.
  ///
  /// In en, this message translates to:
  /// **'Test Sound'**
  String get testSound;

  /// No description provided for @playingTestSound.
  ///
  /// In en, this message translates to:
  /// **'Playing test sound...'**
  String get playingTestSound;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings Saved'**
  String get settingsSaved;

  /// No description provided for @soundNotificationPreferencesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Sound notification preferences updated successfully'**
  String get soundNotificationPreferencesUpdated;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save Failed'**
  String get saveFailed;

  /// Error message when sending verification code fails
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification code: {error}'**
  String failedToSendVerificationCode(String error);

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About the App'**
  String get aboutApp;

  /// No description provided for @appInformationAndVersion.
  ///
  /// In en, this message translates to:
  /// **'App information and version details'**
  String get appInformationAndVersion;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About WIZZ Business Manager'**
  String get aboutTitle;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'WIZZ Business Manager is a comprehensive solution designed to help restaurant owners, cafe managers, and retail store operators manage their business operations efficiently. From order management to analytics, we provide all the tools you need to grow your business.'**
  String get aboutDescription;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Key Features'**
  String get features;

  /// No description provided for @featuresDescription.
  ///
  /// In en, this message translates to:
  /// **'• Real-time order management\n• Product catalog management\n• Business analytics and insights\n• Discount and promotion management\n• Working hours configuration\n• Multi-language support\n• GPS location management\n• POS system integration'**
  String get featuresDescription;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @contactDescription.
  ///
  /// In en, this message translates to:
  /// **'For support, questions, or feedback, please reach out to us at:\nsupport@whizzecosystem.com\n\nWe\'re here to help you succeed!'**
  String get contactDescription;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get developer;

  /// No description provided for @developerInfo.
  ///
  /// In en, this message translates to:
  /// **'Developed with ❤️ by the Whizz Ecosystem team.\n\nBuilt using Flutter and powered by AWS Amplify.'**
  String get developerInfo;

  /// No description provided for @allRightsReserved.
  ///
  /// In en, this message translates to:
  /// **'All rights reserved.'**
  String get allRightsReserved;

  /// No description provided for @loadingLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading location settings...'**
  String get loadingLocationSettings;

  /// No description provided for @cityRequired.
  ///
  /// In en, this message translates to:
  /// **'City required'**
  String get cityRequired;

  /// No description provided for @streetNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Street name used for location mapping and delivery'**
  String get streetNameHelper;

  /// No description provided for @streetNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Street name is required for mapping'**
  String get streetNameRequired;

  /// No description provided for @saveLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Location Settings'**
  String get saveLocationSettings;

  /// No description provided for @locationSettingsSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Location settings saved successfully'**
  String get locationSettingsSavedSuccessfully;

  /// Error message when saving location settings fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save location settings: {error}'**
  String failedToSaveLocationSettings(String error);

  /// Error message when loading location settings fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load location settings: {error}'**
  String failedToLoadLocationSettings(String error);

  /// No description provided for @governorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get governorate;

  /// No description provided for @selectGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Select Governorate'**
  String get selectGovernorate;

  /// No description provided for @pleaseSelectGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Please select a governorate'**
  String get pleaseSelectGovernorate;

  /// No description provided for @selectNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Select Neighborhood'**
  String get selectNeighborhood;

  /// No description provided for @pleaseSelectNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Please select a neighborhood'**
  String get pleaseSelectNeighborhood;

  /// No description provided for @selectGovernorateFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a governorate first'**
  String get selectGovernorateFirst;

  /// No description provided for @selectDistrictFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a district first'**
  String get selectDistrictFirst;

  /// No description provided for @noNeighborhoodsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No neighborhoods available'**
  String get noNeighborhoodsAvailable;

  /// No description provided for @serviceUnavailableInRegion.
  ///
  /// In en, this message translates to:
  /// **'Service is currently unavailable in your region'**
  String get serviceUnavailableInRegion;

  /// No description provided for @regionValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Region validation failed'**
  String get regionValidationFailed;

  /// No description provided for @refreshRegions.
  ///
  /// In en, this message translates to:
  /// **'Refresh Regions'**
  String get refreshRegions;

  /// No description provided for @selectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Select District'**
  String get selectDistrict;

  /// No description provided for @pleaseSelectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Please select a district'**
  String get pleaseSelectDistrict;

  /// No description provided for @noDistrictsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No districts available'**
  String get noDistrictsAvailable;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @addressPreview.
  ///
  /// In en, this message translates to:
  /// **'Address Preview'**
  String get addressPreview;

  /// No description provided for @fullAddress.
  ///
  /// In en, this message translates to:
  /// **'Full Address'**
  String get fullAddress;

  /// No description provided for @coordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get viewOnMap;

  /// No description provided for @noAddressSelected.
  ///
  /// In en, this message translates to:
  /// **'Please select a complete address from the regions above'**
  String get noAddressSelected;

  /// No description provided for @supportCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'How can we help you today?'**
  String get supportCategoryTitle;

  /// No description provided for @supportCategorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a category to get started with WhizzMe AI'**
  String get supportCategorySubtitle;

  /// No description provided for @supportPoweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by WhizzMe AI'**
  String get supportPoweredBy;

  /// No description provided for @supportAiDescription.
  ///
  /// In en, this message translates to:
  /// **'Our AI assistant will help you first, then connect you to a human agent if needed.'**
  String get supportAiDescription;

  /// No description provided for @categoryOrderManagement.
  ///
  /// In en, this message translates to:
  /// **'Orders & Fulfillment'**
  String get categoryOrderManagement;

  /// No description provided for @categoryOrderManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'New orders, order status, cancellations, refunds'**
  String get categoryOrderManagementDesc;

  /// No description provided for @categoryOrderManagementExample1.
  ///
  /// In en, this message translates to:
  /// **'Not receiving orders'**
  String get categoryOrderManagementExample1;

  /// No description provided for @categoryOrderManagementExample2.
  ///
  /// In en, this message translates to:
  /// **'Order stuck in preparing'**
  String get categoryOrderManagementExample2;

  /// No description provided for @categoryOrderManagementExample3.
  ///
  /// In en, this message translates to:
  /// **'Refund request'**
  String get categoryOrderManagementExample3;

  /// No description provided for @categoryPaymentIssues.
  ///
  /// In en, this message translates to:
  /// **'Payments & Payouts'**
  String get categoryPaymentIssues;

  /// No description provided for @categoryPaymentIssuesDesc.
  ///
  /// In en, this message translates to:
  /// **'Payment methods, transaction issues, payout delays'**
  String get categoryPaymentIssuesDesc;

  /// No description provided for @categoryPaymentIssuesExample1.
  ///
  /// In en, this message translates to:
  /// **'Payout delayed'**
  String get categoryPaymentIssuesExample1;

  /// No description provided for @categoryPaymentIssuesExample2.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get categoryPaymentIssuesExample2;

  /// No description provided for @categoryPaymentIssuesExample3.
  ///
  /// In en, this message translates to:
  /// **'Commission questions'**
  String get categoryPaymentIssuesExample3;

  /// No description provided for @categoryAccountIssues.
  ///
  /// In en, this message translates to:
  /// **'Account & Login'**
  String get categoryAccountIssues;

  /// No description provided for @categoryAccountIssuesDesc.
  ///
  /// In en, this message translates to:
  /// **'Login problems, verification, profile updates'**
  String get categoryAccountIssuesDesc;

  /// No description provided for @categoryAccountIssuesExample1.
  ///
  /// In en, this message translates to:
  /// **'Cannot login'**
  String get categoryAccountIssuesExample1;

  /// No description provided for @categoryAccountIssuesExample2.
  ///
  /// In en, this message translates to:
  /// **'Account verification'**
  String get categoryAccountIssuesExample2;

  /// No description provided for @categoryAccountIssuesExample3.
  ///
  /// In en, this message translates to:
  /// **'Password reset'**
  String get categoryAccountIssuesExample3;

  /// No description provided for @categoryBusinessSetup.
  ///
  /// In en, this message translates to:
  /// **'Menu & Store Setup'**
  String get categoryBusinessSetup;

  /// No description provided for @categoryBusinessSetupDesc.
  ///
  /// In en, this message translates to:
  /// **'Menu management, store hours, business settings'**
  String get categoryBusinessSetupDesc;

  /// No description provided for @categoryBusinessSetupExample1.
  ///
  /// In en, this message translates to:
  /// **'Update menu items'**
  String get categoryBusinessSetupExample1;

  /// No description provided for @categoryBusinessSetupExample2.
  ///
  /// In en, this message translates to:
  /// **'Change store hours'**
  String get categoryBusinessSetupExample2;

  /// No description provided for @categoryBusinessSetupExample3.
  ///
  /// In en, this message translates to:
  /// **'Business verification'**
  String get categoryBusinessSetupExample3;

  /// No description provided for @categoryTechnicalSupport.
  ///
  /// In en, this message translates to:
  /// **'Technical Issues'**
  String get categoryTechnicalSupport;

  /// No description provided for @categoryTechnicalSupportDesc.
  ///
  /// In en, this message translates to:
  /// **'App crashes, notifications, sync problems'**
  String get categoryTechnicalSupportDesc;

  /// No description provided for @categoryTechnicalSupportExample1.
  ///
  /// In en, this message translates to:
  /// **'App not working'**
  String get categoryTechnicalSupportExample1;

  /// No description provided for @categoryTechnicalSupportExample2.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get categoryTechnicalSupportExample2;

  /// No description provided for @categoryTechnicalSupportExample3.
  ///
  /// In en, this message translates to:
  /// **'Sync issues'**
  String get categoryTechnicalSupportExample3;

  /// No description provided for @categoryHumanAgent.
  ///
  /// In en, this message translates to:
  /// **'Speak to Human Agent'**
  String get categoryHumanAgent;

  /// No description provided for @categoryHumanAgentDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect directly with our support team'**
  String get categoryHumanAgentDesc;

  /// No description provided for @categoryHumanAgentExample1.
  ///
  /// In en, this message translates to:
  /// **'Complex issue'**
  String get categoryHumanAgentExample1;

  /// No description provided for @categoryHumanAgentExample2.
  ///
  /// In en, this message translates to:
  /// **'Need personal assistance'**
  String get categoryHumanAgentExample2;

  /// No description provided for @categoryHumanAgentExample3.
  ///
  /// In en, this message translates to:
  /// **'Urgent matter'**
  String get categoryHumanAgentExample3;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountButton;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account?'**
  String get deleteAccountConfirmation;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete:'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountItem1.
  ///
  /// In en, this message translates to:
  /// **'Your business profile'**
  String get deleteAccountItem1;

  /// No description provided for @deleteAccountItem2.
  ///
  /// In en, this message translates to:
  /// **'All orders and history'**
  String get deleteAccountItem2;

  /// No description provided for @deleteAccountItem3.
  ///
  /// In en, this message translates to:
  /// **'Products and menu items'**
  String get deleteAccountItem3;

  /// No description provided for @deleteAccountItem4.
  ///
  /// In en, this message translates to:
  /// **'Customer reviews'**
  String get deleteAccountItem4;

  /// No description provided for @deleteAccountItem5.
  ///
  /// In en, this message translates to:
  /// **'All account data'**
  String get deleteAccountItem5;

  /// No description provided for @deleteAccountCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteAccountCannotUndo;

  /// No description provided for @verifyPassword.
  ///
  /// In en, this message translates to:
  /// **'Verify Password'**
  String get verifyPassword;

  /// No description provided for @verifyPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm account deletion'**
  String get verifyPasswordMessage;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get deletingAccount;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// No description provided for @accountDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account deleted successfully'**
  String get accountDeletedSuccessfully;

  /// No description provided for @errorDeletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Error deleting account'**
  String get errorDeletingAccount;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get incorrectPassword;

  /// No description provided for @failedToLoadOrdersPullToRetry.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders. Pull to retry.'**
  String get failedToLoadOrdersPullToRetry;

  /// No description provided for @restaurantNowAvailableForOrders.
  ///
  /// In en, this message translates to:
  /// **'Restaurant now available for orders'**
  String get restaurantNowAvailableForOrders;

  /// No description provided for @restaurantNowUnavailableForOrders.
  ///
  /// In en, this message translates to:
  /// **'Restaurant now unavailable for orders'**
  String get restaurantNowUnavailableForOrders;

  /// No description provided for @returnOrdersFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Return orders feature coming soon.'**
  String get returnOrdersFeatureComingSoon;

  /// No description provided for @failedToUpdateRestaurantStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status: {error}'**
  String failedToUpdateRestaurantStatus(String error);

  /// No description provided for @sessionExpiredPleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please login again.'**
  String get sessionExpiredPleaseLoginAgain;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
