import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/notification.dart';
import 'package:whizz_merchants/services/merchant_financial_notice_privacy.dart';
void main(){
 test('legacy financial inbox entries lose text, amounts and tokens but keep routing references',(){
 final row=NotificationModel(id:'event',title:'تم صرف 50000',body:'private reason',type:'open_wallet',businessId:'branch',createdAt:DateTime.utc(2026),data:{'type':'merchant_payout_updated','payoutId':'reference','amount':50000,'token':'secret','reason':'private','branchId':'branch','action':'open_wallet'});
 final safe=privateFinancialNotice(row);expect(safe.title,'تحديث على حساب المتجر');expect(safe.data.containsKey('amount'),false);expect(safe.data.containsKey('token'),false);expect(safe.data['payoutId'],'reference');expect(safe.businessId,'branch');expect(privateFinancialNotice(safe).toJson(),safe.toJson());
 });
 test('operational notification content remains intact',(){final row=NotificationModel(id:'order',title:'طلب جديد',body:'customer',type:'new_order',createdAt:DateTime.utc(2026),data:{'orderId':'one'});expect(identical(privateFinancialNotice(row),row),true);});
 test('case financial notice hides amounts and reasons without altering order notifications',(){final row=NotificationModel(id:'case',title:'private amount',body:'private reason',type:'merchant_exception_financial_updated',createdAt:DateTime.utc(2026),data:{'amount':7000,'reason':'private','action':'open_wallet'});final safe=privateFinancialNotice(row);expect(safe.title,'تحديث على حساب المتجر');expect(safe.data.containsKey('amount'),false);expect(safe.body.contains('private'),false);});
}
