import 'package:flutter_test/flutter_test.dart';

import '../lib/config/app_config.dart';
import '../lib/config/merchant_auth_routes.dart';

void main() {
  test('merchant binds to the selected environment with its default settings',
      () {
    AppConfig.validateOrThrow();
    if (AppConfig.isProduction) {
      expect(AppConfig.cognitoUserPoolId, AppConfig.productionPoolId);
      expect(AppConfig.appClientId, AppConfig.productionClientId);
      expect(AppConfig.baseUrl, MerchantAuthRoutes.branchesBase);
      expect(
          AppConfig.orderServiceUrl, MerchantAuthRoutes.orderCancellationBase);
      expect(AppConfig.pushNotificationsUrl, AppConfig.productionPushBase);
    } else {
      expect(Uri.parse(AppConfig.baseUrl).path, '/staging');
      expect(Uri.parse(AppConfig.orderServiceUrl).path, '/staging');
    }
  });
}
