import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/address_autofill_service.dart';
import '../services/fcm_platform_service.dart';
import '../services/firebase_messaging_service.dart';
import '../services/audio_notification_service.dart';
import '../services/region_service.dart';
import 'auth_provider_riverpod.dart';
import 'session_provider.dart';

/// Represents the initialization state of the application
enum AppInitStatus {
  /// App is initializing core services
  initializing,

  /// Core services initialized, checking authentication
  checkingAuth,

  /// Initialization complete and ready
  ready,

  /// Initialization failed
  error,
}

class AppInitState {
  final AppInitStatus status;
  final String? errorMessage;
  final bool authChecked;

  const AppInitState({
    this.status = AppInitStatus.initializing,
    this.errorMessage,
    this.authChecked = false,
  });

  AppInitState copyWith({
    AppInitStatus? status,
    String? errorMessage,
    bool? authChecked,
  }) {
    return AppInitState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      authChecked: authChecked ?? this.authChecked,
    );
  }

  bool get isReady => status == AppInitStatus.ready;
  bool get hasError => status == AppInitStatus.error;
}

/// Provider that manages the entire app initialization lifecycle
/// This runs ONCE at app startup and coordinates all initialization tasks
class AppInitializationNotifier extends StateNotifier<AppInitState> {
  final Ref ref;
  static bool _hasInitializedOnce = false; // ⚡ Track if we've ever initialized

  AppInitializationNotifier(this.ref) : super(const AppInitState());

