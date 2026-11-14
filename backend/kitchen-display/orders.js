'use strict';
const {QueryCommand,GetCommand}=require('@aws-sdk/lib-dynamodb');
const statuses=['confirmed','in_kitchen','preparing','ready','ready_for_pickup','reassigning','assigned','heading_to_store','arrived_at_store'];
const unavailable=()=>{throw Object.assign(Error('KITCHEN_SNAPSHOT_INCOMPLETE'),{status:503});};
function project(order){
 if(!statuses.includes(order.status)||order.merchantHandover?.state==='HANDED_TO_DRIVER')return null;
 return {orderId:order.orderId||order.PK?.replace(/^ORDER#/,''),orderNumber:order.orderNumber||order.orderId,
  status:order.status,revision:Number.isSafeInteger(order.rev)?order.rev:null,createdAt:order.createdAt,updatedAt:order.updatedAt,
  cancellationRequested:order.exceptionCancellation?.state==='REQUESTED',
  items:(Array.isArray(order.items)?order.items:[]).map(item=>({name:item.name||item.dishName||item.productName,quantity:item.quantity,
   notes:item.notes||item.specialInstructions||'',
   options:(Array.isArray(item.modifiers)?item.modifiers:Array.isArray(item.selectedOptions)?item.selectedOptions:[]).map(option=>({name:option.name,quantity:option.quantity}))}))};
}
// Branch projection discovers keys with strong reads. Canonical rows are read
// again, so delayed stream updates cannot resurrect cancelled/handover orders.
async function snapshot({db,authorize,token,table=process.env.ORDERS_TABLE}){
 if(!table)unavailable();
 const access=await authorize(token,'read'),ids=new Set();
 const state=(await db.send(new GetCommand({TableName:'staging-MerchantPlatform',Key:{pk:'KITCHEN_INDEX_STATE',sk:'CURRENT'},ConsistentRead:true}))).Item;
 if(state?.status!=='READY')unavailable();
 let cursor;do{
  const result=await db.send(new QueryCommand({TableName:'staging-MerchantPlatform',KeyConditionExpression:'pk=:p AND begins_with(sk,:s)',ExpressionAttributeValues:{':p':'BRANCH#'+access.businessId,':s':'KITCHEN_ORDER#'},ConsistentRead:true,Limit:100,...(cursor?{ExclusiveStartKey:cursor}:{})}));
  for(const row of result.Items||[])if(typeof row.orderId==='string')ids.add('ORDER#'+row.orderId);
  if(ids.size>500)unavailable();cursor=result.LastEvaluatedKey;
 }while(cursor);
 const orders=[];
 // Bounded batches keep large kitchens from exhausting connections.
 const keys=[...ids];for(let start=0;start<keys.length;start+=20){
  const rows=await Promise.all(keys.slice(start,start+20).map(async PK=>(await db.send(new GetCommand({TableName:table,Key:{PK,SK:'META'},ConsistentRead:true}))).Item));
  for(const row of rows){if(!row||(row.storeId||row.businessId)!==access.businessId)continue;const safe=project(row);if(safe)orders.push(safe);}
 }
 // Revoke/owner changes during a slow snapshot must also prevent delivery.
 await authorize(token,'read');
 return {orders:orders.sort((a,b)=>String(a.createdAt).localeCompare(String(b.createdAt))),screen:access.screen,businessName:access.businessName};
}
module.exports={snapshot,project};
