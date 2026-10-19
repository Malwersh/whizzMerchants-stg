'use strict';
const {GetCommand}=require('@aws-sdk/lib-dynamodb');
async function acceptanceAck(db,order,actor,at){
 if(order.merchantResponsePolicy?.schemaVersion!==1)return null;
 const key={operationId:'MERCHANT_RESPONSE#'+order.orderId},row=(await db.send(new GetCommand({TableName:'staging-WalletLifecycle',Key:key,ConsistentRead:true}))).Item;
 if(!row||row.kind!=='MERCHANT_RESPONSE'||row.merchantResponseSchemaVersion!==1||row.orderId!==order.orderId||row.branchId!==actor.businessId||row.ownerId!==(actor.ownerId||actor.sub)||row.status!=='PENDING')throw Object.assign(Error('MERCHANT_RESPONSE_CONFLICT'),{status:409,code:'MERCHANT_RESPONSE_CONFLICT'});
 const names={},values={},conditions=[];
 Object.entries(row).forEach(([k,v],i)=>{names['#mq'+i]=k;values[':mq'+i]=v;conditions.push('#mq'+i+'=:mq'+i);});
 const fields={status:'DONE',result:'confirmed',responseMode:'MANUAL_ACCEPT',responseActorId:actor.sub,completedAt:at,queuePartition:'MERCHANT_RESPONSE_DONE',nextAttemptAt:0};
 const sets=Object.entries(fields).map(([k,v],i)=>{names['#mu'+i]=k;values[':mu'+i]=v;return '#mu'+i+'=:mu'+i;});
 return {Update:{TableName:'staging-WalletLifecycle',Key:key,ConditionExpression:conditions.join(' AND '),UpdateExpression:'SET '+sets.join(', '),ExpressionAttributeNames:names,ExpressionAttributeValues:values}};
}
module.exports={acceptanceAck};