  /// Initialize the application - SIMPLIFIED VERSION
  /// Only blocks on critical init (env + auth), everything else runs in background
  Future<void> initialize() async {
    // ⚡ NEW: Skip full initialization if we've done it before in this app session
    if (_hasInitializedOnce && state.isReady) {
      debugPrint(
          '⚡ AppInit: Already initialized in this session, skipping to restore state...');
      // Just do a quick auth check instead of full initialization
      _kickOffBackgroundInit();
      state = state.copyWith(status: AppInitStatus.ready, authChecked: true);
      return;
    }

    if (state.isReady) {
      debugPrint('⚠️ AppInit: Already initialized, skipping...');
      return;
    }

    debugPrint('🚀 AppInit: Starting SIMPLIFIED initialization...');
    state = const AppInitState(status: AppInitStatus.initializing);

    try {
      // Phase 1: Core init ONLY (env + auth) - this is the ONLY blocking part
      await _initializeCore();

      // Phase 2: Fire-and-forget background tasks (services + session)
      _kickOffBackgroundInit();

      // Phase 3: Mark as ready IMMEDIATELY
      debugPrint('✅ AppInit: Core initialization complete - marking ready');
      state = state.copyWith(
        status: AppInitStatus.ready,
        authChecked: true,
      );
      _hasInitializedOnce = true; // ⚡ Mark that we've initialized at least once
    } catch (e, stackTrace) {
      debugPrint('❌ AppInit: Initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        status: AppInitStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Initialize ONLY critical core services (env + auth)
  /// This is the ONLY method that blocks app startup
  Future<void> _initializeCore() async {
    debugPrint('📦 AppInit: Initializing CORE (env + auth)...');

    // 1. Load environment variables (optional, fast)
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('✅ AppInit: Environment variables loaded');
    } catch (e) {
      debugPrint('⚠️ AppInit: .env file not found or failed to load: $e');
    }

    // 2. Initialize auth (with timeout)
    state = state.copyWith(status: AppInitStatus.checkingAuth);
    try {
      await _initializeAuth();
    } catch (e) {
      debugPrint('⚠️ AppInit: Auth initialization failed, continuing: $e');
      // Don't block the app if auth fails - user can still try to log in
    }

    debugPrint('✅ AppInit: Core initialization complete');
  }

  /// Kick off background initialization (non-blocking, fire-and-forget)
  /// This runs AFTER app is marked ready
  void _kickOffBackgroundInit() {
    debugPrint(
        '🔥 AppInit: Starting background initialization (fire-and-forget)...');

    // Services in background (don't await)
    _initializeServices().catchError((e) {
      debugPrint('⚠️ AppInit: Background service init failed: $e');
    });

    // Session restore in background (don't await)
    ref.read(sessionProvider.notifier).restoreBusinessId().timeout(
      const Duration(
          seconds: 10), // ⚡ Increased from 2s to 10s for better reliability
      onTimeout: () {
        debugPrint('⏱️ AppInit: Session restoration timed out (background)');
      },
    ).catchError((e) {
      debugPrint('⚠️ AppInit: Session restoration failed (background): $e');
    });

    debugPrint('✅ AppInit: Background tasks kicked off');
  }

  /// Initialize core services (non-blocking)
  Future<void> _initializeServices() async {
    debugPrint('📦 AppInit: Initializing core services...');

    // Load environment variables (optional, non-blocking)
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('✅ AppInit: Environment variables loaded');
    } catch (e) {
      debugPrint('⚠️ AppInit: .env file not found or failed to load: $e');
    }

    // Initialize services in parallel (non-blocking, fire-and-forget)
    final futures = <Future<void>>[];

    // Address Autofill Service
    futures.add(
      AddressAutofillService.initialize().then((_) {
        debugPrint('✅ AppInit: Address Autofill initialized');
      }).catchError((e) {
        debugPrint('⚠️ AppInit: Address Autofill failed: $e');
      }),
    );

    // FCM Platform Service
    futures.add(
      FCMPlatformService().initialize().then((_) {
        debugPrint('✅ AppInit: FCM Platform Service initialized');
      }).catchError((e) {
        debugPrint('⚠️ AppInit: FCM Platform Service failed: $e');
      }),
    );

    // Firebase Messaging Service
    futures.add(
      FirebaseMessagingService().initialize().then((_) {
        debugPrint('✅ AppInit: Firebase Messaging Service initialized');
      }).catchError((e) {
        debugPrint('⚠️ AppInit: Firebase Messaging Service failed: $e');
      }),
    );

    // Audio Notification Service
    futures.add(
      AudioNotificationService().initialize().then((_) {
        debugPrint('✅ AppInit: Audio Notification Service initialized');
      }).catchError((e) {
        debugPrint('⚠️ AppInit: Audio Notification Service failed: $e');
      }),
    );

    // Region Service
    futures.add(
      RegionService().initialize().then((_) {
        debugPrint('✅ AppInit: Region Service initialized');
      }).catchError((e) {
        debugPrint('⚠️ AppInit: Region Service failed: $e');
      }),
    );

    // Wait for all services (with timeout)
    try {
      await Future.wait(futures).timeout(
        const Duration(
            seconds: 10), // ⚡ Increased from 3s to 10s for better reliability
        onTimeout: () {
          debugPrint(
              '⏱️ AppInit: Service initialization timed out after 10s, continuing...');
          return <void>[];
        },
      );
    } catch (e) {
      debugPrint('⚠️ AppInit: Some services failed to initialize: $e');
      // Don't fail the entire initialization
    }

    debugPrint('✅ AppInit: Core services initialization complete');
  }

  /// Initialize authentication
  Future<void> _initializeAuth() async {
    debugPrint('🔐 AppInit: Initializing authentication...');

    try {
      // Initialize auth provider with increased timeout (prevent hanging)
      await ref
          .read(authProviderRiverpod.notifier)
          .initialize()
          .timeout(
        const Duration(
            seconds: 10), // ⚡ Increased from 3s to 10s for better reliability
        onTimeout: () {
          debugPrint(
              '⏱️ AppInit: Auth initialization timed out after 10s, continuing...');
        },
      );
      debugPrint('✅ AppInit: Authentication initialized');
    } catch (e) {
      debugPrint('⚠️ AppInit: Auth initialization failed: $e');
      // Don't fail the entire initialization - user can still log in
    }
  }

  /// Reset initialization state (useful for testing or reinitialization)
  void reset() {
    debugPrint('🔄 AppInit: Resetting initialization state');
    state = const AppInitState();
  }

  /// ⚡ NEW: Mark as ready from cached session (skip full initialization)
  /// This is called when we detect a persisted session and can skip the init screen
  void markReadyFromCache() {
    debugPrint(
        '⚡ AppInit: Marking ready from cached session (skipping initialization screen)');
    state = state.copyWith(
      status: AppInitStatus.ready,
      authChecked: true,
    );
    _hasInitializedOnce = true;

    // Still kick off background tasks, but app is already marked ready
    _kickOffBackgroundInit();
  }
}

/// Provider for app initialization
/// This should be read once at app startup
final appInitializationProvider =
    StateNotifierProvider<AppInitializationNotifier, AppInitState>((ref) {
  return AppInitializationNotifier(ref);
});
