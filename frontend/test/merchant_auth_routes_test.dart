import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/config/merchant_auth_routes.dart';

void main() {
  test('production kitchen approval uses the dedicated owner endpoint', () {
    final uri = MerchantAuthRoutes.resolve(
      environment: 'production',
      baseUrl: 'https://example.com/staging',
      path: 'kitchen-screens',
    );
    expect(uri.toString(),
        '${MerchantAuthRoutes.kitchenDisplayBase}/auth/kitchen-screens');
  });

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
  test('native catalog targets the dedicated production endpoint', () {
    final uri = Uri.parse(MerchantAuthRoutes.productCatalogBase);
    expect(() => MerchantAuthRoutes.validateProductionEndpoint(uri.toString()),
        returnsNormally);
    expect(uri.host, 'kpieztr34c.execute-api.us-east-1.amazonaws.com');
    expect(uri.path, '/production');
  });

  test('production profile ignores stale staging base configuration', () {
    final uri = MerchantAuthRoutes.resolve(
        environment: 'production',
        baseUrl: 'https://old.example/staging',
        path: 'person-profile');
    expect(uri.toString(),
        '${MerchantAuthRoutes.profileBase}/auth/person-profile');
  });
  test('business changes preserve the branch identifier and environment', () {
    const path = 'business-changes?businessId=business_branch';
    for (final environment in ['production', 'staging']) {
      final uri = MerchantAuthRoutes.resolve(
        environment: environment,
        baseUrl: 'https://old.example/staging',
        path: path,
      );
      expect(uri.queryParameters['businessId'], 'business_branch');
      final base = environment == 'production'
          ? MerchantAuthRoutes.businessChangesBase
          : 'https://old.example/staging';
      expect(uri.toString(), '$base/auth/$path');
    }
  });
  test('ownership invitations use isolated API routes with queries intact', () {
    for (final path in [
      'ownership-transfer',
      'ownership-transfer?incoming=1',
      'ownership-transfer?businessId=branch-1',
      'ownership-transfer?organizationId=org-1&requestId=transfer-1',
    ]) {
      for (final environment in ['production', 'staging']) {
        final uri = MerchantAuthRoutes.resolve(
          environment: environment,
          baseUrl: 'https://old.example/staging',
          path: path,
        );
        final base = environment == 'production'
            ? MerchantAuthRoutes.ownershipTransferBase
            : 'https://old.example/staging';
        expect(uri.toString(), '$base/auth/$path');
      }
    }
    expect(
      () => MerchantAuthRoutes.resolve(
        environment: 'production',
        baseUrl: 'https://old.example/staging',
        path: 'https://old.example/staging/auth/ownership-transfer',
      ),
      throwsStateError,
    );
  });
  test('production branch staff and device management use the branch finance API', () {
    for (final route in ['branch-staff', 'branch-devices']) {
      final uri = MerchantAuthRoutes.resolve(
          environment: 'production',
          baseUrl: 'https://old.example/staging',
          path: '$route?businessId=branch1');
      expect(uri.toString(),
          '${MerchantAuthRoutes.branchFinanceBase}/auth/$route?businessId=branch1');
      expect(
          MerchantAuthRoutes.resolve(environment: 'staging',
              baseUrl: 'https://old.example/staging', path: route).toString(),
          'https://old.example/staging/auth/$route');
    }
  });
  test('production cancellation and returns use their dedicated API', () {
    for (final path in ['order-cancellation', 'order-returns']) {
      final uri = MerchantAuthRoutes.resolve(
        environment: 'production',
        baseUrl: 'https://old.example/staging',
        path: path,
      );
      expect(uri.toString(),
          '${MerchantAuthRoutes.orderCancellationBase}/auth/$path');
    }
    expect(
        () => MerchantAuthRoutes.validateProductionEndpoint(
            MerchantAuthRoutes.orderCancellationBase),
        returnsNormally);
  });
  test('financial verification uses the API for the current environment', () {
    for (final action in [
      'FINANCIAL_START',
      'FINANCIAL_UNLOCK',
      'FINANCIAL_LOCK',
    ]) {
      final production = MerchantAuthRoutes.resolve(
        environment: 'production',
        baseUrl: 'https://old.example/staging',
        path: 'settlement-schedules',
        action: action,
      );
      expect(production.host, 'ril3ltnbpb.execute-api.us-east-1.amazonaws.com');
      expect(production.path, '/production/auth/merchant-financial-session');
      final staging = MerchantAuthRoutes.resolve(
        environment: 'staging',
        baseUrl: 'https://current.example/staging',
        path: 'settlement-schedules',
        action: action,
      );
      expect(staging.toString(),
          'https://current.example/staging/auth/settlement-schedules');
    }
  });

  test('production payout actions and reads use the settlement API', () {
    expect(
      MerchantAuthRoutes.resolve(
        environment: 'production',
        baseUrl: 'https://old.example/staging',
        path: 'settlement-schedules',
        action: 'REQUEST_PAYOUT',
      ).toString(),
      '${MerchantAuthRoutes.settlementBase}/auth/settlement-schedules',
    );
    expect(
      MerchantAuthRoutes.resolve(
        environment: 'production',
        baseUrl: 'https://old.example/staging',
        path: 'settlement-schedules?view=payouts&branchId=b-1',
      ).toString(),
      '${MerchantAuthRoutes.settlementBase}/auth/settlement-schedules?view=payouts&branchId=b-1',
    );
  });

  test('unpublished production operations fail before requesting credentials',
      () {
    for (final path in [
      'branch-drafts/unknown',
      'https://attacker.example/branch-drafts',
      'branch-drafts#fragment',
      'person-profile?branchId=x',
      'person-registration',
      'order-returns?businessId=x',
      'settlement-schedules/unknown'
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
  test('production branch setup uses its verified host and the branch query', () {
    final uri = MerchantAuthRoutes.resolve(
      environment: 'production',
      baseUrl: 'https://old.example/staging',
      path: 'branch-setup?businessId=branch',
    );
    expect(uri.toString(),
        '${MerchantAuthRoutes.branchSetupBase}/auth/branch-setup?businessId=branch');
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
