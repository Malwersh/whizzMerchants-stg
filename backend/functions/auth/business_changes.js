'use strict';
const {GetCommand,QueryCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const domain=require('./business-change-review');
const TABLE='staging-MerchantPlatform',B='WhizzMerchants_Businesses';
const fail=(code,status=400)=>Object.assign(Error(code),{status});
function fences(sub,businessId){return ['ACCOUNT_LIFECYCLE#MERCHANT#'+sub,'BUSINESS_LIFECYCLE#MERCHANT#'+businessId].map(pk=>({ConditionCheck:{TableName:'staging-AccountDeletion',Key:{pk,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}}));}
async function route({db,sub},event,input){
 const get=async(table,key)=>(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
 const businessId=event.httpMethod==='GET'?event.queryStringParameters?.businessId:input.businessId;
 if(typeof businessId!=='string'||!businessId||businessId.length>150)throw fail('INVALID_BUSINESS_ID');
 const b=await get(B,{businessId});if(!b||b.ownerId!==sub||b.cognitoUserId!==sub)throw fail('BUSINESS_UNAVAILABLE',404);
 if(b.deletionRequestId)throw fail('BUSINESS_CLOSING',409);
 if(event.httpMethod==='GET'){
  const items=[];let cursor;do{const page=await db.send(new QueryCommand({TableName:TABLE,KeyConditionExpression:'pk=:pk AND begins_with(sk,:prefix)',ExpressionAttributeValues:{':pk':'PERSON#'+sub,':prefix':'CHANGE#'},ConsistentRead:true,ExclusiveStartKey:cursor}));for(const row of page.Items||[])if(row.businessId===businessId&&row.subjectId===sub)items.push(row);cursor=page.LastEvaluatedKey;}while(cursor);
  return {items:items.sort((a,b)=>b.createdAt.localeCompare(a.createdAt)),baseUpdatedAt:b.updatedAt??null};
 }
 if(event.httpMethod!=='POST'||Object.keys(input).some(k=>!['businessId','requestId','kind','proposed','reason','baseUpdatedAt'].includes(k)))throw fail('INVALID_CHANGE_REQUEST');
 const now=new Date().toISOString();let request;
 try{request=domain.propose({business:b,subjectId:sub,...input,now});}catch(e){throw fail(e.code||e.message);}
 request.pk='PERSON#'+sub;request.draftId=b.onboardingDraftId||null;request.regionId=b.regionId;
 const previous=await get(TABLE,{pk:request.pk,sk:request.sk});
 if(previous){if(previous.businessId!==businessId||previous.kind!==request.kind||JSON.stringify(previous.proposed)!==JSON.stringify(request.proposed)||previous.reason!==request.reason)throw fail('REQUEST_ID_CONFLICT',409);return {request:previous};}
 if(input.baseUpdatedAt!==(b.updatedAt??null))throw fail('CHANGE_BASE_CONFLICT',409);
 if(input.kind==='LOCATION')await require('./onboarding_regions').validate(db,input.proposed.regionPath,input.proposed.latitude,input.proposed.longitude);
 const queue={...request,pk:'REVIEW#MERCHANT',requestPk:request.pk};
 const guard={ConditionCheck:{TableName:B,Key:{businessId},ConditionExpression:'ownerId=:owner AND cognitoUserId=:owner AND attribute_not_exists(deletionRequestId) AND '+(b.updatedAt===undefined?'attribute_not_exists(updatedAt)':'updatedAt=:base'),ExpressionAttributeValues:{':owner':sub,...(b.updatedAt===undefined?{}:{':base':b.updatedAt})}}};
 try{await db.send(new TransactWriteCommand({TransactItems:[...fences(sub,businessId),guard,...[request,queue].map(Item=>({Put:{TableName:TABLE,Item,ConditionExpression:'attribute_not_exists(pk)'}}))]}));}catch(e){if(e.name==='TransactionCanceledException')throw fail('VERSION_OR_STATE_CONFLICT',409);throw e;}
 return {request};
}
module.exports={route,fences};
