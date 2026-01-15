// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WIZZ';

  @override
  String get welcome => 'Welcome';

  @override
  String get login => 'Login';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get reset => 'Reset';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get createAccount => 'Create Account';

  @override
  String get createBusinessAccount => 'Create Business Account';

  @override
  String get email => 'Email';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get businessName => 'Business Name';

  @override
  String get businessType => 'Business Type';

  @override
  String get businessPhoto => 'Business Photo';

  @override
  String get country => 'Country';

  @override
  String get city => 'City';

  @override
  String get neighborhood => 'Neighborhood';

  @override
  String get streetName => 'Street Name';

  @override
  String get healthCertificate => 'Health Certificate';

  @override
  String get additionalDocuments => 'Additional Documents';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get businessInformation => 'Business Information';

  @override
  String get businessAddress => 'Business Address';

  @override
  String get requiredDocuments => 'Required Documents';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInToYourAccount => 'Sign in to your account';

  @override
  String get registerYourBusiness => 'Register your business to get started';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get resendEmail => 'Resend email';

  @override
  String get createBusinessAccountButton => 'Create Business Account';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get createAStrongPassword => 'Create a strong password';

  @override
  String get confirmYourPassword => 'Confirm your password';

  @override
  String get enterYourFullName => 'Enter your full name';

  @override
  String get enterYourBusinessName => 'Enter your business name';

  @override
  String get selectYourBusinessType => 'Select your business type';

  @override
  String get uploadBusinessPhoto => 'Upload a photo of your business';

  @override
  String get enterYourCity => 'Enter your city';

  @override
  String get enterYourNeighborhood => 'Enter your neighborhood';

  @override
  String get enterYourStreetName => 'Enter your street name';

  @override
  String get uploadHealthCertificate => 'Upload your health certificate';

  @override
  String get uploadAdditionalDocuments =>
      'Upload any additional business documents';

  @override
  String get confirmYourAccount => 'Confirm Your Account';

  @override
  String get confirmationCodeSent =>
      'We\'ve sent a 6-digit confirmation code to:';

  @override
  String get confirmationCode => 'Confirmation Code';

  @override
  String get confirmationCodeHint => '123456';

  @override
  String get confirmAccount => 'Confirm Account';

  @override
  String get resendCode => 'Resend Code';

  @override
  String resendCodeIn(Object seconds) {
    return 'Resend Code in ${seconds}s';
  }

  @override
  String get backToSignUp => 'Back to Sign Up';

  @override
  String get confirmationCodeRequired => 'Confirmation code is required';

  @override
  String get confirmationCodeLength => 'Code must be 6 digits';

  @override
  String confirmationCodeResent(Object email) {
    return 'Confirmation code resent to $email';
  }

  @override
  String get invalidConfirmationCode =>
      'Invalid confirmation code. Please try again.';

  @override
  String get accountConfirmedSuccess => 'Account confirmed successfully!';

  @override
  String get enterRegisteredEmail => 'Enter your registered email';

  @override
  String get resetPasswordDescription =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get emailSentDescription =>
      'We\'ve sent a password reset link to your email address. Please check your inbox and follow the instructions.';

  @override
  String get accountReviewNotice =>
      'Your business information will be reviewed before activation.';

  @override
  String get termsAndConditionsNotice =>
      'By creating an account, you agree to our Terms of Service and Privacy Policy.';

  @override
  String get register => 'Register';

  @override
  String get forgotPassword => 'Forgot Password';

  @override
  String get forgotPasswordQuestion => 'Forgot Password?';

  @override
  String get dontHaveAnAccount => 'Don\'t have an account?';

  @override
  String get joinOrderReceiver => 'Join Order Receiver';

  @override
  String get signUpSubtitle =>
      'Create your business account to start receiving orders';

  @override
  String get accountSecurity => 'Account Security';

  @override
  String get and => 'and';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get iAgreeToThe => 'I agree to the';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get takePicture => 'Take Picture';

  @override
  String get verificationCode => 'Verification Code';

  @override
  String get verificationCodeRequired => 'Verification code is required';

  @override
  String get verifyYourEmail => 'Verify Your Email';

  @override
  String get pleaseEnterYourEmail => 'Please enter your email';

  @override
  String get pleaseEnterYourPassword => 'Please enter your password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get failedToFetchProfile => 'Failed to fetch profile';

  @override
  String get noBusinessFoundForUser => 'No business found for user';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get loginFailedMessage =>
      'Login failed. Please check your credentials.';

  @override
  String get errorInvalidCredentials =>
      'Invalid email or password. Please check your credentials and try again.';

  @override
  String get sessionConflictTitle => 'Already Signed In';

  @override
  String get sessionConflictMessage =>
      'You are already signed in. Please choose an option below.';

  @override
  String get continueCurrentSession => 'Continue with current session';

  @override
  String get signOutAndRetry => 'Sign out and try again';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutConfirmation => 'Are you sure you want to sign out?';

  @override
  String get userAlreadySignedIn => 'User is already signed in';

  @override
  String get userNotLoggedIn => 'User not logged in';

  @override
  String get forceSignInOption => 'Force sign in';

  @override
  String get sessionExpiredTitle => 'Session Expired';

  @override
  String get authenticationFailedTitle => 'Authentication Failed';

  @override
  String get systemErrorTitle => 'System Error';

  @override
  String get tooManyAttemptsTitle => 'Too Many Attempts';

  @override
  String get userNotFoundTitle => 'User Not Found';

  @override
  String get emailVerificationTitle => 'Email Verification Required';

  @override
  String get orders => 'Orders';

  @override
  String get items => 'Items';

  @override
  String get analytics => 'Analytics';

  @override
  String get discounts => 'Discounts';

  @override
  String get settings => 'Settings';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get goOnline => 'Go Online';

  @override
  String get goOffline => 'Go Offline';

  @override
  String get menu => 'Menu';

  @override
  String get retry => 'Retry';

  @override
  String get errorPickingImage => 'Error picking image';

  @override
  String get errorPickingFile => 'Error picking file';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get businessIsNowOnline => 'Business is now online';

  @override
  String get businessIsNowOffline => 'Business is now offline';

  @override
  String get businessNowOnline => 'Business is now online';

  @override
  String get businessNowOffline => 'Business is now offline';

  @override
  String get errorUpdatingStatus => 'Error updating status. Please try again.';

  @override
  String get returnOrderFeature => 'Return order feature coming soon';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsTapped => 'Notifications tapped';

  @override
  String get returnAnOrder => 'Return an Order';

  @override
  String get manageDiscounts => 'Manage Discounts';

  @override
  String get returnOrder => 'Return Order';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get posSettings => 'POS Settings';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get locationSettings => 'Location Settings';

  @override
  String get workingHoursSettings => 'Working Hours Settings';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String timeoutFirstAlert(Object remainingTime) {
    return 'Auto-reject in $remainingTime';
  }

  @override
  String timeoutUrgentAlert(Object remainingTime) {
    return 'URGENT: Reject in $remainingTime';
  }

  @override
  String get timeoutAutoReject => 'Order will be auto-rejected';

  @override
  String get openingTime => 'Opening Time';

  @override
  String get closingTime => 'Closing Time';

  @override
  String get setOpeningTime => 'Set Opening Time';

  @override
  String get setClosingTime => 'Set Closing Time';

  @override
  String get notSet => 'Not set';

  @override
  String get workingHoursSaved => 'Working hours saved successfully';

  @override
  String get setBusinessHours => 'Set your business hours';

  @override
  String get loadingWorkingHours => 'Loading working hours...';

  @override
  String get quickPresets => 'Quick Presets';

  @override
  String get applySchedulesToAllDays => 'Apply schedules to all days';

  @override
  String get regularHours => '9AM-5PM';

  @override
  String get restaurantHours => '11AM-11PM';

  @override
  String get retailHours => '10AM-10PM';

  @override
  String get copyToAllDays => 'Copy to all days';

  @override
  String get opens => 'Opens';

  @override
  String get closes => 'Closes';

  @override
  String get closed => 'Closed';

  @override
  String get saving => 'Saving...';

  @override
  String get saveWorkingHours => 'Save Working Hours';

  @override
  String appliedHoursToAllDays(Object schedule) {
    return 'Applied $schedule hours to all days';
  }

  @override
  String appliedDayHoursToAll(Object dayName) {
    return 'Applied $dayName hours to all days';
  }

  @override
  String failedToLoadWorkingHours(Object error) {
    return 'Failed to load working hours: $error';
  }

  @override
  String get businessManagement => 'Business Management';

  @override
  String get logout => 'Logout';

  @override
  String get ownerName => 'Owner Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get businessAddressLabel => 'Business Address';

  @override
  String get rating => 'Rating';

  @override
  String get changePassword => 'Change Password';

  @override
  String get accountStatus => 'Account Status';

  @override
  String get posSettingsUpdated => 'POS settings updated successfully';

  @override
  String get connectionSuccessful => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get close => 'Close';

  @override
  String get posSystemType => 'POS System Type';

  @override
  String get selectPosSystem => 'Select POS System';

  @override
  String get apiConfiguration => 'API Configuration';

  @override
  String get apiEndpoint => 'API Endpoint';

  @override
  String get pleaseEnterApiEndpoint => 'Please enter API endpoint';

  @override
  String get pleaseEnterValidUrl => 'Please enter a valid URL';

  @override
  String get apiKey => 'API Key';

  @override
  String get enterApiKey => 'Enter API Key';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get pleaseEnterApiKey => 'Please enter API key';

  @override
  String get accessToken => 'Access Token';

  @override
  String get enterAccessToken => 'Enter Access Token';

  @override
  String get locationId => 'Location ID';

  @override
  String get enterLocationId => 'Enter Location ID';

  @override
  String get posIntegrationSettings => 'POS Integration Settings';

  @override
  String get enablePosIntegration => 'Enable POS Integration';

  @override
  String get enablePosIntegrationDescription =>
      'Automatically sync orders with your POS system';

  @override
  String get autoSendOrders => 'Auto Send Orders';

  @override
  String get autoSendOrdersDescription =>
      'Automatically send new orders to POS';

  @override
  String get connectionStatus => 'Connection Status';

  @override
  String get posIntegrationEnabled => 'POS Integration Enabled';

  @override
  String get posIntegrationDisabled => 'POS Integration Disabled';

  @override
  String get system => 'System';

  @override
  String get endpoint => 'Endpoint';

  @override
  String get testing => 'Testing...';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get posSyncLogs => 'POS Sync Logs';

  @override
  String get noSyncLogsFound => 'No sync logs found';

  @override
  String get enablePosIntegrationTitle => 'Enable POS Integration';

  @override
  String get enablePosIntegrationSubtitle =>
      'Connect with your point of sale system';

  @override
  String get posSystemTypeLabel => 'POS System Type';

  @override
  String get selectPosSystemHint => 'Select your POS system';

  @override
  String get genericApi => 'Generic API';

  @override
  String get squarePos => 'Square POS';

  @override
  String get toastPos => 'Toast POS';

  @override
  String get clover => 'Clover';

  @override
  String get shopify => 'Shopify';

  @override
  String get woocommerce => 'WooCommerce';

  @override
  String get apiConfigurationTitle => 'API Configuration';

  @override
  String get apiEndpointLabel => 'API Endpoint';

  @override
  String get apiEndpointHint => 'https://api.yourpos.com/v1';

  @override
  String get apiKeyLabel => 'API Key';

  @override
  String get apiKeyHint => 'Your POS system API key';

  @override
  String get locationIdLabel => 'Location ID (Optional)';

  @override
  String get locationIdHint => 'Location or store ID';

  @override
  String get posConfigurationTitle => 'POS Configuration';

  @override
  String get testModeTitle => 'Test Mode';

  @override
  String get testModeSubtitle => 'Use sandbox/test environment';

  @override
  String get autoSendOrdersTitle => 'Auto Send Orders';

  @override
  String get autoSendOrdersSubtitle =>
      'Automatically send accepted orders to POS';

  @override
  String get autoAcceptOrdersTitle => 'Auto Accept Orders';

  @override
  String get autoAcceptOrdersSubtitle =>
      'Automatically accept all incoming orders';

  @override
  String get connectionTimeoutTitle => 'Connection Timeout';

  @override
  String connectionTimeoutSubtitle(Object timeout) {
    return '$timeout seconds';
  }

  @override
  String get testConnectionButton => 'Test Connection';

  @override
  String get saveSettingsButton => 'Save Settings';

  @override
  String get posSettingsSaved => 'POS settings saved successfully';

  @override
  String get failedToLoadPosSettings => 'Failed to load POS settings';

  @override
  String get failedToSavePosSettings => 'Failed to save POS settings';

  @override
  String get connectionTestSuccessful => 'Connection test successful!';

  @override
  String get connectionTestFailed => 'Connection test failed';

  @override
  String get apiEndpointRequired =>
      'API endpoint is required when POS is enabled';

  @override
  String get apiKeyRequired => 'API key is required when POS is enabled';

  @override
  String get general => 'General';

  @override
  String get advanced => 'Advanced';

  @override
  String get posIntegration => 'POS Integration';

  @override
  String get noSyncLogsAvailable => 'No sync logs available';

  @override
  String get syncSettings => 'Sync Settings';

  @override
  String get syncInterval => 'Sync Interval';

  @override
  String get minutes => 'minutes';

  @override
  String get status => 'Status';

  @override
  String get successful => 'Successful';

  @override
  String get failed => 'Failed';

  @override
  String get syncLogDetails => 'Sync Log Details';

  @override
  String get syncTime => 'Sync Time';

  @override
  String get posOrderId => 'POS Order ID';

  @override
  String get errorMessage => 'Error Message';

  @override
  String get retrySync => 'Retry Sync';

  @override
  String get orderSyncRetryInitiated => 'Order sync retry initiated';

  @override
  String get webhookSetupTitle => 'Webhook Setup Guide';

  @override
  String get webhookSetupDescription =>
      'Follow these steps to configure webhooks';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get contactSupportDescription =>
      'Need help with POS integration? Contact our support team';

  @override
  String get webhookConfigTitle => 'Webhook Configuration';

  @override
  String get webhookConfigDescription =>
      'Configure webhook endpoints for real-time synchronization';

  @override
  String get webhookStep1 => 'Step 1: Create webhook endpoint';

  @override
  String get webhookStep2 => 'Step 2: Configure authentication';

  @override
  String get webhookStep3 => 'Step 3: Test connection';

  @override
  String get advancedConfiguration => 'Advanced Configuration';

  @override
  String get timeoutSeconds => 'Timeout (seconds)';

  @override
  String get retryAttempts => 'Retry Attempts';

  @override
  String get testMode => 'Test Mode';

  @override
  String get testModeDescription => 'Enable test mode for development';

  @override
  String get webhooksIntegration => 'Webhooks Integration';

  @override
  String get webhooksDescription =>
      'Configure webhooks for real-time notifications';

  @override
  String get configureWebhooks => 'Configure Webhooks';

  @override
  String get securitySettings => 'Security Settings';

  @override
  String get encryptionStatus => 'Encryption Status';

  @override
  String get encryptionEnabled => 'Encryption Enabled';

  @override
  String get apiKeyRotation => 'API Key Rotation';

  @override
  String get lastRotated => 'Last Rotated';

  @override
  String get rotate => 'Rotate';

  @override
  String get systemSetupGuides => 'System Setup Guides';

  @override
  String get setupGuide => 'Setup Guide';

  @override
  String get troubleshooting => 'Troubleshooting';

  @override
  String get connectionIssues => 'Connection Issues';

  @override
  String get syncFailures => 'Sync Failures';

  @override
  String get apiErrors => 'API Errors';

  @override
  String get supportContact => 'Support Contact';

  @override
  String get liveChat => 'Live Chat';

  @override
  String get availableWeekdays => 'Available weekdays 9 AM - 5 PM';

  @override
  String get emailSupport => 'Email Support';

  @override
  String get liveChatComingSoon => 'Live chat coming soon';

  @override
  String get emailSupportOpened => 'Email support opened';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get syncLogs => 'Sync Logs';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get help => 'Help';

  @override
  String get allDiscounts => 'All Discounts';

  @override
  String get activeDiscounts => 'Active Discounts';

  @override
  String get scheduledDiscounts => 'Scheduled Discounts';

  @override
  String get expiredDiscounts => 'Expired Discounts';

  @override
  String get createDiscount => 'Create Discount';

  @override
  String get noDiscountsCreated => 'No discounts created yet';

  @override
  String get createYourFirstDiscount =>
      'Create your first discount to start attracting customers';

  @override
  String get deleteDiscount => 'Delete Discount';

  @override
  String get areYouSureYouWantToDeleteThisDiscount =>
      'Are you sure you want to delete this discount?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get editDiscount => 'Edit Discount';

  @override
  String get title => 'Title';

  @override
  String get pleaseEnterTitle => 'Please enter a title';

  @override
  String get discountType => 'Discount Type';

  @override
  String get percentage => 'Percentage';

  @override
  String get fixedAmount => 'Fixed Amount';

  @override
  String get conditional => 'Conditional';

  @override
  String get buyXGetY => 'Buy X Get Y';

  @override
  String get freeDelivery => 'Free Delivery';

  @override
  String get freeDeliveryValue => 'Free Delivery (0.0)';

  @override
  String get buyXGetYValue => 'Buy X Get Y (0.0)';

  @override
  String get conditionalValue => 'Conditional (0.0)';

  @override
  String freeDeliveryTitle(Object title) {
    return 'Free Delivery: $title';
  }

  @override
  String freeDeliveryIncludedWith(Object title) {
    return 'Free delivery included with $title';
  }

  @override
  String categoryAndPrice(Object category, Object currency, Object price) {
    return '$category • $currency $price';
  }

  @override
  String get others => 'Others';

  @override
  String get value => 'Value';

  @override
  String get pleaseEnterValue => 'Please enter a value';

  @override
  String get pleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String minimumOrderAmount(Object amount) {
    return 'Minimum order amount: $amount';
  }

  @override
  String get minimumOrder => 'Minimum Order';

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get create => 'Create';

  @override
  String get off => 'off';

  @override
  String get discount => 'discount';

  @override
  String get active => 'Active';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get expired => 'Expired';

  @override
  String get validityPeriod => 'Validity Period';

  @override
  String get unknownStatus => 'Unknown Status';

  @override
  String get sampleItem => 'Sample Item';

  @override
  String get totalSales => 'Total Sales';

  @override
  String get totalOrders => 'Total Orders';

  @override
  String get averageOrderValue => 'Average Order Value';

  @override
  String get topSellingItems => 'Top Selling Items';

  @override
  String itemSoldQuantity(Object quantity) {
    return 'Sold: $quantity';
  }

  @override
  String itemRevenue(Object revenue) {
    return 'Revenue: \$$revenue';
  }

  @override
  String get ordersByStatus => 'Orders by Status';

  @override
  String get orderStatusPending => 'Pending';

  @override
  String get orderStatusConfirmed => 'Confirmed';

  @override
  String get orderStatusPreparing => 'Preparing';

  @override
  String get orderStatusReady => 'Ready';

  @override
  String get orderStatusOnTheWay => 'On the Way';

  @override
  String get orderStatusDelivered => 'Delivered';

  @override
  String get orderStatusPickedUp => 'Picked Up';

  @override
  String get orderStatusCancelled => 'Cancelled';

  @override
  String get orderStatusReturned => 'Returned';

  @override
  String get orderStatusExpired => 'Expired';

  @override
  String get orderStatusCompleted => 'Completed';

  @override
  String get itemAddedSuccessfully => 'Item added successfully';

  @override
  String get itemUpdatedSuccessfully => 'Item updated successfully';

  @override
  String get refresh => 'Refresh';

  @override
  String get search => 'Search';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get currencyPrefix => 'IQD ';

  @override
  String get edit => 'Edit';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String get deleteItemConfirmation =>
      'Are you sure you want to delete this item?';

  @override
  String get itemDeletedSuccessfully => 'Item deleted successfully';

  @override
  String get addNewItem => 'Add New Item';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get pleaseSelectCategory => 'Please select a category';

  @override
  String get newCategoryName => 'New Category Name';

  @override
  String get pleaseEnterCategoryName => 'Please enter category name';

  @override
  String get selectExistingCategory => 'Select Existing Category';

  @override
  String get addNewCategory => 'Add New Category';

  @override
  String get itemName => 'Item Name';

  @override
  String get pleaseEnterItemName => 'Please enter item name';

  @override
  String get pleaseEnterPrice => 'Please enter price';

  @override
  String get pleaseEnterValidPrice => 'Please enter a valid price';

  @override
  String get imageUrl => 'Image URL';

  @override
  String get optional => 'Optional';

  @override
  String get available => 'Available';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get makeAvailable => 'Make Available';

  @override
  String get makeUnavailable => 'Make Unavailable';

  @override
  String get add => 'Add';

  @override
  String get editItem => 'Edit Item';

  @override
  String get update => 'Update';

  @override
  String get pending => 'Pending';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get preparing => 'Preparing';

  @override
  String get orderReady => 'Ready';

  @override
  String get onTheWay => 'On the Way';

  @override
  String get delivered => 'Delivered';

  @override
  String get pickedUp => 'Picked Up';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get orderReturned => 'Returned';

  @override
  String noOrdersFoundFor(Object filter) {
    return 'No orders found for $filter';
  }

  @override
  String get notes => 'Notes';

  @override
  String get total => 'Total';

  @override
  String get reject => 'Reject';

  @override
  String get accept => 'Accept';

  @override
  String get required => 'Required';

  @override
  String get changeFile => 'Change File';

  @override
  String get selectFile => 'Select File';

  @override
  String get restaurant => 'Restaurant';

  @override
  String get store => 'Store';

  @override
  String get pharmacy => 'Pharmacy';

  @override
  String get cloudKitchen => 'Cloud Kitchen';

  @override
  String get cafe => 'Cafe';

  @override
  String get bakery => 'Bakery';

  @override
  String get herbalspices => 'Herbal & Spices';

  @override
  String get cosmetics => 'Cosmetics';

  @override
  String get betshop => 'Bet Shop';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get registrationSubmitted => 'Registration Submitted';

  @override
  String get registrationSubmittedMessage =>
      'Your registration has been submitted for review';

  @override
  String get nameLabel => 'Name';

  @override
  String get typeLabel => 'Type';

  @override
  String get notSelected => 'Not Selected';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get addressLabel => 'Address';

  @override
  String get countryLabel => 'Country';

  @override
  String get cityLabel => 'City';

  @override
  String get districtLabel => 'District';

  @override
  String get neighbourhoodLabel => 'Neighbourhood';

  @override
  String get streetLabel => 'Street';

  @override
  String get buildingHomeLabel => 'Building/Home';

  @override
  String get zipCodeLabel => 'Zip Code';

  @override
  String get businessOwnerInformation => 'Business Owner Information';

  @override
  String get nationalIdLabel => 'National ID';

  @override
  String get dateOfBirthLabel => 'Date of Birth';

  @override
  String get registrationSuccessLogin =>
      'Registration successful! You can now log in with your credentials.';

  @override
  String get gettingYourLocation => 'Getting your location...';

  @override
  String get locationPermissionDeniedForever =>
      'Location permission denied permanently';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationServicesDisabled => 'Location services are disabled';

  @override
  String get couldNotDeterminePlacemark => 'Could not determine placemark';

  @override
  String get businessRegistration => 'Business Registration';

  @override
  String get welcomeToHadhir => 'Welcome to Hadhir';

  @override
  String get fillInTheFormBelowToGetStarted =>
      'Fill in the form below to get started';

  @override
  String get createYourBusinessAccount => 'Create Your Business Account';

  @override
  String get tapToUpload => 'Tap to upload';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get businessAndOwnerInformation => 'Business and Owner Information';

  @override
  String get selectBusinessType => 'Please select a business type';

  @override
  String get pleaseEnterBusinessName => 'Please enter business name';

  @override
  String get pleaseEnterOwnerName => 'Please enter owner name';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get firstNameRequired => 'First name is required';

  @override
  String get lastNameRequired => 'Last name is required';

  @override
  String get invalidEmailFormat => 'Please enter a valid email address';

  @override
  String get phoneNumberRequired => 'Phone number is required';

  @override
  String get businessNameRequired => 'Business name is required';

  @override
  String get pleaseEnterYourBusinessName => 'Please enter your business name';

  @override
  String get streetAddress => 'Street Address';

  @override
  String get state => 'State/Province';

  @override
  String get zipCode => 'ZIP/Postal Code';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get weakPassword => 'Password is too weak';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get registrationSuccess => 'Registration successful';

  @override
  String get emailAlreadyInUse => 'Email address is already in use';

  @override
  String get passwordResetLinkSent => 'Password reset link sent to your email';

  @override
  String get welcomeToOrderReceiver => 'Welcome to Order Receiver';

  @override
  String get welcomeDescription =>
      'Manage your business orders efficiently with our powerful order management system.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get testRegistrationForm => 'Test Registration Form';

  @override
  String get networkError => 'Network error. Please check your connection.';

  @override
  String get returnOrderTitle => 'Return Order';

  @override
  String get enterOrderNumber => 'Enter Order Number';

  @override
  String get orderNotFound => 'Order Not Found';

  @override
  String get orderReturnedSuccessfully => 'Order Returned Successfully';

  @override
  String get locationSaved => 'Location Saved';

  @override
  String get businessLocation => 'Business Location';

  @override
  String get locationSet => 'Location Set';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get updateLocation => 'Update Location';

  @override
  String get noLocationSet => 'No Location Set';

  @override
  String get chooseLocationOnMap => 'Choose Location on Map';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get enableLocationServices => 'Enable Location Services';

  @override
  String get locationNotSelected => 'Location Not Selected';

  @override
  String get confirmLocation => 'Confirm Location';

  @override
  String get tapToSelectLocation => 'Tap to Select Location';

  @override
  String get registrationDate => 'Registration Date';

  @override
  String get failedToSaveLocation => 'Failed to save location';

  @override
  String get businessLocationDescription =>
      'Set your business location to help customers find you and improve delivery accuracy.';

  @override
  String get locationInformation => 'Location Information';

  @override
  String get customerVisibility => 'Customer Visibility';

  @override
  String get customerVisibilityDescription =>
      'Your location will be shown to customers when they place orders';

  @override
  String get deliveryOptimization => 'Delivery Optimization';

  @override
  String get deliveryOptimizationDescription =>
      'Accurate location helps optimize delivery routes and timing';

  @override
  String get privacyAndSecurity => 'Privacy & Security';

  @override
  String get privacyAndSecurityDescription =>
      'Your location data is encrypted and securely stored';

  @override
  String get pleaseSignInToAccessLocationSettings =>
      'Please sign in to access location settings';

  @override
  String get smartBusinessControls => 'Smart business controls';

  @override
  String get readyToReceiveOrders => 'Ready to receive orders';

  @override
  String get ordersArePaused => 'Orders are paused';

  @override
  String get menuItemsAndCategories => 'Menu items & categories';

  @override
  String get businessInsights => 'Business Insights';

  @override
  String get offersAndPromotions => 'Offers & promotions';

  @override
  String get appConfiguration => 'App configuration';

  @override
  String get changeAppLanguage => 'Change app language';

  @override
  String get cancelRecentOrder => 'Cancel recent order';

  @override
  String get tapOutsideOrPressEscToClose => 'Tap outside or press ESC to close';

  @override
  String get languageChangedToArabic => 'تم تغيير اللغة إلى العربية';

  @override
  String get languageChangedToEnglish => 'Language changed to English';

  @override
  String get managePromotionalOffers => 'Manage promotional offers';

  @override
  String get viewBusinessInsights => 'View business insights';

  @override
  String get manageItemsAndCategories => 'Manage items & categories';

  @override
  String get platformIntegration => 'Platform Integration';

  @override
  String get centralizedDeliveryPlatform => 'Centralized delivery platform';

  @override
  String get appAndAccountPreferences => 'App & account preferences';

  @override
  String get keyboardShortcutsTip =>
      'Tip: Use keyboard shortcuts for faster actions';

  @override
  String get conditionalDiscountConfiguration =>
      'Conditional Discount Configuration';

  @override
  String get buyXGetYConfiguration => 'Buy X Get Y Configuration';

  @override
  String get buyConfiguration => 'Buy Configuration';

  @override
  String get getConfiguration => 'Get Configuration';

  @override
  String get selectItem => 'Select Item';

  @override
  String get itemSelected => 'Item Selected';

  @override
  String get enterValidQuantity => 'Enter valid quantity';

  @override
  String get missingItems => 'Missing Items';

  @override
  String pleasSelectBothBuyAndGetItems(Object discountType) {
    return 'Please select both buy and get items for $discountType discount.';
  }

  @override
  String get ok => 'OK';

  @override
  String get addFreeDeliveryToDiscount => 'Add free delivery to this discount';

  @override
  String get conflictingDiscountsTitle => 'Conflicting Discounts';

  @override
  String get someSelectedItemsAlreadyHaveDiscounts =>
      'Some selected items or categories already have active discounts. Each item can only have one discount at a time.';

  @override
  String get applicabilityNotConfigurable =>
      'Applicability is not configurable for this discount type as items are already specified in the configuration above.';

  @override
  String get noItemSelected => 'No item selected';

  @override
  String get appliesToAllItems => 'Applies to all items';

  @override
  String appliesToSpecificItems(Object count) {
    return 'Applies to $count specific items';
  }

  @override
  String appliesToCategories(Object count) {
    return 'Applies to $count categories';
  }

  @override
  String get appliesToOrdersAboveMinimum =>
      'Applies to orders above minimum amount';

  @override
  String validFromTo(Object endDay, Object endMonth, Object endYear,
      Object startDay, Object startMonth, Object startYear) {
    return 'Valid: $startDay/$startMonth/$startYear - $endDay/$endMonth/$endYear';
  }

  @override
  String minAmount(Object amount) {
    return 'Min: \$$amount';
  }

  @override
  String categoriesSelected(Object count) {
    return '$count categories selected';
  }

  @override
  String itemsSelected(Object count) {
    return '$count items selected';
  }

  @override
  String missingItemsMessage(Object discountType) {
    return 'Please select both buy and get items for $discountType discount.';
  }

  @override
  String get selectBuyItem => 'Select Buy Item';

  @override
  String get selectGetItem => 'Select Get Item';

  @override
  String get noCategoriesFound =>
      'No categories found. Please add categories first.';

  @override
  String get appliesToMinimumOrder => 'Applies to orders above minimum amount';

  @override
  String get startSimulation => 'Start Simulation';

  @override
  String get stopSimulation => 'Stop Simulation';

  @override
  String get simulateNewOrder => 'Simulate New Order';

  @override
  String get newOrder => 'New Order';

  @override
  String get newOrderArrived => 'NEW ORDER ARRIVED!';

  @override
  String get fromLabel => 'From';

  @override
  String get failedToUpdateOrder => 'Failed to update order';

  @override
  String get orderRejectedByMerchant => 'Order rejected by merchant';

  @override
  String get orderHashtag => 'Order #';

  @override
  String get viewDetails => 'View Details';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get live => 'Live';

  @override
  String get sendTestNotification => 'Send Test Notification';

  @override
  String get showLocalNotifications => 'Show Local Notifications';

  @override
  String get showLocalNotificationsDescription =>
      'Display notifications on this device';

  @override
  String get playNotificationSounds => 'Play Notification Sounds';

  @override
  String get playNotificationSoundsDescription =>
      'Play sounds when notifications are received';

  @override
  String get testNotifications => 'Test Notifications';

  @override
  String get testNotificationDescription =>
      'Send a test notification to verify settings';

  @override
  String get notConnectedToNotifications =>
      'Not connected to real-time notifications';

  @override
  String get unread => 'Unread';

  @override
  String get highPriority => 'High Priority';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get newOrderNotificationsAppearHere =>
      'New order notifications will appear here';

  @override
  String get clearAllNotifications => 'Clear All Notifications';

  @override
  String get testNotificationSentSuccessfully =>
      'Test notification sent successfully';

  @override
  String failedToSendTestNotification(Object error) {
    return 'Failed to send test notification: $error';
  }

  @override
  String failedToConnectToNotifications(Object error) {
    return 'Failed to connect to notifications: $error';
  }

  @override
  String get view => 'View';

  @override
  String get urgent => 'urgent';

  @override
  String get high => 'high';

  @override
  String get normal => 'normal';

  @override
  String get low => 'low';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(Object hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(Object days) {
    return '${days}d ago';
  }

  @override
  String get today => 'Today';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get overview => 'Overview';

  @override
  String get performance => 'Performance';

  @override
  String get reviewsAndInsights => 'Reviews & Insights';

  @override
  String get customerReviews => 'Customer Reviews';

  @override
  String get leastOrderedItems => 'Least Ordered Items';

  @override
  String get leastOrderedItemsDescription =>
      'Items that need more attention or promotion';

  @override
  String get growingPopularity => 'Growing Popularity';

  @override
  String get customerSatisfaction => 'Customer Satisfaction';

  @override
  String get efficientService => 'Efficient Service';

  @override
  String get customerBase => 'Customer Base';

  @override
  String get bestPerformer => 'Best Performer';

  @override
  String get needsAttention => 'Needs Attention';

  @override
  String get revenueLabel => 'Revenue';

  @override
  String growingPopularityDescription(Object growthRate) {
    return 'Your business has a $growthRate% growth rate this month';
  }

  @override
  String customerSatisfactionDescription(
      Object averageRating, Object totalReviews) {
    return 'Average rating of $averageRating/5.0 from $totalReviews reviews';
  }

  @override
  String efficientServiceDescription(Object averagePreparationTime) {
    return 'Average preparation time: $averagePreparationTime minutes';
  }

  @override
  String customerBaseDescription(
      Object cancellationRate, Object customersServed) {
    return 'Served $customersServed customers with $cancellationRate% cancellation rate';
  }

  @override
  String quickInsightSoldCount(Object quantity) {
    return '$quantity sold';
  }

  @override
  String onlySoldCount(Object quantity) {
    return 'Only $quantity sold';
  }

  @override
  String get revenueTrend => 'Revenue Trend';

  @override
  String get quickStats => 'Quick Stats';

  @override
  String get revenueBreakdown => 'Revenue Breakdown';

  @override
  String get dailyRevenue => 'Daily Revenue';

  @override
  String get weeklyRevenue => 'Weekly Revenue';

  @override
  String get monthlyRevenue => 'Monthly Revenue';

  @override
  String get performanceMetrics => 'Performance Metrics';

  @override
  String get avgPrepTime => 'Avg. Prep Time';

  @override
  String get successRate => 'Success Rate';

  @override
  String get specialDish => 'Special Dish';

  @override
  String get popularItem => 'Popular Item';

  @override
  String get totalRevenue => 'Total Revenue';

  @override
  String get todaysRevenue => 'Today\'s Revenue';

  @override
  String get avgOrderValue => 'Avg. Order Value';

  @override
  String get upload => 'Upload';

  @override
  String get tapToSelectFile => 'Tap to select file';

  @override
  String get requiredPleaseAddAPhoto => 'Required. Please add a photo.';

  @override
  String get change => 'Change';

  @override
  String get addPhoto => 'Add Photo';

  @override
  String get pleaseFillInAllRequiredFields =>
      'Please fill in all required fields.';

  @override
  String get businessPhotoIsRequired => 'Business photo is required.';

  @override
  String get businessLicenseRequired => 'Business license is required.';

  @override
  String get ownerIdentityRequired => 'Owner identity is required.';

  @override
  String get healthCertificateRequired => 'Health certificate is required.';

  @override
  String get ownerPhotoRequired => 'Owner photo is required.';

  @override
  String get loginInstead => 'Login Instead';

  @override
  String get failedToUploadBusinessPhoto => 'Failed to upload business photo';

  @override
  String get errorUploadingBusinessPhoto => 'Error uploading business photo';

  @override
  String get failedToUploadBusinessLicense =>
      'Failed to upload business license';

  @override
  String get failedToUploadOwnerIdentity => 'Failed to upload owner identity';

  @override
  String get failedToUploadHealthCertificate =>
      'Failed to upload health certificate';

  @override
  String get failedToUploadOwnerPhoto => 'Failed to upload owner photo';

  @override
  String get errorUploadingDocuments => 'Error uploading documents';

  @override
  String get registrationInitiated => 'Registration initiated';

  @override
  String get registrationCompletedSuccessfully =>
      'Registration completed successfully';

  @override
  String get verificationFailed => 'Verification failed';

  @override
  String get selectImageSource => 'Select Image Source';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String verificationCodeSentTo(Object email) {
    return 'Verification code sent to $email';
  }

  @override
  String get applicationPending => 'Application Pending';

  @override
  String get applicationPendingDescription =>
      'Your application is pending approval.';

  @override
  String get applicationApproved => 'Application Approved';

  @override
  String get applicationApprovedDescription =>
      'Your application has been approved.';

  @override
  String get applicationRejected => 'Application Rejected';

  @override
  String get applicationRejectedDescription =>
      'Your application has been rejected.';

  @override
  String get underReview => 'Under Review';

  @override
  String get underReviewDescription => 'Your application is under review.';

  @override
  String get statusUnknown => 'Status Unknown';

  @override
  String get statusUnknownDescription =>
      'The status of your application is unknown.';

  @override
  String get applicationStatus => 'Application Status';

  @override
  String get accountApproved => 'Account Approved';

  @override
  String get accountSuspended => 'Account Suspended';

  @override
  String get accountApprovedMessage =>
      'Your merchant account has been approved. You can now start using the platform.';

  @override
  String get applicationPendingMessage =>
      'Your application is being reviewed. We will notify you once the review is complete.';

  @override
  String get applicationRejectedMessage =>
      'Your application has been rejected. Please contact support for more information.';

  @override
  String get accountSuspendedMessage =>
      'Your account has been suspended. Please contact support to resolve this issue.';

  @override
  String get unknownStatusMessage =>
      'Unknown status detected. Please contact support.';

  @override
  String get needHelp => 'Need Help?';

  @override
  String get contactSupportMessage =>
      'Contact our support team if you have any questions.';

  @override
  String get chatWithSupport => 'Chat with Support';

  @override
  String get supportInformation => 'Support Information';

  @override
  String get completeRegistrationForChat =>
      'To access live chat support, please complete your merchant registration and login.';

  @override
  String get forImmediateAssistance =>
      'For immediate assistance, please contact:';

  @override
  String get supportEmail => 'wizzappdev@outlook.com';

  @override
  String get supportPhone => '07831367435';

  @override
  String get discountApplicability => 'Discount Applicability';

  @override
  String get allItems => 'All Items';

  @override
  String get specificItems => 'Specific Items';

  @override
  String get specificCategories => 'Specific Categories';

  @override
  String get selectItems => 'Select Items';

  @override
  String get noItemsSelected => 'No items selected';

  @override
  String get selectCategories => 'Select Categories';

  @override
  String get noCategoriesSelected => 'No categories selected';

  @override
  String get conflictingDiscounts => 'Conflicting Discounts';

  @override
  String get kwd => 'KWD';

  @override
  String get categories => 'categories';

  @override
  String get notSpecified => 'Not Specified';

  @override
  String get verified => 'Verified';

  @override
  String get viewAndManageOrders => 'View and manage orders';

  @override
  String get businessDashboardVersion => 'Business Dashboard Version';

  @override
  String get modernMaterialDesign => 'Modern Material Design';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get businessLicense => 'Business License';

  @override
  String get ownerIdentity => 'Owner Identity';

  @override
  String get ownerPhoto => 'Owner Photo';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get kitchen => 'Kitchen';

  @override
  String get chooseFromFiles => 'Choose from Files';

  @override
  String get accountInformation => 'Account Information';

  @override
  String get pleaseEnterAValidEmail => 'Please enter a valid email';

  @override
  String get passwordMustBeAtLeast8Chars =>
      'Password must be at least 8 characters';

  @override
  String get reEnterYourPassword => 'Re-enter your password';

  @override
  String get enterOwnerName => 'Enter owner name';

  @override
  String get ownerFirstName => 'Owner First Name';

  @override
  String get enterOwnerFirstName => 'Enter owner first name';

  @override
  String get pleaseEnterOwnerFirstName => 'Please enter owner first name';

  @override
  String get ownerLastName => 'Owner Last Name';

  @override
  String get enterOwnerLastName => 'Enter owner last name';

  @override
  String get pleaseEnterOwnerLastName => 'Please enter owner last name';

  @override
  String get enterYourBusinessPhone => 'Enter your business phone';

  @override
  String get pleaseEnterYourPhoneNumber => 'Please enter your phone number';

  @override
  String get addAPhotoToShowcaseYourBusiness =>
      'Add a photo to showcase your business';

  @override
  String get pleaseEnterYourCity => 'Please enter your city';

  @override
  String get district => 'District';

  @override
  String get enterYourDistrict => 'Enter your district';

  @override
  String get pleaseEnterYourDistrict => 'Please enter your district';

  @override
  String get enterYourStreetAddress => 'Enter your street address';

  @override
  String get pleaseEnterYourStreetAddress => 'Please enter your street address';

  @override
  String get documentsRequired => 'Documents Required';

  @override
  String get pleaseUploadAllRequiredDocuments =>
      'Please upload all required documents';

  @override
  String get emailVerification => 'Email Verification';

  @override
  String get enterTheCodeSentToYourEmail => 'Enter the code sent to your email';

  @override
  String get changeEmail => 'Change Email';

  @override
  String get enter6DigitCode => 'Enter 6-digit code';

  @override
  String get enterVerificationCode => 'Enter verification code';

  @override
  String get pleaseEnterVerificationCode => 'Please enter verification code';

  @override
  String get pleaseEnterTheVerificationCode =>
      'Please enter the verification code';

  @override
  String get verificationCodeSent => 'Verification code sent to your email';

  @override
  String get resendVerificationCode => 'Resend Verification Code';

  @override
  String get failedToResendCode => 'Failed to resend verification code';

  @override
  String get troubleshootingSection => 'Troubleshooting';

  @override
  String get passwordChangedSuccessfully => 'Password changed successfully';

  @override
  String get completeRegistration => 'Complete Registration';

  @override
  String get none => 'None';

  @override
  String get account => 'Account';

  @override
  String get business => 'Business';

  @override
  String get location => 'Location';

  @override
  String get documents => 'Documents';

  @override
  String get createYourAccount => 'Create Your Account';

  @override
  String get enterAccountDetails => 'Enter your account details to get started';

  @override
  String get tellUsAboutYourBusiness => 'Tell us about your business';

  @override
  String get whereIsYourBusiness => 'Where is your business located?';

  @override
  String get uploadDocumentsOptional =>
      'Upload documents to verify your business (optional)';

  @override
  String get selectSubcategory => 'Select Subcategory (Optional)';

  @override
  String get businessSubcategory => 'Business Subcategory (Optional)';

  @override
  String get uploadBusinessLicense => 'Upload your business license';

  @override
  String get identityDocument => 'Identity Document';

  @override
  String get uploadIdentityDocument => 'Upload your identity document';

  @override
  String get uploadOwnerPhoto => 'Upload a photo of the owner';

  @override
  String get enterCountry => 'Enter your country';

  @override
  String get pleaseEnterCountry => 'Please enter your country';

  @override
  String get enterCity => 'Enter your city';

  @override
  String get pleaseEnterCity => 'Please enter your city';

  @override
  String get enterDistrict => 'Enter your district';

  @override
  String get pleaseEnterDistrict => 'Please enter your district';

  @override
  String get enterStreetAddress => 'Enter your street address';

  @override
  String get pleaseEnterStreetAddress => 'Please enter your street address';

  @override
  String get registrationSuccessful =>
      'Registration successful! Welcome to Hadhir Business.';

  @override
  String get registrationVerifiedSuccessfully =>
      'Registration verified successfully!';

  @override
  String verificationFailedWithReason(Object reason) {
    return 'Verification failed: $reason';
  }

  @override
  String get verificationCodeSentToEmail =>
      'Verification code sent to your email';

  @override
  String registrationFailedWithReason(Object reason) {
    return 'Registration failed: $reason';
  }

  @override
  String get confirm => 'Confirm';

  @override
  String get didntReceiveCode => 'Didn\'t receive the code?';

  @override
  String get wrongEmailChangeIt => 'Wrong email? Change it';

  @override
  String get verificationCodeMustBe6Digits =>
      'Verification code must be 6 digits';

  @override
  String get accountAlreadyVerifiedPleaseSignIn =>
      'Account already verified. Please sign in.';

  @override
  String get tooManyAttemptsPleaseWait =>
      'Too many attempts. Please wait and try again.';

  @override
  String get noAccountFoundForThisEmail => 'No account found for this email.';

  @override
  String get mustAgreeToTerms => 'You must agree to the terms and conditions';

  @override
  String get passwordRequirementsTitle => 'Password Requirements';

  @override
  String get passwordRequirementsBullets =>
      '• At least 8 characters\\n• Include uppercase, lowercase, numbers, and a special character';

  @override
  String get changeEmailAddressTitle => 'Change Email Address';

  @override
  String get changeEmailAddressMessage =>
      'Are you sure you want to change your email address? This will take you back to the sign-up screen.';

  @override
  String get invalidIraqiPhoneNumber =>
      'Please enter a valid Iraqi number (77X/78X/79X for mobile)';

  @override
  String get centralizedPlatform => 'Centralized Platform';

  @override
  String get platformConnection => 'Platform Connection';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get syncStatus => 'Sync Status';

  @override
  String get platformApps => 'Platform Apps';

  @override
  String get localBusinesses => 'Local Businesses';

  @override
  String get syncRecommended => 'Sync Recommended';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get unknown => 'Unknown';

  @override
  String get actions => 'Actions';

  @override
  String get setupPlatform => 'Setup Platform';

  @override
  String get syncAllBusinesses => 'Sync All Businesses';

  @override
  String get refreshStatus => 'Refresh Status';

  @override
  String get failedToLoadPlatformStatus => 'Failed to load platform status';

  @override
  String get platformSetupCompletedSuccessfully =>
      'Platform setup completed successfully';

  @override
  String get platformSetupFailed => 'Platform setup failed';

  @override
  String get errorSettingUpPlatform => 'Error setting up platform';

  @override
  String get allBusinessesSyncedSuccessfully =>
      'All businesses synced successfully';

  @override
  String get failedToSyncAllBusinessesToPlatform =>
      'Failed to sync all businesses to platform';

  @override
  String get errorSyncingBusinesses => 'Error syncing businesses';

  @override
  String get noAppsFound => 'No apps found';

  @override
  String get businessDetails => 'Business Details';

  @override
  String get manageYourBusinessProfileAndInformation =>
      'Manage your business profile and information';

  @override
  String get manageYourPersonalInformation =>
      'Manage your personal information';

  @override
  String get updateYourPasswordAndSecurity =>
      'Update your password and security';

  @override
  String get changeAppLanguagePreference => 'Change app language preference';

  @override
  String get selectYourPreferredLanguage => 'Select your preferred language';

  @override
  String get languageChangedSuccessfully => 'Language changed successfully';

  @override
  String get configurePointOfSaleIntegration =>
      'Configure point of sale integration';

  @override
  String get soundNotifications => 'Sound Notifications';

  @override
  String get configureSoundAlertsForNewOrdersAndUpdates =>
      'Configure sound alerts for new orders and updates';

  @override
  String get manageNotificationPreferencesAndDeliveryMethods =>
      'Manage notification preferences and delivery methods';

  @override
  String get manageBusinessLocationAndGpsCoordinates =>
      'Manage business location and GPS coordinates';

  @override
  String get setUpOpeningAndClosingHoursForYourBusiness =>
      'Set up opening and closing hours for your business';

  @override
  String get discountManagement => 'Discount Management';

  @override
  String get createAndManageYourDiscounts => 'Create and manage your discounts';

  @override
  String get reviews => 'Reviews';

  @override
  String get joinThousandsOfBusinessOwners =>
      'Join thousands of business owners who trust our platform to manage their orders and grow their business.';

  @override
  String get startBusinessRegistration => 'Start Business Registration';

  @override
  String get completeBusinessRegistration => 'Complete Business Registration';

  @override
  String get setUpYourBusinessProfileWithAllNecessaryInformationAndDocuments =>
      'Set up your business profile with all necessary information and documents';

  @override
  String get secureAndVerified => 'Secure & Verified';

  @override
  String get yourBusinessWillBeVerifiedBeforeActivationForSecurityAndTrust =>
      'Your business will be verified before activation for security and trust';

  @override
  String get fullDashboardAccess => 'Full Dashboard Access';

  @override
  String get manageOrdersProductsAnalyticsAndBusinessSettingsInOnePlace =>
      'Manage orders, products, analytics, and business settings in one place';

  @override
  String get byCreatingAnAccountYouAgreeToOurTermsOfServiceAndPrivacyPolicy =>
      'By creating an account, you agree to our Terms of Service and Privacy Policy. Your business information will be reviewed before activation.';

  @override
  String get businessDocuments => 'Business Documents';

  @override
  String get uploadOptionalDocumentsToVerifyBusiness =>
      'Upload optional documents to verify your business';

  @override
  String get uploadBusinessLicenseDocument =>
      'Upload your business license document';

  @override
  String get uploadOwnerIdentificationDocument =>
      'Upload owner identification document';

  @override
  String get uploadHealthCertificateIfApplicable =>
      'Upload health certificate if applicable';

  @override
  String get uploadPhotoOfBusinessOwner =>
      'Upload a photo of the business owner';

  @override
  String get previous => 'Previous';

  @override
  String get merchantStatusApplicationApproved => 'Application Approved!';

  @override
  String get merchantStatusApplicationUnderReview => 'Application Under Review';

  @override
  String get merchantStatusApplicationRejected => 'Application Rejected';

  @override
  String get merchantStatusAccountSuspended => 'Account Suspended';

  @override
  String get merchantStatusApplicationStatus => 'Application Status';

  @override
  String get merchantStatusApprovedMessage =>
      'Congratulations! Your merchant application has been approved. You can now start receiving orders.';

  @override
  String get merchantStatusPendingMessage =>
      'Thank you for submitting your application. We are currently reviewing your information and will notify you once the process is complete.';

  @override
  String get merchantStatusRejectedMessage =>
      'Unfortunately, your application has been rejected. Please review the requirements and consider reapplying.';

  @override
  String get merchantStatusSuspendedMessage =>
      'Your merchant account has been suspended. Please contact our support team for more information.';

  @override
  String get merchantStatusDefaultMessage =>
      'Please contact support for more information about your application status.';

  @override
  String get merchantStatusWhatHappensNext => 'What happens next?';

  @override
  String get merchantStatusWhatHappensNextDescription =>
      'Our team will review your application within 1-2 business days. We may contact you if additional information is needed.';

  @override
  String get merchantStatusWhyRejected => 'Why was my application rejected?';

  @override
  String get merchantStatusWhyRejectedDescription =>
      'Common reasons include incomplete documentation, business verification issues, or policy violations. Contact support for details.';

  @override
  String get merchantStatusAccountSuspendedInfo => 'Account Suspended';

  @override
  String get merchantStatusAccountSuspendedDescription =>
      'Your account has been temporarily suspended. This may be due to policy violations or security concerns. Contact support for assistance.';

  @override
  String get merchantStatusReapply => 'Reapply';

  @override
  String get merchantStatusContactSupport => 'Contact Support';

  @override
  String get merchantStatusBackToLogin => 'Back to Login';

  @override
  String get merchantStatusSupportFeatureComingSoon =>
      'Support contact feature coming soon!';

  @override
  String get recaptchaVerificationFailed =>
      'Could not verify reCAPTCHA. Please try again.';

  @override
  String get recaptchaVerifying => 'Verifying security...';

  @override
  String get recaptchaWebToken => 'web-token';

  @override
  String get recaptchaMobileToken => 'mobile-stub-token';

  @override
  String get recaptchaMobilePlatformToken => 'mobile-platform-token';

  @override
  String failedToSaveWorkingHours(Object error) {
    return 'Failed to save working hours: $error';
  }

  @override
  String errorCreatingBusiness(Object error) {
    return 'Error creating business: $error';
  }

  @override
  String get noBusinessAssociated =>
      'No business associated with this account. Please contact support.';

  @override
  String get accountNotVerified =>
      'Your account is not verified. Please check your email for the verification code.';

  @override
  String get accountDisabled =>
      'Your account has been disabled. Please contact support for assistance.';

  @override
  String get tooManyLoginAttempts =>
      'Too many login attempts. Please wait a few minutes and try again.';

  @override
  String get networkConnectionError =>
      'Network error. Please check your internet connection and try again.';

  @override
  String get serverUnavailable =>
      'Server is temporarily unavailable. Please try again later.';

  @override
  String stepXOfY(Object current, Object total) {
    return 'Step $current of $total';
  }

  @override
  String get fillFormToGetStarted => 'Fill in the form below to get started';

  @override
  String get pleaseEnterFirstName => 'Please enter your first name';

  @override
  String get pleaseEnterLastName => 'Please enter your last name';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterPhoneNumber => 'Please enter your phone number';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get passwordComplexity =>
      'Password must contain uppercase, lowercase and numbers';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password';

  @override
  String get grocery => 'Grocery';

  @override
  String get tapToUploadBusinessPhoto => 'Tap to upload business photo';

  @override
  String get requiredField => 'Required field';

  @override
  String get pleaseEnterNeighborhood => 'Please enter neighborhood';

  @override
  String get termsAndConditions => 'Terms and Conditions';

  @override
  String get verificationCodeMustBeSixDigits =>
      'Verification code must be 6 digits';

  @override
  String get verifyAndComplete => 'Verify & Complete';

  @override
  String get youMustAgreeToTerms =>
      'You must agree to the terms and conditions';

  @override
  String get verificationCodeResent => 'Verification code resent';

  @override
  String get pleaseEnterYourFirstName => 'Please enter your first name';

  @override
  String get pleaseEnterYourLastName => 'Please enter your last name';

  @override
  String get pleaseEnterValidEmailAddress =>
      'Please enter a valid email address';

  @override
  String get pleaseEnterAPassword => 'Please enter a password';

  @override
  String get passwordMustContainUpperLowerNumber =>
      'Password must contain at least one uppercase letter, one lowercase letter, and one number';

  @override
  String errorPickingDocument(Object error) {
    return 'Error picking document: $error';
  }

  @override
  String get pleaseUploadBusinessPhoto => 'Please upload business photo';

  @override
  String get recoverYourAccountAccess => 'Recover your account access';

  @override
  String get sendResetCode => 'Send Reset Code';

  @override
  String get sending => 'Sending...';

  @override
  String get verificationCodeSentTitle => 'Verification Code Sent!';

  @override
  String get checkSpamFolder =>
      'Check your spam folder if you don\'t see the code in your inbox.';

  @override
  String get continueToVerification => 'Continue to Verification';

  @override
  String get rememberYourPassword => 'Remember your password? ';

  @override
  String get verificationCodeSentAgain => 'Verification code sent again!';

  @override
  String get failedToResend => 'Failed to resend code';

  @override
  String get enterVerificationCodeSentTo =>
      'Enter the verification code sent to:';

  @override
  String get codeMustBeSixDigits => 'Code must be 6 digits';

  @override
  String get newPassword => 'New Password';

  @override
  String get enterYourNewPassword => 'Enter your new password';

  @override
  String get pleaseEnterNewPassword => 'Please enter a new password';

  @override
  String get confirmNewPassword => 'Confirm your new password';

  @override
  String get passwordResetSuccessfully =>
      'Password has been reset successfully!';

  @override
  String get loadingDiscountManagement => 'Loading discount management...';

  @override
  String get processing => 'Processing...';

  @override
  String get discountCreatedSuccessfully => 'Discount created successfully';

  @override
  String get discountUpdatedSuccessfully => 'Discount updated successfully';

  @override
  String get discountDeletedSuccessfully => 'Discount deleted successfully';

  @override
  String get failedToCreateDiscount => 'Failed to create discount';

  @override
  String get failedToUpdateDiscount => 'Failed to update discount';

  @override
  String get failedToDeleteDiscount => 'Failed to delete discount';

  @override
  String get archiveAndHistory => 'Archive & History';

  @override
  String get viewCancelledOrders => 'View Cancelled Orders';

  @override
  String get viewDeliveredOrders => 'View Delivered Orders';

  @override
  String get viewReturnedOrders => 'View Returned Orders';

  @override
  String get viewExpiredOrders => 'View Expired Orders';

  @override
  String get addProduct => 'Add Product';

  @override
  String get createNewProductForMenu => 'Create a new product for your menu';

  @override
  String get productInformation => 'Product Information';

  @override
  String get addDetailsImagePricing =>
      'Add details, image, and pricing for your new product';

  @override
  String get productImage => 'Product Image';

  @override
  String get changeImage => 'Change Image';

  @override
  String get tapToAddProductImage => 'Tap to add product image';

  @override
  String get imageFormat => 'JPG, PNG • Max 5MB';

  @override
  String get productDetails => 'Product Details';

  @override
  String get productName => 'Product Name';

  @override
  String get enterProductName => 'Enter product name';

  @override
  String get enterProductDescription => 'Enter product description';

  @override
  String get pleaseEnterProductName => 'Please enter product name';

  @override
  String get pleaseEnterProductDescription =>
      'Please enter product description';

  @override
  String get pleaseAddProductImage => 'Please add a product image';

  @override
  String get productAddedSuccessfully => 'Product added successfully!';

  @override
  String failedToAddProduct(Object error) {
    return 'Failed to add product: $error';
  }

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get imageUploadFailed => 'Image upload failed';

  @override
  String get remove => 'Remove';

  @override
  String get enterPrice => 'Enter price';

  @override
  String get category => 'Category';

  @override
  String get price => 'Price';

  @override
  String get description => 'Description';

  @override
  String get pleaseSignInToViewOrders => 'Please sign in to view orders';

  @override
  String get whenOrdersComeInTheyWillAppearHere =>
      'When orders come in, they\'ll appear here';

  @override
  String get ordersRefreshedSuccessfully => 'Orders refreshed successfully';

  @override
  String get failedToRefreshOrders => 'Failed to refresh orders';

  @override
  String get archive => 'Archive';

  @override
  String get viewNow => 'VIEW NOW';

  @override
  String get viewInArchive => 'VIEW IN ARCHIVE';

  @override
  String get activeProducts => 'Active Products';

  @override
  String get customers => 'Customers';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get enterCurrentPassword => 'Enter your current password';

  @override
  String get updateAccountPassword => 'Update your account password';

  @override
  String get currentPasswordRequired => 'Current password is required';

  @override
  String get newPasswordRequired => 'Please enter a new password';

  @override
  String get passwordMustBeDifferent =>
      'New password must be different from current password';

  @override
  String get failedToChangePassword => 'Failed to change password';

  @override
  String get changingPassword => 'Changing Password...';

  @override
  String get enterValidEmail => 'Enter a valid email address';

  @override
  String get restaurantManagementSystem => 'Restaurant Management System';

  @override
  String get resetCodeSent => 'Reset code sent to your email';

  @override
  String get invalidResetCode => 'Invalid reset code';

  @override
  String get passwordResetSuccess => 'Password reset successfully';

  @override
  String get resetCodeRequired => 'Reset code is required';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get loginSuccess => 'Login successful!';

  @override
  String get wizzBusinessManager => 'WIZZ Business Manager';

  @override
  String get noBusinessDataAvailable => 'No business data available';

  @override
  String get error => 'Error';

  @override
  String get notificationsFeatureComingSoon =>
      'Notifications feature coming soon';

  @override
  String get settingsFeatureComingSoon => 'Settings feature coming soon';

  @override
  String get quickOrderFeatureComingSoon => 'Quick order feature coming soon';

  @override
  String get todaysOrders => 'Today\'s Orders';

  @override
  String get revenue => 'Revenue';

  @override
  String get products => 'Products';

  @override
  String get recentOrders => 'Recent Orders';

  @override
  String get order => 'Order';

  @override
  String get customer => 'Customer';

  @override
  String get ready => 'Ready';

  @override
  String get appColorPalette => 'App Color Palette';

  @override
  String get primaryYellow => 'Primary (Yellow)';

  @override
  String get secondaryGold => 'Secondary (Gold)';

  @override
  String get success => 'Success';

  @override
  String get warning => 'Warning';

  @override
  String get info => 'Info';

  @override
  String get allOrders => 'All';

  @override
  String get newOrders => 'New';

  @override
  String get preparingOrders => 'Preparing';

  @override
  String get readyOrders => 'Ready';

  @override
  String get allOrdersShownHere => 'All orders shown here';

  @override
  String get newOrdersShownHere => 'New orders shown here';

  @override
  String get ordersBeingPrepared => 'Orders being prepared';

  @override
  String get readyOrdersShownHere => 'Ready orders';

  @override
  String get confirmAccountButton => 'Confirm Account';

  @override
  String get basicInformation => 'Basic Information';

  @override
  String get discountConfiguration => 'Discount Configuration';

  @override
  String get quantityShort => 'Qty';

  @override
  String get merchants => 'Merchants';

  @override
  String get splashTagline => 'Manage your business efficiently';

  @override
  String get poweredByWhizz => 'Powered by Whizz';

  @override
  String versionNumber(Object version) {
    return 'Version $version';
  }

  @override
  String get accountConfirmedSuccessfully =>
      'Account confirmed successfully! Welcome to WIZZ Business Manager.';

  @override
  String get confirmationCodeSentTo =>
      'We\'ve sent a 6-digit confirmation code to:';

  @override
  String get searchProducts => 'Search products...';

  @override
  String get loadingProducts => 'Loading products...';

  @override
  String get oopsSomethingWentWrong => 'Oops! Something went wrong';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get yourProductCatalogAwaits => 'Your Product Catalog Awaits!';

  @override
  String get noProductsFound => 'No Products Found';

  @override
  String startBuildingYourMenu(Object businessType) {
    return 'Start building your menu by adding your first product. Showcase what makes your $businessType special!';
  }

  @override
  String get tryAdjustingYourSearchTerms =>
      'Try adjusting your search terms or check the spelling.';

  @override
  String get addYourFirstProduct => 'Add Your First Product';

  @override
  String get showcaseMenu => 'Showcase Menu';

  @override
  String get displayYourOfferingsBeautifully =>
      'Display your offerings beautifully';

  @override
  String get manageInventory => 'Manage Inventory';

  @override
  String get controlAvailabilityInRealTime =>
      'Control availability in real-time';

  @override
  String get trackPerformance => 'Track Performance';

  @override
  String get monitorSalesAndPopularity => 'Monitor sales and popularity';

  @override
  String get deleteProduct => 'Delete Product';

  @override
  String areYouSureYouWantToDeleteProduct(Object productName) {
    return 'Are you sure you want to delete \"$productName\"? This action cannot be undone.';
  }

  @override
  String get productDeletedSuccessfully => 'Product deleted successfully';

  @override
  String get unknownError => 'Unknown error';

  @override
  String failedToDeleteProduct(Object error) {
    return 'Failed to delete product: $error';
  }

  @override
  String get productUpdatedSuccessfully => 'Product updated successfully';

  @override
  String failedToUpdateProduct(Object error) {
    return 'Failed to update product: $error';
  }

  @override
  String get availability => 'Availability';

  @override
  String get productIsAvailable => 'Product is available';

  @override
  String get productIsUnavailable => 'Product is unavailable';

  @override
  String get priceLabel => 'Price';

  @override
  String errorSelectingImage(Object error) {
    return 'Error selecting image: $error';
  }

  @override
  String errorTakingPhoto(Object error) {
    return 'Error taking photo: $error';
  }

  @override
  String get businessPhotoUpdatedSuccessfully =>
      'Business photo updated successfully!';

  @override
  String failedToUploadPhoto(Object message) {
    return 'Failed to upload photo: $message';
  }

  @override
  String errorUploadingPhoto(Object error) {
    return 'Error uploading photo: $error';
  }

  @override
  String get noBusinessFound => 'No business found';

  @override
  String get businessProfileUpdatedSuccessfully =>
      'Business profile updated successfully!';

  @override
  String failedToUpdateProfile(Object error) {
    return 'Failed to update profile: $error';
  }

  @override
  String get pleaseSignInToAccessAccountSettings =>
      'Please sign in to access account settings';

  @override
  String get loadingAccountInformation => 'Loading account information...';

  @override
  String get errorLoadingAccount => 'Error Loading Account';

  @override
  String get noBusinessFoundForThisAccount =>
      'No business found for this account';

  @override
  String get notProvided => 'Not provided';

  @override
  String get website => 'Website';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get deliveryMethods => 'Delivery Methods';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get receiveNotificationsOnYourDevice =>
      'Receive notifications on your device';

  @override
  String get emailNotifications => 'Email Notifications';

  @override
  String get receiveNotificationsViaEmail => 'Receive notifications via email';

  @override
  String get smsNotifications => 'SMS Notifications';

  @override
  String get receiveNotificationsViaSMS =>
      'Receive notifications via SMS (charges may apply)';

  @override
  String get orderNotifications => 'Order Notifications';

  @override
  String get getNotifiedWhenNewOrdersArrive =>
      'Get notified when new orders arrive';

  @override
  String get orderStatusUpdates => 'Order Status Updates';

  @override
  String get getNotifiedWhenOrderStatusChanges =>
      'Get notified when order status changes';

  @override
  String get paymentNotifications => 'Payment Notifications';

  @override
  String get getNotifiedAboutPaymentUpdates =>
      'Get notified about payment updates';

  @override
  String get settingsSavedSuccessfully => 'Settings saved successfully!';

  @override
  String failedToSaveSettings(Object error) {
    return 'Failed to save settings: $error';
  }

  @override
  String get save => 'Save';

  @override
  String get soundSettings => 'Sound Settings';

  @override
  String get enableSound => 'Enable Sound';

  @override
  String get notificationSound => 'Notification Sound';

  @override
  String get defaultNotification => 'Default Notification';

  @override
  String get notificationChime => 'Notification Chime';

  @override
  String get bell => 'Bell';

  @override
  String get ding => 'Ding';

  @override
  String get tone => 'Tone';

  @override
  String get newOrderNotifications => 'New Order Notifications';

  @override
  String get playSoundWhenNewOrdersArrive =>
      'Play sound when new orders arrive';

  @override
  String get playSoundForOrderStatusChanges =>
      'Play sound for order status changes';

  @override
  String get systemNotifications => 'System Notifications';

  @override
  String get playSoundForSystemAlerts =>
      'Play sound for system alerts and errors';

  @override
  String get vibration => 'Vibration';

  @override
  String get vibrateDeviceForNewOrders => 'Vibrate device for new orders';

  @override
  String volume(Object percent) {
    return 'Volume: $percent%';
  }

  @override
  String get testSound => 'Test Sound';

  @override
  String get playingTestSound => 'Playing test sound...';

  @override
  String get settingsSaved => 'Settings Saved';

  @override
  String get soundNotificationPreferencesUpdated =>
      'Sound notification preferences updated successfully';

  @override
  String get saveFailed => 'Save Failed';

  @override
  String failedToSendVerificationCode(String error) {
    return 'Failed to send verification code: $error';
  }

  @override
  String get aboutApp => 'About the App';

  @override
  String get appInformationAndVersion => 'App information and version details';

  @override
  String get version => 'Version';

  @override
  String get aboutTitle => 'About WIZZ Business Manager';

  @override
  String get aboutDescription =>
      'WIZZ Business Manager is a comprehensive solution designed to help restaurant owners, cafe managers, and retail store operators manage their business operations efficiently. From order management to analytics, we provide all the tools you need to grow your business.';

  @override
  String get features => 'Key Features';

  @override
  String get featuresDescription =>
      '• Real-time order management\n• Product catalog management\n• Business analytics and insights\n• Discount and promotion management\n• Working hours configuration\n• Multi-language support\n• GPS location management\n• POS system integration';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get contactDescription =>
      'For support, questions, or feedback, please reach out to us at:\nsupport@whizzecosystem.com\n\nWe\'re here to help you succeed!';

  @override
  String get developer => 'Development';

  @override
  String get developerInfo =>
      'Developed with ❤️ by the Whizz Ecosystem team.\n\nBuilt using Flutter and powered by AWS Amplify.';

  @override
  String get allRightsReserved => 'All rights reserved.';

  @override
  String get loadingLocationSettings => 'Loading location settings...';

  @override
  String get cityRequired => 'City required';

  @override
  String get streetNameHelper =>
      'Street name used for location mapping and delivery';

  @override
  String get streetNameRequired => 'Street name is required for mapping';

  @override
  String get saveLocationSettings => 'Save Location Settings';

  @override
  String get locationSettingsSavedSuccessfully =>
      'Location settings saved successfully';

  @override
  String failedToSaveLocationSettings(String error) {
    return 'Failed to save location settings: $error';
  }

  @override
  String failedToLoadLocationSettings(String error) {
    return 'Failed to load location settings: $error';
  }

  @override
  String get governorate => 'Governorate';

  @override
  String get selectGovernorate => 'Select Governorate';

  @override
  String get pleaseSelectGovernorate => 'Please select a governorate';

  @override
  String get selectNeighborhood => 'Select Neighborhood';

  @override
  String get pleaseSelectNeighborhood => 'Please select a neighborhood';

  @override
  String get selectGovernorateFirst => 'Please select a governorate first';

  @override
  String get selectDistrictFirst => 'Please select a district first';

  @override
  String get noNeighborhoodsAvailable => 'No neighborhoods available';

  @override
  String get serviceUnavailableInRegion =>
      'Service is currently unavailable in your region';

  @override
  String get regionValidationFailed => 'Region validation failed';

  @override
  String get refreshRegions => 'Refresh Regions';

  @override
  String get selectDistrict => 'Select District';

  @override
  String get pleaseSelectDistrict => 'Please select a district';

  @override
  String get noDistrictsAvailable => 'No districts available';

  @override
  String get loading => 'Loading...';

  @override
  String get addressPreview => 'Address Preview';

  @override
  String get fullAddress => 'Full Address';

  @override
  String get coordinates => 'Coordinates';

  @override
  String get viewOnMap => 'View on Map';

  @override
  String get noAddressSelected =>
      'Please select a complete address from the regions above';

  @override
  String get supportCategoryTitle => 'How can we help you today?';

  @override
  String get supportCategorySubtitle =>
      'Choose a category to get started with WhizzMe AI';

  @override
  String get supportPoweredBy => 'Powered by WhizzMe AI';

  @override
  String get supportAiDescription =>
      'Our AI assistant will help you first, then connect you to a human agent if needed.';

  @override
  String get categoryOrderManagement => 'Orders & Fulfillment';

  @override
  String get categoryOrderManagementDesc =>
      'New orders, order status, cancellations, refunds';

  @override
  String get categoryOrderManagementExample1 => 'Not receiving orders';

  @override
  String get categoryOrderManagementExample2 => 'Order stuck in preparing';

  @override
  String get categoryOrderManagementExample3 => 'Refund request';

  @override
  String get categoryPaymentIssues => 'Payments & Payouts';

  @override
  String get categoryPaymentIssuesDesc =>
      'Payment methods, transaction issues, payout delays';

  @override
  String get categoryPaymentIssuesExample1 => 'Payout delayed';

  @override
  String get categoryPaymentIssuesExample2 => 'Payment failed';

  @override
  String get categoryPaymentIssuesExample3 => 'Commission questions';

  @override
  String get categoryAccountIssues => 'Account & Login';

  @override
  String get categoryAccountIssuesDesc =>
      'Login problems, verification, profile updates';

  @override
  String get categoryAccountIssuesExample1 => 'Cannot login';

  @override
  String get categoryAccountIssuesExample2 => 'Account verification';

  @override
  String get categoryAccountIssuesExample3 => 'Password reset';

  @override
  String get categoryBusinessSetup => 'Menu & Store Setup';

  @override
  String get categoryBusinessSetupDesc =>
      'Menu management, store hours, business settings';

  @override
  String get categoryBusinessSetupExample1 => 'Update menu items';

  @override
  String get categoryBusinessSetupExample2 => 'Change store hours';

  @override
  String get categoryBusinessSetupExample3 => 'Business verification';

  @override
  String get categoryTechnicalSupport => 'Technical Issues';

  @override
  String get categoryTechnicalSupportDesc =>
      'App crashes, notifications, sync problems';

  @override
  String get categoryTechnicalSupportExample1 => 'App not working';

  @override
  String get categoryTechnicalSupportExample2 => 'No notifications';

  @override
  String get categoryTechnicalSupportExample3 => 'Sync issues';

  @override
  String get categoryHumanAgent => 'Speak to Human Agent';

  @override
  String get categoryHumanAgentDesc => 'Connect directly with our support team';

  @override
  String get categoryHumanAgentExample1 => 'Complex issue';

  @override
  String get categoryHumanAgentExample2 => 'Need personal assistance';

  @override
  String get categoryHumanAgentExample3 => 'Urgent matter';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountButton => 'Delete Account';

  @override
  String get deleteAccountQuestion => 'Delete Account?';

  @override
  String get deleteAccountConfirmation =>
      'Are you sure you want to permanently delete your account?';

  @override
  String get deleteAccountWarning => 'This will permanently delete:';

  @override
  String get deleteAccountItem1 => 'Your business profile';

  @override
  String get deleteAccountItem2 => 'All orders and history';

  @override
  String get deleteAccountItem3 => 'Products and menu items';

  @override
  String get deleteAccountItem4 => 'Customer reviews';

  @override
  String get deleteAccountItem5 => 'All account data';

  @override
  String get deleteAccountCannotUndo => 'This action cannot be undone.';

  @override
  String get verifyPassword => 'Verify Password';

  @override
  String get verifyPasswordMessage =>
      'Enter your password to confirm account deletion';

  @override
  String get deletingAccount => 'Deleting account...';

  @override
  String get pleaseWait => 'Please wait';

  @override
  String get accountDeletedSuccessfully => 'Account deleted successfully';

  @override
  String get errorDeletingAccount => 'Error deleting account';

  @override
  String get incorrectPassword => 'Incorrect password. Please try again.';

  @override
  String get failedToLoadOrdersPullToRetry =>
      'Failed to load orders. Pull to retry.';

  @override
  String get restaurantNowAvailableForOrders =>
      'Restaurant now available for orders';

  @override
  String get restaurantNowUnavailableForOrders =>
      'Restaurant now unavailable for orders';

  @override
  String get returnOrdersFeatureComingSoon =>
      'Return orders feature coming soon.';

  @override
  String failedToUpdateRestaurantStatus(String error) {
    return 'Failed to update status: $error';
  }

  @override
  String get sessionExpiredPleaseLoginAgain =>
      'Session expired. Please login again.';
}
