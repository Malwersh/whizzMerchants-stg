import 'notification_sound_policy.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_header_builder.dart';
import 'branch_employee_access.dart';
class OrderReceptionService {
 static final changes=ValueNotifier<int>(0);
 final String businessId;final BranchEmployeeAccess? access;
 OrderReceptionService(this.businessId,{this.access});
 Future<Map<String,dynamic>> call(Map<String,dynamic> input)async{
  Map<String,dynamic> result;
  if(access!=null){result=await access!.api.call(access!.token,input,session:access!.session);}
  else{
   final headers=await AuthHeaderBuilder.build();final uri=Uri.parse('${AppConfig.baseUrl}/businesses/$businessId/status?view=order-reception');
   final r=input['action']=='read_order_reception'?await http.get(uri,headers:headers).timeout(const Duration(seconds:15)):await http.put(uri,headers:headers,body:jsonEncode(input)).timeout(const Duration(seconds:15));
   result=Map<String,dynamic>.from(jsonDecode(r.body));
   if(r.statusCode!=200)throw Exception(r.statusCode==409?'تغيرت إعدادات الفرع. حدّث الصفحة وأعد المحاولة.':'تعذر حفظ إعدادات استقبال الطلبات. أعد المحاولة.');
  }
  final data=result['data'] is Map?Map<String,dynamic>.from(result['data']):result;
  if(data['businessId']!=businessId||data['revision'] is! String||data['settings'] is! Map)throw StateError('تعذر قراءة إعدادات الفرع.');
  await NotificationSoundPolicy.adopt(data['notificationPolicy']);
  if(input['action']!='read_order_reception')changes.value++;
  return data;
 }
}
