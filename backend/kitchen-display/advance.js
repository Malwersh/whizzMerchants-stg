'use strict';
const {GetCommand}=require('@aws-sdk/lib-dynamodb');
const fail=(code,status)=>{throw Object.assign(Error(code),{status});};
async function prepare({db,service,token,input,table=process.env.ORDERS_TABLE}){
 if(!input||Object.keys(input).some(k=>!['action','orderId','target','revision'].includes(k))||input.action!=='advance'||!/^[-\w]{1,150}$/.test(input.orderId||'')||!['preparing','ready_for_pickup'].includes(input.target)||!(input.revision===null||Number.isSafeInteger(input.revision)&&input.revision>=0))fail('INVALID_KITCHEN_REQUEST',400);
 const access=await service.authorize(token,input.target);
 const order=(await db.send(new GetCommand({TableName:table,Key:{PK:'ORDER#'+input.orderId,SK:'META'},ConsistentRead:true}))).Item;
 if(!order||(order.businessId||order.storeId||order.merchantId)!==access.businessId)fail('ORDER_BUSINESS_SCOPE_INVALID',403);
 if((order.rev??null)!==input.revision)fail('ORDER_STATE_CONFLICT',409);
 if(!(input.target==='preparing'?['confirmed']:['preparing','in_kitchen']).includes(order.status)||order.merchantHandover?.state==='HANDED_TO_DRIVER'||order.exceptionCancellation?.state==='REQUESTED')fail('ORDER_STATE_CONFLICT',409);
 return {sub:'KITCHEN#'+access.row.screenId,ownerId:access.row.ownerId,businessId:access.businessId,deviceId:access.row.screenId,sessionId:access.row.screenId,actorName:access.screen.name,roleName:'شاشة المطبخ',deviceGuards:access.guards,kitchenOrder:true,deviceOrder:{id:input.orderId,expectedStatus:order.status,expectedRevision:input.revision,targetStatus:input.target==='preparing'?'preparing':'ready'}};
}
async function handle({db,event,original,context,scope}){
 if(process.env.KITCHEN_DISPLAY_ENABLED!=='true')fail('KITCHEN_NOT_ENABLED',503);
 if(event.httpMethod!=='POST')fail('INVALID_KITCHEN_REQUEST',400);
 let input;try{input=JSON.parse(event.body||'{}');}catch{fail('INVALID_KITCHEN_REQUEST',400);}
 const token=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /,'');
 const service=require('./pairing').createService({db}),actor=await prepare({db,service,token,input});
 const result=await scope.run(actor,()=>original({httpMethod:'PUT',path:'/merchant/order/'+input.orderId+'/status',pathParameters:{orderId:input.orderId},body:JSON.stringify({status:actor.deviceOrder.targetStatus})},context));
 // Canonical handler may contain customer/financial fields: never return them to TV.
 if(result.statusCode!==200)fail('ORDER_STATE_CONFLICT',409);
 return {success:true};
}
module.exports={prepare,handle};
