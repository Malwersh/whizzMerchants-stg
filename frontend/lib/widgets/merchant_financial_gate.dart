import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/whizz_colors.dart';
import '../providers/auth_provider_riverpod.dart';
import '../services/merchant_financial_session_state.dart';
import '../services/person_onboarding_service.dart';

/// Enable only alongside server enforcement on every financial entry point.
const merchantFinancialLockEnabled =
    bool.fromEnvironment('MERCHANT_FINANCIAL_LOCK_ENABLED');

class MerchantFinancialGate extends ConsumerStatefulWidget {
  final String branchId;
  final Widget child;
  const MerchantFinancialGate(
      {super.key, required this.branchId, required this.child});
  @override
  ConsumerState<MerchantFinancialGate> createState() =>
      _MerchantFinancialGateState();
}

class _MerchantFinancialGateState extends ConsumerState<MerchantFinancialGate>
    with WidgetsBindingObserver {
  final _session = MerchantFinancialSessionState.instance;
  final _api = PersonOnboardingService();
  final _code = TextEditingController();
  String? _device, _challenge, _error;
  DateTime? _resendAt;
  bool _busy = false;
  int _generation = 0;
  String _owner() {
    final auth = ref.read(authProviderRiverpod);
    return auth.isAuthenticated
        ? (auth.currentUser?['sub'] ?? auth.currentUser?['userId'] ?? '')
            .toString()
        : '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _generation++;
      final access = _session.access(widget.branchId);
      _session.clear();
      if (access != null) {
        unawaited(_api.call('settlement-schedules', body: {
          'action': 'FINANCIAL_LOCK',
          'branchId': widget.branchId,
          ...access,
        }).then<void>((_) {}, onError: (Object _) {}));
      }
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant MerchantFinancialGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _generation++;
      _session.clear();
      _challenge = null;
      _code.clear();
      _busy = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_changed);
    _code.dispose();
    super.dispose();
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('merchant_financial_device_id');
    if (id == null) {
      id = const Uuid().v4().replaceAll('-', '');
      await prefs.setString('merchant_financial_device_id', id);
    }
    return id;
  }

  Future<void> _run(bool verify) async {
    if (_busy) return;
    final owner = _owner(),
        branch = widget.branchId,
        generation = ++_generation;
    if (owner.isEmpty) {
      setState(() {
        _error = 'سجّل دخول المالك أولًا.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _device ??= await _deviceId();
      final result = await _api.call('settlement-schedules', body: {
        'action': verify ? 'FINANCIAL_UNLOCK' : 'FINANCIAL_START',
        'branchId': branch,
        'deviceId': _device,
        if (verify) ...{'challengeId': _challenge, 'code': _code.text.trim()},
      });
      if (!mounted ||
          generation != _generation ||
          owner != _owner() ||
          branch != widget.branchId) {
        return;
      }
      if (verify) {
        final token = result['token'], expiry = result['expiresAt'];
        if (token is! String || expiry is! int) {
          throw Exception('تعذر تأكيد التحقق المالي.');
        }
        _session.grant(
            owner: owner,
            branch: branch,
            device: _device!,
            token: token,
            expiresAt: expiry);
        _code.clear();
      } else {
        _challenge = result['challengeId'] as String;
        _resendAt = DateTime.fromMillisecondsSinceEpoch(
            (result['resendAfter'] as int) * 1000,
            isUtc: true);
        if (result['delivery'] == 'UNCONFIRMED') {
          _error = 'لم نتأكد من إرسال الرمز. إذا وصلك يمكنك إدخاله هنا.';
        }
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProviderRiverpod, (previous, next) {
      if (previous?.currentUser?['sub'] != next.currentUser?['sub'] ||
          previous?.currentUser?['userId'] != next.currentUser?['userId'] ||
          !next.isAuthenticated) {
        _generation++;
        _session.clear();
        _challenge = null;
        _code.clear();
        _busy = false;
      }
    });
    if (_session.unlocked(_owner(), widget.branchId)) return widget.child;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: WhizzColors.grey50,
          appBar: AppBar(
              title: const Text('التحقق المالي'),
              backgroundColor: Colors.white),
          body: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 24),
            const Icon(Icons.lock_outline,
                size: 48, color: WhizzColors.secondary),
            const SizedBox(height: 20),
            const Text('بياناتك المالية خاصة',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: WhizzColors.secondary)),
            const SizedBox(height: 12),
            const Text(
                'للإطلاع على المستحقات والصرف، أكّد هويتك برمز يُرسل إلى رقم المالك الموثّق. تُقفل البيانات عند مغادرة التطبيق.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (_challenge != null)
              TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                      labelText: 'رمز التحقق', border: OutlineInputBorder())),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red))),
            FilledButton(
                onPressed: _busy ? null : () => _run(_challenge != null),
                style: FilledButton.styleFrom(
                    backgroundColor: WhizzColors.secondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48)),
                child: Text(_busy
                    ? 'جارٍ التحقق…'
                    : _challenge == null
                        ? 'إرسال رمز للمالك'
                        : 'فتح القسم المالي')),
            if (_challenge != null)
              TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_resendAt?.isAfter(DateTime.now().toUtc()) ??
                              false) {
                            setState(() {
                              _error = 'انتظر دقيقة قبل إعادة إرسال الرمز.';
                            });
                            return;
                          }
                          _run(false);
                        },
                  child: const Text('إعادة إرسال الرمز')),
          ]),
        ));
  }
}
