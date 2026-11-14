import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class OnboardingConfig {
  OnboardingConfig.fromJson(Map<String, dynamic> value) {
    if (value['configVersion'] is! String ||
        (value['configVersion'] as String).isEmpty ||
        value['version'] is! int ||
        (value['version'] as int) < 1 ||
        value['termsVersion'] is! String ||
        value['termsTextAr'] is! String ||
        value['types'] is! List)
      throw const FormatException('Invalid onboarding configuration');
    configVersion = value['configVersion'];
    version = value['version'];
    termsVersion = value['termsVersion'];
    termsTextAr = value['termsTextAr'];
    final result = <Map<String, dynamic>>[], ids = <String>{};
    for (final row in value['types'] as List) {
      if (row is! Map ||
          row['id'] is! String ||
          !ids.add(row['id']) ||
          row['labelAr'] is! String ||
          row['labelEn'] is! String ||
          !['FOOD', 'RETAIL'].contains(row['model']) ||
          row['fields'] is! List)
        throw const FormatException('Unsupported onboarding configuration');
      result.add(Map<String, dynamic>.from(row));
    }
    types = List.unmodifiable(result);
  }
  late final String configVersion, termsVersion, termsTextAr;
  late final int version;
  late final List<Map<String, dynamic>> types;
}

class OnboardingConfigService {
  OnboardingConfigService({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;
  void close() => _client.close();
  Future<OnboardingConfig> load({String? regionId}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/auth/onboarding-settings')
        .replace(queryParameters: {if (regionId != null) 'regionId': regionId});
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('تعذر تحميل إعدادات إنشاء النشاط. حاول مجددًا.');
    return OnboardingConfig.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }
}
