import 'dart:convert';
import '../config/merchant_auth_routes.dart';
import 'package:http/http.dart' as http;
import '../legal/application_legal_bundle.dart';
import '../legal/application_legal_service.dart';
import 'app_auth_service.dart';
import 'auth_header_builder.dart';
import 'merchant_enrollment_service.dart';
import 'person_onboarding_service.dart';

/// Production adapter for the existing personal-registration UI.
/// Collecting details does not create a Cognito identity before phone verification.
class ProductionPersonOnboardingService extends PersonOnboardingService {
  static const enrollmentUrl = MerchantAuthRoutes.enrollmentBase;
  static const profileUrl = MerchantAuthRoutes.profileBase;
  final MerchantEnrollmentService enrollment;
  final Future<bool> Function(String, String) exchangeProof;
  final Future<Map<String, String>> Function() headers;
  Map<String, dynamic>? _details;
  String? _sessionId;
  ProductionPersonOnboardingService(
      {http.Client? client,
      MerchantEnrollmentService? enrollment,
      Future<bool> Function(String, String)? exchangeProof,
      Future<Map<String, String>> Function()? headers})
      : enrollment = enrollment ??
            MerchantEnrollmentService(
                client: client ?? http.Client(), baseUrl: enrollmentUrl),
        exchangeProof = exchangeProof ??
            ((username, proof) async =>
                (await AppAuthService.completeProductionEnrollment(
                        username: username, loginProof: proof))
                    .success),
        headers = headers ?? (() => AuthHeaderBuilder.build()),
        super(client: client);

  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    if (path == 'person-registration') {
      if (body != null) _details = Map.of(body);
      return {
        'acknowledgementVersion': 'personal-account-2026-10-14',
        'acknowledgementText':
            'أوافق على إنشاء حساب شخصي بالهاتف لإدارة أنشطتي، وأفهم أن توثيق الرقم لا يعني اعتماد النشاط أو إثبات ملكيته.'
      };
    }
    if (path != 'person-profile' || !authenticated || body == null) {
      throw StateError('Unsupported production onboarding operation');
    }
    final response = await client
        .post(Uri.parse('$profileUrl/auth/person-profile'),
            headers: await headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    final data =
        Map<String, dynamic>.from(jsonDecode(utf8.decode(response.bodyBytes)));
    if (response.statusCode != 200) {
      if ([
        'LEGAL_VERSION_CHANGED',
        'LEGAL_DOCUMENTS_CHANGED',
        'LEGAL_ACCEPTANCE_REQUIRED'
      ].contains(data['code'])) {
        throw LegalRegistrationException(data['code']);
      }
      throw const MerchantEnrollmentException('PROFILE_UNAVAILABLE');
    }
    return data;
  }

  @override
  Future<bool> startPhoneSignIn(String phone) async {
    if (_details == null || _details!['phoneNumber'] != phone) {
      throw StateError('Registration details required');
    }
    final result = await enrollment.send(phone);
    final id = result['sessionId'];
    if (id is! String || id.isEmpty)
      throw const FormatException('Missing session');
    _sessionId = id;
    return true;
  }

  @override
  Future<bool> verifyPhoneCode(String code) async {
    final d = _details;
    if (d == null || _sessionId == null) return false;
    try {
      final result = await enrollment.verify(
          phone: d['phoneNumber'],
          sessionId: _sessionId!,
          code: code,
          name: '${d['firstName']} ${d['lastName']}'.trim(),
          legalAcceptance: Map<String, dynamic>.from(d['legalAcceptance']));
      final username = result['username'], proof = result['loginProof'];
      if (username is! String || proof is! String) {
        throw const FormatException('Missing login proof');
      }
      if (!await exchangeProof(username, proof)) {
        throw const MerchantEnrollmentException('LOGIN_EXCHANGE_FAILED');
      }
      return true;
    } on MerchantEnrollmentException catch (e) {
      if (e.code == 'LEGAL_DOCUMENTS_CHANGED') {
        throw LegalRegistrationException(e.code);
      }
      rethrow;
    }
  }
}

class ProductionEnrollmentLegalService extends ApplicationLegalService {
  final MerchantEnrollmentService enrollment;
  ProductionEnrollmentLegalService(this.enrollment);
  @override
  Future<ApplicationLegalBundle> load({bool refresh = false}) async {
    final result = await enrollment.legal();
    final bundle = ApplicationLegalBundle.fromJson(result['bundle']);
    if (bundle.audience != 'MERCHANT') {
      throw const FormatException('WRONG_LEGAL_AUDIENCE');
    }
    return bundle;
  }
}
