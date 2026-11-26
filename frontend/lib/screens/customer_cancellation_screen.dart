import 'package:flutter/material.dart';
import '../services/order_returns_service.dart';
class CustomerCancellationScreen extends StatefulWidget {
 final Map<String,dynamic> selectors;
 final OrderReturnsService? service;
 const CustomerCancellationScreen({super.key,required this.selectors,this.service});
 @override State<CustomerCancellationScreen> createState()=>_CustomerCancellationScreenState();
}
class _CustomerCancellationScreenState extends State<CustomerCancellationScreen>{
 Map<String,dynamic>? data;
 bool busy=false,noPreparation=false,retained=false;
 String preparation='STARTED';
 final note=TextEditingController();
 String? error;
 @override void initState(){super.initState();load();}
 @override void dispose(){note.dispose();super.dispose();}
 Future<void> load()async{if(busy)return;setState((){busy=true;error=null;noPreparation=false;retained=false;});try{final r=await(widget.service??OrderReturnsService()).call(widget.selectors,cancel:true);if(mounted)setState((){data=r;preparation=r['preparationState']??'STARTED';});}catch(_){if(mounted)setState(()=>error='تعذر تحميل طلب الإلغاء؛ أعد التحديث.');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> confirm()async{if(busy||!noPreparation||data?['canConfirmNoPreparation']!=true)return;setState(()=>busy=true);try{final r=await(widget.service??OrderReturnsService()).call(widget.selectors,cancel:true,receipt:{'requestId':data!['cancellationRequestId'],'expectedVersion':data!['version'],'preparationNotStarted':true});if(mounted)setState(()=>data=r);}catch(_){if(mounted)setState((){data=null;error='لم يتأكد الإلغاء. حدّث الحالة قبل إعادة المحاولة؛ إذا بدأ التجهيز تُراجع الحالة مع الإدارة.';});}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> recordRetention()async{
  if(busy||!retained||note.text.trim().length<3||data?['cancellationStatus']!='REQUESTED')return;
  setState(()=>busy=true);
  try{final api=widget.service??OrderReturnsService();await api.call(widget.selectors,cancel:true,receipt:{'requestId':data!['cancellationRequestId'],'expectedVersion':data!['version'],'goodsRetainedByBranch':true,'preparationState':preparation,'note':note.text.trim()});
   final r=await api.call(widget.selectors,cancel:true);if(mounted)setState((){data=r;retained=false;});
  }catch(_){if(mounted)setState((){data=null;error='تعذر تأكيد تسجيل الإثبات. حدّث الحالة قبل إعادة المحاولة.';});}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('طلب إلغاء من الزبون'),actions:[IconButton(onPressed:busy?null:load,icon:const Icon(Icons.refresh))]),body:Directionality(textDirection:TextDirection.rtl,child:ListView(padding:const EdgeInsets.all(20),children:[
 if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
 if(data!=null)...[Text('مرجع القضية: ${data!['caseId']??''}'),if(data!['reason']!=null)Text('سبب الطلب: ${data!['reason']}'),Text(data!['message']??''),
 if(data!['merchantRetentionProof']!=null)const Text('سُجل إثبات بقاء الأصناف لدى المطعم. لا يعني تسجيله اعتماد تعويض أو صرفه.'),
 if(data!['canConfirmNoPreparation']==true)...[const Text('أكد فقط إذا لم يبدأ تجهيز أي صنف. الإلغاء يلغي الطلب دون رسوم على الزبون، ولا يُنشئ تعويضًا عن طعام غير مُجهز.'),CheckboxListTile(value:noPreparation,onChanged:busy?null:(v)=>setState(()=>noPreparation=v??false),title:const Text('لم نبدأ تجهيز أي صنف ولم نسلم أصنافًا للسائق')),FilledButton(onPressed:busy||!noPreparation?null:confirm,child:const Text('تأكيد عدم التجهيز وإلغاء الطلب'))]
 else if(data!['cancellationStatus']=='REQUESTED')...[
 const Text('يحتاج الإلغاء إلى مراجعة الإدارة. إذا بقيت الأصناف لديكم، سجّل حالتها الفعلية. لا تسجّل هذا الإثبات بعد تسليمها للسائق.'),
 DropdownButtonFormField<String>(initialValue:preparation,items:const[DropdownMenuItem(value:'NOT_STARTED',child:Text('لم يبدأ التجهيز')),DropdownMenuItem(value:'STARTED',child:Text('بدأ التجهيز')),DropdownMenuItem(value:'READY',child:Text('الأصناف جاهزة'))],onChanged:busy?null:(v)=>setState(()=>preparation=v??'STARTED')),
 TextField(controller:note,maxLength:1000,maxLines:3,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'توضيح حالة الأصناف والتجهيز')),
 CheckboxListTile(value:retained,onChanged:busy?null:(v)=>setState(()=>retained=v??false),title:const Text('جميع الأصناف ما زالت لدينا ولم يستلمها السائق')),
 FilledButton(onPressed:busy||!retained||note.text.trim().length<3?null:recordRetention,child:const Text('تسجيل إثبات بقاء الأصناف للإدارة')),
 const Text('هذا إثبات للحيازة والتجهيز؛ لا يُلغى الطلب أو يُعتمد التعويض بمجرد تسجيله.')
 ]]
 ])));
}
