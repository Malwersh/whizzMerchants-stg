import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/person_onboarding_service.dart';

/// Mounted inside the verified owner's financial gate only.
class MerchantFinancialNotificationDevice extends StatefulWidget {
  final String businessId;
  final PersonOnboardingService? service;
  final Future<String?> Function()? tokenLoader;
  const MerchantFinancialNotificationDevice(
      {super.key, required this.businessId, this.service, this.tokenLoader});
  @override
  State<MerchantFinancialNotificationDevice> createState() => _DeviceState();
}

class _DeviceState extends State<MerchantFinancialNotificationDevice> {
  bool? _enabled;
  bool _busy = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(covariant MerchantFinancialNotificationDevice old) {
    super.didUpdateWidget(old);
    if (old.businessId != widget.businessId) {
      _generation++;
      _enabled = null;
      _busy = false;
      _request();
    }
  }

  Future<void> _request({bool? enabled}) async {
    if (_busy) return;
    final revision = ++_generation, branch = widget.businessId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await (widget.tokenLoader?.call() ??
          FirebaseMessaging.instance.getToken());
      if (!mounted || revision != _generation) return;
      if (token == null || token.isEmpty) {
        throw Exception();
      }
      final result = await (widget.service ?? PersonOnboardingService())
          .call('settlement-schedules', body: {
        'action': enabled == null
            ? 'FINANCIAL_NOTIFICATION_DEVICE_STATUS'
            : 'FINANCIAL_NOTIFICATION_DEVICE',
        'branchId': branch,
        'pushToken': token,
        if (enabled != null) 'enabled': enabled
      });
      if (mounted && revision == _generation) {
        setState(() => _enabled = result['enabled'] == true);
      }
    } catch (_) {
      if (mounted && revision == _generation) {
        setState(() => _error = 'تعذر تحديث تفضيل هذا الجهاز. أعد المحاولة.');
      }
    } finally {
      if (mounted && revision == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xffe2e8f2))),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xff00306b),
                title: const Text('التنبيهات المالية',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'لهذا الجهاز فقط · دون عرض المبالغ. لا يؤثر على تنبيهات الطلبات.',
                    style: TextStyle(fontSize: 12, height: 1.5)),
                value: _enabled == true,
                onChanged: _busy || _enabled == null
                    ? null
                    : (v) => _request(enabled: v)),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Row(children: [
                Expanded(child: Text(_error!)),
                TextButton(
                    onPressed: _busy ? null : () => _request(),
                    child: const Text('إعادة المحاولة'))
              ]),
          ])));
}
