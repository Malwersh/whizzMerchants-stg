'use strict';
const {AsyncLocalStorage}=require('node:async_hooks');
const {TransactWriteCommand,GetCommand,ScanCommand,PutCommand,DeleteCommand}=require('@aws-sdk/lib-dynamodb');
const {CognitoIdentityProviderClient,GetUserCommand,AdminGetUserCommand}=require('@aws-sdk/client-cognito-identity-provider');
const scope=new AsyncLocalStorage();
let publicKeys,keysUntil=0;
async function liveMerchantIdentity(cognito,token){
 let claims;try{claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url').toString());}catch(_){throw Error('UNAUTHORIZED');}
 if(claims.token_use==='access')return {user:await cognito.send(new GetUserCommand({AccessToken:token})),claims};
 const issuer='https://cognito-idp.us-east-1.amazonaws.com/us-east-1_gtCR3ndzT';
 if(claims.token_use!=='id'||claims.iss!==issuer||claims.aud!=='4qabvh11nmghmf9fmc6e6ludd2'||!Number.isFinite(claims.exp)||claims.exp<=Date.now()/1000)throw Error('UNAUTHORIZED');
 const parts=token.split('.');if(parts.length!==3)throw Error('UNAUTHORIZED');
 let header;try{header=JSON.parse(Buffer.from(parts[0],'base64url').toString());}catch(_){throw Error('UNAUTHORIZED');}
 if(header.alg!=='RS256'||typeof header.kid!=='string')throw Error('UNAUTHORIZED');
 if(!publicKeys||keysUntil<Date.now()){const response=await fetch(issuer+'/.well-known/jwks.json',{signal:AbortSignal.timeout(10000)});if(!response.ok)throw Error('AUTH_UNAVAILABLE');publicKeys=(await response.json()).keys;keysUntil=Date.now()+300000;}
 const key=publicKeys.find(k=>k.kid===header.kid&&k.kty==='RSA');if(!key)throw Error('UNAUTHORIZED');
 const crypto=require('node:crypto');if(!crypto.verify('RSA-SHA256',Buffer.from(parts[0]+'.'+parts[1]),crypto.createPublicKey({key,format:'jwk'}),Buffer.from(parts[2],'base64url')))throw Error('UNAUTHORIZED');
 const user=await cognito.send(new AdminGetUserCommand({UserPoolId:'us-east-1_gtCR3ndzT',Username:claims.sub}));if(!user.Enabled)throw Error('UNAUTHORIZED');return {user,claims};
}
function merchantLifecycleClient(raw){
 return {send:async command=>{
  const name=command.constructor.name;
  if(!['PutCommand','UpdateCommand','DeleteCommand','TransactWriteCommand'].includes(name))return raw.send(command);
  const actor=scope.getStore();
  if(!actor?.sub||!actor.businessId)throw Error('VERIFIED_MERCHANT_SCOPE_REQUIRED');
  // Legacy registration photos have no immutable subject in their S3 prefix.
  // Prevent another restaurant from adding a new reference during cleanup.
  const legacyPhoto=/https:\/\/order-receiver-business-photos-dev-1755170214\.s3\.amazonaws\.com\/business-photos\/registration\/[A-Za-z0-9_.-]+/g;
  const requestedPhotos=JSON.stringify(command.input).match(legacyPhoto)||[];
  if(requestedPhotos.length){
   const {Item:business}=await raw.send(new GetCommand({TableName:'WhizzMerchants_Businesses',Key:{businessId:actor.businessId},ConsistentRead:true}));
   for(const photo of requestedPhotos)if(!business||!['businessPhotoUrl','businessPhoto','logoUrl','photoUrl','imageUrl'].some(k=>business[k]===photo))throw Error('CROSS_BUSINESS_ASSET_REFERENCE');
  }
  const ownedPhoto=/https:\/\/wizz-merchants-staging-businessphotosbucket-up3j1qega8m5\.s3\.amazonaws\.com\/merchants\/([A-Za-z0-9_-]+)\/[A-Za-z0-9_-]+\/[A-Za-z0-9_.-]+/g;
  for(const match of JSON.stringify(command.input).matchAll(ownedPhoto)){
   if(match[1]===actor.businessId)continue;
   const globalProductId=command.input.Item?.globalProductId;
   if(!globalProductId)throw Error('CROSS_BUSINESS_ASSET_REFERENCE');
   const {Item:catalog}=await raw.send(new GetCommand({TableName:'WhizzMerchants_GlobalProducts',Key:{globalProductId},ConsistentRead:true}));
   if(!catalog||!JSON.stringify(catalog).includes(match[0]))throw Error('CROSS_BUSINESS_ASSET_REFERENCE');
  }
  let businessWrite=false;
  const fences=[
   {ConditionCheck:{TableName:'staging-AccountDeletion',Key:{pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+actor.sub,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}},
   {ConditionCheck:{TableName:'staging-AccountDeletion',Key:{pk:'BUSINESS_LIFECYCLE#MERCHANT#'+actor.businessId,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}},
   {ConditionCheck:{TableName:'WhizzMerchants_Businesses',Key:{businessId:actor.businessId},ConditionExpression:'ownerId = :sub AND cognitoUserId = :sub AND attribute_not_exists(deletionRequestId)',ExpressionAttributeValues:{':sub':actor.sub}}}
  ];
  const items=name==='TransactWriteCommand'?command.input.TransactItems:[{[name.slice(0,-7)]:{...command.input}}];
  for(const item of items){
   const operation=item.Put||item.Update||item.Delete||item.ConditionCheck;
   if(operation?.TableName==='WizzOrders'){
    const record=item.Put?.Item||(await raw.send(new GetCommand({TableName:operation.TableName,Key:operation.Key,ConsistentRead:true}))).Item;
    const field=record?.businessId?'businessId':record?.storeId?'storeId':record?.merchantId?'merchantId':null;
    if(!field||record[field]!==actor.businessId)throw Error('ORDER_BUSINESS_SCOPE_INVALID');
    if(!item.Put){
     operation.ConditionExpression=(operation.ConditionExpression?'('+operation.ConditionExpression+') AND ':'')+'#lifecycleOrderBusiness=:lifecycleOrderBusiness';
     operation.ExpressionAttributeNames={...operation.ExpressionAttributeNames,'#lifecycleOrderBusiness':field};
     operation.ExpressionAttributeValues={...operation.ExpressionAttributeValues,':lifecycleOrderBusiness':actor.businessId};
    }
   }
   if(operation?.TableName==='WhizzMerchants_Businesses'){
    if(businessWrite||item.Put||!operation.Key||operation.Key.businessId!==actor.businessId)throw Error('BUSINESS_WRITE_SCOPE_INVALID');
    businessWrite=true;
    operation.ConditionExpression=(operation.ConditionExpression?'('+operation.ConditionExpression+') AND ':'')+'#lifecycleOwner = :lifecycleSubject AND #lifecycleCognito = :lifecycleSubject AND attribute_not_exists(#lifecycleDeletion)';
    operation.ExpressionAttributeNames={...operation.ExpressionAttributeNames,'#lifecycleOwner':'ownerId','#lifecycleCognito':'cognitoUserId','#lifecycleDeletion':'deletionRequestId'};
    operation.ExpressionAttributeValues={...operation.ExpressionAttributeValues,':lifecycleSubject':actor.sub};
   }
  }
  if(name!=='TransactWriteCommand'){
   if(command.input.ReturnValues&&!['NONE','ALL_NEW'].includes(command.input.ReturnValues))throw Error('UNSUPPORTED_GUARDED_RETURN_VALUES');
   delete items[0][name.slice(0,-7)].ReturnValues;
  }
  const result=await raw.send(new TransactWriteCommand({TransactItems:[...(businessWrite?fences.slice(0,2):fences),...items]}));
  if(command.input.ReturnValues==='ALL_NEW'){
   const read=await raw.send(new GetCommand({TableName:command.input.TableName,Key:command.input.Key,ConsistentRead:true}));
   return {...result,Attributes:read.Item};
  }
  return result;
 }};
}
function merchantHandler(handler,{db,cognito=new CognitoIdentityProviderClient({region:'us-east-1'})}){
 return async(event,context)=>{
  if(event.httpMethod==='OPTIONS')return handler(event,context);
  const headers={'Content-Type':'application/json','Access-Control-Allow-Origin':'*'};
  try{
   const token=/^Bearer (\S+)$/.exec(event.headers?.Authorization||event.headers?.authorization||'')?.[1];
   if(!token)throw Error('UNAUTHORIZED');
   const {user,claims}=await liveMerchantIdentity(cognito,token);
   const sub=(user.UserAttributes||[]).find(a=>a.Name==='sub')?.Value;
   // GetUser authenticates before any claim is used as an authority.
   if(!sub||claims.sub!==sub||claims.iss!=='https://cognito-idp.us-east-1.amazonaws.com/us-east-1_gtCR3ndzT'||(claims.token_use==='access'?claims.client_id:claims.aud)!=='4qabvh11nmghmf9fmc6e6ludd2')throw Error('UNAUTHORIZED');
   let cursor,owned=[];
   do{
    const page=await db.send(new ScanCommand({TableName:'WhizzMerchants_Businesses',ExclusiveStartKey:cursor,ConsistentRead:true,FilterExpression:'ownerId = :sub OR cognitoUserId = :sub',ExpressionAttributeValues:{':sub':sub}}));
    owned.push(...page.Items||[]);cursor=page.LastEvaluatedKey;
   }while(cursor);
   let body={};try{body=JSON.parse(event.body||'{}');}catch(_){}
   const requested=event.pathParameters?.businessId||body.businessId;
   const business=requested?owned.find(b=>b.businessId===requested):(owned.length===1?owned[0]:null);
   if(!business||business.ownerId!==sub||business.cognitoUserId!==sub)throw Error('OWNER_REQUIRED');
   if(business.deletionRequestId)throw Error('ACCOUNT_CLOSING');
   return await scope.run({sub,businessId:business.businessId},()=>handler(event,context));
  }catch(e){
   const unauthorized=['UNAUTHORIZED','NotAuthorizedException','UserNotFoundException','InvalidParameterException'].includes(e.code||e.name)||e.message==='UNAUTHORIZED';
   const forbidden=['OWNER_REQUIRED','ACCOUNT_CLOSING'].includes(e.message);
   return {statusCode:unauthorized?401:forbidden?403:503,headers,body:JSON.stringify({code:unauthorized?'UNAUTHORIZED':forbidden?e.message:'AUTH_UNAVAILABLE',message:unauthorized?'يرجى تسجيل الدخول':forbidden?'لا يمكن تنفيذ العملية على هذا المطعم':'تعذر التحقق؛ أعد المحاولة'})};
  }
 };
}
async function beginMerchantUpload(raw){
 const actor=scope.getStore();if(!actor?.sub||!actor.businessId)throw Error('VERIFIED_MERCHANT_SCOPE_REQUIRED');
 const id=require('node:crypto').randomUUID(),key={pk:'ACCOUNT_OPERATION#MERCHANT#'+actor.sub,sk:'UPLOAD#'+id};
 await merchantLifecycleClient(raw).send(new PutCommand({TableName:'staging-AccountDeletion',Item:{...key,subjectId:actor.sub,businessId:actor.businessId,operationId:id,expiresAt:Math.floor(Date.now()/1000)+3600},ConditionExpression:'attribute_not_exists(pk)'}));
 return ()=>raw.send(new DeleteCommand({TableName:'staging-AccountDeletion',Key:key,ConditionExpression:'operationId=:id',ExpressionAttributeValues:{':id':id}}));
}
module.exports={liveMerchantIdentity,merchantRequestContext:scope,merchantLifecycleClient,merchantHandler,beginMerchantUpload};
