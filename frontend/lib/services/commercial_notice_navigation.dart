import 'dart:async';

import '../screens/merchant_payout_notice_screen.dart';
import '../widgets/merchant_financial_gate.dart';
import '../screens/merchant_wallet_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../screens/commercial_agreements_screen.dart';
import '../screens/ownership_transfer_screen.dart';
import '../config/app_config.dart';
import '../providers/branch_device_provider.dart';
import 'person_onboarding_service.dart';
import 'secure_token_storage.dart';

class CommercialNoticeNavigation {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final changes = ValueNotifier<int>(0);
  static final ownershipChanges = ValueNotifier<int>(0);
  static Map<String, dynamic>? _pending;
  static bool _opening = false;
  static bool ownerReady = false;

  static void _openOwnershipInvitation() {
    _pending = {'ownershipInvitation': true};
    tryOpen();
  }

  static void _presentOwnershipInvitation() {
    final context = navigatorKey.currentContext;
    if (!ownerReady || context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: const Text('لديك دعوة جديدة لنقل ملكية نشاط.'),
      action: SnackBarAction(
        label: 'عرض الدعوة',
        onPressed: _openOwnershipInvitation,
      ),
    ));
  }

  static Future<void> _presentPayoutNotice(Map<String, dynamic> data) async {
    if (!ownerReady || data['driverId'] is! String) return;
    try {
      final token = await SecureTokenStorage.getAccessToken();
      if (!ownerReady || token == null || JwtDecoder.isExpired(token) ||
          JwtDecoder.decode(token)['sub'] != data['driverId']) return;
      final context = navigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: const Text('لديك تحديث على مستحقات مطعمك.'),
        action: SnackBarAction(
          label: 'عرض التفاصيل',
          onPressed: () => receive(data, tapped: true),
        ),
      ));
    } catch (_) {
      // The inbox handles the notification once the owner session is available.
    }
  }

  static void receive(Map<String, dynamic> data, {bool tapped = false}) {
    final type = data['type'];
    if (type == 'ownership_accepted' && AppConfig.ownershipTransferEnabled) {
      final context = navigatorKey.currentContext;
      if (!tapped && ownerReady && context != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('قَبِل المالك الجديد دعوة النقل. الطلب بانتظار مراجعة الإدارة.'),
        ));
      }
      return;
    }
    if (type == 'ownership_completed_previous' ||
        type == 'ownership_completed_new') {
      ownershipChanges.value++;
      final context = navigatorKey.currentContext;
      if (!tapped && ownerReady && context != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(type == 'ownership_completed_new'
              ? 'اكتمل نقل النشاط إليك. تجده ضمن مطاعمك وأنشطتك.'
              : 'اكتمل نقل ملكية نشاطك إلى المالك الجديد.'),
        ));
      }
      return;
    }
    if (type == 'ownership_invitation' && AppConfig.ownershipTransferEnabled) {
      if (tapped) {
        _openOwnershipInvitation();
      } else {
        _presentOwnershipInvitation();
      }
      return;
    }
    final payoutNotice = type == 'merchant_payout_updated';
    final financialNoticeEnabled = payoutNotice
        ? merchantPayoutNoticesEnabled
        : merchantFinancialLockEnabled &&
            ['wallet_transfer_completed', 'merchant_exception_financial_updated']
                .contains(type);
    if (financialNoticeEnabled && data['action'] == 'open_wallet') {
      if (payoutNotice && !tapped) unawaited(_presentPayoutNotice(data));
      if (tapped && data['driverId'] is String) {
        _pending = {
          'subjectId': data['driverId'],
          'financialWallet': true,
          if (payoutNotice) ...{
            'payoutId': data['payoutId'],
            'branchId': data['branchId'],
          },
        };
        tryOpen();
      }
      return;
    }
    if (data['action'] != 'commercial_sharing_requested') return;
    changes.value++;
    if (tapped) {
      _pending = Map<String, dynamic>.from(data);
      tryOpen();
    }
  }
  static Future<void> tryOpen({PersonOnboardingService? service}) async {
    final data = _pending, nav = navigatorKey.currentState;
    if (!ownerReady || data == null || nav == null || _opening) return;
    _opening = true;
    try {
      if (await const FlutterSecureStorage().read(key: BranchDeviceNotifier.key) != null) {
        _pending = null;
        return;
      }
      final token = await SecureTokenStorage.getAccessToken();
      if (token == null || JwtDecoder.isExpired(token)) return;
      if (data['ownershipInvitation'] == true) {
        _pending = null;
        await nav.push(MaterialPageRoute(builder: (_) => const OwnershipTransferScreen()));
        return;
      }
      if (JwtDecoder.decode(token)['sub'] != data['subjectId']) {
        _pending = null;
        return;
      }
      if (data['financialWallet'] == true) {
        _pending = null;
        // Select the account from the authenticated server; never trust a branch
        // supplied by push. WalletTransferScreen enforces the financial gate.
        if(data.containsKey('payoutId')) {
          final payout=data['payoutId'], branch=data['branchId'];
          if(payout is! String || !RegExp(r'^MPO:[a-f0-9]{48}$').hasMatch(payout) || branch is! String || branch.isEmpty || branch.length>150)return;
          await nav.push(MaterialPageRoute(builder:(_)=>MerchantPayoutNoticeScreen(businessId:branch,payoutId:payout)));
        } else {
        await nav.push(MaterialPageRoute(builder: (_) => const MerchantWalletAccountsScreen()));
        }
        return;
      }
      final business = data['businessId'], id = data['sharingId'];
      final kind = data['requestKind'] ?? 'FUNDING';
      if (!['FUNDING', 'DELIVERY'].contains(kind)) { _pending = null; return; }
      if (business is! String || id is! String) { _pending = null; return; }
      if(merchantFinancialLockEnabled){
        _pending=null;
        await nav.push(MaterialPageRoute(builder:(_)=>CommercialAgreementsScreen(businessId:business,focusSharingId:id,focusRequestKind:kind,service:service)));
        return;
      }
      // Push data is a navigation hint. Only the authenticated server decides visibility and terms.
      final result = await (service ?? PersonOnboardingService()).call('commercial-agreements?businessId=${Uri.encodeComponent(business)}&view=pending-sharing');
      final currentToken = await SecureTokenStorage.getAccessToken();
      if (!ownerReady || currentToken == null || JwtDecoder.isExpired(currentToken) || JwtDecoder.decode(currentToken)['sub'] != data['subjectId']) { _pending = null; return; }
      if (_pending != data || !List<dynamic>.from(result['items'] ?? []).any((x) => x['draft']['id'] == id && x['draft']['kind'] == kind)) {
        _pending = null;
        return;
      }
      _pending = null;
      await nav.push(MaterialPageRoute(builder: (_) => CommercialAgreementsScreen(businessId: business, focusSharingId: id, focusRequestKind: kind, service: service)));
    } catch (_) {
      // Keep the target for the next authenticated owner-screen mount/resume.
    } finally { _opening = false; }
  }
}
