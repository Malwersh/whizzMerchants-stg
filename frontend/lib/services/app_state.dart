import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Reception state belongs to one branch, never to the personal account.
class AppState with ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();
  String? _branch;
  int _generation = 0;
  bool _isOnline = false, _known = false, _isToggling = false;
  bool get isOnline => _isOnline;
  bool get statusKnown => _known;
  bool get isToggling => _isToggling;
  void selectBranch(String? id) {
    if (id != null && id == _branch) return;
    ++_generation;
    _branch = id;
    _isOnline = false;
    _known = false;
    _isToggling = false;
    notifyListeners();
  }

  Future<void> initializeOnlineStatusFromDatabase(String businessId) async {
    if (_branch != businessId) return;
    final generation = _generation;
    try {
      final response = await ApiService().getBusinessOnlineStatus(businessId);
      if (generation != _generation || _branch != businessId) return;
      final value = response['data']?['acceptingOrders'];
      if (response['success'] == true && value is bool) {
        _isOnline = value;
        _known = true;
        notifyListeners();
      }
    } catch (_) {/* Do not restore another branch's status on failure. */}
  }

  Future<void> syncOnlineStatusFromDatabase(String id) =>
      initializeOnlineStatusFromDatabase(id);
  void updateOnlineStatus(bool value) {
    if (_branch == null) return;
    _isOnline = value;
    _known = true;
    notifyListeners();
  }

  Future<void> setOnline(
      bool value, Future<void> Function(bool) callback) async {
    if (_branch == null || _isToggling) return;
    final generation = _generation;
    _isToggling = true;
    notifyListeners();
    try {
      await callback(value);
      if (generation == _generation) {
        _isOnline = value;
        _known = true;
      }
    } finally {
      if (generation == _generation) {
        _isToggling = false;
        notifyListeners();
      }
    }
  }

  void logout() => selectBranch(null);
  Future<void> forceOnlineOnLogin(String id, String userId) =>
      initializeOnlineStatusFromDatabase(id);
}
