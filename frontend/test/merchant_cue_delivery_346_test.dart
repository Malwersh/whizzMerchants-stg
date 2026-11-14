import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/audio_notification_service.dart';
import '../lib/services/sound_notification_settings.dart';
import '../lib/services/notification_sound_files.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(()async{SharedPreferences.setMockInitialValues({});debugDefaultTargetPlatformOverride=TargetPlatform.iOS;await SoundNotificationSettings().initialize();});
 tearDown((){debugDefaultTargetPlatformOverride=null;TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(NotificationSoundFiles.bridge,null);});
 test('failed native cue is not recorded and a duplicate arrival retries',()async{var calls=0;TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(NotificationSoundFiles.bridge,(call)async{if(call.method=='playOrderCue')return {'playing':++calls>1};return null;});final audio=AudioNotificationService();await audio.playNewOrderSoundOnce('retry-346');final prefs=await SharedPreferences.getInstance();expect((jsonDecode(prefs.getString('merchant_order_sound_history_v1')??'{}') as Map).containsKey('retry-346'),false);await audio.playNewOrderSoundOnce('retry-346');await audio.playNewOrderSoundOnce('retry-346');expect(calls,2);expect((jsonDecode(prefs.getString('merchant_order_sound_history_v1')!) as Map).containsKey('retry-346'),true);});
 test('FCM and socket arrivals coalesce while one native cue is pending',()async{final started=Completer<void>(),done=Completer<Map<String,dynamic>>();var calls=0;TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(NotificationSoundFiles.bridge,(call)async{if(call.method=='playOrderCue'){calls++;started.complete();return done.future;}return null;});final audio=AudioNotificationService(),first=audio.playNewOrderSoundOnce('duplicate-346');await started.future;final second=audio.playNewOrderSoundOnce('duplicate-346');done.complete({'playing':true});await Future.wait([first,second]);expect(calls,1);});
 test('two distinct new orders do not permanently silence the second due to reminder cadence',()async{var calls=0;TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(NotificationSoundFiles.bridge,(call)async{if(call.method=='playOrderCue'){calls++;return {'playing':true};}return null;});await AudioNotificationService().playNewOrderSoundOnce('first-346');await AudioNotificationService().playNewOrderSoundOnce('second-346');expect(calls,2);});
}
