import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_logger.dart';
import '../models/order.dart';

/// A LAN thermal printer (ESC/POS over raw TCP, usually port 9100).
class KitchenPrinter {
  final String name;
  final String ip;
  final int port;
  final int paperWidthMm; // 80 or 58
  final int copies;
  final bool enabled;
  final String ticketType; // kitchen, customer, both

  const KitchenPrinter({
    required this.name,
    required this.ip,
    this.port = 9100,
    this.paperWidthMm = 80,
    this.copies = 1,
    this.enabled = true,
    this.ticketType = 'kitchen',
  });

  int get dotsWidth => paperWidthMm == 58 ? 384 : 576;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ip': ip,
        'port': port,
        'paperWidthMm': paperWidthMm,
        'copies': copies,
        'enabled': enabled,
        'ticketType': ticketType,
      };

  factory KitchenPrinter.fromJson(Map<String, dynamic> j) => KitchenPrinter(
        name: j['name'] ?? '',
        ip: j['ip'] ?? '',
        port: j['port'] ?? 9100,
        paperWidthMm: j['paperWidthMm'] ?? 80,
        copies: j['copies'] ?? 1,
        enabled: j['enabled'] ?? true,
        ticketType: j['ticketType'] ?? 'kitchen',
      );

  KitchenPrinter copyWith({
    String? name,
    String? ip,
    int? port,
    int? paperWidthMm,
    int? copies,
    bool? enabled,
  }) =>
      KitchenPrinter(
        name: name ?? this.name,
        ip: ip ?? this.ip,
        port: port ?? this.port,
        paperWidthMm: paperWidthMm ?? this.paperWidthMm,
        copies: copies ?? this.copies,
        enabled: enabled ?? this.enabled,
        ticketType: ticketType,
      );
}

class KitchenSettings {
  final String businessName;
  final DateTime? automaticFrom;
  final bool autoDispatchOnAccept;
  final List<KitchenPrinter> printers;
  final String kdsUrl; // optional kitchen display endpoint (HTTP POST JSON)
  final String kdsApiKey;

  const KitchenSettings({
    this.businessName = '',
    this.automaticFrom,
    this.autoDispatchOnAccept = true,
    this.printers = const [],
    this.kdsUrl = '',
    this.kdsApiKey = '',
  });

  bool get hasTargets =>
      printers.any((p) => p.enabled) || kdsUrl.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'automaticFrom': automaticFrom?.toIso8601String(),
        'autoDispatchOnAccept': autoDispatchOnAccept,
        'printers': printers.map((p) => p.toJson()).toList(),
        'kdsUrl': kdsUrl,
        'kdsApiKey': kdsApiKey,
      };

  factory KitchenSettings.fromJson(Map<String, dynamic> j) => KitchenSettings(
        businessName: j['businessName']?.toString() ?? '',
        automaticFrom: DateTime.tryParse('${j['automaticFrom'] ?? ''}'),
        autoDispatchOnAccept: j['autoDispatchOnAccept'] ?? true,
        printers: ((j['printers'] as List?) ?? [])
            .map((e) => KitchenPrinter.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        kdsUrl: j['kdsUrl'] ?? '',
        kdsApiKey: j['kdsApiKey'] ?? '',
      );
}

class DispatchResult {
  final int succeeded;
  final List<String> failures;
  const DispatchResult(this.succeeded, this.failures);
  bool get allOk => failures.isEmpty;
}

/// Sends accepted orders to kitchen printers and/or a kitchen display (KDS).
/// Settings are stored on this device because printers live on the shop's LAN.
class KitchenDispatchService {
  static const _prefsKey = 'kitchen_settings_v1';

