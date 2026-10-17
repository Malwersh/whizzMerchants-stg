import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final branchDeviceProvider = StateNotifierProvider<BranchDeviceNotifier,
    AsyncValue<Map<String, dynamic>?>>((ref) => BranchDeviceNotifier());

class BranchDeviceNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  static const key = 'merchant_paired_branch_device_v1';
  final FlutterSecureStorage storage;
  BranchDeviceNotifier({this.storage = const FlutterSecureStorage()})
      : super(const AsyncLoading()) {
    load();
  }
  Future<void> load() async {
    try {
      final value = await storage.read(key: key);
      state = AsyncData(
          value == null ? null : Map<String, dynamic>.from(jsonDecode(value)));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> activate(Map<String, dynamic> device) async {
    await storage.write(key: key, value: jsonEncode(device));
    state = AsyncData(device);
  }

  Future<void> forget() async {
    await storage.delete(key: key);
    state = const AsyncData(null);
  }
}
