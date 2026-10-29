import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../lib/models/order.dart';
import '../lib/services/order_service.dart';
import '../lib/providers/order_providers.dart';
class Orders extends OrderService {
 final replies=<Completer<List<Order>>>[];
 @override Future<List<Order>> getMerchantOrders(String? businessId,{String? status}){final c=Completer<List<Order>>();replies.add(c);return c.future;}
}
Order order(String id,String branch)=>Order.fromJson({'orderId':id,'businessId':branch,'status':'pending','items':[]});
void main(){
 test('scoped order notifier rejects another branch before requesting',()async{final api=Orders();final n=OrdersNotifier(businessId:'a',orderService:api);await n.loadOrders('b');expect(n.state,isEmpty);expect(api.replies,isEmpty);n.dispose();});
 test('newer order request wins and foreign rows are excluded',()async{final api=Orders(),n=OrdersNotifier(businessId:'a',orderService:api);final first=n.loadOrders('a'),second=n.loadOrders('a');api.replies[1].complete([order('new','a'),order('foreign','b')]);await second;api.replies[0].complete([order('old','a')]);await first;expect(n.state.map((o)=>o.id),['new']);n.dispose();});
 test('late order response cannot update a disposed branch or repopulate a cleared list',()async{for(final dispose in [true,false]){final api=Orders(),n=OrdersNotifier(businessId:'a',orderService:api);final pending=n.loadOrders('a');if(dispose){n.dispose();}else{n.clearOrders();}api.replies.single.complete([order('old','a')]);await pending;if(!dispose){expect(n.state,isEmpty);n.dispose();}}});
}
