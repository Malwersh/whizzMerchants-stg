import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/config/merchant_auth_routes.dart';

void main() {
  test('production build rejects staging defaults and insecure endpoints', () {
    for (final value in [
      'https://example.com/staging',
      'http://example.com/production',
      'https://example.com/dev',
      'https://example.com/production?target=staging',
      'https://example.com/staging/support/attachments',
      'https://user:password@example.com/production',
      'https://example.com/production#staging',
      ''
    ]) {
      expect(() => MerchantAuthRoutes.validateProductionEndpoint(value),
          throwsStateError);
    }
    expect(
        () => MerchantAuthRoutes.validateProductionEndpoint(
            MerchantAuthRoutes.profileBase),
        returnsNormally);
    expect(
        () => MerchantAuthRoutes.validateProductionEndpoint(
            'wss://example.com/production',
            socket: true),
        returnsNormally);
  });
  test('optional production integrations validate protocol and environment', () {
    expect(
      () => MerchantAuthRoutes.validateProductionEndpoint(
          'https://example.com/production/support/attachments'),
      returnsNormally,
    );
    for (final value in [
      'wss://example.com/staging',
      'https://example.com/production',
      'ws://example.com/production',
    ]) {
      expect(
        () => MerchantAuthRoutes.validateProductionEndpoint(value, socket: true),
        throwsStateError,
      );
    }
  });
  test('production profile ignores stale staging base configuration', () {
    final uri = MerchantAuthRoutes.resolve(
        environment: 'production',
        baseUrl: 'https://old.example/staging',
        path: 'person-profile');
    expect(uri.toString(),
        '${MerchantAuthRoutes.profileBase}/auth/person-profile');
  });
  test('unpublished production operations fail before requesting credentials',
      () {
    for (final path in [
      'branch-drafts/unknown',
      'https://attacker.example/branch-drafts',
      'branch-drafts#fragment',
      'person-profile?branchId=x',
      'person-registration',
      'settlement-schedules'
    ]) {
      expect(
          () => MerchantAuthRoutes.resolve(
              environment: 'production',
              baseUrl: 'https://old.example/staging',
              path: path),
          throwsStateError);
    }
  });
  test('reviewed branch routes preserve queries without staging fallback', () {
    for (final path in [
      'branch-drafts',
      'branch-drafts/config?draftId=abc',
      'branch-drafts/assets?assetId=xyz',
      'branch-drafts/submit',
      'branch-drafts/rebase',
      'user-businesses',
    ]) {
      expect(
          MerchantAuthRoutes.resolve(
                  environment: 'production',
                  baseUrl: 'https://old.example/staging',
                  path: path)
              .toString(),
          '${MerchantAuthRoutes.branchesBase}/auth/$path');
    }
  });
  test('staging preserves current route and query', () {
    expect(
        MerchantAuthRoutes.resolve(
                environment: 'staging',
                baseUrl: 'https://current.example/staging',
                path: 'branch-drafts?x=1')
            .toString(),
        'https://current.example/staging/auth/branch-drafts?x=1');
  });
}
