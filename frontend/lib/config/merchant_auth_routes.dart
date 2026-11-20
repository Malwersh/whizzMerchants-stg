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

  static Uri resolve({
    required String environment,
    required String baseUrl,
    required String path,
  }) {
    if (environment == 'production') {
      if (path == 'person-profile') {
        return Uri.parse('$profileBase/auth/person-profile');
      }
      final requested = Uri.tryParse(path);
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
