import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../services/order_returns_service.dart';
class MerchantCancellationScreen extends StatefulWidget{
 final Order order;final OrderReturnsService? service;
 const MerchantCancellationScreen({super.key,required this.order,this.service});
 @override State<MerchantCancellationScreen> createState()=>_MerchantCancellationScreenState();
}
class _MerchantCancellationScreenState extends State<MerchantCancellationScreen>{
 final reason=TextEditingController();final nonce=const Uuid().v4();
 bool retained=false,noCash=false,busy=false,uncertain=false,done=false;
 late String preparation;
 @override void initState(){super.initState();preparation=[OrderStatus.pending,OrderStatus.confirmed].contains(widget.order.status)?'NOT_STARTED':widget.order.status==OrderStatus.preparing?'STARTED':'READY';}
 @override void dispose(){reason.dispose();super.dispose();}
 bool get ready=>!busy&&!uncertain&&!done&&retained&&noCash&&reason.text.trim().length>=5;
 Future<void> submit()async{
  if(!ready)return;
  final agree=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('تأكيد إلغاء المطعم قبل الاستلام'),content:const Text('يُلغى الطلب بعد تحقق الخادم أن السائق لم يستلم الأصناف، ويُحرر الضمان المؤهل. لا يتحمل الزبون رسومًا. يسجّل السبب وحالة التجهيز؛ لا يعني ذلك اعتماد تعويض للمطعم أو للسائق.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('تأكيد الإلغاء'))]));
  if(!mounted||agree!=true||!ready)return;setState(()=>busy=true);
  try{final r=await(widget.service??OrderReturnsService()).call({'businessId':widget.order.businessId,'orderId':widget.order.id},cancel:true,receipt:{'merchantCancellation':true,'reason':reason.text.trim(),'preparationState':preparation,'goodsRetainedByBranch':true,'cashCollected':false,'idempotencyKey':nonce});if(r['cancellationStatus']!='CANCELLED'&&r['kind']!='COD_CANCELLED')throw Exception('لم يتأكد الإلغاء');if(mounted)setState(()=>done=true);}
  catch(_){if(mounted)setState(()=>uncertain=true);}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('إلغاء من المطعم قبل الاستلام')),body:Directionality(textDirection:TextDirection.rtl,child:ListView(padding:const EdgeInsets.all(20),children:[Text('الطلب ${widget.order.orderNumber??widget.order.id}'),if(busy)const LinearProgressIndicator(),if(done)...[const Text('أكد الخادم إلغاء الطلب وسُجل السبب وحالة التجهيز. أي تعويض يحتاج مراجعة واعتمادًا مستقلًا؛ لا يعني الإلغاء صرفه.'),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('العودة للطلبات'))]else if(uncertain)const Text('لم تتأكد النتيجة. عد إلى الطلبات وحدّث الحالة قبل إعادة المحاولة.')else...[
 const Text('سجّل السبب والحالة الفعلية للتجهيز. هذا المسار متاح قبل استلام السائق فقط، مع بقاء جميع الأصناف لديكم وعدم تحصيل نقد من الزبون.'),
 TextField(controller:reason,maxLength:1000,minLines:2,maxLines:4,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'سبب الإلغاء')),
 DropdownButtonFormField<String>(initialValue:preparation,items:const[DropdownMenuItem(value:'NOT_STARTED',child:Text('لم يبدأ التجهيز')),DropdownMenuItem(value:'STARTED',child:Text('بدأ التجهيز')),DropdownMenuItem(value:'READY',child:Text('الأصناف جاهزة'))],onChanged:busy?null:(v)=>setState(()=>preparation=v??preparation)),
 CheckboxListTile(value:retained,onChanged:busy?null:(v)=>setState(()=>retained=v??false),title:const Text('جميع الأصناف باقية لدينا ولم يستلمها السائق')),
 CheckboxListTile(value:noCash,onChanged:busy?null:(v)=>setState(()=>noCash=v??false),title:const Text('لم يُحصّل أي نقد من الزبون')),
 FilledButton(onPressed:ready?submit:null,child:const Text('مراجعة الإلغاء'))
 ]])));
}
