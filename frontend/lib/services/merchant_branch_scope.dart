import 'package:shared_preferences/shared_preferences.dart';

/// A request captures its selected branch once. The server verifies ownership.
class MerchantBranchScope {
  final String businessId;
  final int _capturedRevision;
  const MerchantBranchScope._(this.businessId, this._capturedRevision);
  static int _revision = 0;
  static bool _selectionKnown = false;
  static String? _selected;

  static void selectionChanged(String? businessId) {
    _selectionKnown = true;
    _selected = businessId;
    ++_revision;
  }

  static Future<MerchantBranchScope> capture({String? businessId}) async {
    final prefs = await SharedPreferences.getInstance();
    final selected = businessId ??
        (_selectionKnown
            ? _selected
            : (prefs.getString('business_id') ??
                prefs.getString('session_business_id')));
    if (selected == null || selected.trim().isEmpty) {
      throw StateError('اختر الفرع أولاً ثم أعد المحاولة.');
    }
    return MerchantBranchScope._(selected, _revision);
  }

  Uri uri(String url, {Map<String, String> query = const {}}) => Uri.parse(url)
      .replace(queryParameters: {...query, 'businessId': businessId});

  Map<String, dynamic> body(Map<String, dynamic> values) =>
      {...values, 'businessId': businessId};

  Future<void> assertCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = _selectionKnown
        ? _selected
        : (prefs.getString('business_id') ??
            prefs.getString('session_business_id'));
    if (selected != businessId || _capturedRevision != _revision) {
      throw StateError(
          'تم تغيير الفرع أثناء العملية. أعد فتح الشاشة وحاول مجددًا.');
    }
  }
}
