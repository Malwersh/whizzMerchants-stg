import '../models/notification.dart';

/// Inbox storage is never a source of financial detail or authority.
NotificationModel privateFinancialNotice(NotificationModel row){
 final financial=row.data['action']=='open_wallet'||row.type.contains('wallet')||row.type.contains('transfer')||row.type=='merchant_payout_updated'||row.type=='merchant_exception_financial_updated';
 if(!financial)return row;
 return row.copyWith(title:'تحديث على حساب المتجر',body:'افتح التفاصيل بعد التحقق المالي.',data:{for(final key in ['type','action','eventId','driverId','subjectId','businessId','branchId','payoutId'])if(row.data[key] is String)key:row.data[key]});
}
