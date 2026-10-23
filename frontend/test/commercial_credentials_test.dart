import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:whizz_merchants/services/person_onboarding_service.dart';
import 'package:whizz_merchants/services/token_refresh_service.dart';
String token(String type) => '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode(jsonEncode({'token_use':type,'exp':DateTime.now().millisecondsSinceEpoch~/1000+3600})))}.fixture';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('commercial GET and POST keep ID token for Gateway and access token for live GetUser',()async{
  final id=token('id'),access=token('access');FlutterSecureStorage.setMockInitialValues({'secure_id_token':id,'secure_access_token':access});
  final calls=<http.Request>[];final api=PersonOnboardingService(client:MockClient((r)async{calls.add(r);return http.Response('{"items":[]}',200);}));
  await api.call('commercial-agreements?businessId=branch');await api.call('commercial-agreements',body:{'businessId':'branch'});
  for(final r in calls){expect(r.headers['Authorization'],'Bearer $id');expect(r.headers['Access-Token'],access);}
 });
 test('strict accessor refuses ID token stored in access slot',()async{FlutterSecureStorage.setMockInitialValues({'secure_access_token':token('id')});expect(await TokenRefreshService.getValidUserAccessToken(),isNull);});
}
