import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_header_builder.dart';
import 'token_refresh_service.dart';
import 'app_auth_service.dart';

class LegalRegistrationException implements Exception {
  final String code;
  LegalRegistrationException(this.code);
  @override
  String toString() => code;
}

class PersonOnboardingService {
  final http.Client client;
  PersonOnboardingService({http.Client? client})
      : client = client ?? http.Client();
  Future<bool> startPhoneSignIn(String phone) =>
      AppAuthService.startPhoneSignIn(phone);
  Future<bool> verifyPhoneCode(String code) async =>
      (await AppAuthService.confirmPhoneCode(code)).success;
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/auth/$path');
    final headers = authenticated
        ? await AuthHeaderBuilder.build()
        : <String, String>{'Content-Type': 'application/json'};
    // Gateway verifies the ID token; the commercial service independently
    // validates the access token and checks the live Cognito account.
    if (authenticated &&
        ['commercial-agreements', 'settlement-schedules']
            .contains(path.split('?').first)) {
      final accessToken = await TokenRefreshService.getValidUserAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('أعد تسجيل الدخول لعرض البيانات المالية والاتفاقيات.');
      }
      headers['Access-Token'] = accessToken;
    }
    final response = await (body == null
            ? client.get(uri, headers: headers)
            : client.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 20));
    final data = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode != 200) {
      if ([
        'LEGAL_VERSION_CHANGED',
        'LEGAL_ACCEPTANCE_REQUIRED',
        'LEGAL_DOCUMENTS_UNAVAILABLE'
      ].contains(data['code'])) throw LegalRegistrationException(data['code']);
      throw Exception(<String, String>{
            'PAYOUT_REAUTH_REQUIRED':
                'أعد تسجيل الدخول برمز هاتف جديد ثم حاول خلال خمس دقائق.',
            'PAYOUT_DESTINATION_VERIFICATION_REQUIRED':
                'تحقق من رقم زين كاش لهذا الطلب أولًا.',
            'PAYOUT_INVALID_PHONE': 'أدخل رقم محفظة زين كاش عراقيًا صحيحًا.',
            'PAYOUT_INVALID_CODE': 'رمز التحقق غير صحيح.',
            'PAYOUT_DESTINATION_EXPIRED':
                'انتهى التحقق أو محاولاته. ابدأ تحققًا جديدًا.',
            'PAYOUT_DESTINATION_RATE_LIMIT':
                'انتظر دقيقة قبل إعادة الإرسال. الحد خمس مرات خلال الساعة.',
            'PAYOUT_CODE_SEND_UNCONFIRMED':
                'لم نتأكد من إرسال الرمز. أعد المحاولة نفسها؛ قد يصلك الرمز السابق.',
            'PAYOUT_STATEMENT_ALREADY_CLAIMED':
                'هذا الكشف مرتبط بطلب صرف قائم. حدّث القائمة.',
            'PAYOUT_STATE_CHANGED': 'تغيرت حالة الطلب. حدّث القائمة.',
            'PAYOUT_RECEIPT_AMOUNT_MISMATCH':
                'تأكيد الاستلام يخص كامل المبلغ المثبت فقط.',
            'PAYOUT_ACCOUNT_CHANGED':
                'تغيرت الحركات أثناء التصفح. حدّث الحساب لعرض رصيد متطابق.',
            'PAYOUT_ACCOUNT_INVALID_FILTER':
                'اختر تاريخ بداية ونهاية صحيحين، بفترة لا تتجاوز سنة.',
            'PAYOUT_ACCOUNT_INVALID_CURSOR':
                'أعد تحديث الحساب قبل تحميل بقية الحركات.',
            'PAYOUT_OWNER_REQUIRED': 'هذا الإجراء متاح لمالك المطعم فقط.',
            'PAYOUT_OWNER_CHANGED':
                'تغير مالك المطعم؛ تحتاج العملية إلى مراجعة الإدارة.',
            'PAYOUT_STATEMENT_APPROVAL_REQUIRED':
                'انتظر اعتماد الإدارة للكشف أولًا.',
            'RECENT_SIGN_IN_REQUIRED':
                'لحماية جهاز الفرع وPIN، أعد تسجيل الدخول برمز هاتف جديد ثم حاول خلال خمس دقائق.',
            'INVALID_ACTIVITY_PERIOD':
                'اختر يومي بداية ونهاية صحيحين لفترة السجل.',
            'INVALID_ACTIVITY_REFERENCE':
                'أدخل معرف المنتج أو الفرع كاملًا دون مسافات.',
            'INVALID_PAIRING_CODE': 'رمز الربط غير صحيح. تحقق منه مع المالك.',
            'PAIRING_EXPIRED':
                'انتهى رمز الربط أو استُخدم. اطلب رمزًا جديدًا من المالك.',
            'INVALID_DEVICE_NAME':
                'أدخل اسمًا واضحًا للجهاز لا يتجاوز 60 حرفًا.',
            'DEVICE_REVOKED': 'الجهاز غير معتمد أو انتهت صلاحيته.',
            'DEVICE_SCOPE_REQUIRED': 'هذا الجهاز مرتبط بفرع آخر.',
            'MEMBERSHIP_REQUIRED': 'تحتاج عضوية فعالة في هذا الفرع.',
            'INVALID_PIN': 'أدخل PIN من ستة أرقام.',
            'ROLE_ORDER_BUNDLE_REQUIRED':
                'حزمة تشغيل الطلبات غير مكتملة في هذا النوع. تطلب من المنصة تجهيز القبول والرفض وتحديث الحالات معًا.',
            'STAFF_POLICY_UNAVAILABLE':
                'تعذر تحميل سياسة الصلاحيات. أعد المحاولة دون تغيير المنح.',
            'POLICY_VERSION_CONFLICT':
                'تغيرت سياسة الصلاحيات. أعد فتح الاختيار وراجع المنح قبل الحفظ.',
            'ROLE_UNAVAILABLE':
                'نوع الموظف غير متاح حاليًا. اختر نوعًا متاحًا من المنصة.',
            'PERMISSION_UNAVAILABLE':
                'إحدى الصلاحيات غير متاحة للتفويض حاليًا.',
            'DEPENDENCY_REQUIRED':
                'تحتاج الصلاحية إلى أذونات القراءة المرتبطة بها.',
            'BRANCH_READ_REQUIRED': 'اختر قراءة بيانات الفرع قبل اعتماد المنح.',
            'EXPLICIT_STAFF_GRANT_REQUIRED':
                'عدّل المنح الصريحة من سياسة المنصة لهذا الموظف.',
            'AMBIGUOUS_STAFF_GRANT':
                'اختر مسار تخصيص المنح دون خلطه بالدور القديم.',
            'INVALID_STAFF_ROLE': 'اختر دورًا وصلاحيات مدعومة.',
            'SELF_MEMBERSHIP_FORBIDDEN':
                'لا يمكن إنشاء أو تعديل عضوية للمالك بهذا المسار.',
            'INVITATION_ALREADY_PENDING':
                'توجد دعوة معلقة لهذا الرقم في الفرع. ألغها أو انتظر انتهاءها.',
            'INVITATION_UNAVAILABLE': 'الدعوة غير متاحة لهويتك أو لهذا الفرع.',
            'INVITATION_EXPIRED_OR_CHANGED':
                'انتهت الدعوة أو تغيرت حالتها. حدّث القائمة.',
            'MEMBERSHIP_ALREADY_ACTIVE':
                'للشخص عضوية فعالة في الفرع. عدّل صلاحياتها بدل دعوته مجددًا.',
            'OWNER_REQUIRED': 'هذا الإجراء متاح لمالك الفرع فقط.',
            'BRANCH_APPROVAL_REQUIRED':
                'تعتمد دعوات الموظفين بعد اعتماد الفرع.',
            'MEMBERSHIP_UNAVAILABLE': 'العضوية غير متاحة. حدّث القائمة.',
            'INVALID_CODE': 'رمز التحقق غير صحيح.',
            'PERSON_PROFILE_REQUIRED': 'أكمل ملفك الشخصي أولًا.',
            'PHONE_CHANGE_EXPIRED':
                'انتهت صلاحية التحقق أو المحاولات. ابدأ محاولة جديدة.',
            'PHONE_CHANGE_FAILED': 'لم يكتمل تغيير الرقم. ابدأ محاولة جديدة.',
            'PHONE_UNAVAILABLE': 'لا يمكن استخدام هذا الرقم لهذا الحساب.',
            'PHONE_UNCHANGED': 'أدخل رقمًا مختلفًا عن الرقم الحالي.',
            'PHONE_CHANGE_STALE':
                'تغير رقم الهاتف أثناء التحقق. أعد تحميل البيانات.',
            'PHONE_CHANGE_IN_PROGRESS':
                'يتم إكمال تغيير سابق. أعد تحميل حالة التحقق.',
            'PHONE_CHANGE_RATE_LIMIT':
                'انتظر دقيقة بين المحاولات. الحد الأقصى خمس محاولات إرسال في الساعة.',
            'PHONE_CODE_SEND_FAILED':
                'تعذر إرسال الرمز. انتظر دقيقة ثم ابدأ محاولة جديدة.',
            'CHANGE_BASE_CONFLICT':
                'تغيرت بيانات الفرع. أعد تحميلها ثم قدم الطلب.',
            'REQUEST_ID_CONFLICT':
                'تغيرت بيانات محاولة الإرسال. أعد فتح الشاشة.',
            'INVALID_TEXT': 'أكمل الاسم وسبب التعديل.',
            'BUSINESS_UNAVAILABLE': 'النشاط غير متاح لهذا الحساب.',
            'SETTLEMENT_SCHEDULE_ADMIN_DISABLED':
                'إدارة جداول التسوية لم تُفعّل بعد.',
            'SCHEDULE_OWNER_REQUIRED': 'موافقة مالك المتجر مطلوبة لهذا الجدول.',
            'SCHEDULE_PROPOSAL_CONFLICT':
                'تغيّر الاقتراح. حدّث الصفحة وراجع البيانات.',
            'SCHEDULE_FUTURE_BOUNDARY_REQUIRED':
                'انقضى تاريخ بداية الاقتراح. يلزم اقتراح جديد.',
            'SCHEDULE_BASE_VERSION_CONFLICT':
                'تغيّر الجدول المعتمد. حدّث الصفحة.',
            'SCHEDULE_CONFLICT_OR_UNKNOWN_OUTCOME_RETRY_SAME_PROPOSAL':
                'تعذر التحقق من النتيجة. أعد المحاولة على الطلب نفسه.',
            'COMMERCIAL_MANAGEMENT_DISABLED':
                'إدارة الاتفاقيات التجارية لم تُفتح بعد على هذه البيئة.',
            'COMMERCIAL_RECENT_SIGN_IN_REQUIRED':
                'أعد تسجيل الدخول لتأكيد موافقتك على الاتفاقية التجارية.',
            'FUNDING_TERMS_CHANGED':
                'تغيرت شروط تمويل الخصم. اطلب مراجعة النسخة الجديدة قبل الموافقة.',
            'INVALID_PHONE': 'أدخل رقم هاتف عراقيًا صحيحًا.',
            'REGION_PATH_REQUIRED': 'اختر البلد والمحافظة والقضاء والمنطقة.',
            'REGION_UNAVAILABLE':
                'منطقة العمل غير متاحة أو لا تتبع المناطق المختارة. أعد تحميل المناطق.',
            'LOCATION_OUTSIDE_REGION':
                'الموقع خارج المنطقة المختارة. صحح الدبوس أو اختيار المنطقة.',
            'INVALID_HOURS':
                'تحقق من ساعات العمل: وقت الإغلاق بعد الفتح والفترات لا تتداخل.',
            'REGISTRATION_CLOSED':
                'التسجيل غير متاح لهذا النوع أو المنطقة حاليًا. تبقى المسودة محفوظة.',
            'ASSET_UNAVAILABLE': 'المرفق غير متاح. أعد رفعه ثم حاول مجددًا.',
            'ASSET_SIZE_LIMIT': 'الحد الأقصى للمرفق 3 ميغابايت.',
            'UNSUPPORTED_ASSET_FORMAT':
                'اختر صورة JPEG أو PNG أو شهادة PDF مدعومة.',
            'PARTNERSHIP_AGREEMENT_REQUIRED':
                'تحتاج الاتفاقية إلى تحديث أو موافقة قبل التقديم.',
            'BRANCH_DETAILS_REQUIRED':
                'أكمل عنوان الفرع والموقع وساعات العمل قبل التقديم.',
            'INVALID_EMAIL': 'تحقق من البريد الإلكتروني.',
            'ACCOUNT_CLOSING': 'الحساب قيد الحذف.',
            'ACKNOWLEDGEMENT_REQUIRED': 'يجب تأكيد الموافقة أولًا.',
            'PERSONAL_DETAILS_REQUIRED': 'تحقق من الاسم والموافقة.',
            'VERSION_OR_STATE_CONFLICT':
                'تغيرت البيانات أو حالة الطلب. أعد تحميل الشاشة.'
          }[data['code']] ??
          'تعذر إكمال العملية. حاول مجددًا.');
    }
    return data;
  }
}
