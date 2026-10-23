import 'dart:async';
import '../lib/providers/auth_provider_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/auth_navigation.dart';

void main() {
  test('logout leaves authenticated state before session cleanup starts', () async {
    final cleanup = Completer<void>();
    late AuthNotifier auth;
    auth = AuthNotifier(signOutAction: () {
      expect(auth.state.isAuthenticated, false);
      expect(auth.state.isLoading, true);
      return cleanup.future;
    });
    addTearDown(auth.dispose);
    auth.setAuthenticated();
    final pending = auth.signOut();
    expect(auth.state.isAuthenticated, false);
    expect(auth.state.isLoading, true);
    cleanup.complete();
    await pending;
    expect(auth.state.isAuthenticated, false);
    expect(auth.state.isLoading, false);
  });

  testWidgets(
      'logout clears branch and settings pages and back cannot restore them',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    final signedIn = ValueNotifier(true);
    addTearDown(signedIn.dispose);
    await t.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: ValueListenableBuilder<bool>(
            valueListenable: signedIn,
            builder: (_, authenticated, __) =>
                Scaffold(body: Text(authenticated ? 'activities' : 'login')))));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('branch'))));
    await t.pumpAndSettle();
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('settings'))));
    await t.pumpAndSettle();
    final capturedRoot = navigator.currentState!;
    signedIn.value = false;
    clearProtectedRoutes(capturedRoot);
    await t.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
    expect(find.text('branch'), findsNothing);
    expect(find.text('settings'), findsNothing);
    expect(capturedRoot.canPop(), false);
    expect(await capturedRoot.maybePop(), false);
  });
}
