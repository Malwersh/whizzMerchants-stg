import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../lib/providers/business_provider.dart';
import '../lib/providers/session_provider.dart';
import '../lib/services/branch_session_store.dart';
import '../lib/services/merchant_branch_scope.dart';
import '../lib/services/app_state.dart';

class Store extends BranchSessionStore {
  final restore = Completer<StoredBranchSession>();
  Completer<void>? saving;
  final writes = <String>[];
  @override
  Future<StoredBranchSession> read() => restore.future;
  @override
  Future<void> save(String id, Map<String, dynamic> data) async {
    writes.add(id);
    await saving?.future;
  }

  @override
  Future<void> clear() async {
    writes.add('clear');
  }
}

String token(String sub) => 'h.${base64Url.encode(utf8.encode(jsonEncode({
          'sub': sub,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })))}.s';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test('late restore cannot replace a newly selected branch', () async {
    final store = Store();
    final s = SessionNotifier(store: store);
    await s.setSessionWithBusinessData('new', {'businessId': 'new'});
    store.restore.complete(
        const StoredBranchSession(authenticated: true, businessId: 'old'));
    await Future<void>.delayed(Duration.zero);
    expect(s.state.businessId, 'new');
    s.dispose();
  });
  test('late restore cannot revive a logged-out account', () async {
    final store = Store(), s = SessionNotifier(store: store);
    await s.clearSession();
    store.restore.complete(
        const StoredBranchSession(authenticated: true, businessId: 'old'));
    await Future<void>.delayed(Duration.zero);
    expect(s.state.isAuthenticated, false);
    expect(s.state.businessId, isNull);
    s.dispose();
  });
  test('older business response cannot clear a later selection including A B A',
      () async {
    final s = SessionNotifier(store: Store(), restoreOnStart: false);
    await s.setSession('a');
    final captured = s.state;
    await s.setSession('b');
    await s.setSession('a');
    await s.clearBusinessSelection(expected: captured);
    expect(s.state.businessId, 'a');
    s.dispose();
  });
  test('logout waits for pending persistence then clears it permanently',
      () async {
    final store = Store()..saving = Completer<void>(),
        s = SessionNotifier(store: store, restoreOnStart: false);
    final selecting = s.setSession('a');
    await Future<void>.delayed(Duration.zero);
    final logout = s.clearSession();
    expect(s.state.isAuthenticated, false);
    store.saving!.complete();
    await Future.wait([selecting, logout]);
    expect(store.writes, ['a', 'clear']);
    expect(s.state.businessId, isNull);
    s.dispose();
  });
  test('serialized branch changes leave the newest selection persisted',
      () async {
    final store = Store()..saving = Completer<void>(),
        s = SessionNotifier(store: store, restoreOnStart: false);
    final first = s.setSession('a');
    await Future<void>.delayed(Duration.zero);
    final second = s.setSession('b');
    expect(s.state.businessId, 'b');
    store.saving!.complete();
    await Future.wait([first, second]);
    expect(store.writes, ['a', 'b']);
    s.dispose();
  });
  test('mismatched cached branch is rejected', () async {
    final s = SessionNotifier(store: Store(), restoreOnStart: false);
    await expectLater(s.setSessionWithBusinessData('a', {'businessId': 'b'}),
        throwsArgumentError);
    expect(s.state.businessId, isNull);
    s.dispose();
  });
  test('captured mutation invalid immediately before storage and after A B A',
      () async {
    final store = Store()..saving = Completer<void>(),
        s = SessionNotifier(store: store, restoreOnStart: false);
    final a = s.setSession('a');
    await Future<void>.delayed(Duration.zero);
    final scope = await MerchantBranchScope.capture();
    final b = s.setSession('b');
    await expectLater(scope.assertCurrent(), throwsStateError);
    final again = s.setSession('a');
    await expectLater(scope.assertCurrent(), throwsStateError);
    store.saving!.complete();
    await Future.wait([a, b, again]);
    s.dispose();
  });
  test('status from previous branch never carries to next or logout', () {
    final a = AppState();
    a.selectBranch('a');
    a.updateOnlineStatus(true);
    expect(a.isOnline, true);
    a.selectBranch('b');
    expect(a.statusKnown, false);
    expect(a.isOnline, false);
    a.logout();
    a.updateOnlineStatus(true);
    expect(a.isOnline, false);
  });
  test('pending reception toggle cannot update a newly selected branch',
      () async {
    final a = AppState(), done = Completer<void>();
    a.selectBranch('a');
    final pending = a.setOnline(true, (_) => done.future);
    a.selectBranch('b');
    done.complete();
    await pending;
    expect(a.statusKnown, false);
    expect(a.isOnline, false);
  });
  test('persisted selection belongs to the same authenticated subject',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'secure_id_token': token('owner')});
    final store = BranchSessionStore();
    await store.save('a', {'businessId': 'a'});
    expect((await store.read()).businessId, 'a');
    FlutterSecureStorage.setMockInitialValues(
        {'secure_id_token': token('other')});
    expect((await store.read()).businessId, isNull);
  });
  test('stored business data from a different branch never restores', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'secure_id_token': token('owner')});
    SharedPreferences.setMockInitialValues({
      'business_id': 'a',
      'business_selection_subject': 'owner',
      'business_data': '{"businessId":"b","businessName":"Foreign"}'
    });
    final restored = await BranchSessionStore().read();
    expect(restored.businessId, 'a');
    expect(restored.businessData, isNull);
  });
  test(
      'no identity cannot restore authenticated state from a branch preference',
      () async {
    SharedPreferences.setMockInitialValues({'business_id': 'a'});
    final restored = await BranchSessionStore().read();
    expect(restored.authenticated, false);
    expect(restored.businessId, isNull);
  });
  test('actual business provider cannot clear B after missing A returns late',
      () async {
    final session = SessionNotifier(store: Store(), restoreOnStart: false);
    final first = Completer<List<Map<String, dynamic>>>(),
        second = Completer<List<Map<String, dynamic>>>();
    var calls = 0;
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((_) => session),
      businessListLoaderProvider
          .overrideWithValue(() => ++calls == 1 ? first.future : second.future)
    ]);
    await session.setSessionWithBusinessData('a', {'businessId': 'a'});
    final subscription = container.listen(businessProvider, (_, __) {});
    final old = container.read(businessProvider.future);
    await session.setSessionWithBusinessData('b', {'businessId': 'b'});
    final current = container.read(businessProvider.future);
    first.complete([]);
    await Future<void>.delayed(Duration.zero);
    expect(session.state.businessId, 'b');
    second.complete([
      {'businessId': 'b', 'businessName': 'Branch B'}
    ]);
    await Future.wait([old,current]);
    expect(session.state.businessId, 'b');
    subscription.close();
    container.dispose();
  });
}
