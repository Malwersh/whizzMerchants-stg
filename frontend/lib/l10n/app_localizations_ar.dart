// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'WIZZ';

  @override
  String get welcome => 'مرحباً';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get reset => 'إعادة تعيين';

  @override
  String get resetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get createBusinessAccount => 'إنشاء حساب تجاري';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailAddress => 'عنوان البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get businessName => 'اسم النشاط التجاري';

  @override
  String get businessType => 'نوع النشاط التجاري';

  @override
  String get businessPhoto => 'صورة النشاط التجاري';

  @override
  String get country => 'البلد';

  @override
  String get city => 'المدينة';

  @override
  String get neighborhood => 'الحي';

  @override
  String get streetName => 'اسم الشارع';

  @override
  String get healthCertificate => 'شهادة صحية';

  @override
  String get additionalDocuments => 'مستندات إضافية';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get businessInformation => 'معلومات النشاط التجاري';

  @override
  String get businessAddress => 'عنوان النشاط التجاري';

  @override
  String get requiredDocuments => 'المستندات المطلوبة';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get signInToYourAccount => 'سجل دخولك إلى حسابك';

  @override
  String get registerYourBusiness => 'سجل نشاطك التجاري للبدء';

  @override
  String get checkYourEmail => 'تحقق من بريدك الإلكتروني';

  @override
  String get sendResetLink => 'إرسال رابط إعادة التعيين';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get resendEmail => 'إعادة إرسال البريد';

  @override
  String get createBusinessAccountButton => 'إنشاء حساب تجاري';

  @override
  String get enterYourEmail => 'أدخل بريدك الإلكتروني';

  @override
  String get enterYourPassword => 'أدخل كلمة المرور';

  @override
  String get createAStrongPassword => 'أنشئ كلمة مرور قوية';

  @override
  String get confirmYourPassword => 'أكد كلمة المرور';

  @override
  String get enterYourFullName => 'أدخل اسمك الكامل';

  @override
  String get enterYourBusinessName => 'أدخل اسم نشاطك التجاري';

  @override
  String get selectYourBusinessType => 'اختر نوع نشاطك التجاري';

  @override
  String get uploadBusinessPhoto => 'ارفع صورة لنشاطك التجاري';

  @override
  String get enterYourCity => 'أدخل مدينتك';

  @override
  String get enterYourNeighborhood => 'أدخل حيك';

  @override
  String get enterYourStreetName => 'أدخل اسم الشارع';

  @override
  String get uploadHealthCertificate => 'ارفع شهادتك الصحية';

  @override
  String get uploadAdditionalDocuments => 'ارفع أي مستندات تجارية إضافية';

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
      'رمز التأكيد غير صحيح. يرجى المحاولة مرة أخرى.';

  @override
  String get accountConfirmedSuccess => 'Account confirmed successfully!';

  @override
  String get enterRegisteredEmail => 'أدخل بريدك الإلكتروني المسجل';

  @override
  String get resetPasswordDescription =>
      'أدخل عنوان بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.';

  @override
  String get emailSentDescription =>
      'لقد أرسلنا رابط إعادة تعيين كلمة المرور إلى عنوان بريدك الإلكتروني. يرجى التحقق من صندوق الوارد واتباع التعليمات.';

  @override
  String get accountReviewNotice =>
      'ستتم مراجعة معلومات نشاطك التجاري قبل التفعيل.';

  @override
  String get termsAndConditionsNotice =>
      'بإنشاء حساب، فإنك توافق على شروط الخدمة وسياسة الخصوصية.';

  @override
  String get register => 'تسجيل';

  @override
  String get forgotPassword => 'نسيت كلمة المرور';

  @override
  String get forgotPasswordQuestion => 'نسيت كلمة المرور؟';

  @override
  String get dontHaveAnAccount => 'ليس لديك حساب؟';

  @override
  String get joinOrderReceiver => 'انضم إلى مستلم الطلبات';

  @override
  String get signUpSubtitle => 'أنشئ حسابك للبدء';

  @override
  String get accountSecurity => 'أمان الحساب';

  @override
  String get and => 'و';

  @override
  String get back => 'رجوع';

  @override
  String get next => 'التالي';

  @override
  String get iAgreeToThe => 'أوافق على';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get takePicture => 'التقاط صورة';

  @override
  String get verificationCode => 'رمز التحقق';

  @override
  String get verificationCodeRequired => 'يرجى إدخال رمز التحقق';

  @override
  String get verifyYourEmail => 'تحقق من بريدك الإلكتروني';

  @override
  String get pleaseEnterYourEmail => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get pleaseEnterYourPassword => 'الرجاء إدخال كلمة المرور';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get errorOccurred => 'حدث خطأ';

  @override
  String get failedToFetchProfile => 'فشل في جلب الملف الشخصي';

  @override
  String get noBusinessFoundForUser =>
      'لم يتم العثور على نشاط تجاري لهذا المستخدم';

  @override
  String get loginFailed => 'فشل تسجيل الدخول';

  @override
  String get loginFailedMessage =>
      'Login failed. Please check your credentials.';

  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى التحقق من البيانات والمحاولة مرة أخرى.';

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
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirmation => 'هل أنت متأكد من أنك تريد تسجيل الخروج؟';

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
  String get orders => 'الطلبات';

  @override
  String get items => 'العناصر';

  @override
  String get analytics => 'التحليلات';

  @override
  String get discounts => 'الخصومات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get online => 'متصل';

  @override
  String get offline => 'غير متصل';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get goOnline => 'الانتقال للحالة المتصلة';

  @override
  String get goOffline => 'فصل الاتصال';

  @override
  String get menu => 'القائمة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get errorPickingImage => 'خطأ في اختيار الصورة';

  @override
  String get errorPickingFile => 'خطأ في اختيار الملف';

  @override
  String get chooseFromGallery => 'اختيار من المعرض';

  @override
  String get takePhoto => 'التقط صورة';

  @override
  String get businessIsNowOnline => 'النشاط التجاري متصل الآن';

  @override
  String get businessIsNowOffline => 'النشاط التجاري غير متصل الآن';

  @override
  String get businessNowOnline => 'النشاط التجاري متصل الآن';

  @override
  String get businessNowOffline => 'النشاط التجاري غير متصل الآن';

  @override
  String get errorUpdatingStatus =>
      'خطأ في تحديث الحالة. يرجى المحاولة مرة أخرى.';

  @override
  String get returnOrderFeature => 'Return order feature coming soon';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get notificationsTapped => 'Notifications tapped';

  @override
  String get returnAnOrder => 'Return an Order';

  @override
  String get manageDiscounts => 'Manage Discounts';

  @override
  String get returnOrder => 'إرجاع الطلب';

  @override
  String get accountSettings => 'إعدادات الحساب';

  @override
  String get posSettings => 'إعدادات نقاط البيع';

  @override
  String get languageSettings => 'إعدادات اللغة';

  @override
  String get locationSettings => 'إعدادات الموقع';

  @override
  String get workingHoursSettings => 'إعدادات ساعات العمل';

  @override
  String get monday => 'الاثنين';

  @override
  String get tuesday => 'الثلاثاء';

  @override
  String get wednesday => 'الأربعاء';

  @override
  String get thursday => 'الخميس';

  @override
  String get friday => 'الجمعة';

  @override
  String get saturday => 'السبت';

  @override
  String get sunday => 'الأحد';

  @override
  String timeoutFirstAlert(Object remainingTime) {
    return 'سيتم رفض الطلب تلقائيًا في غضون $remainingTime.';
  }

  @override
  String timeoutUrgentAlert(Object remainingTime) {
    return 'عاجل: سيتم الرفض التلقائي في غضون $remainingTime.';
  }

  @override
  String get timeoutAutoReject => 'تم رفض الطلب تلقائيًا بسبب انتهاء الوقت.';

  @override
  String get openingTime => 'وقت الافتتاح';

  @override
  String get closingTime => 'وقت الإغلاق';

  @override
  String get setOpeningTime => 'تحديد وقت الافتتاح';

  @override
  String get setClosingTime => 'تحديد وقت الإغلاق';

  @override
  String get notSet => 'غير محدد';

  @override
  String get workingHoursSaved => 'تم حفظ ساعات العمل بنجاح';

  @override
  String get setBusinessHours => 'اضبط ساعات عمل نشاطك التجاري';

  @override
  String get loadingWorkingHours => 'جاري تحميل ساعات العمل...';

  @override
  String get quickPresets => 'الإعدادات السريعة';

  @override
  String get applySchedulesToAllDays => 'تطبيق الجداول على جميع الأيام';

  @override
  String get regularHours => '9ص-5م';

  @override
  String get restaurantHours => '11ص-11م';

  @override
  String get retailHours => '10ص-10م';

  @override
  String get copyToAllDays => 'نسخ إلى جميع الأيام';

  @override
  String get opens => 'يفتح';

  @override
  String get closes => 'يغلق';

  @override
  String get closed => 'مغلق';

  @override
  String get saving => 'Saving...';

  @override
  String get saveWorkingHours => 'حفظ ساعات العمل';

  @override
  String appliedHoursToAllDays(Object schedule) {
    return 'تم تطبيق ساعات $schedule على جميع الأيام';
  }

  @override
  String appliedDayHoursToAll(Object dayName) {
    return 'تم تطبيق ساعات $dayName على جميع الأيام';
  }

  @override
  String failedToLoadWorkingHours(Object error) {
    return 'فشل في تحميل ساعات العمل: $error';
  }

  @override
  String get businessManagement => 'إدارة الأعمال';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get ownerName => 'اسم المالك';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get businessAddressLabel => 'عنوان النشاط التجاري';

  @override
  String get rating => 'التقييم';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get accountStatus => 'حالة الحساب';

  @override
  String get posSettingsUpdated => 'POS settings updated successfully';

  @override
  String get connectionSuccessful => 'Connection successful';

  @override
  String get connectionFailed => 'فشل اختبار الاتصال';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get close => 'Close';

  @override
  String get posSystemType => 'POS System Type';

  @override
  String get selectPosSystem => 'اختر نظام نقاط البيع';

  @override
  String get apiConfiguration => 'API Configuration';

  @override
  String get apiEndpoint => 'نقطة نهاية API';

  @override
  String get pleaseEnterApiEndpoint => 'Please enter API endpoint';

  @override
  String get pleaseEnterValidUrl => 'Please enter a valid URL';

  @override
  String get apiKey => 'مفتاح API';

  @override
  String get enterApiKey => 'Enter API Key';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get pleaseEnterApiKey => 'Please enter API key';

  @override
  String get accessToken => 'رمز الوصول';

  @override
  String get enterAccessToken => 'Enter Access Token';

  @override
  String get locationId => 'معرف الموقع';

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
  String get connectionStatus => 'حالة الاتصال';

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
  String get saveSettings => 'حفظ الإعدادات';

  @override
  String get posSyncLogs => 'سجلات المزامنة';

  @override
  String get noSyncLogsFound => 'لم يتم العثور على سجلات مزامنة';

  @override
  String get enablePosIntegrationTitle => 'تفعيل تكامل نقاط البيع';

  @override
  String get enablePosIntegrationSubtitle =>
      'اتصال مع نظام نقطة البيع الخاص بك';

  @override
  String get posSystemTypeLabel => 'نوع نظام نقاط البيع';

  @override
  String get selectPosSystemHint => 'اختر نظام نقاط البيع الخاص بك';

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
  String get apiConfigurationTitle => 'إعداد API';

  @override
  String get apiEndpointLabel => 'نقطة نهاية API';

  @override
  String get apiEndpointHint => 'https://api.yourpos.com/v1';

  @override
  String get apiKeyLabel => 'مفتاح API';

  @override
  String get apiKeyHint => 'مفتاح نظام نقاط البيع الخاص بك';

  @override
  String get locationIdLabel => 'معرف الموقع (اختياري)';

  @override
  String get locationIdHint => 'معرف الموقع أو المتجر';

  @override
  String get posConfigurationTitle => 'إعداد نقاط البيع';

  @override
  String get testModeTitle => 'وضع الاختبار';

  @override
  String get testModeSubtitle => 'استخدام بيئة الاختبار/التجريب';

  @override
  String get autoSendOrdersTitle => 'إرسال الطلبات تلقائياً';

  @override
  String get autoSendOrdersSubtitle =>
      'إرسال الطلبات المقبولة تلقائياً لنقاط البيع';

  @override
  String get autoAcceptOrdersTitle => 'قبول الطلبات تلقائياً';

  @override
  String get autoAcceptOrdersSubtitle => 'قبول جميع الطلبات الواردة تلقائياً';

  @override
  String get connectionTimeoutTitle => 'مهلة الاتصال';

  @override
  String connectionTimeoutSubtitle(Object timeout) {
    return '$timeout ثانية';
  }

  @override
  String get testConnectionButton => 'اختبار الاتصال';

  @override
  String get saveSettingsButton => 'حفظ الإعدادات';

  @override
  String get posSettingsSaved => 'تم حفظ إعدادات نقاط البيع بنجاح';

  @override
  String get failedToLoadPosSettings => 'فشل في تحميل إعدادات نقاط البيع';

  @override
  String get failedToSavePosSettings => 'فشل في حفظ إعدادات نقاط البيع';

  @override
  String get connectionTestSuccessful => 'اختبار الاتصال نجح!';

  @override
  String get connectionTestFailed => 'اختبار الاتصال فشل';

  @override
  String get apiEndpointRequired =>
      'نقطة نهاية API مطلوبة عند تفعيل نقاط البيع';

  @override
  String get apiKeyRequired => 'مفتاح API مطلوب عند تفعيل نقاط البيع';

  @override
  String get general => 'عام';

  @override
  String get advanced => 'متقدم';

  @override
  String get posIntegration => 'تكامل نقاط البيع';

  @override
  String get noSyncLogsAvailable => 'لا توجد سجلات مزامنة متاحة';

  @override
  String get syncSettings => 'إعدادات المزامنة';

  @override
  String get syncInterval => 'فترة المزامنة';

  @override
  String get minutes => 'دقائق';

  @override
  String get status => 'الحالة';

  @override
  String get successful => 'ناجح';

  @override
  String get failed => 'فاشل';

  @override
  String get syncLogDetails => 'تفاصيل سجل المزامنة';

  @override
  String get syncTime => 'وقت المزامنة';

  @override
  String get posOrderId => 'معرف طلب نقاط البيع';

  @override
  String get errorMessage => 'رسالة الخطأ';

  @override
  String get retrySync => 'إعادة المزامنة';

  @override
  String get orderSyncRetryInitiated => 'تم بدء إعادة محاولة مزامنة الطلب';

  @override
  String get webhookSetupTitle => 'دليل إعداد الويب هوك';

  @override
  String get webhookSetupDescription => 'اتبع هذه الخطوات لتكوين الويب هوك';

  @override
  String get contactSupport => 'التواصل مع الدعم';

  @override
  String get contactSupportDescription =>
      'تحتاج مساعدة في تكامل نقاط البيع؟ تواصل مع فريق الدعم';

  @override
  String get webhookConfigTitle => 'تكوين الويب هوك';

  @override
  String get webhookConfigDescription =>
      'تكوين نقاط نهاية الويب هوك للمزامنة الفورية';

  @override
  String get webhookStep1 => 'الخطوة 1: إنشاء نقطة نهاية الويب هوك';

  @override
  String get webhookStep2 => 'الخطوة 2: تكوين المصادقة';

  @override
  String get webhookStep3 => 'الخطوة 3: اختبار الاتصال';

  @override
  String get advancedConfiguration => 'التكوين المتقدم';

  @override
  String get timeoutSeconds => 'ثواني المهلة الزمنية';

  @override
  String get retryAttempts => 'محاولات الإعادة';

  @override
  String get testMode => 'وضع الاختبار';

  @override
  String get testModeDescription => 'تفعيل وضع الاختبار للتطوير والاختبار';

  @override
  String get webhooksIntegration => 'تكامل Webhooks';

  @override
  String get webhooksDescription =>
      'تكوين webhooks للحصول على تحديثات الطلبات الفورية';

  @override
  String get configureWebhooks => 'تكوين Webhooks';

  @override
  String get securitySettings => 'إعدادات الأمان';

  @override
  String get encryptionStatus => 'حالة التشفير';

  @override
  String get encryptionEnabled => 'جميع اتصالات API مشفرة';

  @override
  String get apiKeyRotation => 'تدوير مفتاح API';

  @override
  String get lastRotated => 'آخر تدوير منذ 30 يوماً';

  @override
  String get rotate => 'تدوير';

  @override
  String get systemSetupGuides => 'أدلة إعداد النظام';

  @override
  String get setupGuide => 'دليل الإعداد';

  @override
  String get troubleshooting => 'استكشاف الأخطاء وإصلاحها';

  @override
  String get connectionIssues => 'مشاكل الاتصال';

  @override
  String get syncFailures => 'فشل المزامنة';

  @override
  String get apiErrors => 'أخطاء API';

  @override
  String get supportContact => 'الدعم والاتصال';

  @override
  String get liveChat => 'المحادثة المباشرة';

  @override
  String get availableWeekdays => 'متاح أيام الأسبوع من 9 صباحاً - 6 مساءً';

  @override
  String get emailSupport => 'دعم البريد الإلكتروني';

  @override
  String get liveChatComingSoon => 'ميزة المحادثة المباشرة قريباً';

  @override
  String get emailSupportOpened => 'تم فتح دعم البريد الإلكتروني';

  @override
  String get generalSettings => 'عام';

  @override
  String get syncLogs => 'سجلات المزامنة';

  @override
  String get advancedSettings => 'متقدم';

  @override
  String get help => 'مساعدة';

  @override
  String get allDiscounts => 'جميع الخصومات';

  @override
  String get activeDiscounts => 'الخصومات النشطة';

  @override
  String get scheduledDiscounts => 'الخصومات المجدولة';

  @override
  String get expiredDiscounts => 'الخصومات المنتهية الصلاحية';

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
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get editDiscount => 'Edit Discount';

  @override
  String get title => 'Title';

  @override
  String get pleaseEnterTitle => 'Please enter a title';

  @override
  String get discountType => 'نوع الخصم';

  @override
  String get percentage => 'النسبة المئوية';

  @override
  String get fixedAmount => 'مبلغ ثابت';

  @override
  String get conditional => 'مشروط';

  @override
  String get buyXGetY => 'اشتري X واحصل على Y';

  @override
  String get freeDelivery => 'توصيل مجاني';

  @override
  String get freeDeliveryValue => 'توصيل مجاني (0.0)';

  @override
  String get buyXGetYValue => 'اشتري X واحصل على Y (0.0)';

  @override
  String get conditionalValue => 'مشروط (0.0)';

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
  String get others => 'أخرى';

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
  String get minimumOrder => 'الحد الأدنى للطلب';

  @override
  String get startDate => 'تاريخ البداية';

  @override
  String get endDate => 'تاريخ النهاية';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get create => 'Create';

  @override
  String get off => 'off';

  @override
  String get discount => 'discount';

  @override
  String get active => 'نشط';

  @override
  String get scheduled => 'مجدول';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String get validityPeriod => 'فترة الصلاحية';

  @override
  String get unknownStatus => 'حالة غير معروفة';

  @override
  String get sampleItem => 'Sample Item';

  @override
  String get totalSales => 'إجمالي المبيعات';

  @override
  String get totalOrders => 'إجمالي الطلبات';

  @override
  String get averageOrderValue => 'متوسط قيمة الطلب';

  @override
  String get topSellingItems => 'العناصر الأكثر مبيعاً';

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
  String get orderStatusPending => 'قيد الانتظار';

  @override
  String get orderStatusConfirmed => 'مؤكد';

  @override
  String get orderStatusPreparing => 'قيد التحضير';

  @override
  String get orderStatusReady => 'جاهز';

  @override
  String get orderStatusOnTheWay => 'في الطريق';

  @override
  String get orderStatusDelivered => 'تم التوصيل';

  @override
  String get orderStatusPickedUp => 'تم الاستلام';

  @override
  String get orderStatusCancelled => 'ملغي';

  @override
  String get orderStatusReturned => 'مُرجع';

  @override
  String get orderStatusExpired => 'منتهي الصلاحية';

  @override
  String get orderStatusCompleted => 'مكتمل';

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
  String get currencyPrefix => 'د.ع ';

  @override
  String get edit => 'تعديل';

  @override
  String get deleteItem => 'Delete Item';

  @override
  String get deleteItemConfirmation =>
      'Are you sure you want to delete this item?';

  @override
  String get itemDeletedSuccessfully => 'Item deleted successfully';

  @override
  String get addNewItem => 'إضافة عنصر جديد';

  @override
  String get uploadImage => 'رفع صورة';

  @override
  String get selectCategory => 'اختر فئة';

  @override
  String get pleaseSelectCategory => 'يرجى اختيار فئة';

  @override
  String get newCategoryName => 'اسم الفئة الجديدة';

  @override
  String get pleaseEnterCategoryName => 'يرجى إدخال اسم الفئة';

  @override
  String get selectExistingCategory => 'اختر فئة موجودة';

  @override
  String get addNewCategory => 'إضافة فئة جديدة';

  @override
  String get itemName => 'اسم العنصر';

  @override
  String get pleaseEnterItemName => 'يرجى إدخال اسم العنصر';

  @override
  String get pleaseEnterPrice => 'Please enter price';

  @override
  String get pleaseEnterValidPrice => 'Please enter a valid price';

  @override
  String get imageUrl => 'رابط الصورة';

  @override
  String get optional => 'اختياري';

  @override
  String get available => 'متاح';

  @override
  String get unavailable => 'غير متاح';

  @override
  String get makeAvailable => 'جعل متاح';

  @override
  String get makeUnavailable => 'جعل غير متاح';

  @override
  String get add => 'Add';

  @override
  String get editItem => 'Edit Item';

  @override
  String get update => 'Update';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get confirmed => 'مؤكد';

  @override
  String get preparing => 'قيد التحضير';

  @override
  String get orderReady => 'الطلب جاهز';

  @override
  String get onTheWay => 'في الطريق';

  @override
  String get delivered => 'تم التوصيل';

  @override
  String get pickedUp => 'تم الاستلام';

  @override
  String get cancelled => 'ملغي';

  @override
  String get orderReturned => 'مُرجع';

  @override
  String noOrdersFoundFor(Object filter) {
    return 'لم يتم العثور على طلبات لـ $filter';
  }

  @override
  String get notes => 'الملاحظات';

  @override
  String get total => 'المجموع';

  @override
  String get reject => 'رفض';

  @override
  String get accept => 'قبول';

  @override
  String get required => 'Required';

  @override
  String get changeFile => 'Change File';

  @override
  String get selectFile => 'Select File';

  @override
  String get restaurant => 'مطعم';

  @override
  String get store => 'متجر';

  @override
  String get pharmacy => 'صيدلية';

  @override
  String get cloudKitchen => 'مطبخ سحابي';

  @override
  String get cafe => 'مقهى';

  @override
  String get bakery => 'مخبزة';

  @override
  String get herbalspices => 'الأعشاب والتوابل';

  @override
  String get cosmetics => 'مستحضرات التجميل';

  @override
  String get betshop => 'بيت الرهان';

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
  String get businessOwnerInformation => 'معلومات مالك النشاط';

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
  String get businessRegistration => 'تسجيل النشاط التجاري';

  @override
  String get welcomeToHadhir => 'مرحباً بك في حاضر';

  @override
  String get fillInTheFormBelowToGetStarted => 'املأ النموذج أدناه للبدء';

  @override
  String get createYourBusinessAccount => 'أنشئ حساب نشاطك التجاري';

  @override
  String get tapToUpload => 'اضغط للرفع';

  @override
  String get uploaded => 'تم الرفع';

  @override
  String get businessAndOwnerInformation => 'معلومات النشاط والمالك';

  @override
  String get selectBusinessType => 'يرجى اختيار نوع النشاط التجاري';

  @override
  String get pleaseEnterBusinessName => 'يرجى إدخال اسم النشاط التجاري';

  @override
  String get pleaseEnterOwnerName => 'يرجى إدخال اسم المالك';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get firstNameRequired => 'First name is required';

  @override
  String get lastNameRequired => 'Last name is required';

  @override
  String get invalidEmailFormat => 'يرجى إدخال بريد إلكتروني صالح';

  @override
  String get phoneNumberRequired => 'Phone number is required';

  @override
  String get businessNameRequired => 'Business name is required';

  @override
  String get pleaseEnterYourBusinessName => 'يرجى إدخال اسم نشاطك التجاري';

  @override
  String get streetAddress => 'عنوان الشارع';

  @override
  String get state => 'State/Province';

  @override
  String get zipCode => 'الرمز البريدي';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get weakPassword => 'كلمة المرور ضعيفة جداً';

  @override
  String get confirmPasswordRequired => 'يرجى تأكيد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get registrationSuccess => 'Registration successful';

  @override
  String get emailAlreadyInUse => 'البريد الإلكتروني مستخدم بالفعل';

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
  String get businessLocation => 'موقع النشاط التجاري';

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
  String get confirmLocation => 'تأكيد الموقع';

  @override
  String get tapToSelectLocation => 'انقر لتحديد الموقع';

  @override
  String get registrationDate => 'تاريخ التسجيل';

  @override
  String get failedToSaveLocation => 'فشل في حفظ الموقع';

  @override
  String get businessLocationDescription =>
      'حدد موقع نشاطك التجاري لمساعدة العملاء في العثور عليك وتحسين دقة التوصيل.';

  @override
  String get locationInformation => 'معلومات الموقع';

  @override
  String get customerVisibility => 'رؤية العملاء';

  @override
  String get customerVisibilityDescription =>
      'سيتم عرض موقعك للعملاء عند تقديم الطلبات';

  @override
  String get deliveryOptimization => 'تحسين التوصيل';

  @override
  String get deliveryOptimizationDescription =>
      'الموقع الدقيق يساعد على تحسين مسارات التوصيل والتوقيت';

  @override
  String get privacyAndSecurity => 'الخصوصية والأمان';

  @override
  String get privacyAndSecurityDescription =>
      'يتم تشفير بيانات موقعك وتخزينها بأمان';

  @override
  String get pleaseSignInToAccessLocationSettings =>
      'يرجى تسجيل الدخول للوصول إلى إعدادات الموقع';

  @override
  String get smartBusinessControls => 'عناصر التحكم الذكية في الأعمال';

  @override
  String get readyToReceiveOrders => 'مستعد لاستقبال الطلبات';

  @override
  String get ordersArePaused => 'الطلبات متوقفة';

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
  String get managePromotionalOffers => 'إدارة العروض الترويجية';

  @override
  String get viewBusinessInsights => 'عرض رؤى الأعمال';

  @override
  String get manageItemsAndCategories => 'إدارة العناصر والفئات';

  @override
  String get platformIntegration => 'تكامل المنصة';

  @override
  String get centralizedDeliveryPlatform => 'منصة توصيل مركزية';

  @override
  String get appAndAccountPreferences => 'تفضيلات التطبيق والحساب';

  @override
  String get keyboardShortcutsTip =>
      'نصيحة: استخدم اختصارات لوحة المفاتيح للإجراءات الأسرع';

  @override
  String get conditionalDiscountConfiguration => 'إعداد الخصم المشروط';

  @override
  String get buyXGetYConfiguration => 'إعداد اشتري X واحصل على Y';

  @override
  String get buyConfiguration => 'إعداد الشراء';

  @override
  String get getConfiguration => 'إعداد الحصول';

  @override
  String get selectItem => 'اختر عنصراً';

  @override
  String get itemSelected => 'تم اختيار العنصر';

  @override
  String get enterValidQuantity => 'أدخل كمية صحيحة';

  @override
  String get missingItems => 'عناصر مفقودة';

  @override
  String pleasSelectBothBuyAndGetItems(Object discountType) {
    return 'يرجى اختيار عناصر الشراء والحصول للخصم $discountType.';
  }

  @override
  String get ok => 'موافق';

  @override
  String get addFreeDeliveryToDiscount => 'إضافة توصيل مجاني لهذا الخصم';

  @override
  String get conflictingDiscountsTitle => 'خصومات متعارضة';

  @override
  String get someSelectedItemsAlreadyHaveDiscounts =>
      'بعض العناصر أو الفئات المختارة لديها خصومات نشطة بالفعل. كل عنصر يمكن أن يحتوي على خصم واحد فقط في المرة الواحدة.';

  @override
  String get applicabilityNotConfigurable =>
      'لا يمكن تكوين القابلية للتطبيق لهذا النوع من الخصم حيث أن العناصر محددة مسبقاً في الإعداد أعلاه.';

  @override
  String get noItemSelected => 'لم يتم اختيار عنصر';

  @override
  String get appliesToAllItems => 'يطبق على جميع العناصر';

  @override
  String appliesToSpecificItems(Object count) {
    return 'يطبق على $count عناصر محددة';
  }

  @override
  String appliesToCategories(Object count) {
    return 'يطبق على $count فئات';
  }

  @override
  String get appliesToOrdersAboveMinimum => 'يطبق على الطلبات فوق الحد الأدنى';

  @override
  String validFromTo(Object endDay, Object endMonth, Object endYear,
      Object startDay, Object startMonth, Object startYear) {
    return 'صالح من: $startDay/$startMonth/$startYear - $endDay/$endMonth/$endYear';
  }

  @override
  String minAmount(Object amount) {
    return 'الحد الأدنى: \$$amount';
  }

  @override
  String categoriesSelected(Object count) {
    return '$count فئات مختارة';
  }

  @override
  String itemsSelected(Object count) {
    return '$count عناصر مختارة';
  }

  @override
  String missingItemsMessage(Object discountType) {
    return 'يرجى اختيار عناصر الشراء والحصول لخصم $discountType.';
  }

  @override
  String get selectBuyItem => 'اختر عنصر الشراء';

  @override
  String get selectGetItem => 'اختر عنصر الحصول';

  @override
  String get noCategoriesFound =>
      'لم يتم العثور على فئات. يرجى إضافة فئات أولاً.';

  @override
  String get appliesToMinimumOrder =>
      'ينطبق على الطلبات التي تزيد عن الحد الأدنى للمبلغ';

  @override
  String get startSimulation => 'Start Simulation';

  @override
  String get stopSimulation => 'Stop Simulation';

  @override
  String get simulateNewOrder => 'Simulate New Order';

  @override
  String get newOrder => 'طلب جديد';

  @override
  String get newOrderArrived => 'وصل طلب جديد!';

  @override
  String get fromLabel => 'من';

  @override
  String get failedToUpdateOrder => 'فشل في تحديث الطلب';

  @override
  String get orderRejectedByMerchant => 'تم رفض الطلب من قبل التاجر';

  @override
  String get orderHashtag => 'طلب #';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get live => 'Live';

  @override
  String get sendTestNotification => 'إرسال إشعار تجريبي';

  @override
  String get showLocalNotifications => 'إظهار الإشعارات المحلية';

  @override
  String get showLocalNotificationsDescription =>
      'عرض الإشعارات في منطقة إشعارات النظام';

  @override
  String get playNotificationSounds => 'تشغيل أصوات الإشعارات';

  @override
  String get playNotificationSoundsDescription =>
      'تشغيل الصوت عند استلام الإشعارات';

  @override
  String get testNotifications => 'اختبار الإشعارات';

  @override
  String get testNotificationDescription =>
      'سيرسل هذا إشعار اختبار للتحقق من أن إعداداتك تعمل بشكل صحيح.';

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
  String get today => 'اليوم';

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
  String get revenueLabel => 'الإيرادات';

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
  String get performanceMetrics => 'مقاييس الأداء';

  @override
  String get avgPrepTime => 'Avg. Prep Time';

  @override
  String get successRate => 'Success Rate';

  @override
  String get specialDish => 'Special Dish';

  @override
  String get popularItem => 'Popular Item';

  @override
  String get totalRevenue => 'إجمالي الإيرادات';

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
  String get loginInstead => 'تسجيل الدخول بدلاً من ذلك';

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
  String get verificationFailed => 'فشل التحقق';

  @override
  String get selectImageSource => 'اختر مصدر الصورة';

  @override
  String get camera => 'الكاميرا';

  @override
  String get gallery => 'المعرض';

  @override
  String verificationCodeSentTo(Object email) {
    return 'تم إرسال رمز التحقق إلى $email';
  }

  @override
  String get applicationPending => 'الطلب قيد المراجعة';

  @override
  String get applicationPendingDescription => 'طلبك قيد الموافقة.';

  @override
  String get applicationApproved => 'تمت الموافقة على الطلب';

  @override
  String get applicationApprovedDescription => 'تمت الموافقة على طلبك.';

  @override
  String get applicationRejected => 'تم رفض الطلب';

  @override
  String get applicationRejectedDescription => 'تم رفض طلبك.';

  @override
  String get underReview => 'قيد المراجعة';

  @override
  String get underReviewDescription => 'طلبك قيد المراجعة.';

  @override
  String get statusUnknown => 'الحالة غير معروفة';

  @override
  String get statusUnknownDescription => 'حالة طلبك غير معروفة.';

  @override
  String get applicationStatus => 'حالة الطلب';

  @override
  String get accountApproved => 'تمت الموافقة على الحساب';

  @override
  String get accountSuspended => 'تم تعليق الحساب';

  @override
  String get accountApprovedMessage =>
      'تمت الموافقة على حساب التاجر الخاص بك. يمكنك الآن البدء في استخدام المنصة.';

  @override
  String get applicationPendingMessage =>
      'طلبك قيد المراجعة. سنقوم بإخطارك بمجرد اكتمال المراجعة.';

  @override
  String get applicationRejectedMessage =>
      'تم رفض طلبك. يرجى الاتصال بالدعم للحصول على مزيد من المعلومات.';

  @override
  String get accountSuspendedMessage =>
      'تم تعليق حسابك. يرجى الاتصال بالدعم لحل هذه المشكلة.';

  @override
  String get unknownStatusMessage =>
      'تم اكتشاف حالة غير معروفة. يرجى الاتصال بالدعم.';

  @override
  String get needHelp => 'هل تحتاج إلى مساعدة؟';

  @override
  String get contactSupportMessage => 'اتصل بفريق الدعم إذا كان لديك أي أسئلة.';

  @override
  String get chatWithSupport => 'تحدث مع الدعم';

  @override
  String get supportInformation => 'معلومات الدعم';

  @override
  String get completeRegistrationForChat =>
      'للوصول إلى الدعم المباشر، يرجى إكمال تسجيل التاجر وتسجيل الدخول.';

  @override
  String get forImmediateAssistance =>
      'للحصول على المساعدة الفورية، يرجى الاتصال:';

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
  String get kwd => 'د.ك';

  @override
  String get categories => 'categories';

  @override
  String get notSpecified => 'Not Specified';

  @override
  String get verified => 'موثق';

  @override
  String get viewAndManageOrders => 'View and manage orders';

  @override
  String get businessDashboardVersion => 'Business Dashboard Version';

  @override
  String get modernMaterialDesign => 'Modern Material Design';

  @override
  String get language => 'اللغة';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get businessLicense => 'رخصة النشاط التجاري';

  @override
  String get ownerIdentity => 'Owner Identity';

  @override
  String get ownerPhoto => 'صورة المالك';

  @override
  String get alreadyHaveAccount => 'هل لديك حساب بالفعل؟';

  @override
  String get kitchen => 'مطبخ';

  @override
  String get chooseFromFiles => 'Choose from Files';

  @override
  String get accountInformation => 'معلومات الحساب';

  @override
  String get pleaseEnterAValidEmail => 'يرجى إدخال بريد إلكتروني صالح';

  @override
  String get passwordMustBeAtLeast8Chars =>
      'كلمة المرور يجب أن تكون 8 أحرف على الأقل';

  @override
  String get reEnterYourPassword => 'أعد إدخال كلمة المرور';

  @override
  String get enterOwnerName => 'Enter owner name';

  @override
  String get ownerFirstName => 'الاسم الأول للمالك';

  @override
  String get enterOwnerFirstName => 'أدخل الاسم الأول للمالك';

  @override
  String get pleaseEnterOwnerFirstName => 'يرجى إدخال الاسم الأول للمالك';

  @override
  String get ownerLastName => 'اسم العائلة للمالك';

  @override
  String get enterOwnerLastName => 'أدخل اسم العائلة للمالك';

  @override
  String get pleaseEnterOwnerLastName => 'يرجى إدخال اسم العائلة للمالك';

  @override
  String get enterYourBusinessPhone => 'أدخل هاتف نشاطك التجاري';

  @override
  String get pleaseEnterYourPhoneNumber => 'يرجى إدخال رقم هاتفك';

  @override
  String get addAPhotoToShowcaseYourBusiness => 'أضف صورة لعرض نشاطك التجاري';

  @override
  String get pleaseEnterYourCity => 'يرجى إدخال مدينتك';

  @override
  String get district => 'المنطقة';

  @override
  String get enterYourDistrict => 'أدخل منطقتك';

  @override
  String get pleaseEnterYourDistrict => 'يرجى إدخال منطقتك';

  @override
  String get enterYourStreetAddress => 'أدخل عنوان الشارع';

  @override
  String get pleaseEnterYourStreetAddress => 'يرجى إدخال عنوان الشارع';

  @override
  String get documentsRequired => 'الوثائق المطلوبة';

  @override
  String get pleaseUploadAllRequiredDocuments =>
      'يرجى رفع جميع الوثائق المطلوبة';

  @override
  String get emailVerification => 'التحقق من البريد الإلكتروني';

  @override
  String get enterTheCodeSentToYourEmail =>
      'أدخل الرمز المرسل إلى بريدك الإلكتروني';

  @override
  String get changeEmail => 'تغيير البريد الإلكتروني';

  @override
  String get enter6DigitCode => 'أدخل الرمز المكون من 6 أرقام';

  @override
  String get enterVerificationCode => 'Enter verification code';

  @override
  String get pleaseEnterVerificationCode => 'يرجى إدخال رمز التحقق';

  @override
  String get pleaseEnterTheVerificationCode => 'يرجى إدخال رمز التحقق';

  @override
  String get verificationCodeSent => 'Verification code sent to your email';

  @override
  String get resendVerificationCode => 'إعادة إرسال رمز التحقق';

  @override
  String get failedToResendCode => 'فشل في إعادة إرسال رمز التحقق';

  @override
  String get troubleshootingSection => 'استكشاف الأخطاء وإصلاحها';

  @override
  String get passwordChangedSuccessfully => 'تم تغيير كلمة المرور بنجاح';

  @override
  String get completeRegistration => 'إكمال التسجيل';

  @override
  String get none => 'لا شيء';

  @override
  String get account => 'الحساب';

  @override
  String get business => 'النشاط التجاري';

  @override
  String get location => 'الموقع';

  @override
  String get documents => 'الوثائق';

  @override
  String get createYourAccount => 'إنشاء حسابك';

  @override
  String get enterAccountDetails => 'أدخل تفاصيل حسابك للبدء';

  @override
  String get tellUsAboutYourBusiness => 'أخبرنا عن نشاطك التجاري';

  @override
  String get whereIsYourBusiness => 'أين يقع نشاطك التجاري؟';

  @override
  String get uploadDocumentsOptional =>
      'ارفع الوثائق للتحقق من نشاطك التجاري (اختياري)';

  @override
  String get selectSubcategory => 'اختر الفئة الفرعية (اختياري)';

  @override
  String get businessSubcategory => 'الفئة الفرعية للنشاط التجاري (اختياري)';

  @override
  String get uploadBusinessLicense => 'ارفع رخصة نشاطك التجاري';

  @override
  String get identityDocument => 'وثيقة الهوية';

  @override
  String get uploadIdentityDocument => 'ارفع وثيقة هويتك';

  @override
  String get uploadOwnerPhoto => 'ارفع صورة المالك';

  @override
  String get enterCountry => 'أدخل بلدك';

  @override
  String get pleaseEnterCountry => 'يرجى إدخال البلد';

  @override
  String get enterCity => 'أدخل مدينتك';

  @override
  String get pleaseEnterCity => 'يرجى إدخال المدينة';

  @override
  String get enterDistrict => 'أدخل منطقتك';

  @override
  String get pleaseEnterDistrict => 'يرجى إدخال المنطقة';

  @override
  String get enterStreetAddress => 'أدخل عنوان الشارع';

  @override
  String get pleaseEnterStreetAddress => 'يرجى إدخال عنوان الشارع';

  @override
  String get registrationSuccessful =>
      'تم التسجيل بنجاح! مرحباً بك في حاضر للأعمال.';

  @override
  String get registrationVerifiedSuccessfully => 'تم التحقق من التسجيل بنجاح!';

  @override
  String verificationFailedWithReason(Object reason) {
    return 'فشل التحقق: $reason';
  }

  @override
  String get verificationCodeSentToEmail =>
      'تم إرسال رمز التحقق إلى بريدك الإلكتروني';

  @override
  String registrationFailedWithReason(Object reason) {
    return 'فشل التسجيل: $reason';
  }

  @override
  String get confirm => 'تأكيد';

  @override
  String get didntReceiveCode => 'لم تستلم الرمز؟';

  @override
  String get wrongEmailChangeIt => 'هل البريد الإلكتروني خاطئ؟ غيّره';

  @override
  String get verificationCodeMustBe6Digits =>
      'يجب أن يتكون رمز التحقق من 6 أرقام';

  @override
  String get accountAlreadyVerifiedPleaseSignIn =>
      'تم التحقق من الحساب مسبقاً. يرجى تسجيل الدخول.';

  @override
  String get tooManyAttemptsPleaseWait =>
      'محاولات كثيرة. يرجى الانتظار ثم المحاولة مرة أخرى.';

  @override
  String get noAccountFoundForThisEmail =>
      'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';

  @override
  String get mustAgreeToTerms => 'يجب الموافقة على الشروط والأحكام';

  @override
  String get passwordRequirementsTitle => 'متطلبات كلمة المرور';

  @override
  String get passwordRequirementsBullets =>
      '• 8 أحرف على الأقل\\n• تشمل أحرفاً كبيرة وصغيرة وأرقاماً ورمزاً خاصاً';

  @override
  String get changeEmailAddressTitle => 'تغيير عنوان البريد الإلكتروني';

  @override
  String get changeEmailAddressMessage =>
      'هل أنت متأكد من رغبتك في تغيير بريدك الإلكتروني؟ سيؤدي ذلك إلى إعادتك إلى شاشة التسجيل.';

  @override
  String get invalidIraqiPhoneNumber =>
      'يرجى إدخال رقم عراقي صالح (77X/78X/79X للهاتف المحمول)';

  @override
  String get centralizedPlatform => 'المنصة المركزية';

  @override
  String get platformConnection => 'اتصال المنصة';

  @override
  String get connected => 'متصل';

  @override
  String get disconnected => 'غير متصل';

  @override
  String get syncStatus => 'حالة المزامنة';

  @override
  String get platformApps => 'تطبيقات المنصة';

  @override
  String get localBusinesses => 'الأعمال المحلية';

  @override
  String get syncRecommended => 'المزامنة مُوصى بها';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get unknown => 'Unknown';

  @override
  String get actions => 'Actions';

  @override
  String get setupPlatform => 'إعداد المنصة';

  @override
  String get syncAllBusinesses => 'مزامنة جميع الأعمال';

  @override
  String get refreshStatus => 'تحديث الحالة';

  @override
  String get failedToLoadPlatformStatus => 'فشل في تحميل حالة المنصة';

  @override
  String get platformSetupCompletedSuccessfully =>
      'تم إكمال إعداد المنصة بنجاح';

  @override
  String get platformSetupFailed => 'فشل في إعداد المنصة';

  @override
  String get errorSettingUpPlatform => 'خطأ في إعداد المنصة';

  @override
  String get allBusinessesSyncedSuccessfully => 'تم مزامنة جميع الأعمال بنجاح';

  @override
  String get failedToSyncAllBusinessesToPlatform =>
      'فشل في مزامنة جميع الأعمال مع المنصة';

  @override
  String get errorSyncingBusinesses => 'خطأ في مزامنة الأعمال';

  @override
  String get noAppsFound => 'لم يتم العثور على تطبيقات';

  @override
  String get businessDetails => 'تفاصيل النشاط التجاري';

  @override
  String get manageYourBusinessProfileAndInformation =>
      'إدارة ملف نشاطك التجاري ومعلوماتك';

  @override
  String get manageYourPersonalInformation => 'إدارة معلوماتك الشخصية';

  @override
  String get updateYourPasswordAndSecurity => 'تحديث كلمة المرور والأمان';

  @override
  String get changeAppLanguagePreference => 'تغيير لغة التطبيق المفضلة';

  @override
  String get selectYourPreferredLanguage => 'اختر لغتك المفضلة';

  @override
  String get languageChangedSuccessfully => 'تم تغيير اللغة بنجاح';

  @override
  String get configurePointOfSaleIntegration => 'تكوين تكامل نقاط البيع';

  @override
  String get soundNotifications => 'الإشعارات الصوتية';

  @override
  String get configureSoundAlertsForNewOrdersAndUpdates =>
      'تكوين التنبيهات الصوتية للطلبات الجديدة والتحديثات';

  @override
  String get manageNotificationPreferencesAndDeliveryMethods =>
      'إدارة تفضيلات الإشعارات وطرق التوصيل';

  @override
  String get manageBusinessLocationAndGpsCoordinates =>
      'إدارة موقع النشاط التجاري وإحداثيات GPS';

  @override
  String get setUpOpeningAndClosingHoursForYourBusiness =>
      'تحديد أوقات الفتح والإغلاق لنشاطك التجاري';

  @override
  String get discountManagement => 'إدارة الخصومات';

  @override
  String get createAndManageYourDiscounts => 'إنشاء وإدارة خصوماتك';

  @override
  String get reviews => 'المراجعات';

  @override
  String get joinThousandsOfBusinessOwners =>
      'انضم إلى آلاف أصحاب الأعمال الذين يثقون في منصتنا لإدارة طلباتهم وتنمية أعمالهم.';

  @override
  String get startBusinessRegistration => 'بدء تسجيل النشاط التجاري';

  @override
  String get completeBusinessRegistration => 'تسجيل النشاط التجاري بالكامل';

  @override
  String get setUpYourBusinessProfileWithAllNecessaryInformationAndDocuments =>
      'قم بإعداد ملف نشاطك التجاري بجميع المعلومات والوثائق اللازمة';

  @override
  String get secureAndVerified => 'آمن وموثق';

  @override
  String get yourBusinessWillBeVerifiedBeforeActivationForSecurityAndTrust =>
      'سيتم التحقق من نشاطك التجاري قبل التفعيل للأمان والثقة';

  @override
  String get fullDashboardAccess => 'الوصول الكامل للوحة التحكم';

  @override
  String get manageOrdersProductsAnalyticsAndBusinessSettingsInOnePlace =>
      'إدارة الطلبات والمنتجات والتحليلات وإعدادات النشاط التجاري في مكان واحد';

  @override
  String get byCreatingAnAccountYouAgreeToOurTermsOfServiceAndPrivacyPolicy =>
      'من خلال إنشاء حساب، فإنك توافق على شروط الخدمة وسياسة الخصوصية الخاصة بنا. سيتم مراجعة معلومات نشاطك التجاري قبل التفعيل.';

  @override
  String get businessDocuments => 'مستندات النشاط التجاري';

  @override
  String get uploadOptionalDocumentsToVerifyBusiness =>
      'ارفع المستندات الاختيارية للتحقق من نشاطك التجاري';

  @override
  String get uploadBusinessLicenseDocument => 'ارفع مستند رخصة نشاطك التجاري';

  @override
  String get uploadOwnerIdentificationDocument => 'ارفع مستند هوية المالك';

  @override
  String get uploadHealthCertificateIfApplicable =>
      'ارفع الشهادة الصحية إذا كانت مطلوبة';

  @override
  String get uploadPhotoOfBusinessOwner => 'ارفع صورة مالك النشاط التجاري';

  @override
  String get previous => 'السابق';

  @override
  String get merchantStatusApplicationApproved => 'تم قبول الطلب!';

  @override
  String get merchantStatusApplicationUnderReview => 'الطلب قيد المراجعة';

  @override
  String get merchantStatusApplicationRejected => 'تم رفض الطلب';

  @override
  String get merchantStatusAccountSuspended => 'تم تعليق الحساب';

  @override
  String get merchantStatusApplicationStatus => 'حالة الطلب';

  @override
  String get merchantStatusApprovedMessage =>
      'تهانينا! تم قبول طلب التاجر الخاص بك. يمكنك الآن البدء في استقبال الطلبات.';

  @override
  String get merchantStatusPendingMessage =>
      'شكراً لك على تقديم طلبك. نحن نراجع معلوماتك حالياً وسنخبرك بمجرد اكتمال العملية.';

  @override
  String get merchantStatusRejectedMessage =>
      'للأسف، تم رفض طلبك. يرجى مراجعة المتطلبات والنظر في إعادة التقديم.';

  @override
  String get merchantStatusSuspendedMessage =>
      'تم تعليق حساب التاجر الخاص بك. يرجى الاتصال بفريق الدعم للحصول على مزيد من المعلومات.';

  @override
  String get merchantStatusDefaultMessage =>
      'يرجى الاتصال بالدعم للحصول على مزيد من المعلومات حول حالة طلبك.';

  @override
  String get merchantStatusWhatHappensNext => 'ما الذي سيحدث بعد ذلك؟';

  @override
  String get merchantStatusWhatHappensNextDescription =>
      'سيقوم فريقنا بمراجعة طلبك خلال 1-2 يوم عمل. قد نتصل بك إذا كانت هناك حاجة لمعلومات إضافية.';

  @override
  String get merchantStatusWhyRejected => 'لماذا تم رفض طلبي؟';

  @override
  String get merchantStatusWhyRejectedDescription =>
      'الأسباب الشائعة تشمل الوثائق غير المكتملة، أو مشاكل في التحقق من النشاط التجاري، أو انتهاكات السياسة. اتصل بالدعم للحصول على التفاصيل.';

  @override
  String get merchantStatusAccountSuspendedInfo => 'تم تعليق الحساب';

  @override
  String get merchantStatusAccountSuspendedDescription =>
      'تم تعليق حسابك مؤقتاً. قد يكون هذا بسبب انتهاكات السياسة أو مخاوف أمنية. اتصل بالدعم للحصول على المساعدة.';

  @override
  String get merchantStatusReapply => 'إعادة التقديم';

  @override
  String get merchantStatusContactSupport => 'اتصل بالدعم';

  @override
  String get merchantStatusBackToLogin => 'العودة لتسجيل الدخول';

  @override
  String get merchantStatusSupportFeatureComingSoon =>
      'ميزة الاتصال بالدعم قريباً!';

  @override
  String get recaptchaVerificationFailed =>
      'لم يتم التحقق من reCAPTCHA. يرجى المحاولة مرة أخرى.';

  @override
  String get recaptchaVerifying => 'جاري التحقق من الأمان...';

  @override
  String get recaptchaWebToken => 'web-token';

  @override
  String get recaptchaMobileToken => 'mobile-stub-token';

  @override
  String get recaptchaMobilePlatformToken => 'mobile-platform-token';

  @override
  String failedToSaveWorkingHours(Object error) {
    return 'فشل في حفظ ساعات العمل: $error';
  }

  @override
  String errorCreatingBusiness(Object error) {
    return 'Error creating business: $error';
  }

  @override
  String get noBusinessAssociated =>
      'لا يوجد نشاط تجاري مرتبط بهذا الحساب. يرجى التواصل مع الدعم الفني.';

  @override
  String get accountNotVerified =>
      'حسابك غير مؤكد. يرجى التحقق من بريدك الإلكتروني للحصول على رمز التحقق.';

  @override
  String get accountDisabled =>
      'تم تعطيل حسابك. يرجى التواصل مع الدعم الفني للمساعدة.';

  @override
  String get tooManyLoginAttempts =>
      'محاولات تسجيل دخول كثيرة. يرجى الانتظار بضع دقائق والمحاولة مرة أخرى.';

  @override
  String get networkConnectionError =>
      'خطأ في الشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';

  @override
  String get serverUnavailable =>
      'الخادم غير متاح مؤقتاً. يرجى المحاولة مرة أخرى لاحقاً.';

  @override
  String stepXOfY(Object current, Object total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get fillFormToGetStarted => 'املأ النموذج أدناه للبدء';

  @override
  String get pleaseEnterFirstName => 'يرجى إدخال اسمك الأول';

  @override
  String get pleaseEnterLastName => 'يرجى إدخال اسم العائلة';

  @override
  String get pleaseEnterValidEmail => 'يرجى إدخال بريد إلكتروني صحيح';

  @override
  String get pleaseEnterPhoneNumber => 'يرجى إدخال رقم هاتفك';

  @override
  String get pleaseEnterPassword => 'يرجى إدخال كلمة مرور';

  @override
  String get passwordMinLength => 'يجب أن تكون كلمة المرور 8 أحرف على الأقل';

  @override
  String get passwordComplexity =>
      'يجب أن تحتوي كلمة المرور على أحرف كبيرة وصغيرة وأرقام';

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
  String get pleaseUploadBusinessPhoto => 'يرجى تحميل صورة العمل';

  @override
  String get recoverYourAccountAccess => 'استعادة الوصول إلى حسابك';

  @override
  String get sendResetCode => 'إرسال رمز إعادة التعيين';

  @override
  String get sending => 'جارٍ الإرسال...';

  @override
  String get verificationCodeSentTitle => 'تم إرسال رمز التحقق!';

  @override
  String get checkSpamFolder =>
      'تحقق من مجلد الرسائل غير المرغوب فيها إذا لم تجد الرمز في بريدك الوارد.';

  @override
  String get continueToVerification => 'متابعة إلى التحقق';

  @override
  String get rememberYourPassword => 'هل تتذكر كلمة مرورك؟ ';

  @override
  String get verificationCodeSentAgain => 'تم إرسال رمز التحقق مرة أخرى!';

  @override
  String get failedToResend => 'فشل إعادة إرسال الرمز';

  @override
  String get enterVerificationCodeSentTo => 'أدخل رمز التحقق المرسل إلى:';

  @override
  String get codeMustBeSixDigits => 'يجب أن يكون الرمز 6 أرقام';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get enterYourNewPassword => 'Enter your new password';

  @override
  String get pleaseEnterNewPassword => 'يرجى إدخال كلمة مرور جديدة';

  @override
  String get confirmNewPassword => 'أكد كلمة مرورك الجديدة';

  @override
  String get passwordResetSuccessfully => 'تم إعادة تعيين كلمة المرور بنجاح!';

  @override
  String get loadingDiscountManagement => 'جاري تحميل إدارة الخصومات...';

  @override
  String get processing => 'جارٍ المعالجة...';

  @override
  String get discountCreatedSuccessfully => 'تم إنشاء الخصم بنجاح';

  @override
  String get discountUpdatedSuccessfully => 'تم تحديث الخصم بنجاح';

  @override
  String get discountDeletedSuccessfully => 'تم حذف الخصم بنجاح';

  @override
  String get failedToCreateDiscount => 'فشل في إنشاء الخصم';

  @override
  String get failedToUpdateDiscount => 'فشل في تحديث الخصم';

  @override
  String get failedToDeleteDiscount => 'فشل في حذف الخصم';

  @override
  String get archiveAndHistory => 'الأرشيف والتاريخ';

  @override
  String get viewCancelledOrders => 'عرض الطلبات الملغية';

  @override
  String get viewDeliveredOrders => 'عرض الطلبات المسلمة';

  @override
  String get viewReturnedOrders => 'عرض الطلبات المرتجعة';

  @override
  String get viewExpiredOrders => 'عرض الطلبات المنتهية الصلاحية';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get createNewProductForMenu => 'إنشاء منتج جديد للقائمة';

  @override
  String get productInformation => 'معلومات المنتج';

  @override
  String get addDetailsImagePricing =>
      'أضف التفاصيل والصورة والتسعير لمنتجك الجديد';

  @override
  String get productImage => 'صورة المنتج';

  @override
  String get changeImage => 'تغيير الصورة';

  @override
  String get tapToAddProductImage => 'اضغط لإضافة صورة المنتج';

  @override
  String get imageFormat => 'JPG, PNG • بحد أقصى 5 ميجا';

  @override
  String get productDetails => 'تفاصيل المنتج';

  @override
  String get productName => 'اسم المنتج';

  @override
  String get enterProductName => 'أدخل اسم المنتج';

  @override
  String get enterProductDescription => 'أدخل وصف المنتج';

  @override
  String get pleaseEnterProductName => 'الرجاء إدخال اسم المنتج';

  @override
  String get pleaseEnterProductDescription => 'الرجاء إدخال وصف المنتج';

  @override
  String get pleaseAddProductImage => 'الرجاء إضافة صورة للمنتج';

  @override
  String get productAddedSuccessfully => 'تم إضافة المنتج بنجاح!';

  @override
  String failedToAddProduct(Object error) {
    return 'Failed to add product: $error';
  }

  @override
  String errorWithMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get imageUploadFailed => 'فشل تحميل الصورة';

  @override
  String get remove => 'إزالة';

  @override
  String get enterPrice => 'أدخل السعر';

  @override
  String get category => 'الفئة';

  @override
  String get price => 'السعر';

  @override
  String get description => 'Description';

  @override
  String get pleaseSignInToViewOrders => 'يرجى تسجيل الدخول لعرض الطلبات';

  @override
  String get whenOrdersComeInTheyWillAppearHere =>
      'عندما تأتي الطلبات، ستظهر هنا';

  @override
  String get ordersRefreshedSuccessfully => 'تم تحديث الطلبات بنجاح';

  @override
  String get failedToRefreshOrders => 'فشل في تحديث الطلبات';

  @override
  String get archive => 'الأرشيف';

  @override
  String get viewNow => 'عرض الآن';

  @override
  String get viewInArchive => 'عرض في الأرشيف';

  @override
  String get activeProducts => 'المنتجات النشطة';

  @override
  String get customers => 'العملاء';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get enterCurrentPassword => 'أدخل كلمة المرور الحالية';

  @override
  String get updateAccountPassword => 'تحديث كلمة مرور الحساب';

  @override
  String get currentPasswordRequired => 'كلمة المرور الحالية مطلوبة';

  @override
  String get newPasswordRequired => 'يرجى إدخال كلمة مرور جديدة';

  @override
  String get passwordMustBeDifferent =>
      'كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية';

  @override
  String get failedToChangePassword => 'فشل في تغيير كلمة المرور';

  @override
  String get changingPassword => 'جاري تغيير كلمة المرور...';

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
  String get wizzBusinessManager => 'مدير أعمال ويز';

  @override
  String get noBusinessDataAvailable => 'لا تتوفر بيانات الأعمال';

  @override
  String get error => 'خطأ';

  @override
  String get notificationsFeatureComingSoon => 'ميزة الإشعارات قريباً';

  @override
  String get settingsFeatureComingSoon => 'ميزة الإعدادات قريباً';

  @override
  String get quickOrderFeatureComingSoon => 'ميزة الطلب السريع قريباً';

  @override
  String get todaysOrders => 'طلبات اليوم';

  @override
  String get revenue => 'الإيرادات';

  @override
  String get products => 'Products';

  @override
  String get recentOrders => 'الطلبات الأخيرة';

  @override
  String get order => 'Order';

  @override
  String get customer => 'العميل';

  @override
  String get ready => 'Ready';

  @override
  String get appColorPalette => 'لوحة ألوان التطبيق';

  @override
  String get primaryYellow => 'أصفر أساسي';

  @override
  String get secondaryGold => 'ذهبي ثانوي';

  @override
  String get success => 'نجح';

  @override
  String get warning => 'Warning';

  @override
  String get info => 'Info';

  @override
  String get allOrders => 'الكل';

  @override
  String get newOrders => 'جديد';

  @override
  String get preparingOrders => 'قيد التحضير';

  @override
  String get readyOrders => 'جاهز';

  @override
  String get allOrdersShownHere => 'جميع الطلبات معروضة هنا';

  @override
  String get newOrdersShownHere => 'الطلبات الجديدة معروضة هنا';

  @override
  String get ordersBeingPrepared => 'الطلبات قيد التحضير';

  @override
  String get readyOrdersShownHere => 'الطلبات الجاهزة';

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
      'تم تأكيد الحساب بنجاح! مرحباً بك في مدير أعمال ويز.';

  @override
  String get confirmationCodeSentTo =>
      'لقد أرسلنا رمز تأكيد مكون من 6 أرقام إلى:';

  @override
  String get searchProducts => 'البحث عن المنتجات...';

  @override
  String get loadingProducts => 'جاري تحميل المنتجات...';

  @override
  String get oopsSomethingWentWrong => 'عذراً! حدث خطأ ما';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get yourProductCatalogAwaits => 'كتالوج منتجاتك في انتظارك!';

  @override
  String get noProductsFound => 'لم يتم العثور على منتجات';

  @override
  String startBuildingYourMenu(Object businessType) {
    return 'ابدأ ببناء قائمتك بإضافة منتجك الأول. أظهر ما يميز $businessType الخاص بك!';
  }

  @override
  String get tryAdjustingYourSearchTerms =>
      'حاول تعديل مصطلحات البحث أو تحقق من الإملاء.';

  @override
  String get addYourFirstProduct => 'أضف منتجك الأول';

  @override
  String get showcaseMenu => 'عرض القائمة';

  @override
  String get displayYourOfferingsBeautifully => 'اعرض عروضك بشكل جميل';

  @override
  String get manageInventory => 'إدارة المخزون';

  @override
  String get controlAvailabilityInRealTime =>
      'التحكم في التوفر في الوقت الفعلي';

  @override
  String get trackPerformance => 'تتبع الأداء';

  @override
  String get monitorSalesAndPopularity => 'راقب المبيعات والشعبية';

  @override
  String get deleteProduct => 'حذف المنتج';

  @override
  String areYouSureYouWantToDeleteProduct(Object productName) {
    return 'هل أنت متأكد من حذف \"$productName\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get productDeletedSuccessfully => 'تم حذف المنتج بنجاح';

  @override
  String get unknownError => 'خطأ غير معروف';

  @override
  String failedToDeleteProduct(Object error) {
    return 'فشل حذف المنتج: $error';
  }

  @override
  String get productUpdatedSuccessfully => 'تم تحديث المنتج بنجاح';

  @override
  String failedToUpdateProduct(Object error) {
    return 'فشل تحديث المنتج: $error';
  }

  @override
  String get availability => 'التوفر';

  @override
  String get productIsAvailable => 'المنتج متاح';

  @override
  String get productIsUnavailable => 'المنتج غير متاح';

  @override
  String get priceLabel => 'السعر';

  @override
  String errorSelectingImage(Object error) {
    return 'خطأ في اختيار الصورة';
  }

  @override
  String errorTakingPhoto(Object error) {
    return 'خطأ في التقاط الصورة: $error';
  }

  @override
  String get businessPhotoUpdatedSuccessfully =>
      'تم تحديث صورة النشاط التجاري بنجاح!';

  @override
  String failedToUploadPhoto(Object message) {
    return 'فشل تحميل الصورة: $message';
  }

  @override
  String errorUploadingPhoto(Object error) {
    return 'خطأ في تحميل الصورة: $error';
  }

  @override
  String get noBusinessFound => 'لم يتم العثور على نشاط تجاري';

  @override
  String get businessProfileUpdatedSuccessfully =>
      'تم تحديث ملف النشاط التجاري بنجاح!';

  @override
  String failedToUpdateProfile(Object error) {
    return 'فشل تحديث الملف الشخصي: $error';
  }

  @override
  String get pleaseSignInToAccessAccountSettings =>
      'يرجى تسجيل الدخول للوصول إلى إعدادات الحساب';

  @override
  String get loadingAccountInformation => 'جارٍ تحميل معلومات الحساب...';

  @override
  String get errorLoadingAccount => 'خطأ في تحميل الحساب';

  @override
  String get noBusinessFoundForThisAccount =>
      'لم يتم العثور على نشاط تجاري لهذا الحساب';

  @override
  String get notProvided => 'غير مقدم';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get notificationSettings => 'إعدادات الإشعارات';

  @override
  String get deliveryMethods => 'طرق التوصيل';

  @override
  String get pushNotifications => 'الإشعارات الفورية';

  @override
  String get receiveNotificationsOnYourDevice => 'تلقي الإشعارات على جهازك';

  @override
  String get emailNotifications => 'إشعارات البريد الإلكتروني';

  @override
  String get receiveNotificationsViaEmail =>
      'تلقي الإشعارات عبر البريد الإلكتروني';

  @override
  String get smsNotifications => 'إشعارات الرسائل النصية';

  @override
  String get receiveNotificationsViaSMS =>
      'تلقي الإشعارات عبر SMS (قد تطبق رسوم)';

  @override
  String get orderNotifications => 'إشعارات الطلبات';

  @override
  String get getNotifiedWhenNewOrdersArrive =>
      'احصل على إشعار عند وصول طلبات جديدة';

  @override
  String get orderStatusUpdates => 'تحديثات حالة الطلب';

  @override
  String get getNotifiedWhenOrderStatusChanges =>
      'احصل على إشعار عند تغيير حالة الطلب';

  @override
  String get paymentNotifications => 'إشعارات الدفع';

  @override
  String get getNotifiedAboutPaymentUpdates =>
      'احصل على إشعار حول تحديثات الدفع';

  @override
  String get settingsSavedSuccessfully => 'تم حفظ الإعدادات بنجاح!';

  @override
  String failedToSaveSettings(Object error) {
    return 'فشل حفظ الإعدادات: $error';
  }

  @override
  String get save => 'حفظ';

  @override
  String get soundSettings => 'إعدادات الصوت';

  @override
  String get enableSound => 'تفعيل الصوت';

  @override
  String get notificationSound => 'صوت الإشعار';

  @override
  String get defaultNotification => 'الإشعار الافتراضي';

  @override
  String get notificationChime => 'رنين الإشعار';

  @override
  String get bell => 'جرس';

  @override
  String get ding => 'دينغ';

  @override
  String get tone => 'نغمة';

  @override
  String get newOrderNotifications => 'إشعارات الطلبات الجديدة';

  @override
  String get playSoundWhenNewOrdersArrive => 'تشغيل الصوت عند وصول طلبات جديدة';

  @override
  String get playSoundForOrderStatusChanges =>
      'تشغيل الصوت عند تغيير حالة الطلب';

  @override
  String get systemNotifications => 'إشعارات النظام';

  @override
  String get playSoundForSystemAlerts => 'تشغيل الصوت للتنبيهات والأخطاء';

  @override
  String get vibration => 'الاهتزاز';

  @override
  String get vibrateDeviceForNewOrders => 'اهتزاز الجهاز للطلبات الجديدة';

  @override
  String volume(Object percent) {
    return 'مستوى الصوت';
  }

  @override
  String get testSound => 'اختبار الصوت';

  @override
  String get playingTestSound => 'جاري تشغيل صوت الاختبار...';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات بنجاح';

  @override
  String get soundNotificationPreferencesUpdated =>
      'تم تحديث تفضيلات إشعارات الصوت بنجاح';

  @override
  String get saveFailed => 'فشل الحفظ';

  @override
  String failedToSendVerificationCode(String error) {
    return 'فشل في إرسال رمز التحقق: $error';
  }

  @override
  String get aboutApp => 'حول التطبيق';

  @override
  String get appInformationAndVersion => 'معلومات التطبيق وتفاصيل الإصدار';

  @override
  String get version => 'الإصدار';

  @override
  String get aboutTitle => 'حول ويز لإدارة الأعمال';

  @override
  String get aboutDescription =>
      'ويز لإدارة الأعمال هو حل شامل مصمم لمساعدة أصحاب المطاعم ومديري المقاهي وتجار التجزئة على إدارة عمليات أعمالهم بكفاءة. من إدارة الطلبات إلى التحليلات، نوفر جميع الأدوات التي تحتاجها لتنمية عملك.';

  @override
  String get features => 'الميزات';

  @override
  String get featuresDescription =>
      '• إدارة الطلبات في الوقت الفعلي\n• إدارة كتالوج المنتجات\n• تحليلات ورؤى الأعمال\n• إدارة الخصومات والعروض الترويجية\n• تكوين ساعات العمل\n• دعم متعدد اللغات\n• إدارة موقع GPS\n• تكامل نظام نقاط البيع';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get contactDescription =>
      'للدعم أو الأسئلة أو الملاحظات، يرجى التواصل معنا على:\nsupport@whizzecosystem.com\n\nنحن هنا لمساعدتك على النجاح!';

  @override
  String get developer => 'Development';

  @override
  String get developerInfo =>
      'تم التطوير بحب ❤️ من قبل فريق ويز.\n\nمبني باستخدام Flutter ومدعوم بـ AWS Amplify.';

  @override
  String get allRightsReserved => 'جميع الحقوق محفوظة.';

  @override
  String get loadingLocationSettings => 'جاري تحميل إعدادات الموقع...';

  @override
  String get cityRequired => 'المدينة مطلوبة';

  @override
  String get streetNameHelper => 'اسم الشارع المستخدم لتحديد الموقع والتوصيل';

  @override
  String get streetNameRequired => 'اسم الشارع مطلوب لتحديد الموقع';

  @override
  String get saveLocationSettings => 'حفظ إعدادات الموقع';

  @override
  String get locationSettingsSavedSuccessfully => 'تم حفظ إعدادات الموقع بنجاح';

  @override
  String failedToSaveLocationSettings(String error) {
    return 'فشل في حفظ إعدادات الموقع: $error';
  }

  @override
  String failedToLoadLocationSettings(String error) {
    return 'فشل في تحميل إعدادات الموقع: $error';
  }

  @override
  String get governorate => 'المحافظة';

  @override
  String get selectGovernorate => 'اختر المحافظة';

  @override
  String get pleaseSelectGovernorate => 'الرجاء اختيار المحافظة';

  @override
  String get selectNeighborhood => 'اختر الحي';

  @override
  String get pleaseSelectNeighborhood => 'الرجاء اختيار الحي';

  @override
  String get selectGovernorateFirst => 'اختر المحافظة أولاً';

  @override
  String get selectDistrictFirst => 'Please select a district first';

  @override
  String get noNeighborhoodsAvailable =>
      'لا توجد أحياء نشطة في هذا القضاء حالياً';

  @override
  String get serviceUnavailableInRegion => 'الخدمة غير متوفرة حالياً في منطقتك';

  @override
  String get regionValidationFailed => 'فشل التحقق من المنطقة';

  @override
  String get refreshRegions => 'تحديث المناطق';

  @override
  String get selectDistrict => 'اختر القضاء';

  @override
  String get pleaseSelectDistrict => 'الرجاء اختيار القضاء';

  @override
  String get noDistrictsAvailable => 'لا توجد أقضية متاحة';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get addressPreview => 'معاينة العنوان';

  @override
  String get fullAddress => 'العنوان الكامل';

  @override
  String get coordinates => 'الإحداثيات';

  @override
  String get viewOnMap => 'عرض على الخريطة';

  @override
  String get noAddressSelected => 'الرجاء اختيار عنوان كامل من المناطق أعلاه';

  @override
  String get supportCategoryTitle => 'كيف يمكننا مساعدتك اليوم؟';

  @override
  String get supportCategorySubtitle => 'اختر فئة للبدء مع WhizzMe AI';

  @override
  String get supportPoweredBy => 'مدعوم بواسطة WhizzMe AI';

  @override
  String get supportAiDescription =>
      'سيساعدك مساعد الذكاء الاصطناعي أولاً، ثم يوصلك بموظف الدعم عند الحاجة.';

  @override
  String get categoryOrderManagement => 'الطلبات والتسليم';

  @override
  String get categoryOrderManagementDesc =>
      'الطلبات الجديدة، حالة الطلب، الإلغاءات، الاسترجاعات';

  @override
  String get categoryOrderManagementExample1 => 'لا أستقبل طلبات';

  @override
  String get categoryOrderManagementExample2 => 'طلب عالق في التحضير';

  @override
  String get categoryOrderManagementExample3 => 'طلب استرجاع';

  @override
  String get categoryPaymentIssues => 'الدفع والتحويلات';

  @override
  String get categoryPaymentIssuesDesc =>
      'طرق الدفع، مشاكل التحويلات، تأخر المدفوعات';

  @override
  String get categoryPaymentIssuesExample1 => 'تأخر في الدفعة';

  @override
  String get categoryPaymentIssuesExample2 => 'فشل الدفع';

  @override
  String get categoryPaymentIssuesExample3 => 'أسئلة عن العمولة';

  @override
  String get categoryAccountIssues => 'الحساب وتسجيل الدخول';

  @override
  String get categoryAccountIssuesDesc =>
      'مشاكل تسجيل الدخول، التحقق، تحديثات الملف الشخصي';

  @override
  String get categoryAccountIssuesExample1 => 'لا أستطيع تسجيل الدخول';

  @override
  String get categoryAccountIssuesExample2 => 'التحقق من الحساب';

  @override
  String get categoryAccountIssuesExample3 => 'إعادة تعيين كلمة المرور';

  @override
  String get categoryBusinessSetup => 'القائمة وإعدادات المتجر';

  @override
  String get categoryBusinessSetupDesc =>
      'إدارة القائمة، ساعات العمل، إعدادات العمل';

  @override
  String get categoryBusinessSetupExample1 => 'تحديث عناصر القائمة';

  @override
  String get categoryBusinessSetupExample2 => 'تغيير ساعات العمل';

  @override
  String get categoryBusinessSetupExample3 => 'التحقق من العمل';

  @override
  String get categoryTechnicalSupport => 'المشاكل التقنية';

  @override
  String get categoryTechnicalSupportDesc =>
      'انهيار التطبيق، الإشعارات، مشاكل المزامنة';

  @override
  String get categoryTechnicalSupportExample1 => 'التطبيق لا يعمل';

  @override
  String get categoryTechnicalSupportExample2 => 'لا توجد إشعارات';

  @override
  String get categoryTechnicalSupportExample3 => 'مشاكل المزامنة';

  @override
  String get categoryHumanAgent => 'التحدث مع موظف الدعم';

  @override
  String get categoryHumanAgentDesc => 'اتصال مباشر مع فريق الدعم';

  @override
  String get categoryHumanAgentExample1 => 'مشكلة معقدة';

  @override
  String get categoryHumanAgentExample2 => 'أحتاج مساعدة شخصية';

  @override
  String get categoryHumanAgentExample3 => 'موضوع عاجل';

  @override
  String get dangerZone => 'منطقة الخطر';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountButton => 'حذف الحساب';

  @override
  String get deleteAccountQuestion => 'هل تريد حذف الحساب؟';

  @override
  String get deleteAccountConfirmation =>
      'هل أنت متأكد من أنك تريد حذف حسابك بشكل دائم؟';

  @override
  String get deleteAccountWarning => 'سيؤدي هذا إلى حذف نهائي لـ:';

  @override
  String get deleteAccountItem1 => 'ملف عملك التجاري';

  @override
  String get deleteAccountItem2 => 'جميع الطلبات والسجلات';

  @override
  String get deleteAccountItem3 => 'المنتجات وعناصر القائمة';

  @override
  String get deleteAccountItem4 => 'تقييمات العملاء';

  @override
  String get deleteAccountItem5 => 'جميع بيانات الحساب';

  @override
  String get deleteAccountCannotUndo => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get verifyPassword => 'التحقق من كلمة المرور';

  @override
  String get verifyPasswordMessage => 'أدخل كلمة المرور لتأكيد حذف الحساب';

  @override
  String get deletingAccount => 'جارٍ حذف الحساب...';

  @override
  String get pleaseWait => 'الرجاء الانتظار';

  @override
  String get accountDeletedSuccessfully => 'تم حذف الحساب بنجاح';

  @override
  String get errorDeletingAccount => 'خطأ في حذف الحساب';

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

  @override
  String get phoneRequired => 'رقم الهاتف مطلوب';

  @override
  String get invalidIraqiPhone => 'أدخل رقم هاتف عراقي صحيح (07XX XXX XXXX)';

  @override
  String otpSentTo(String phone) {
    return 'أرسلنا رمزًا من 6 أرقام إلى $phone';
  }

  @override
  String get enterSixDigitCode => 'أدخل الرمز المكوّن من 6 أرقام';

  @override
  String get changeNumber => 'تغيير الرقم';

  @override
  String get verifyAndSignIn => 'تحقق وسجّل الدخول';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get otpSendFailed => 'تعذّر إرسال الرمز. حاول مرة أخرى.';

  @override
  String get phoneNotRegistered =>
      'لا يوجد حساب تاجر بهذا الرقم. يرجى التسجيل أولًا.';

  @override
  String get invalidOtp => 'الرمز غير صحيح. حاول مرة أخرى.';

  @override
  String get otpExpired =>
      'انتهت صلاحية الرمز أو تجاوزت عدد المحاولات. اطلب رمزًا جديدًا.';
}
