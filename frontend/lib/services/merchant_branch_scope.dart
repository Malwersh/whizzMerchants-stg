import 'package:shared_preferences/shared_preferences.dart';

/// A request captures its selected branch once. The server verifies ownership.
class MerchantBranchScope {
  final String businessId;
  const MerchantBranchScope._(this.businessId);

  static Future<MerchantBranchScope> capture({String? businessId}) async {
    final prefs = await SharedPreferences.getInstance();
    final selected = businessId ??
        prefs.getString('business_id') ??
        prefs.getString('session_business_id');
    if (selected == null || selected.trim().isEmpty) {
      throw StateError('اختر الفرع أولاً ثم أعد المحاولة.');
    }
    return MerchantBranchScope._(selected);
  }

  Uri uri(String url, {Map<String, String> query = const {}}) => Uri.parse(url)
      .replace(queryParameters: {...query, 'businessId': businessId});

  Map<String, dynamic> body(Map<String, dynamic> values) =>
      {...values, 'businessId': businessId};

  Future<void> assertCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString('business_id') ??
        prefs.getString('session_business_id');
    if (selected != businessId) {
      throw StateError('تم تغيير الفرع أثناء العملية. أعد فتح شاشة الاستيراد.');
    }
  }
}
