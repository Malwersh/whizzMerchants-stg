import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../screens/commercial_agreements_screen.dart';
import 'person_onboarding_service.dart';
import 'secure_token_storage.dart';

class CommercialNoticeNavigation {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final changes = ValueNotifier<int>(0);
  static Map<String, dynamic>? _pending;
  static bool _opening = false;
  static bool ownerReady = false;
  static void receive(Map<String, dynamic> data, {bool tapped = false}) {
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
      if (await const FlutterSecureStorage().read(key: 'merchant_paired_branch_device_v1') != null) {
        _pending = null;
        return;
      }
      final token = await SecureTokenStorage.getAccessToken();
      if (token == null || JwtDecoder.isExpired(token)) return;
      if (JwtDecoder.decode(token)['sub'] != data['subjectId']) {
        _pending = null;
        return;
      }
      final business = data['businessId'], id = data['sharingId'];
      final kind = data['requestKind'] ?? 'FUNDING';
      if (!['FUNDING', 'DELIVERY'].contains(kind)) { _pending = null; return; }
      if (business is! String || id is! String) { _pending = null; return; }
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
