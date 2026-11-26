import 'branch_employee_access.dart';
import 'person_onboarding_service.dart';

/// Uses only this employee's device and PIN session, never owner credentials.
class BranchSettlementService extends PersonOnboardingService {
  final BranchEmployeeAccess access;
  BranchSettlementService(this.access);
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body, bool authenticated = true}) async {
    final uri = Uri.parse(path);
    if (uri.path != 'settlement-schedules')
      throw StateError('مسار الموظف غير متاح');
    final input = body ?? <String, dynamic>{...uri.queryParameters};
    if (input['branchId'] != access.businessId)
      throw StateError('هذا الحساب مرتبط بفرع آخر');
    return access.api.call(
        access.token,
        {
          'action': 'settlements',
          'httpMethod': body == null ? 'GET' : 'POST',
          'input': input
        },
        session: access.session);
  }
}
