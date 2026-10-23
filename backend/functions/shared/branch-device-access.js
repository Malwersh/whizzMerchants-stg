'use strict';
const {GetCommand}=require('@aws-sdk/lib-dynamodb');
const devices=require('../auth/branch_devices');
const {permissions}=require('../../merchant-platform/domain');
const fail=(code,status=403)=>{throw Object.assign(Error(code),{status});};
async function orders(db,event){
 const token=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /,''),access=await devices.reception(db,token),{b,d}=access;
 const hasStaff=!!(event.headers?.['X-Staff-Session']||event.headers?.['x-staff-session']);
 const staff=hasStaff?await devices.employeeAccess(db,event,access):null,s=staff?.s,m=staff?.m;
 const method=event.httpMethod,path=event.path||'';let body={};try{body=JSON.parse(event.body||'{}');}catch(_){fail('INVALID_JSON',400);}
 const read=method==='GET'&&path==='/branch-device/merchant/orders/'+b.businessId;
 const match=/^\/branch-device\/merchant\/order\/([^/]+)\/(confirm|reject|status)$/.exec(path);
 if(!read&&!(method==='PUT'&&match))fail('PERMISSION_REQUIRED');
 if(!staff&&!read)fail('SESSION_REVOKED',401);
 const granted=staff?.authorization?.permissions||(staff?permissions(m):[]);
 const required=read?'orders.read':match?.[2]==='confirm'?'orders.accept':match?.[2]==='reject'?'orders.reject':body.status==='preparing'?'orders.prepare':body.status==='ready'?'orders.ready':null;
 if(staff&&!granted.includes(staff.authorization?required:read?'orders.read':'orders.manage'))fail('PERMISSION_REQUIRED');
 if(body.businessId&&body.businessId!==b.businessId)fail('BRANCH_SCOPE_REQUIRED');
 const common=[...devices.guards(b),devices.check(d),...(staff?.common||[])];
 let order,expectedStatus,targetStatus;
 if(match){
  if(Object.keys(body).some(k=>!['businessId','status','estimatedPreparationTime','reason','notes','requestId'].includes(k)))fail('INVALID_ORDER_ACTION',400);
  if(body.estimatedPreparationTime!==undefined&&(!Number.isSafeInteger(body.estimatedPreparationTime)||body.estimatedPreparationTime<1||body.estimatedPreparationTime>180))fail('INVALID_PREPARATION_TIME',400);
  for(const k of ['reason','notes'])if(body[k]!==undefined&&(typeof body[k]!=='string'||body[k].length>500))fail('INVALID_ORDER_ACTION',400);
  order=(await db.send(new GetCommand({TableName:process.env.ORDERS_TABLE||'WizzOrders',Key:{PK:'ORDER#'+match[1],SK:'META'},ConsistentRead:true}))).Item;
  if(!order||(order.businessId||order.storeId||order.merchantId)!==b.businessId)fail('ORDER_BUSINESS_SCOPE_INVALID');
  const target=match[2]==='confirm'?'confirmed':match[2]==='reject'?'rejected':body.status;
  const allowed={confirmed:['pending'],rejected:['pending'],preparing:['confirmed'],ready:['preparing','in_kitchen']};
  if(!allowed[target]?.includes(order.status))fail('ORDER_STATE_CONFLICT',409);
  expectedStatus=order.status;targetStatus=target;
 }
 // Prove access before reads and repeat the canonical fences in every write.
 await devices.tx(db,common);
 return {sub:s?.subjectId||b.ownerId,receptionOnly:!staff,ownerId:b.ownerId,businessId:b.businessId,deviceId:d.deviceId,sessionId:s?.sessionId,actorName:m?.displayName||'',roleName:m?.grant?.roleNameAr||m?.role||'',permissionVersion:m?.version,policyVersion:staff?.authorization?.policy.version||0,deviceGuards:common,deviceOrder:order?{id:match[1],expectedStatus,targetStatus}:null};
}
function projectOrders(result,actor){
 if(result.statusCode!==200)return result;
 const data=JSON.parse(result.body);
 if(Array.isArray(data.orders))data.orders=data.orders.filter(o=>(o.businessId||o.storeId||o.merchantId)===actor.businessId).map(o=>{
  const fields=actor.receptionOnly?['orderId','id','status','createdAt']:['orderId','id','orderNumber','status','createdAt','merchantAcceptanceDeadlineAt','items','totalAmount','deliveryFee','paymentMethod','estimatedPreparationTime','estimatedReadyAt','notes','deliveryInstructions','driverName','driverPhone'];
  return Object.fromEntries(fields.filter(k=>o[k]!==undefined).map(k=>[k,o[k]]));
 });
 return {...result,body:JSON.stringify(data)};
}
async function operations(db,event,kind){
 const token=(event.headers?.Authorization||event.headers?.authorization||'').replace(/^Bearer /,''),access=await devices.reception(db,token),{b,d}=access;
 const staff=await devices.employeeAccess(db,event,access),{s,m}=staff;
 const method=event.httpMethod,path=event.path||'',read=method==='GET';
 let permission;
 if(kind==='menu' && /^\/branch-device\/products(?:\/[\w-]+)?$/.test(path)&&['GET','PUT','POST','DELETE'].includes(method))permission=read?'menu.read':'menu.write';
 if(kind==='menu'&&path==='/branch-device/categories'&&read)permission='menu.read';
 if(kind==='hours'&&path==='/branch-device/businesses/'+b.businessId+'/working-hours'&&['GET','PUT'].includes(method))permission=read?'branch.read':'branch.hours.write';
 if(!permission)fail('PERMISSION_REQUIRED');
 const granted=staff.authorization?.permissions||permissions(m);
 if(!staff.authorization&&!granted.includes(permission))fail('PERMISSION_REQUIRED');
 if(event.pathParameters?.businessId&&event.pathParameters.businessId!==b.businessId)fail('BRANCH_SCOPE_REQUIRED');
 let body={};try{body=JSON.parse(event.body||'{}');}catch(_){fail('INVALID_JSON',400);}
 if(body.businessId&&body.businessId!==b.businessId)fail('BRANCH_SCOPE_REQUIRED');
 if(kind==='menu'&&['POST','DELETE'].includes(method)&&!staff.authorization)fail('PERMISSION_REQUIRED');
 if(kind==='menu'&&(method==='POST'&&path!=='/branch-device/products'||method==='DELETE'&&(!/^\/branch-device\/products\/[\w-]+$/.test(path)||!event.pathParameters?.productId)))fail('PERMISSION_REQUIRED');
 if(staff.authorization){const required=kind==='hours'?[read?'hours.read':'hours.write']:read?['menu.read']:method==='POST'?['menu.create']:method==='DELETE'?['menu.delete']:[...(body.name!==undefined||body.description!==undefined?['menu.edit']:[]),...(body.price!==undefined?['menu.price.write']:[]),...(body.isAvailable!==undefined?['menu.availability.write']:[])];if(!required.length||required.some(p=>!granted.includes(p)))fail('PERMISSION_REQUIRED');}
 if(kind==='menu'&&method==='PUT'){
  if(Object.keys(body).some(k=>!['businessId','requestId','name','price','isAvailable','description'].includes(k)))fail('INVALID_MENU_UPDATE',400);
  if(body.price!==undefined&&(!Number.isSafeInteger(body.price)||body.price<=0||body.price>1000000000))fail('INVALID_PRICE',400);
  if(body.isAvailable!==undefined&&typeof body.isAvailable!=='boolean')fail('INVALID_MENU_UPDATE',400);
  for(const [k,max] of [['name',150],['description',2000]])if(body[k]!==undefined&&(typeof body[k]!=='string'||body[k].length>max||k==='name'&&!body[k].trim()))fail('INVALID_MENU_UPDATE',400);
 }
 const common=[...devices.guards(b),devices.check(d),...staff.common];await devices.tx(db,common);
 return {sub:s.subjectId,ownerId:b.ownerId,businessId:b.businessId,deviceId:d.deviceId,sessionId:s.sessionId,actorName:m.displayName||'',roleName:m.grant?.roleNameAr||m.role,permissionVersion:m.version,policyVersion:staff.authorization?.policy.version||0,deviceGuards:common};
}
module.exports={orders,operations,projectOrders};
