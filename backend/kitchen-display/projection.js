'use strict';
const {GetCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {project}=require('./orders');
const TABLE='staging-MerchantPlatform';
// Stream records are hints only. Always project the latest canonical order.
async function syncOrder(db,orderId,businessId,table=process.env.ORDERS_TABLE){
 const key={PK:'ORDER#'+orderId,SK:'META'};
 const order=(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
 const item=order&&(order.businessId||order.storeId||order.merchantId)===businessId?project(order):null;
 const condition=order?{ConditionExpression:'#s=:s AND '+(order.rev===undefined?'attribute_not_exists(#r)':'#r=:r'),ExpressionAttributeNames:{'#s':'status','#r':'rev'},ExpressionAttributeValues:{':s':order.status,...(order.rev===undefined?{}:{':r':order.rev})}}:{ConditionExpression:'attribute_not_exists(PK)'};
 const target={pk:'BRANCH#'+businessId,sk:'KITCHEN_ORDER#'+orderId};
 try{await db.send(new TransactWriteCommand({TransactItems:[{ConditionCheck:{TableName:table,Key:key,...condition}},item?{Put:{TableName:TABLE,Item:{...target,orderId}}}:{Delete:{TableName:TABLE,Key:target}}]}));}
 catch(e){if(e.name==='TransactionCanceledException')throw Object.assign(Error('KITCHEN_PROJECTION_CHANGED'),{retryable:true});throw e;}
}
module.exports={syncOrder};
