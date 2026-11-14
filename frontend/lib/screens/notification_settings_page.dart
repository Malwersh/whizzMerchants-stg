import '../services/sound_notification_settings.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import '../services/push_notifications_service.dart';

/// Device permission comes from the OS. No local switches pretending to control
/// server delivery; category delivery preferences require a server contract.
class NotificationSettingsPage extends StatefulWidget {
  final Future<AuthorizationStatus> Function()? readPermission;
  final Future<AuthorizationStatus> Function()? requestPermission;
  final Future<void> Function()? registerDevice;
  final Future<bool> Function()? openSettings;
  final ValueNotifier<String>? registrationStatus;
  const NotificationSettingsPage(
      {super.key,
      this.readPermission,
      this.requestPermission,
      this.registerDevice,
      this.openSettings,
      this.registrationStatus});
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  AuthorizationStatus? _permission;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SoundNotificationSettings().initialize();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool request = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      AuthorizationStatus permission;
      if (request && widget.requestPermission != null) {
        permission = await widget.requestPermission!();
      } else if (!request && widget.readPermission != null) {
        permission = await widget.readPermission!();
      } else {
        await Firebase.initializeApp();
        final settings = request
            ? await FirebaseMessaging.instance
                .requestPermission(alert: true, badge: true, sound: true)
            : await FirebaseMessaging.instance.getNotificationSettings();
        permission = settings.authorizationStatus;
      }
      if (!mounted) return;
      setState(() => _permission = permission);
      if (permission == AuthorizationStatus.authorized ||
          permission == AuthorizationStatus.provisional) {
        await (widget.registerDevice?.call() ??
            PushNotificationsService.instance.registerTokenIfPossible());
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذر التحقق من الإشعارات. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = _permission == AuthorizationStatus.authorized ||
        _permission == AuthorizationStatus.provisional;
    final denied = _permission == AuthorizationStatus.denied;
    final status = granted
        ? 'الإشعارات مسموحة على هذا الجهاز'
        : denied
            ? 'الإشعارات غير مسموحة على هذا الجهاز'
            : _permission == AuthorizationStatus.notDetermined
                ? 'لم تحدد إذن الإشعارات بعد'
                : 'جارٍ التحقق من الإذن…';
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(title: const Text('إعدادات الإشعارات')),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              ListenableBuilder(listenable:SoundNotificationSettings(),builder:(context,_)=>Card(child:SwitchListTile(
                title:const Text('صوت الطلبات الجديدة'),subtitle:const Text('فعّال افتراضيًا. عند كتم الصوت تستمر التنبيهات المرئية داخل التطبيق.'),
                value:SoundNotificationSettings().soundEnabled&&SoundNotificationSettings().newOrderSoundEnabled,
                onChanged:(value)async{await SoundNotificationSettings().setSoundEnabled(value);await SoundNotificationSettings().setNewOrderSoundEnabled(value);},
                secondary:const Icon(Icons.volume_up_outlined),
              ))),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                                granted
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_off_outlined,
                                size: 36),
                            const SizedBox(height: 12),
                            Text(status,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            const Text(
                                'قد لا يظهر طلب الإذن مرة أخرى إذا سبق أن اخترت السماح أو الرفض. يمكنك تغيير اختيارك من إعدادات الهاتف.'),
                            const SizedBox(height: 16),
                            if (_error != null)
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            if (_busy) const LinearProgressIndicator(),
                            if (_permission ==
                                AuthorizationStatus.notDetermined)
                              FilledButton(
                                  onPressed:
                                      _busy ? null : () => _load(request: true),
                                  child: const Text('السماح بالإشعارات')),
                            OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final opened = await (widget
                                                .openSettings
                                                ?.call() ??
                                            openAppSettings());
                                        if (!opened && mounted)
                                          setState(() => _error =
                                              'تعذر فتح الإعدادات. افتح إعدادات الهاتف ثم اختر تطبيق المطعم والإشعارات.');
                                      },
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('فتح إعدادات الهاتف')),
                          ]))),
              const SizedBox(height: 12),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('تسجيل هذا الجهاز',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<String>(
                                valueListenable: widget.registrationStatus ??
                                    PushNotificationsService
                                        .instance.registrationStatus,
                                builder: (_, value, __) => Text(value)),
                            TextButton.icon(
                                onPressed: _busy ? null : () => _load(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('تحديث الإذن وتسجيل الجهاز')),
                            const Text(
                                'السماح بالإشعارات وتسجيل الجهاز لا يعنيان تأكيد وصول إشعار؛ يتم التحقق من الإرسال بشكل مستقل.'),
                          ]))),
              const SizedBox(height: 12),
              Card(
                  child: Column(children: const [
                ListTile(
                    title: Text('أنواع الإشعارات'),
                    subtitle:
                        Text('تظهر الأنواع المرتبطة بعملك وصلاحيات حسابك.')),
                ListTile(
                    leading: Icon(Icons.shopping_bag_outlined),
                    title: Text('الطلبات'),
                    subtitle: Text('الطلبات الجديدة وتحديثات حالتها.')),
                ListTile(
                    leading: Icon(Icons.handshake_outlined),
                    title: Text('المشاركات التجارية'),
                    subtitle:
                        Text('طلبات الموافقة على المشاركة في تمويل الخصومات.')),
                ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined),
                    title: Text('المحفظة'),
                    subtitle: Text('الإشعارات المالية المرتبطة بحسابك.')),
              ])),
            ])));
  }
}
