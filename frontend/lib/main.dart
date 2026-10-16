import 'providers/branch_device_provider.dart';
import 'screens/branch_device_home_screen.dart';
import 'providers/login_intent_provider.dart';
import 'services/auth_navigation.dart';
import 'providers/business_provider.dart';
import 'screens/employee_home_screen.dart';
import 'screens/merchant_businesses_screen.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/design_system/design_system.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider_riverpod.dart';
import 'providers/session_provider.dart';
import 'providers/language_provider_riverpod.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/splash_screen.dart'; // ✅ إضافة SplashScreen
import 'services/app_auth_service.dart';
import 'services/push_notifications_service.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable all debugPrint output in release builds (token/URL leakage risk).
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Fail-fast on missing or unsafe staging configuration
  AppConfig.validateOrThrow();

  runApp(const ProviderScope(child: OrderReceiverApp()));

  // Post-start bootstrap work.
  // Important: do not block `runApp` on network/keychain work, or iOS can show a
  // blank/white screen on cold start (e.g. app opened from a push tap).
  unawaited(_bootstrapAfterRunApp());
}

Future<void> _bootstrapAfterRunApp() async {
  // 🔔 Initialize Firebase Messaging (push)
  try {
    await PushNotificationsService.instance.initialize();
  } catch (e) {
    debugPrint('❌ PushNotificationsService init failed (non-fatal): $e');
  }
}

class OrderReceiverApp extends ConsumerStatefulWidget {
  const OrderReceiverApp({super.key});
  @override
  ConsumerState<OrderReceiverApp> createState() => _OrderReceiverAppState();
}

class _OrderReceiverAppState extends ConsumerState<OrderReceiverApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Provide container to AppAuthService for session updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppAuthService.setProviderContainer(ProviderScope.containerOf(context));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Validate session when app resumes
      debugPrint('🔄 App resumed - validating session...');
      final sessionNotifier = ref.read(sessionProvider.notifier);
      sessionNotifier.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ App paused');
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('😴 App inactive');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(languageProviderRiverpod);
    return MaterialApp(
      title: 'WIZZ Business Manager',
      debugShowCheckedModeBanner: false,
      theme: DesignSystem.lightTheme,
      darkTheme: DesignSystem.darkTheme,
      themeMode: ThemeMode.system,
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: const SplashScreen(
        nextScreen: AuthGate(),
        duration: Duration(seconds: 2), // ✅ مدة Splash 2 ثانية
      ),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProviderRiverpod);
    final session = ref.watch(sessionProvider);

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    void returnToLogin() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !rootNavigator.mounted) return;
        ref.read(loginIntentProvider.notifier).state = null;
        ref.invalidate(businessProvider);
        clearProtectedRoutes(rootNavigator);
      });
    }

    ref.listen(authProviderRiverpod, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        returnToLogin();
      }
    });

    // 🔧 Handle session expiration + trigger push token registration when logged-in
    ref.listen(sessionProvider, (previous, next) async {
      if (next.isExpired && !next.isAuthenticated) {
        returnToLogin();
        debugPrint('🚨 Session expired detected in AuthGate');
        // Show session expired message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      final prevAuthed = previous?.isAuthenticated == true;
      final prevBusinessId = previous?.businessId;
      final becameAuthed = !prevAuthed && next.isAuthenticated;
      final businessChanged = prevBusinessId != next.businessId;
      final hasBusiness =
          next.businessId != null && next.businessId!.isNotEmpty;

      if ((becameAuthed || businessChanged) &&
          next.isAuthenticated &&
          hasBusiness &&
          !next.isExpired) {
        try {
          await ref.read(sessionProvider.notifier).waitForSessionReady();
          await PushNotificationsService.instance
              .registerTokenIfPossible(businessId: next.businessId);
        } catch (e) {
          debugPrint('⚠️ Push token registration skipped/failed: $e');
        }
      }
    });

    final pairedDevice = ref.watch(branchDeviceProvider);
    if (pairedDevice.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (pairedDevice.hasError) {
      return Scaffold(body: Center(child: TextButton(
        onPressed: () => ref.read(branchDeviceProvider.notifier).load(),
        child: const Text('تعذر قراءة إعداد الجهاز. إعادة المحاولة'),
      )));
    }
    if (pairedDevice.valueOrNull != null) {
      return BranchDeviceHomeScreen(device: pairedDevice.valueOrNull!);
    }
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.isAuthenticated && !session.isExpired) {
      final selectedIntent = ref.watch(loginIntentProvider);
      final savedIntent = ref.watch(savedLoginIntentProvider);
      if (selectedIntent == null && savedIntent.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if ((selectedIntent ?? savedIntent.valueOrNull) == LoginIntent.employee) {
        return const EmployeeHomeScreen();
      }
      return const MerchantBusinessesScreen();
    }
    return const AuthScreen();
  }
}
