import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/person_onboarding_service.dart';

class MerchantBusinessChangesScreen extends StatefulWidget {
  final String businessId;
  final bool embedded;
  final PersonOnboardingService? service;
  const MerchantBusinessChangesScreen({super.key, required this.businessId, this.service, this.embedded=false});
  @override
  State<MerchantBusinessChangesScreen> createState()=>_ChangesState();
}
class _ChangesState extends State<MerchantBusinessChangesScreen> {
  final _name=TextEditingController(), _reason=TextEditingController();
  late final PersonOnboardingService _api=widget.service??PersonOnboardingService();
  List<dynamic> _items=[];
  dynamic _base;
  bool _busy=true;
  String? _error;
  String? _requestId;
  String? _requestSignature;
  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){_name.dispose();_reason.dispose();super.dispose();}
  Future<void> _load()async{
    setState((){_busy=true;_error=null;});
    try{final r=await _api.call('business-changes?businessId=${Uri.encodeComponent(widget.businessId)}');if(mounted)setState((){_items=r['items']??[];_base=r['baseUpdatedAt'];});}
    catch(e){if(mounted)setState(()=>_error=e.toString());}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _submit()async{
    if(_busy||_error!=null)return;
    if(_name.text.trim().isEmpty||_reason.text.trim().length<5){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أدخل الاسم وسبب التعديل من خمسة أحرف على الأقل.')));return;}
    final signature='${_name.text.trim()}\n${_reason.text.trim()}';
    if(signature!=_requestSignature){_requestId=const Uuid().v4();_requestSignature=signature;}
    setState(()=>_busy=true);
    try{await _api.call('business-changes',body:{'businessId':widget.businessId,'baseUpdatedAt':_base,'requestId':_requestId,'kind':'NAME','proposed':{'businessName':_name.text.trim()},'reason':_reason.text.trim()});if(!mounted)return;_name.clear();_reason.clear();_requestId=null;_requestSignature=null;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أُرسل الطلب للمراجعة. يبقى الاسم المعتمد ظاهرًا حتى الموافقة.')));await _load();}
    catch(e){if(mounted){setState(()=>_busy=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
  }
  @override
  Widget build(BuildContext context)=>widget.embedded ? Column(mainAxisSize:MainAxisSize.min,children:[Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh),label:const Text('تحديث حالة الطلبات'))),_content()]) : Scaffold(appBar:AppBar(title:const Text('طلبات تعديل بيانات النشاط'),actions:[IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh))]),body:_content());
  Widget _content()=>ListView(shrinkWrap:widget.embedded,physics:widget.embedded?const NeverScrollableScrollPhysics():null,padding:const EdgeInsets.all(20),children:[
    const Text('تعديل الاسم أو نقل الموقع يرسل للمراجعة. تبقى البيانات المعتمدة سارية حتى الموافقة. لتعديل الموقع افتح إعدادات الموقع.'),
    if(_busy)const LinearProgressIndicator(),
    if(_error!=null)...[Text(_error!),TextButton(onPressed:_load,child:const Text('إعادة المحاولة'))],
    TextField(controller:_name,maxLength:150,enabled:!_busy&&_error==null,decoration:const InputDecoration(labelText:'الاسم المقترح')),
    TextField(controller:_reason,maxLength:1000,enabled:!_busy&&_error==null,decoration:const InputDecoration(labelText:'سبب التعديل')),
    FilledButton(onPressed:_busy||_error!=null?null:_submit,child:const Text('إرسال طلب تعديل الاسم')),
    const SizedBox(height:20),const Text('طلباتك السابقة'),
    for(final r in _items)Card(child:ListTile(title:Text(r['kind']=='NAME'?'تعديل الاسم: ${r['proposed']['businessName']}':'نقل الموقع: ${r['proposed']['address']}'),subtitle:Text('${({'PENDING':'قيد المراجعة','APPROVED':'معتمد','REJECTED':'مرفوض'})[r['status']]??r['status']}\nسبب الطلب: ${r['reason']??''}${r['decisionReason']==null?'':'\nسبب القرار: ${r['decisionReason']}'}'))),
  ]);
}