  static Future<KitchenSettings> load({String? businessId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs
        .getString(businessId == null ? _prefsKey : '${_prefsKey}_$businessId');
    if (raw == null) return const KitchenSettings();
    try {
      return KitchenSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return const KitchenSettings();
    }
  }

  static Future<void> save(KitchenSettings s,
      {String? businessId, String? businessName}) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = await load(businessId: businessId);
    final data = s.toJson();
    data['businessName'] = businessName ??
        (s.businessName.isNotEmpty ? s.businessName : previous.businessName);
    if (businessId != null && s.autoDispatchOnAccept && s.hasTargets) {
      data['automaticFrom'] =
          (previous.autoDispatchOnAccept && previous.hasTargets
                  ? previous.automaticFrom ?? DateTime.now()
                  : DateTime.now())
              .toIso8601String();
    }
    await prefs.setString(
        businessId == null ? _prefsKey : '${_prefsKey}_$businessId',
        jsonEncode(data));
  }

  /// Called after the merchant accepts an order. Never throws.
  static Future<DispatchResult?> dispatchAcceptedOrder(Order order,
      {String businessName = ''}) async {
    final settings = await load();
    if (!settings.autoDispatchOnAccept || !settings.hasTargets) return null;
    return dispatch(order, settings, businessName: businessName);
  }

  static Future<DispatchResult> dispatch(Order order, KitchenSettings settings,
      {String businessName = ''}) async {
    var ok = 0;
    final failures = <String>[];

    for (final p in settings.printers.where((p) => p.enabled)) {
      try {
        final bytes =
            await _buildTicket(order, p.dotsWidth, businessName: businessName);
        for (var i = 0; i < p.copies.clamp(1, 5); i++) {
          await sendRaw(p.ip, p.port, bytes);
        }
        ok++;
      } catch (e) {
        AppLogger.error('Kitchen printer ${p.name} (${p.ip}) failed: $e');
        failures.add(p.name.isEmpty ? p.ip : p.name);
      }
    }

    if (settings.kdsUrl.trim().isNotEmpty) {
      try {
        await sendToKds(order, settings);
        ok++;
      } catch (e) {
        AppLogger.error('KDS dispatch failed: $e');
        failures.add('KDS');
      }
    }
    return DispatchResult(ok, failures);
  }

  /// Prints a short test ticket.
  static Future<void> testPrinter(KitchenPrinter p) async {
    final order = Order(
      id: 'TEST',
      businessId: '',
      customerId: '',
      customerName: 'اختبار / Test',
      items: [
        OrderItem(id: '1', name: 'طباعة تجريبية', price: 0, quantity: 1),
        OrderItem(
            id: '2', name: 'Test print', price: 0, quantity: 2, notes: 'OK'),
      ],
      totalAmount: 0,
      status: OrderStatus.confirmed,
      createdAt: DateTime.now(),
      orderNumber: 'TEST',
    );
    final bytes = await _buildTicket(order, p.dotsWidth);
    await sendRaw(p.ip, p.port, bytes);
  }

  static Future<void> testKds(KitchenSettings s) async {
    final order = Order(
      id: 'TEST',
      businessId: '',
      customerId: '',
      customerName: 'Test',
      items: [OrderItem(id: '1', name: 'Test item', price: 0, quantity: 1)],
      totalAmount: 0,
      status: OrderStatus.confirmed,
      createdAt: DateTime.now(),
      orderNumber: 'TEST',
    );
    await sendToKds(order, s);
  }

  static Future<Uint8List> ticketBytes(
          Order order, int width, List<String> lines) =>
      _buildTicket(order, width, lines: lines);

  static Future<Uint8List> previewBytes(
      Order order, int width, List<String> lines) async {
    final image = await _renderTicketImage(order, width, '', lines: lines);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  // ---------------------------------------------------------------- transport

  static Future<void> sendRaw(String ip, int port, Uint8List bytes) async {
    final socket =
        await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
      socket.destroy();
    }
  }

  static Future<void> sendToKds(Order order, KitchenSettings s) async {
    final body = jsonEncode({
      'event': 'order.accepted',
      'orderId': order.id,
      'orderNumber': order.orderNumber ?? order.id,
      'customerName': order.customerName,
      'notes': order.notes,
      'createdAt': order.createdAt.toIso8601String(),
      'acceptedAt': DateTime.now().toIso8601String(),
      'items': order.items
          .map(
              (i) => {'name': i.name, 'quantity': i.quantity, 'notes': i.notes})
          .toList(),
    });
    final resp = await http
        .post(
          Uri.parse(s.kdsUrl.trim()),
          headers: {
            'Content-Type': 'application/json',
            if (s.kdsApiKey.trim().isNotEmpty)
              'Authorization': 'Bearer ${s.kdsApiKey.trim()}',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}');
    }
  }

