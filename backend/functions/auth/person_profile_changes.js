'use strict';
const {GetCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {AdminUpdateUserAttributesCommand,AdminGetUserCommand}=require('@aws-sdk/client-cognito-identity-provider');
const {randomUUID,randomInt,createHmac,timingSafeEqual}=require('node:crypto');
const TABLE='staging-MerchantPlatform',DELETION='staging-AccountDeletion',POOL='us-east-1_gtCR3ndzT';
const fail=(code,status=400)=>Object.assign(Error(code),{status});
const get=async(db,table,key)=>(await db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
const absent=(table,key)=>({ConditionCheck:{TableName:table,Key:key,ConditionExpression:'attribute_not_exists(pk)'}});
const owned=(b,sub)=>({ConditionCheck:{TableName:'WhizzMerchants_Businesses',Key:{businessId:b.businessId},ConditionExpression:'ownerId=:s AND cognitoUserId=:s AND attribute_not_exists(deletionRequestId) AND updatedAt=:u',ExpressionAttributeValues:{':s':sub,':u':b.updatedAt}}});
const put=(item,version)=>({Put:{TableName:TABLE,Item:item,ConditionExpression:version===undefined?'attribute_not_exists(pk)':'#v=:v',...(version===undefined?{}:{ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':version}})}});
async function write(db,items){try{await db.send(new TransactWriteCommand({TransactItems:items}));}catch(e){if(e.name==='TransactionCanceledException')throw fail('VERSION_OR_STATE_CONFLICT',409);throw e;}}
function publicChallenge(c){return {requestId:c.requestId,scope:c.scope,stage:c.stage,expiresAt:c.expiresAt,maskedPhone:c.target.replace(/\d(?=\d{4})/g,'*')};}
async function route({db,cognito,sub,current,identity,phone,input,provider}){
 const key={pk:'PERSON#'+sub,sk:'PROFILE'},fences=[absent(DELETION,{pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+sub,sk:'META'})];
 if(!current)throw fail('PERSON_PROFILE_REQUIRED',409);
 const now=new Date().toISOString(),attrs=Object.fromEntries((identity.user.UserAttributes||[]).map(a=>[a.Name,a.Value]));
 const challengeKey={pk:key.pk,sk:'CONTACT_CHANGE'};
 const existing=await get(db,TABLE,challengeKey);
 if(input.action==='update_details'){
  if(Object.keys(input).some(k=>!['action','name','email','baseVersion'].includes(k)))throw fail('UNKNOWN_FIELD');
  if(typeof input.name!=='string'||!input.name.trim()||input.name.trim().length>200)throw fail('PERSONAL_DETAILS_REQUIRED');
  if(typeof input.email!=='string'||(input.email&&(input.email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim()))))throw fail('INVALID_EMAIL');
  if(input.baseVersion!==current.version||existing?.stage==='APPLYING')throw fail('VERSION_OR_STATE_CONFLICT',409);
  const profile={...current,name:input.name.trim(),email:input.email.trim().toLowerCase(),version:current.version+1,updatedAt:now};
  const audit={pk:key.pk,sk:'PROFILE_AUDIT#'+randomUUID(),action:'UPDATE_DETAILS',subjectId:sub,fields:['name','email'],baseVersion:current.version,version:profile.version,createdAt:now};
  // The profile is the current display/contact source. Cognito remains the authentication source.
  await write(db,[...fences,put(profile,current.version),{ConditionCheck:{TableName:TABLE,Key:challengeKey,ConditionExpression:'attribute_not_exists(#stage) OR #stage <> :applying',ExpressionAttributeNames:{'#stage':'stage'},ExpressionAttributeValues:{':applying':'APPLYING'}}},put(audit)]);
  return {profile};
 }
 if(!['start_phone_change','verify_phone_change'].includes(input.action))throw fail('UNKNOWN_ACTION');
 if(Object.keys(input).some(k=>!['action','scope','newPhone','businessId','requestId','code'].includes(k)))throw fail('UNKNOWN_FIELD');
 provider=provider||require('./profile_otp_provider');
 const secret=await provider.secret();
 const digest=(id,stage,code)=>createHmac('sha256',secret).update('merchant-contact-change\0'+sub+'\0'+id+'\0'+stage+'\0'+code).digest('hex');
 const currentPhone=phone(attrs.phone_number);
 let business;
 const branch=async(id)=>{const b=await get(db,'WhizzMerchants_Businesses',{businessId:id});if(!b||b.ownerId!==sub||b.cognitoUserId!==sub||b.deletionRequestId)throw fail('BUSINESS_UNAVAILABLE',403);return b;};
 if(input.action==='start_phone_change'){
  if(!['PERSONAL','BRANCH'].includes(input.scope)||typeof input.requestId!=='string'||!/^[a-f0-9-]{36}$/.test(input.requestId))throw fail('INVALID_PHONE_CHANGE');
  if(input.scope==='PERSONAL'&&input.businessId)throw fail('INVALID_PHONE_CHANGE');
  const newPhone=phone(input.newPhone);
  if(existing?.requestId===input.requestId){if(existing.newPhone!==newPhone||existing.scope!==input.scope||existing.businessId!==(input.businessId||null))throw fail('REQUEST_ID_CONFLICT',409);if(existing.stage==='APPLYING')throw fail('PHONE_CHANGE_IN_PROGRESS',409);return {challenge:publicChallenge(existing)};}
  if(existing?.stage==='APPLYING'||existing?.lastSentAt>Date.now()-60000)throw fail('PHONE_CHANGE_RATE_LIMIT',429);
  if(existing?.rateWindow>Date.now()-3600000&&existing?.sendCount>=5)throw fail('PHONE_CHANGE_RATE_LIMIT',429);
  if(input.scope==='BRANCH')business=await branch(input.businessId);
  if(newPhone===(business?business.phoneNumber:currentPhone))throw fail('PHONE_UNCHANGED');
  const stage=input.scope==='PERSONAL'?'OLD_PHONE':'NEW_PHONE',code=String(randomInt(1000000)).padStart(6,'0');
  const c={...challengeKey,subjectId:sub,requestId:input.requestId,scope:input.scope,businessId:input.businessId||null,branchPhone:business?.phoneNumber||null,newPhone,oldPhone:currentPhone,target:stage==='OLD_PHONE'?currentPhone:newPhone,stage,attempts:0,expiresAt:Math.floor(Date.now()/1000)+300,lastSentAt:Date.now(),rateWindow:existing?.rateWindow>Date.now()-3600000?existing.rateWindow:Date.now(),sendCount:(existing?.rateWindow>Date.now()-3600000?existing.sendCount:0)+1,version:(existing?.version||0)+1};
  c.digest=digest(c.requestId,stage,code);
  await write(db,[...fences,...(business?[absent(DELETION,{pk:'BUSINESS_LIFECYCLE#MERCHANT#'+business.businessId,sk:'META'}),owned(business,sub)]:[]),put(c,existing?.version)]);
  await provider.send(c.target,code);
  return {challenge:publicChallenge(c)};
 }
 let c=existing;
 if(!c||input.requestId!==c.requestId)throw fail('PHONE_CHANGE_EXPIRED');
 if(c.stage==='DONE')return {success:true,profile:current,scope:c.scope,businessId:c.businessId};
 if(c.stage==='FAILED')throw fail('PHONE_CHANGE_FAILED');
 if(c.stage!=='APPLYING'){
  if(c.expiresAt<=Date.now()/1000||c.attempts>=5)throw fail('PHONE_CHANGE_EXPIRED');
  if(typeof input.code!=='string'||!/^\d{6}$/.test(input.code))throw fail('INVALID_CODE');
  const valid=timingSafeEqual(Buffer.from(c.digest,'hex'),Buffer.from(digest(c.requestId,c.stage,input.code),'hex'));
  const next={...c,attempts:c.attempts+1,version:c.version+1};
  if(!valid){await write(db,[...fences,put(next,c.version)]);throw fail('INVALID_CODE');}
  if(c.scope==='PERSONAL'&&c.oldPhone!==currentPhone)throw fail('PHONE_CHANGE_STALE',409);
  if(c.stage==='OLD_PHONE'){
   const code=String(randomInt(1000000)).padStart(6,'0');next.stage='NEW_PHONE';next.target=c.newPhone;next.digest=digest(c.requestId,next.stage,code);next.attempts=0;next.expiresAt=Math.floor(Date.now()/1000)+300;
   await write(db,[...fences,put(next,c.version)]);await provider.send(next.target,code);return {challenge:publicChallenge(next)};
  }
  next.stage='APPLYING';delete next.digest;
  await write(db,[...fences,put(next,c.version)]);c=next;
 }
 const done={...c,stage:'DONE',version:c.version+1,completedAt:now};
 const audit={pk:key.pk,sk:'PROFILE_AUDIT#'+c.requestId,action:'CHANGE_'+c.scope+'_PHONE',subjectId:sub,businessId:c.businessId,createdAt:now};
 if(c.scope==='BRANCH'){
  business=await branch(c.businessId);
  if((business.phoneNumber||null)!==c.branchPhone)throw fail('PHONE_CHANGE_STALE',409);
  await write(db,[...fences,absent(DELETION,{pk:'BUSINESS_LIFECYCLE#MERCHANT#'+business.businessId,sk:'META'}),{Update:{TableName:'WhizzMerchants_Businesses',Key:{businessId:c.businessId},UpdateExpression:'SET phoneNumber=:p, contactPhoneVerifiedAt=:t, updatedAt=:t',ConditionExpression:'ownerId=:s AND cognitoUserId=:s AND attribute_not_exists(deletionRequestId) AND updatedAt=:u',ExpressionAttributeValues:{':p':c.newPhone,':t':now,':s':sub,':u':business.updatedAt}}},put(done,c.version),put(audit)]);
  return {success:true,scope:c.scope,businessId:c.businessId};
 }
 // Recover a provider timeout by reading the live attribute; never create or transfer an identity.
 const user=await cognito.send(new AdminGetUserCommand({UserPoolId:POOL,Username:sub}));
 if(user.Enabled===false)throw fail('ACCOUNT_CLOSING',403);
 const live=Object.fromEntries((user.UserAttributes||[]).map(a=>[a.Name,a.Value]));
 if(live.phone_number!==c.newPhone){
  if(live.phone_number!==c.oldPhone)throw fail('PHONE_CHANGE_STALE',409);
  try{await cognito.send(new AdminUpdateUserAttributesCommand({UserPoolId:POOL,Username:sub,UserAttributes:[{Name:'phone_number',Value:c.newPhone},{Name:'phone_number_verified',Value:'true'}]}));}
  catch(e){if(e.name==='AliasExistsException'){await write(db,[...fences,put({...done,stage:'FAILED'},c.version)]);throw fail('PHONE_UNAVAILABLE',409);}throw e;}
 }
 const profile={...current,phoneNumber:c.newPhone,phoneVerifiedAt:now,version:current.version+1,updatedAt:now};
 await write(db,[...fences,put(profile,current.version),put(done,c.version),put(audit)]);
 return {success:true,scope:c.scope,profile};
}
module.exports={route};
