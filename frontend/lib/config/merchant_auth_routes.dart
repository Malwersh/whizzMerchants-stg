/// Only routes backed by reviewed production services belong here.
class MerchantAuthRoutes {
  static void validateProductionEndpoint(String value, {bool socket = false}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != (socket ? 'wss' : 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.isEmpty ||
        uri.pathSegments.first != 'production') {
      throw StateError('Production service endpoint is not configured');
    }
  }

  static const enrollmentBase =
      'https://1sn78mol4f.execute-api.us-east-1.amazonaws.com/production';
  static const profileBase =
      'https://z6arovog63.execute-api.us-east-1.amazonaws.com/production';

  static const branchesBase =
      'https://eyvi6bxrz6.execute-api.us-east-1.amazonaws.com/production';

  static const businessChangesBase =
      'https://c1iepyeltj.execute-api.us-east-1.amazonaws.com/production';

  static const ownershipTransferBase =
      'https://x3o01kuhkb.execute-api.us-east-1.amazonaws.com/production';

  static const kitchenDisplayBase =
      'https://ncjn4dk7vi.execute-api.us-east-1.amazonaws.com/production';

  static const branchSetupBase =
      'https://sfljm1w1ah.execute-api.us-east-1.amazonaws.com/production';

  static const productCatalogBase =
      'https://kpieztr34c.execute-api.us-east-1.amazonaws.com/production';

  static const merchantCommercialBase =
      'https://te5d6a852m.execute-api.us-east-1.amazonaws.com/production';

  static const merchantOrdersBase =
      'https://1yc7a1fd70.execute-api.us-east-1.amazonaws.com/production';

  static const orderCancellationBase =
      'https://5ijjfzcxb8.execute-api.us-east-1.amazonaws.com/production';

  static const financialSessionBase =
      'https://ril3ltnbpb.execute-api.us-east-1.amazonaws.com/production';
  static const settlementBase =
      'https://qa7qftdttc.execute-api.us-east-1.amazonaws.com/production';
  static const branchFinanceBase =
      'https://0ryxdrtvd7.execute-api.us-east-1.amazonaws.com/production';
  static const branchOrdersBase =
      'https://e5fjqvxy47.execute-api.us-east-1.amazonaws.com/production';
  static const branchOperationsBase =
      'https://7zozvckdhh.execute-api.us-east-1.amazonaws.com/production';
  static const branchOrderPushBase =
      'https://nuixo96d79.execute-api.us-east-1.amazonaws.com/production';
  static const financialSessionActions = {
    'FINANCIAL_START',
    'FINANCIAL_UNLOCK',
    'FINANCIAL_LOCK',
  };

  static Uri resolve({
    required String environment,
    required String baseUrl,
    required String path,
    Object? action,
  }) {
    if (environment == 'production') {
      if (path == 'kitchen-screens') {
        return Uri.parse('$kitchenDisplayBase/auth/kitchen-screens');
      }
      if (path == 'person-profile') {
        return Uri.parse('$profileBase/auth/person-profile');
      }
      if (const {'order-cancellation', 'order-returns'}.contains(path)) {
        return Uri.parse('$orderCancellationBase/auth/$path');
      }
      if (path == 'settlement-schedules' &&
          financialSessionActions.contains(action)) {
        return Uri.parse('$financialSessionBase/auth/merchant-financial-session');
      }
      final requested = Uri.tryParse(path);
      if (requested != null &&
          !requested.hasScheme &&
          !requested.hasAuthority &&
          !requested.hasFragment &&
          const {'business-changes', 'ownership-transfer'}.contains(requested.path)) {
        final base = requested.path == 'ownership-transfer'
            ? ownershipTransferBase
            : businessChangesBase;
        return Uri.parse('$base/auth/${requested.path}')
            .replace(query: requested.hasQuery ? requested.query : null);
      }
      if (requested != null &&
          !requested.hasScheme &&
          !requested.hasAuthority &&
          !requested.hasFragment &&
          const {'branch-staff', 'branch-devices'}.contains(requested.path)) {
        validateProductionEndpoint(branchFinanceBase);
        return Uri.parse('$branchFinanceBase/auth/${requested.path}')
            .replace(query: requested.hasQuery ? requested.query : null);
      }
      if (requested != null &&
          !requested.hasScheme &&
          !requested.hasAuthority &&
          !requested.hasFragment &&
          const {'commercial-agreements', 'branch-setup', 'settlement-schedules'}
              .contains(requested.path)) {
        final base = switch (requested.path) {
          'branch-setup' => branchSetupBase,
          'settlement-schedules' => settlementBase,
          _ => merchantCommercialBase,
        };
        return Uri.parse('$base/auth/${requested.path}')
            .replace(query: requested.hasQuery ? requested.query : null);
      }
      const branchPaths = {
        'branch-drafts',
        'branch-drafts/config',
        'branch-drafts/regions',
        'branch-drafts/submit',
        'branch-drafts/rebase',
        'branch-drafts/assets',
        'user-businesses',
      };
      if (requested != null &&
          !requested.hasScheme &&
          !requested.hasAuthority &&
          !requested.hasFragment &&
          branchPaths.contains(requested.path)) {
        return Uri.parse('$branchesBase/auth/${requested.path}')
            .replace(query: requested.hasQuery ? requested.query : null);
      }
      // Never send production identity tokens to the staging fallback.
      throw StateError('هذه الخدمة لم تُفعّل في الإنتاج بعد.');
    }
    return Uri.parse('$baseUrl/auth/$path');
  }
}