  // ------------------------------------------------------------------ ticket

  /// Renders the kitchen ticket as an image (supports Arabic shaping/RTL)
  /// and converts it to an ESC/POS raster command.
  static Future<Uint8List> _buildTicket(Order order, int widthDots,
      {String businessName = '', List<String>? lines}) async {
    final image =
        await _renderTicketImage(order, widthDots, businessName, lines: lines);
    late Uint8List raster;
    try {
      raster = await _toEscPosRaster(image);
    } finally {
      image.dispose();
    }

    final out = BytesBuilder();
    out.add([0x1B, 0x40]); // ESC @ init
    out.add(raster);
    out.add([0x1B, 0x64, 0x04]); // feed 4 lines
    out.add([0x1D, 0x56, 0x42, 0x00]); // GS V B: partial cut
    return out.toBytes();
  }

  static Future<ui.Image> _renderTicketImage(
      Order order, int width, String businessName,
      {List<String>? lines}) async {
    const pad = 12.0;
    final w = width.toDouble();
    final contentW = w - pad * 2;
    final pairedRows = <TextPainter, (TextPainter, TextPainter)>{};
    final deliveryBars = <TextPainter>{};
    final separators = <TextPainter>{};
    final customerReceipt =
        lines != null && lines.isNotEmpty && lines.first == 'وصل الزبون';
    ui.Image? logo;
    if (customerReceipt) {
      final bytes =
          await rootBundle.load('assets/images/wizz-wordmark-blue.png');
      final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      try {
        logo = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    }
    final logoWidth = contentW * .58;
    final logoHeight =
        logo == null ? 0.0 : logoWidth * logo.height / logo.width;
    final headerHeight = logo == null ? 0.0 : logoHeight + 22 * width / 576;
    final painters = <(TextPainter, double)>[]; // painter, spacing after

    TextPainter tp(String text, double size,
        {bool bold = false,
        TextAlign align = TextAlign.right,
        Color color = Colors.black}) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            height: 1.25,
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.rtl,
      )..layout(minWidth: contentW, maxWidth: contentW);
      return p;
    }

    void add(TextPainter p, [double gap = 6]) => painters.add((p, gap));

    final scale = width / 576; // shrink fonts for 58mm paper
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');

