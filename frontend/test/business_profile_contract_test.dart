import 'package:flutter_test/flutter_test.dart';
import 'package:whizz_merchants/models/business.dart';
void main(){
 test('creation detailed address survives the business reader',(){final b=Business.fromJson({'businessId':'b','address':{'fullAddress':'قرب السوق الكبير','country':'العراق','city':'النجف','district':'المناذرة','latitude':31.9,'longitude':44.4}});expect(b.address,'قرب السوق الكبير');expect(b.city,'النجف');expect(b.latitude,31.9);});
 test('legacy components remain readable without inventing activation',(){final b=Business.fromJson({'address':{'country':'العراق','city':'النجف'},'status':'approved'});expect(b.address,contains('النجف'));expect(b.isActive,isNull);expect(b.acceptingOrders,isNull);});
 test('review and operational flags are independently retained',(){final b=Business.fromJson({'status':'approved','isActive':false,'acceptingOrders':false,'businessTypeId':'CUSTOM','businessTypeLabelAr':'عطور'});final copy=Business.fromJson(b.toJson());expect(copy.status,'approved');expect(copy.isActive,false);expect(copy.acceptingOrders,false);expect(copy.businessTypeId,'CUSTOM');expect(copy.businessTypeLabelAr,'عطور');});
}
