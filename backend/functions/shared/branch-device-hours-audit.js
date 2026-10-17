'use strict';
const {GetCommand}=require('@aws-sdk/lib-dynamodb');
const {randomUUID}=require('node:crypto');
const TABLE='WhizzMerchants_BusinessWorkingHours';
const DAYS=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
const fields=['opening','closing','isClosed'];
const view=(day,row)=>({weekday:day,...Object.fromEntries(fields.filter(k=>row?.[k]!==undefined).map(k=>[k,row[k]]))});
// The existing handler still builds the seven day writes. Guard and audit them
// as one schedule, without copying arbitrary persisted fields into the event.
async function prepare(raw,actor,items){
 const writes=items.filter(x=>(x.Put||x.Update||x.Delete||x.ConditionCheck)?.TableName===TABLE);
 if(!writes.length)return [];
 if(writes.length!==7||new Set(writes.map(x=>x.Put?.Item.weekday)).size!==7||writes.some(x=>!x.Put||x.Put.Item.businessId!==actor.businessId||!DAYS.includes(x.Put.Item.weekday)))throw Error('DEVICE_HOURS_WRITE_INVALID');
 for(const {Put:{Item:r}} of writes){
  const time=/^([01]?\d|2[0-3]):[0-5]\d$/;
  if(typeof r.isClosed!=='boolean'||(r.isClosed?r.opening!=='closed'||r.closing!=='closed':!time.test(r.opening)||!time.test(r.closing)))throw Error('DEVICE_HOURS_WRITE_INVALID');
 }
 const previous=await Promise.all(writes.map(async({Put})=>(await raw.send(new GetCommand({TableName:TABLE,Key:{businessId:actor.businessId,weekday:Put.Item.weekday},ConsistentRead:true}))).Item));
 const before=[],after=[];
 writes.forEach(({Put},i)=>{
  const row=previous[i],day=Put.Item.weekday;
  if(row&&(row.businessId!==actor.businessId||row.weekday!==day))throw Error('DEVICE_WRITE_SCOPE_INVALID');
  before.push(view(day,row));after.push(view(day,Put.Item));
  const names={},values={},conditions=[];
  for(const [index,field] of ['businessId','opening','closing','isClosed','updatedAt'].entries()){
   const alias='#hours'+index;names[alias]=field;
   if(row?.[field]===undefined)conditions.push('attribute_not_exists('+alias+')');
   else{values[':hours'+index]=row[field];conditions.push(alias+'=:hours'+index);}
  }
  Put.ConditionExpression=(Put.ConditionExpression?'('+Put.ConditionExpression+') AND ':'')+conditions.join(' AND ');
  Put.ExpressionAttributeNames={...Put.ExpressionAttributeNames,...names};
  if(Object.keys(values).length)Put.ExpressionAttributeValues={...Put.ExpressionAttributeValues,...values};
 });
 if(JSON.stringify(before)===JSON.stringify(after))return [];
 const now=new Date().toISOString(),id=randomUUID();
 return [{Put:{TableName:'staging-MerchantPlatform',Item:{pk:'BRANCH#'+actor.businessId,sk:'STAFF_AUDIT#OPERATIONS#'+now+'#'+id,ownerId:actor.ownerId,businessId:actor.businessId,actorId:actor.sub,actorName:actor.actorName||'',roleName:actor.roleName||'',deviceId:actor.deviceId,sessionId:actor.sessionId,permissionVersion:actor.permissionVersion,policyVersion:actor.policyVersion||0,action:'BRANCH_HOURS_CHANGED',entityId:actor.businessId,result:'SUCCEEDED',createdAt:now,before:{days:before},after:{days:after}},ConditionExpression:'attribute_not_exists(pk)'}}];
}
module.exports={prepare};
