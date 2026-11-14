import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import 'session_provider.dart';

final businessListLoaderProvider =
    Provider<Future<List<Map<String, dynamic>>> Function()>(
        (ref) => ApiService().getUserBusinesses);

final businessProvider = FutureProvider<Business?>((ref) async {
  final session = ref.watch(sessionProvider);
  debugPrint(
    '🏢 BusinessProvider: auth=${session.isAuthenticated} businessId=${session.businessId}',
  );
  debugPrint(
      '🏢 BusinessProvider: has businessData = ${session.businessData != null}');

  if (!session.isAuthenticated || session.businessId == null) {
    debugPrint(
        '🏢 BusinessProvider: returning null - not authenticated or no businessId');
    return null;
  }

  // Try the API first so profile edits and photo uploads show up immediately.
  // Fall back to cached session data when the API is unavailable (offline resilience).
  debugPrint('🏢 BusinessProvider: fetching from API...');
  try {
    final businesses = await ref.read(businessListLoaderProvider)();
    debugPrint(
        '🏢 BusinessProvider: API returned ${businesses.length} businesses');

    final matches = businesses
        .where((b) =>
            (b['businessId'] ?? b['id']) == session.businessId &&
            b['deletionRequestId'] == null)
        .toList();
    if (matches.isNotEmpty) return Business.fromJson(matches.first);
    // A successful server response is authoritative: do not restore a
    // removed business from cached data or synthesize a placeholder for it.
    await ref
        .read(sessionProvider.notifier)
        .clearBusinessSelection(expected: session);
    return null;
  } catch (e) {
    debugPrint('🏢 BusinessProvider: API error, falling back to cache: $e');
  }

  // Cached data fallback (also keeps offline behavior)
  if (session.businessData != null &&
      (session.businessData!['businessId'] ?? session.businessData!['id']) ==
          session.businessId) {
    debugPrint('🏢 BusinessProvider: trying to parse cached businessData');
    try {
      final business = Business.fromJson(session.businessData!);
      debugPrint(
          '🏢 BusinessProvider: successfully parsed business from cache: ${business.name}');
      return business;
    } catch (e) {
      debugPrint('🏢 BusinessProvider: failed to parse cached data: $e');
    }
  }

  // Last resort: minimal Business from session
  if (session.businessId != null) {
    debugPrint(
        '🏢 BusinessProvider: Creating minimal business from session businessId');
    return Business(
      id: session.businessId!,
      name: 'Business', // Placeholder - will be updated when API works
      email: '',
      phone: '',
      address: '',
      businessType: BusinessType.restaurant, // Default type
    );
  }
  return null;
});

final enhancedBusinessProvider = FutureProvider<Business?>((ref) async {
  // Now same logic as businessProvider (legacy enhanced removed)
  return await ref.watch(businessProvider.future);
});

// Provider for refreshing business data
final businessRefreshProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(businessProvider);
    ref.invalidate(enhancedBusinessProvider);
  };
});

// Provider for updating business profile
final businessUpdateProvider =
    StateNotifierProvider<BusinessUpdateNotifier, AsyncValue<void>>((ref) {
  return BusinessUpdateNotifier(ref);
});

class BusinessUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  BusinessUpdateNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> updateBusinessProfile(
      String businessId, Map<String, dynamic> updateData) async {
    state = const AsyncValue.loading();

    try {
      final apiService = ApiService();
      await apiService.updateBusinessProfile(businessId, updateData);

      // Refresh the business provider to get updated data
      ref.invalidate(businessProvider);
      ref.invalidate(enhancedBusinessProvider);

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateBusinessPhoto(String businessId, String photoUrl) async {
    state = const AsyncValue.loading();

    try {
      final apiService = ApiService();
      await apiService.updateBusinessPhoto(businessId, photoUrl);

      // Refresh the business provider to get updated data
      ref.invalidate(businessProvider);
      ref.invalidate(enhancedBusinessProvider);

      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
