'use strict';
const {GetCommand,QueryCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const TABLE='staging-MerchantPlatform';
const fail=(code,status=400)=>{throw Object.assign(Error(code),{status});};
function createRealtime({db,service,send,disconnect,clock=()=>Math.floor(Date.now()/1000)}){
 const get=async Key=>(await db.send(new GetCommand({TableName:TABLE,Key,ConsistentRead:true}))).Item;
 const remove=async row=>db.send(new TransactWriteCommand({TransactItems:[
  {Delete:{TableName:TABLE,Key:{pk:'KITCHEN_CONNECTION#'+row.connectionId,sk:'META'}}},
  {Delete:{TableName:TABLE,Key:{pk:'BRANCH#'+row.businessId,sk:'KITCHEN_CONNECTION#'+row.connectionId}}}
 ]}));
 async function authenticate(connectionId,input){
  if(!input||input.action!=='authenticate'||Object.keys(input).some(k=>!['action','token'].includes(k)))fail('INVALID_KITCHEN_REQUEST');
  const access=await service.authenticate(input.token),old=await get({pk:'KITCHEN_CONNECTION#'+connectionId,sk:'META'});
  if(old&&(old.screenId!==access.row.screenId||old.businessId!==access.businessId))fail('KITCHEN_CONNECTION_SCOPE',403);
  // Store no browser secret. Subsequent fanout revalidates this trusted binding.
  const row={pk:'KITCHEN_CONNECTION#'+connectionId,sk:'META',connectionId,businessId:access.businessId,screenId:access.row.screenId,pairKey:access.row.pk,expiresAt:clock()+120};
  await db.send(new TransactWriteCommand({TransactItems:[...access.guards,
   {Put:{TableName:TABLE,Item:row}},
   {Put:{TableName:TABLE,Item:{...row,pk:'BRANCH#'+row.businessId,sk:'KITCHEN_CONNECTION#'+connectionId}}}
  ]}));
  await send(connectionId,{type:old?'ALIVE':'READY'});
 }
 async function closed(connectionId){const row=await get({pk:'KITCHEN_CONNECTION#'+connectionId,sk:'META'});if(row)await remove(row);}
 async function notify(businessId){
  let cursor;do{
   const page=await db.send(new QueryCommand({TableName:TABLE,KeyConditionExpression:'pk=:p AND begins_with(sk,:s)',ExpressionAttributeValues:{':p':'BRANCH#'+businessId,':s':'KITCHEN_CONNECTION#'},ConsistentRead:true,Limit:100,...(cursor?{ExclusiveStartKey:cursor}:{})}));
   for(const row of page.Items||[]){
    let valid=false;
    if(row.expiresAt>clock())try{const a=await service.authenticateBinding(row.pairKey,row.screenId);valid=a.businessId===businessId;}catch(e){if(![401,403].includes(e.status))throw e;}
    if(!valid){await disconnect(row.connectionId);await remove(row);continue;}
    try{await send(row.connectionId,{type:'ORDERS_CHANGED'});}catch(e){if(e.statusCode===410||e.$metadata?.httpStatusCode===410)await remove(row);else throw e;}
   }
   cursor=page.LastEvaluatedKey;
  }while(cursor);
 }
 return {authenticate,closed,notify};
}
module.exports={createRealtime};