    if (lines != null) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line == '────────────────────────') {
          final separator = tp('', 8 * scale);
          separators.add(separator);
          add(separator, 14 * scale);
          continue;
        }
        if (customerReceipt && i == 0) continue;
        if (customerReceipt && i == 2) {
          final bar = tp('توصيل', 42 * scale,
              bold: true, align: TextAlign.center, color: Colors.white);
          deliveryBars.add(bar);
          add(bar, 20 * scale);
          continue;
        }
        if (customerReceipt && (i == 1 || i == 3)) {
          add(
              tp(line, (i == 3 ? 38 : 25) * scale,
                  bold: i == 3,
                  align: i == 3 ? TextAlign.right : TextAlign.center),
              14 * scale);
          continue;
        }
        final parts = line.split('\t');
        if (parts.length == 2) {
          final total = parts.first == 'الإجمالي';
          final size = (total ? 32.0 : 24.0) * scale;
          TextPainter column(String text, double available, TextAlign align) =>
              TextPainter(
                text: TextSpan(
                    text: text,
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: size,
                        height: 1.25,
                        fontWeight: total ? FontWeight.w800 : FontWeight.w500)),
                textAlign: align,
                textDirection: TextDirection.rtl,
              )..layout(minWidth: available, maxWidth: available);
          final label = column(parts.first, contentW * .59, TextAlign.right);
          final price = column(parts.last, contentW * .38, TextAlign.left);
          final row = label.height >= price.height ? label : price;
          pairedRows[row] = (label, price);
          add(row, total ? 14 : 8);
        } else {
          final heading = i == 0;
          add(tp(line, (heading ? 32 : 24) * scale,
              bold: heading,
              align: heading ? TextAlign.center : TextAlign.right));
        }
      }
    } else {
      add(tp('مطبخ / KITCHEN', 34 * scale,
          bold: true, align: TextAlign.center));
      if (businessName.isNotEmpty) {
        add(tp(businessName, 24 * scale, align: TextAlign.center));
      }
      add(tp('طلب #${order.orderNumber ?? order.id}', 40 * scale,
          bold: true, align: TextAlign.center));
      add(
          tp('${two(t.hour)}:${two(t.minute)}  ${t.year}-${two(t.month)}-${two(t.day)}',
              22 * scale,
              align: TextAlign.center),
          10);
      add(tp('─' * 40, 18 * scale, align: TextAlign.center), 4);

      for (final item in order.items) {
        add(tp('${item.quantity} ×  ${item.name}', 32 * scale, bold: true), 2);
        if (item.notes != null && item.notes!.trim().isNotEmpty) {
          add(tp('   ↳ ${item.notes}', 24 * scale), 4);
        }
        add(tp('', 6 * scale), 2);
      }

      add(tp('─' * 40, 18 * scale, align: TextAlign.center), 4);
      if (order.notes != null && order.notes!.trim().isNotEmpty) {
        add(tp('ملاحظات: ${order.notes}', 26 * scale, bold: true));
      }
      add(tp('الزبون: ${order.customerName}', 22 * scale));
    }

    final height = painters
        .fold<double>(pad * 2 + headerHeight + deliveryBars.length * 16 * scale,
            (sum, e) => sum + e.$1.height + e.$2)
        .ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, height.toDouble()),
        Paint()..color = Colors.white);
    var y = pad;
    if (logo != null) {
      canvas.drawImageRect(
          logo,
          Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
          Rect.fromLTWH((w - logoWidth) / 2, y, logoWidth, logoHeight),
          Paint());
      y += headerHeight;
    }
    for (final (p, gap) in painters) {
      final pair = pairedRows[p];
      if (separators.contains(p)) {
        final pen = Paint()
          ..color = const Color(0xFF777777)
          ..strokeWidth = 1.3 * scale;
        for (double x = pad; x < w - pad; x += 9 * scale) {
          canvas.drawLine(Offset(x, y + 4 * scale),
              Offset((x + 3 * scale).clamp(pad, w - pad), y + 4 * scale), pen);
        }
        y += p.height + gap;
        continue;
      }
      if (deliveryBars.contains(p)) {
        canvas.drawRect(Rect.fromLTWH(0, y, w, p.height + 16 * scale),
            Paint()..color = const Color(0xFF333333));
        p.paint(canvas, Offset(pad, y + 8 * scale));
        y += p.height + 16 * scale + gap;
        continue;
      }
      if (pair == null) {
        p.paint(canvas, Offset(pad, y));
      } else {
        pair.$1.paint(canvas, Offset(w - pad - pair.$1.width, y));
        pair.$2.paint(canvas, Offset(pad, y));
      }
      y += p.height + gap;
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
      logo?.dispose();
    }
  }

  static Future<Uint8List> _toEscPosRaster(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = data!.buffer.asUint8List();
    final w = image.width;
    final h = image.height;
    final bytesPerRow = (w + 7) ~/ 8;

    final out = BytesBuilder();
    // Send in bands so printers with small buffers don't choke.
    const band = 200;
    for (var top = 0; top < h; top += band) {
      final rows = (top + band > h) ? h - top : band;
      out.add([
        0x1D, 0x76, 0x30, 0x00, // GS v 0, normal density
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        rows & 0xFF, (rows >> 8) & 0xFF,
      ]);
      final bandBytes = Uint8List(bytesPerRow * rows);
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < w; x++) {
          final i = ((top + y) * w + x) * 4;
          final lum =
              (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
          if (lum < 140) {
            bandBytes[y * bytesPerRow + (x >> 3)] |= (0x80 >> (x & 7));
          }
        }
      }
      out.add(bandBytes);
    }
    return out.toBytes();
  }
}
