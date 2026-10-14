import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import '../models/order.dart';
import 'secure_token_storage.dart';
import 'order_service.dart';

/// Device inbox, scoped to both the signed-in account and restaurant.
class MerchantNotificationInbox extends ChangeNotifier {
  static final instance = MerchantNotificationInbox();
  MerchantNotificationInbox(
      {Future<String?> Function()? subjectLoader,
      Future<List<Order>> Function(String)? orderLoader})
      : _subjectLoader = subjectLoader ?? _currentSubject,
        _orderLoader =
            orderLoader ?? ((id) => OrderService().getMerchantOrders(id));
  final Future<String?> Function() _subjectLoader;
  final Future<List<Order>> Function(String) _orderLoader;
  String? _scope;
  List<NotificationModel> items = [];
  String? error;
  static Future<void> _writes = Future.value();
  static Future<String?> _currentSubject() async {
    final token = await SecureTokenStorage.getAccessToken();
    if (token == null) return null;
    try {
      return JwtDecoder.decode(token)['sub']?.toString();
    } catch (_) {
      return null;
    }
  }

  static String _key(String subject, String business) =>
      'merchant_inbox_${Uri.encodeComponent(subject)}_${Uri.encodeComponent(business)}';
  static List<NotificationModel> _read(SharedPreferences prefs, String key) {
    try {
      return (jsonDecode(prefs.getString(key) ?? '[]') as List)
          .map((x) => NotificationModel.fromJson(Map<String, dynamic>.from(x)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(
      String key, Future<void> Function(SharedPreferences) operation) {
    final next = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      await operation(prefs);
    });
    _writes = next;
    return next;
  }

  static Future<void> _save(SharedPreferences prefs, String key,
      Iterable<NotificationModel> rows) async {
    final sorted = rows.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await prefs.setString(
        key, jsonEncode(sorted.take(200).map((x) => x.toJson()).toList()));
  }

  static Future<void> recordPush(Map<String, dynamic> data,
      {String? title, String? body, String? messageId}) async {
    final subject = await _currentSubject();
    final business = data['businessId']?.toString();
    if (subject == null || business == null || business.isEmpty) return;
    final recipient = data['subjectId']?.toString();
    if (recipient != null && recipient != subject) return;
    final order = data['orderId']?.toString();
    final action =
        data['action']?.toString() ?? data['type']?.toString() ?? 'general';
    final id = action == 'new_order' && order != null
        ? 'order:$order:created'
        : data['eventId']?.toString() ?? messageId;
    if (id == null) return;
    final key = _key(subject, business);
    await _write(key, (prefs) async {
      final rows = _read(prefs, key);
      final existing = rows.indexWhere((x) => x.id == id);
      if (existing >= 0 && rows[existing].type != 'order_history') return;
      if (existing >= 0) rows.removeAt(existing);
      rows.add(NotificationModel(
          id: id,
          title: title ?? 'إشعار جديد',
          body: body ?? '',
          type: action,
          data: data,
          orderId: order,
          businessId: business,
          createdAt: DateTime.tryParse(data['updatedAt']?.toString() ?? '') ??
              DateTime.now()));
      await _save(prefs, key, rows);
    });
    if (instance._scope == key) await instance._reload(key);
  }

  Future<void> _reload(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (_scope != key) return;
    items = _read(prefs, key);
    notifyListeners();
  }

  Future<void> load(String business) async {
    final subject = await _subjectLoader();
    if (subject == null) {
      _scope = null;
      items = [];
      error = 'يرجى تسجيل الدخول لعرض الإشعارات';
      notifyListeners();
      return;
    }
    final key = _key(subject, business);
    if (_scope != key) items = [];
    _scope = key;
    await _reload(key);
    try {
      final orders = await _orderLoader(business);
      if (_scope != key || await _subjectLoader() != subject) return;
      await _write(key, (prefs) async {
        final rows = _read(prefs, key);
        final known = rows.map((x) => x.id).toSet();
        for (final order in orders.where((x) => x.businessId == business)) {
          final id = 'order:${order.id}:created';
          if (!known.add(id)) continue;
          // Actual order history, not a fabricated push receipt. Historical
          // entries start read so opening the screen does not create alerts.
          rows.add(NotificationModel(
              id: id,
              title: 'طلب #${order.orderNumber ?? order.id}',
              body: 'تم إنشاء الطلب — ${order.customerName}',
              type: 'order_history',
              data: {},
              businessId: business,
              orderId: order.id,
              createdAt: order.createdAt,
              isRead: true));
        }
        await _save(prefs, key, rows);
      });
      error = null;
      await _reload(key);
    } catch (_) {
      if (_scope == key) {
        error = 'تعذر تحديث الإشعارات. اسحب لإعادة المحاولة.';
        notifyListeners();
      }
    }
  }

  Future<void> markRead({String? id}) async {
    final key = _scope;
    if (key == null) return;
    await _write(key, (prefs) async {
      await _save(
          prefs,
          key,
          _read(prefs, key).map(
              (x) => id == null || x.id == id ? x.copyWith(isRead: true) : x));
    });
    await _reload(key);
  }
}
