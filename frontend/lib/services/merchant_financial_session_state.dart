import 'dart:async';
import 'package:flutter/widgets.dart';

/// Opaque financial capability stays in memory, never preferences or route URLs.
class MerchantFinancialSessionState extends ChangeNotifier with WidgetsBindingObserver {
  bool _observing=false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed)clear();}
  @override
  void dispose(){if(_observing)WidgetsBinding.instance.removeObserver(this);_timer?.cancel();super.dispose();}
  static final instance = MerchantFinancialSessionState();
  String? _owner, _branch, _device, _token;
  DateTime? _expires;
  Timer? _timer;
  int revision = 0;
  Map<String, String>? access(String branch) {
    if (_branch != branch ||
        _token == null ||
        !(_expires?.isAfter(DateTime.now().toUtc()) ?? false)) {
      return null;
    }
    return {'deviceId': _device!, 'token': _token!};
  }

  bool unlocked(String owner, String branch) =>
      owner == _owner && access(branch) != null;
  void grant(
      {required String owner,
      required String branch,
      required String device,
      required String token,
      required int expiresAt}) {
    if(!_observing){WidgetsBinding.instance.addObserver(this);_observing=true;}
    clear();
    final expires =
        DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);
    if (!expires.isAfter(DateTime.now().toUtc())) return;
    _owner = owner;
    _branch = branch;
    _device = device;
    _token = token;
    _expires = expires;
    _timer = Timer(expires.difference(DateTime.now().toUtc()), clear);
    notifyListeners();
  }

  void clear() {
    revision++;
    _timer?.cancel();
    _timer = null;
    _owner = null;
    _branch = null;
    _device = null;
    _token = null;
    _expires = null;
    notifyListeners();
  }
}
