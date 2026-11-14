import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/person_onboarding_service.dart';
import '../services/app_auth_service.dart';
import 'auth/auth_surface.dart';

class BranchDevicePinSetupScreen extends StatefulWidget {
  final String businessId, deviceToken;
  final PersonOnboardingService? service;
  const BranchDevicePinSetupScreen(
      {super.key,
      required this.businessId,
      required this.deviceToken,
      this.service});
  @override
  State<BranchDevicePinSetupScreen> createState() => _PinSetupState();
}

class _PinSetupState extends State<BranchDevicePinSetupScreen> {
  final phone = TextEditingController(),
      otp = TextEditingController(),
      pin = TextEditingController(),
      repeat = TextEditingController();
  late final api = widget.service ?? PersonOnboardingService();
  int step = 0;
  bool busy = false, verified = false;
  String? error;
  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    pin.dispose();
    repeat.dispose();
    super.dispose();
  }

  Future<void> next() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (step == 0) {
        final normalized = AppAuthService.normalizeIraqiPhone(phone.text);
        if (normalized == null) {
          throw Exception('أدخل رقم هاتف عراقيًا صحيحًا، مثل 07XX XXX XXXX.');
        }
        if (!await api.startPhoneSignIn(normalized))
          throw Exception('تعذر إرسال الرمز. تحقق من الرقم ثم حاول مجددًا.');
        if (mounted) setState(() => step = 1);
      } else if (step == 1) {
        if (!await api.verifyPhoneCode(otp.text))
          throw Exception('رمز التحقق غير صحيح أو منتهي.');
        verified = true;
        if (mounted) setState(() => step = 2);
      } else {
        if (!RegExp(r'^\d{6}$').hasMatch(pin.text) || pin.text != repeat.text)
          throw Exception('أدخل ستة أرقام متطابقة في الحقلين.');
        await api.call('branch-devices', body: {
          'action': 'set_pin',
          'businessId': widget.businessId,
          'deviceToken': widget.deviceToken,
          'pin': pin.text
        });
        await AppAuthService.signOut();
        verified = false;
        if (mounted) Navigator.pop(context, true);
      }
    } on PhoneAuthException catch (e) {
      if (mounted) {
        setState(() => error = e.error == PhoneAuthError.notRegistered
            ? 'لم يُعثر على حساب بهذا الرقم. استخدم رقم دخول الموظف الذي قبل الدعوة.'
            : 'تعذر إرسال رمز التحقق. حاول مجددًا بعد قليل.');
      }
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> leave() async {
    if (busy) return false;
    if (verified) {
      await AppAuthService.signOut();
      verified = false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => AuthSurface(
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: WillPopScope(
              onWillPop: leave,
              child: Scaffold(
                  appBar: AppBar(title: const Text('إعداد PIN الشخصي')),
                  body: ListView(padding: const EdgeInsets.all(24), children: [
                    const Icon(Icons.pin_outlined,
                        size: 48, color: Color(0xFF00296B)),
                    const SizedBox(height: 20),
                    Text(
                        [
                          'تحقق من رقم هاتفك',
                          'أدخل رمز التحقق',
                          'اختر PIN للعمل اليومي'
                        ][step],
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text(
                        'PIN خاص بك على أجهزة الفرع المعتمدة. لا تشاركه مع زملائك. تُغلق مهامك تلقائيًا بعد دقيقتين، ويستمر الجهاز في الاستقبال.'),
                    const SizedBox(height: 24),
                    if (step == 0)
                      TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                              labelText: 'هاتف حساب الموظف',
                              hintText: '07XX XXX XXXX',
                              helperText: 'رقم دخول الموظف الذي قبل دعوة الفرع',
                              prefixText: '+964 ',
                              border: OutlineInputBorder())),
                    if (step == 1)
                      TextField(
                          controller: otp,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: 'رمز التحقق المرسل لهاتفك',
                              border: OutlineInputBorder())),
                    if (step == 2) ...[
                      for (final field in [pin, repeat])
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                                controller: field,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                obscureText: true,
                                maxLength: 6,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: InputDecoration(
                                    labelText: field == pin
                                        ? 'PIN من ستة أرقام'
                                        : 'تأكيد PIN',
                                    border: const OutlineInputBorder()))),
                    ],
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(error!,
                              style:
                                  const TextStyle(color: Color(0xFFB3261E)))),
                    FilledButton(
                        onPressed: busy ? null : next,
                        child: Text(busy
                            ? 'جارٍ التحقق…'
                            : step == 0
                                ? 'إرسال رمز التحقق'
                                : step == 1
                                    ? 'تحقق ومتابعة'
                                    : 'حفظ PIN')),
                  ])))));
}
