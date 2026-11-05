// Emulator-only entry point. Never used by lib/main.dart or release builds.
// Uses synthetic tokens to exercise the real Android encrypted-storage plugin.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whizz_merchants/services/secure_token_storage.dart';
import 'package:whizz_merchants/services/branch_session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final phase = prefs.getString('merchant_session_probe_phase');
  var message = '';
  if (phase == null) {
    if (await SecureTokenStorage.getRefreshToken() != null) {
      throw StateError('Refusing to overwrite an existing session');
    }
    final token = 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'sub': 'android-storage-fixture',
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
        })))}.fixture';
    await SecureTokenStorage.setAccessToken(token);
    await SecureTokenStorage.setIdToken(token);
    await SecureTokenStorage.setRefreshToken('synthetic-emulator-refresh');
    await BranchSessionStore()
        .save('fixture-branch', {'businessId': 'fixture-branch'});
    await prefs.setString('merchant_session_probe_phase', 'saved');
    message = 'SESSION_PROBE_SAVED';
  } else if (phase == 'saved') {
    final branch = await BranchSessionStore().read();
    if (!branch.authenticated ||
        branch.businessId != 'fixture-branch' ||
        await SecureTokenStorage.getRefreshToken() !=
            'synthetic-emulator-refresh') {
      throw StateError('SESSION_PROBE_RESTORE_FAILED');
    }
    message = 'SESSION_PROBE_RESTORED';
  } else {
    final branch = await BranchSessionStore().read();
    if (branch.authenticated ||
        branch.businessId != null ||
        await SecureTokenStorage.getRefreshToken() != null) {
      throw StateError('SESSION_PROBE_LOGOUT_FAILED');
    }
    message = 'SESSION_PROBE_LOGOUT_PERSISTED';
  }
  debugPrint(message);
  runApp(MaterialApp(
      home: Scaffold(
          body: Center(
              child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(message),
      ElevatedButton(
          onPressed: () async {
            await SecureTokenStorage.clearAll();
            await BranchSessionStore().clear();
            await prefs.setString('merchant_session_probe_phase', 'cleared');
            debugPrint('SESSION_PROBE_CLEARED');
          },
          child: const Text('CLEAR TEST SESSION')),
    ],
  )))));
}
