// Diagnostic entrypoint to test product fetching end-to-end.
// Usage:
// flutter run -d iPhone 16 Pro -t lib/diagnostics/product_fetch_diagnostic.dart \
//   --dart-define=AUTH_MODE=cognito \
//   --dart-define=COGNITO_USER_POOL_ID=<your-user-pool-id> \
//   --dart-define=APP_CLIENT_ID=<your-app-client-id> \
//   --dart-define=COGNITO_REGION=us-east-1 \
//   --dart-define=ENVIRONMENT=development \
//   --dart-define=API_URL=https://<api-id>.execute-api.<region>.amazonaws.com/<stage> \
//   --dart-define=WEBSOCKET_URL=wss://<api-id>.execute-api.<region>.amazonaws.com/<stage> \
//   --dart-define=DIAG_EMAIL=<email> \
//   --dart-define=DIAG_PASSWORD=<password>
//
// NOTE: Credentials must be provided via dart-define.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_auth_service.dart';
import '../services/product_service.dart';
import '../core/utils/app_logger.dart';

const _email = String.fromEnvironment('DIAG_EMAIL', defaultValue: '');
const _password = String.fromEnvironment('DIAG_PASSWORD', defaultValue: '');

void main() {
  // Global error capture to surface sync errors causing white screen
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('[DiagMain] Initializing app');
    runApp(const ProviderScope(child: ProductFetchDiagnosticApp()));
  }, (e, st) {
    // Print full error so it appears in flutter logs
    AppLogger.error('Uncaught zone error: $e');
    AppLogger.error('Stack trace: $st');
  });
}

class ProductFetchDiagnosticApp extends StatefulWidget {
  const ProductFetchDiagnosticApp({super.key});
  @override
  State<ProductFetchDiagnosticApp> createState() =>
      _ProductFetchDiagnosticAppState();
}

class _ProductFetchDiagnosticAppState extends State<ProductFetchDiagnosticApp> {
  String _log = 'Starting...';
  bool _loading = true;
  bool _hasStarted = false;

  void _append(String line) {
    debugPrint(line);
    setState(() => _log += '\n$line');
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _run();
    }
  }

  Future<void> _run() async {
    _append('🧪 Begin run()');
    try {
      AppAuthService.setProviderContainer(ProviderScope.containerOf(context));
      _append('🚀 Product Fetch Diagnostic started');
      final signIn =
          await AppAuthService.signIn(email: _email, password: _password);
      _append(
          '🔐 Sign-in attempt complete success=${signIn.success} msg=${signIn.message}');
      _append('🔎 Auth state: Checking authentication...');
      final isSignedIn = await AppAuthService.isSignedIn();
      _append('🔎 Auth state signed in: $isSignedIn');
      if (!signIn.success) {
        _append('❌ Sign-in failed: ${signIn.message}');
        setState(() => _loading = false);
        return;
      }
      _append('✅ Sign-in success. Businesses: ${signIn.businesses.length}');

      _append('🌐 Fetching products...');
      final productsResp = await ProductService.getProducts();
      _append(
          '🌐 Products response success=${productsResp['success']} status=${productsResp['status']}');
      if (productsResp['success'] == true) {
        final products = productsResp['products'] as List? ?? [];
        _append('✅ Products fetched: count=${products.length}');
        for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
          final p = products[i];
          _append('  • ${p['productId'] ?? p['id']}: ${p['name']}');
        }
      } else {
        _append('❌ Failed to fetch products: ${productsResp['message']}');
        _append('   Raw: ${productsResp['body'] ?? productsResp}');
      }
      _append('🏁 Diagnostic complete');
    } catch (e, st) {
      _append('💥 Exception in _run: $e');
      _append(st.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Product Fetch Diagnostic')),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_log,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13)),
                ),
              ),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _log = '';
                          _loading = true;
                          _hasStarted = false;
                        });
                      },
                child: const Text('Re-run'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
