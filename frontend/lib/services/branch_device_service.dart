import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class BranchDeviceException implements Exception {
  final String code;
  BranchDeviceException(this.code);
  @override
  String toString() =>
      {
        'DEVICE_REVOKED': 'انتهى اعتماد الجهاز أو ألغاه المالك. أعد ربطه.',
        'SESSION_REVOKED': 'قُفلت مهامك. افتحها برمز PIN من جديد.',
        'MEMBERSHIP_REVOKED': 'تغيرت عضويتك أو سُحبت. راجع مالك الفرع.',
        'INVALID_PIN': 'رمز PIN غير صحيح. بعد خمس محاولات يلزم إعادة إعداده.',
        'PIN_RESET_REQUIRED': 'يلزم إعداد PIN بعد التحقق من هاتفك.',
        'WALLET_UNAVAILABLE': 'المحفظة غير متاحة لهذا الفرع حاليًا.',
        'FINANCIAL_READ_UNAVAILABLE':
            'تعذر تحميل بيانات المحفظة. أعد المحاولة.',
        'CATEGORY_UNAVAILABLE':
            'القسم غير متاح. حدّث قائمة الأقسام واختر قسمًا آخر.',
        'PRODUCT_UNAVAILABLE': 'المنتج غير متاح لهذا الفرع. حدّث القائمة.',
        'PRODUCT_REMOVED': 'حُذف هذا المنتج. لا تعيد المحاولة القديمة إنشاءه.',
        'REQUEST_ID_CONFLICT': 'تغير محتوى محاولة الحفظ. ابدأ محاولة جديدة.',
        'BRANCH_NOT_READY':
            'لا يمكن تشغيل الاستقبال. تحقق من جاهزية الفرع أو تواصل مع المنصة.',
        'INVALID_STATUS_REQUEST':
            'تعذر حفظ الحالة. حدّث الشاشة ثم حاول مجددًا.',
        'INVALID_DISCOUNT': 'راجع اسم الخصم وقيمته وفترته والحد الأدنى للطلب.',
        'DISCOUNT_UNAVAILABLE': 'الخصم غير متاح لهذا الفرع. حدّث القائمة.',
        'DISCOUNT_UNSUPPORTED':
            'هذا النوع من الخصومات للقراءة فقط في مسار الموظف حاليًا.',
        'DISCOUNT_EXPIRED': 'انتهت فترة الخصم. عدّل الفترة قبل تفعيله.',
        'INVALID_PRICE': 'أدخل سعرًا صحيحًا موجبًا بالدينار.',
        'INVALID_MENU_CREATE': 'راجع اسم المنتج وقسمه وبياناته.',
        'PERMISSION_REQUIRED': 'ليس لديك إذن لتنفيذ هذا الإجراء.',
        'VERSION_OR_STATE_CONFLICT':
            'تغيرت البيانات. حدّث الشاشة ثم حاول مجددًا.',
      }[code] ??
      'تعذر الاتصال بالخادم. لم تُعتمد العملية؛ أعد المحاولة.';
}

class BranchDeviceService {
  final http.Client client;
  BranchDeviceService({http.Client? client}) : client = client ?? http.Client();
  Future<Map<String, dynamic>> operation(String token, String path,
      {String? session, Map<String, dynamic>? body, String? method}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/branch-device/$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      if (session != null) 'X-Staff-Session': session
    };
    final request = http.Request(method ?? (body == null ? 'GET' : 'PUT'), uri)
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    final data = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw BranchDeviceException(data['code'] ?? 'UNAVAILABLE');
    return data;
  }

  Future<Map<String, dynamic>> call(String token, Map<String, dynamic> body,
      {String? session}) async {
    final response = await client
        .post(Uri.parse('${AppConfig.baseUrl}/branch-device'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              if (session != null) 'X-Staff-Session': session
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    final data = Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode != 200)
      throw BranchDeviceException(data['code'] ?? 'UNAVAILABLE');
    return data;
  }
}
