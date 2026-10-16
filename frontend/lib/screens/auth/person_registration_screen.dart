import 'auth_surface.dart';
import 'dart:async';
import '../../providers/login_intent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/person_onboarding_service.dart';
import '../../services/app_auth_service.dart';
import '../../providers/auth_provider_riverpod.dart';

class PersonRegistrationScreen extends ConsumerStatefulWidget {
  final PersonOnboardingService? service;
  const PersonRegistrationScreen({super.key, this.service});
  @override
  ConsumerState<PersonRegistrationScreen> createState() =>
      _PersonRegistrationScreenState();
}

class _PersonRegistrationScreenState
    extends ConsumerState<PersonRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(),
      _last = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _code = TextEditingController();
  late final _api = widget.service ?? PersonOnboardingService();
  Map<String, dynamic>? _ack;
  bool _accepted = false, _busy = false, _sent = false, _verified = false;
  String? _error, _e164;
  Timer? _timer;
  int _seconds = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ack = await _api.call('person-registration', authenticated: false);
      if (mounted)
        setState(() {
          _ack = ack;
          _error = null;
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل معلومات التسجيل.');
    }
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _email, _code]) {
      c.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _countdown() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _seconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _send({bool resend = false}) async {
    if (!resend && (!_form.currentState!.validate() || !_accepted)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!resend) {
        _e164 = AppAuthService.normalizeIraqiPhone(_phone.text);
        await _api.call('person-registration', authenticated: false, body: {
          'firstName': _first.text.trim(),
          'lastName': _last.text.trim(),
          'phoneNumber': _e164,
          'email': _email.text.trim(),
          'acknowledgementVersion': _ack!['acknowledgementVersion']
        });
      }
      final sent = await _api.startPhoneSignIn(_e164!);
      if (!sent) throw Exception('تعذر إرسال رمز التحقق.');
      if (mounted) {
        setState(() => _sent = true);
        _countdown();
      }
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'تعذر إرسال رمز التحقق. تحقق من البيانات والاتصال ثم حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (!_verified && !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'أدخل رمز التحقق المكون من 6 أرقام.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_verified) {
        final success = await _api.verifyPhoneCode(_code.text.trim());
        if (!success) throw Exception('رمز غير صحيح أو منتهي.');
        _verified = true;
      }
      await _api.call('person-profile',
          body: {'acknowledgementVersion': _ack!['acknowledgementVersion']});
      if (!mounted) return;
      ref.read(authProviderRiverpod.notifier).setAuthenticated();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted)
        setState(() => _error = _verified
            ? 'تم تأكيد الهاتف، لكن تعذر حفظ الحساب. اضغط متابعة للمحاولة مجددًا.'
            : 'رمز غير صحيح أو منتهي، أو تعذر الاتصال. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label,
          {TextInputType? keyboard, bool optional = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: controller,
              keyboardType: keyboard,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
              validator: (v) {
                if (!optional && (v == null || v.trim().isEmpty))
                  return 'هذا الحقل مطلوب';
                if (controller == _phone &&
                    AppAuthService.normalizeIraqiPhone(v ?? '') == null)
                  return 'أدخل رقم هاتف عراقيًا صحيحًا';
                if (controller == _email &&
                    v != null &&
                    v.trim().isNotEmpty &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()))
                  return 'تحقق من البريد الإلكتروني';
                return null;
              }));
  @override
  Widget build(BuildContext context) => AuthSurface(
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              appBar: AppBar(
                  title: Text(_sent
                      ? 'تأكيد رقم الهاتف'
                      : (ref.watch(loginIntentProvider) == LoginIntent.employee
                          ? 'إنشاء حساب موظف'
                          : 'إنشاء حساب المالك'))),
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                _sent
                                    ? 'أدخل الرمز المرسل إلى $_e164'
                                    : (ref.watch(loginIntentProvider) ==
                                            LoginIntent.employee
                                        ? 'أنشئ حسابك الشخصي بالرقم المدعو، ثم أكد انضمامك إلى الفرع. لا تحتاج إلى إنشاء نشاط.'
                                        : 'أنشئ حسابك الشخصي أولًا، ثم أضف أنشطتك وفروعك.'),
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 24),
                            if (!_sent) ...[
                              _field(_first, 'الاسم الأول'),
                              _field(_last, 'اسم العائلة'),
                              _field(_phone, 'رقم الهاتف',
                                  keyboard: TextInputType.phone),
                              _field(_email, 'البريد الإلكتروني — اختياري',
                                  keyboard: TextInputType.emailAddress,
                                  optional: true),
                              if (_ack != null)
                                CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _accepted,
                                    onChanged: _busy
                                        ? null
                                        : (v) => setState(
                                            () => _accepted = v ?? false),
                                    title: Text(_ack!['acknowledgementText']
                                        as String)),
                              if (_ack == null)
                                TextButton(
                                    onPressed: _load,
                                    child: const Text('تحميل معلومات التسجيل')),
                              FilledButton(
                                  onPressed: _busy || !_accepted || _ack == null
                                      ? null
                                      : () => _send(),
                                  child: Text(_busy
                                      ? 'جارٍ إرسال الرمز…'
                                      : 'إرسال رمز التحقق')),
                            ] else ...[
                              if (!_verified)
                                TextField(
                                    controller: _code,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                        labelText: 'رمز التحقق',
                                        border: OutlineInputBorder())),
                              FilledButton(
                                  onPressed: _busy ? null : _verify,
                                  child: Text(_busy
                                      ? 'جارٍ التحقق…'
                                      : _verified
                                          ? 'متابعة'
                                          : 'تأكيد الهاتف ومتابعة')),
                              if (!_verified)
                                TextButton(
                                    onPressed: _busy || _seconds > 0
                                        ? null
                                        : () => _send(resend: true),
                                    child: Text(_seconds > 0
                                        ? 'إعادة الإرسال بعد $_seconds ثانية'
                                        : 'إعادة إرسال الرمز')),
                            ],
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                          ]))))));
}
