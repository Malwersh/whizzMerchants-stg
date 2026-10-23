import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/person_onboarding_service.dart';

class PersonProfileScreen extends StatefulWidget {
  final PersonOnboardingService? service;
  final String? businessId;
  const PersonProfileScreen({super.key, this.service, this.businessId});
  @override
  State<PersonProfileScreen> createState() => _PersonProfileScreenState();
}

class _PersonProfileScreenState extends State<PersonProfileScreen> {
  late final api = widget.service ?? PersonOnboardingService();
  final name = TextEditingController(), email = TextEditingController();
  final phone = TextEditingController(), code = TextEditingController();
  Map<String, dynamic>? profile, challenge;
  String? error, notice, requestId;
  bool busy = true;
  bool get branch => widget.businessId != null;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => perform(() async {
        final r = await api.call('person-profile');
        if (!mounted) return;
        setState(() {
          profile = r['profile'] == null
              ? null
              : Map<String, dynamic>.from(r['profile']);
          final c = r['challenge'];
          challenge = c != null &&
                  c['scope'] == (branch ? 'BRANCH' : 'PERSONAL') &&
                  (!branch || c['businessId'] == widget.businessId)
              ? Map<String, dynamic>.from(c)
              : null;
          name.text = profile?['name'] ?? '';
          email.text = profile?['email'] ?? '';
        });
      });
  Future<void> completeProfile() => perform(() async {
        final ack = await api.call('person-registration', authenticated: false);
        if (!mounted) return;
        final accepted = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    title: const Text('إكمال الملف الشخصي'),
                    content: Text(ack['acknowledgementText']),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('موافق'))
                    ]));
        if (accepted != true) return;
        final r = await api.call('person-profile',
            body: {'acknowledgementVersion': ack['acknowledgementVersion']});
        if (mounted)
          setState(() {
            profile = Map<String, dynamic>.from(r['profile']);
            name.text = profile!['name'] ?? '';
            email.text = profile!['email'] ?? '';
          });
      });
  Future<void> save() => perform(() async {
        final r = await api.call('person-profile', body: {
          'action': 'update_details',
          'name': name.text,
          'email': email.text,
          'baseVersion': profile!['version']
        });
        if (mounted)
          setState(() {
            profile = Map<String, dynamic>.from(r['profile']);
            notice = 'حُفظت بياناتك الشخصية.';
          });
      });
  Future<void> start() => perform(() async {
        requestId ??= const Uuid().v4();
        final r = await api.call('person-profile', body: {
          'action': 'start_phone_change',
          'scope': branch ? 'BRANCH' : 'PERSONAL',
          'newPhone': phone.text,
          'requestId': requestId,
          if (branch) 'businessId': widget.businessId
        });
        if (mounted)
          setState(() {
            challenge = Map<String, dynamic>.from(r['challenge']);
            code.clear();
          });
      });
  Future<void> verify() => perform(() async {
        final r = await api.call('person-profile', body: {
          'action': 'verify_phone_change',
          'requestId': challenge!['requestId'],
          'code': code.text
        });
        if (!mounted) return;
        if (r['success'] == true) {
          setState(() {
            challenge = null;
            requestId = null;
            code.clear();
            phone.clear();
            if (r['profile'] != null)
              profile = Map<String, dynamic>.from(r['profile']);
            notice = branch
                ? 'حُفظ هاتف الفرع بعد إثبات الرقم.'
                : 'حُفظ هاتف الدخول الجديد. استخدمه في تسجيل الدخول القادم.';
          });
        } else {
          setState(() {
            challenge = Map<String, dynamic>.from(r['challenge']);
            code.clear();
          });
        }
      });
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: Text(branch ? 'هاتف تواصل الفرع' : 'بياناتي الشخصية')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(branch
              ? 'هذا الرقم لتواصل الفرع فقط؛ تغييره لا يغير هاتف دخولك.'
              : 'تحديث اسمك وبريد التواصل يسري على ملفك الشخصي. تبقى ملكية الأنشطة وسجلاتها التاريخية كما هي.'),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (notice != null) Text(notice!),
          if (profile == null && !busy) ...[
            const Text('يجب إكمال إنشاء ملفك الشخصي أولًا.'),
            FilledButton(
                onPressed: completeProfile,
                child: const Text('إكمال الملف الشخصي')),
            TextButton(onPressed: load, child: const Text('إعادة التحميل')),
          ],
          if (profile != null) ...[
            if (!branch) ...[
              TextField(
                  controller: name,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'الاسم الشخصي'),
                  maxLength: 200),
              TextField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                      labelText: 'بريد التواصل (اختياري وغير موثق)'),
                  maxLength: 254),
              FilledButton(
                  onPressed: busy ? null : save,
                  child: const Text('حفظ بياناتي')),
              ListTile(
                  title: const Text('هاتف الدخول الحالي'),
                  subtitle: Text(profile!['phoneNumber'] ?? '',
                      textDirection: TextDirection.ltr)),
              const Divider(),
            ],
            const Text('تغيير رقم الهاتف'),
            if (challenge == null) ...[
              TextField(
                  controller: phone,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  onChanged: (_) => requestId = null,
                  decoration: const InputDecoration(
                      labelText: 'الرقم الجديد', hintText: '07XX XXX XXXX')),
              Text(branch
                  ? 'سنرسل رمز تحقق إلى الرقم الجديد.'
                  : 'سنطلب رمز الرقم الحالي أولًا ثم رمز الرقم الجديد.'),
              FilledButton(
                  onPressed: busy ? null : start,
                  child: const Text('بدء التحقق')),
            ] else ...[
              Text(challenge!['stage'] == 'OLD_PHONE'
                  ? 'أدخل الرمز المرسل إلى رقمك الحالي'
                  : challenge!['stage'] == 'APPLYING'
                      ? 'جارٍ إكمال حفظ الرقم. يمكنك إعادة المحاولة.'
                      : 'أدخل الرمز المرسل إلى الرقم الجديد'),
              Text(challenge!['maskedPhone'] ?? '',
                  textDirection: TextDirection.ltr),
              if (challenge!['stage'] != 'APPLYING')
                TextField(
                    controller: code,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'رمز التحقق')),
              FilledButton(
                  onPressed: busy ? null : verify,
                  child: const Text('تأكيد ومتابعة')),
              if (challenge!['stage'] != 'APPLYING')
                TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              challenge = null;
                              requestId = null;
                              code.clear();
                            });
                          },
                    child: const Text('بدء محاولة جديدة')),
            ],
            TextButton(
                onPressed: busy ? null : load,
                child: const Text('إعادة تحميل البيانات وحالة التحقق')),
          ],
        ]),
      ));
}
