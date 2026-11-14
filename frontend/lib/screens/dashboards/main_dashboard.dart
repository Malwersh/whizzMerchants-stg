import 'package:flutter/material.dart';
import '../merchant_businesses_screen.dart';

/// Compatibility entry point for older confirmation routes.
/// All accounts now use the authenticated businesses flow, never demo revenue.
class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});
  @override
  Widget build(BuildContext context) => const MerchantBusinessesScreen();
}
