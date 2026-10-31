import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class MerchantPlace {
  final String id, label;
  const MerchantPlace(this.id, this.label);
}

class MerchantLocation {
  final double latitude, longitude;
  final String? address;
  const MerchantLocation(this.latitude, this.longitude, {this.address});
}

class MerchantPlacesService {
  final http.Client _client;
  final String? _key;
  String _session = const Uuid().v4();
  MerchantPlacesService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _key = apiKey;
  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> parameters) async {
    if (_key == null && !dotenv.isInitialized)
      await dotenv.load(fileName: '.env');
    final key = _key ?? dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) throw Exception('تعذر تهيئة بحث Google.');
    final response = await _client
        .get(Uri.https('maps.googleapis.com', '/maps/api/place/$path/json', {
          ...parameters,
          'key': key,
          'language': 'ar',
          'sessiontoken': _session
        }))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200)
      throw Exception('تعذر الاتصال ببحث العناوين. أعد المحاولة.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (!['OK', 'ZERO_RESULTS'].contains(data['status']))
      throw Exception('تعذر تحميل نتائج Google. أعد المحاولة.');
    return data;
  }

  Future<List<MerchantPlace>> search(String query) async {
    if (query.trim().length < 3) return [];
    final data = await _get(
        'autocomplete', {'input': query.trim(), 'components': 'country:iq'});
    return [
      for (final row in data['predictions'] ?? [])
        MerchantPlace(row['place_id'], row['description'])
    ];
  }

  Future<MerchantLocation> details(String id) async {
    final data = await _get(
        'details', {'place_id': id, 'fields': 'geometry,formatted_address'});
    final result = data['result'], point = result['geometry']['location'];
    _session = const Uuid().v4();
    return MerchantLocation(
        (point['lat'] as num).toDouble(), (point['lng'] as num).toDouble(),
        address: result['formatted_address']);
  }

  void dispose() => _client.close();
}
