import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider_riverpod.dart';
import '../services/person_onboarding_service.dart';
import 'branch_staff_screen.dart';

class EmployeeHomeScreen extends ConsumerWidget {
  final PersonOnboardingService? service;
  const EmployeeHomeScreen({super.key, this.service});
  @override
  Widget build(BuildContext context, WidgetRef ref) => BranchStaffScreen(
        employeeHome: true,
        service: service,
        onSignOut: () => ref.read(authProviderRiverpod.notifier).signOut(),
      );
}
