'use strict';
const {SignUpCommand}=require('@aws-sdk/client-cognito-identity-provider');
const {GetCommand,QueryCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {randomBytes,randomUUID}=require('node:crypto');
const TABLE='staging-MerchantPlatform';
const ACK_VERSION='personal-account-2026-10-14';
const ACK_TEXT='أوافق على إنشاء حساب شخصي بالهاتف لإدارة أنشطتي، وأفهم أن توثيق الرقم لا يعني اعتماد النشاط أو إثبات ملكيته.';
const fail=(code,status=400)=>Object.assign(Error(code),{status});
function phone(value){const p=String(value||'').replace(/[٠-٩]/g,c=>c.charCodeAt(0)-1632).replace(/[۰-۹]/g,c=>c.charCodeAt(0)-1776).replace(/[\s()-]/g,'');if(/^07\d{9}$/.test(p))return '+964'+p.slice(1);if(/^\+?9647\d{9}$/.test(p))return '+'+p.replace(/^\+/,'');throw fail('INVALID_PHONE');}
function registration(input){
 for(const k of Object.keys(input))if(!['firstName','lastName','phoneNumber','email','acknowledgementVersion'].includes(k))throw fail('UNKNOWN_FIELD');
 const text=v=>typeof v==='string'&&v.trim().length>0&&v.trim().length<=100;
 if(!text(input.firstName)||!text(input.lastName)||input.acknowledgementVersion!==ACK_VERSION)throw fail('PERSONAL_DETAILS_REQUIRED');
 const email=typeof input.email==='string'?input.email.trim().toLowerCase():'';if(email&&(email.length>254||!(/^[^\s@]+@[^\s@]+\.[^\s@]+$/).test(email)))throw fail('INVALID_EMAIL');
 return {firstName:input.firstName.trim(),lastName:input.lastName.trim(),phoneNumber:phone(input.phoneNumber),email};
}
async function route({db,cognito,authenticate},event){
 const method=event.httpMethod,path=event.path;let input={};try{input=JSON.parse(event.body||'{}');if(!input||Array.isArray(input)||typeof input!=='object')throw Error();}catch(_){throw fail('INVALID_JSON');}
 if(method==='GET'&&path==='/auth/person-registration')return {acknowledgementVersion:ACK_VERSION,acknowledgementText:ACK_TEXT};
 if(method==='POST'&&path==='/auth/person-registration'){
  const p=registration(input),attributes=[{Name:'phone_number',Value:p.phoneNumber},{Name:'given_name',Value:p.firstName},{Name:'family_name',Value:p.lastName},{Name:'name',Value:p.firstName+' '+p.lastName}];if(p.email)attributes.push({Name:'email',Value:p.email});
  try{await cognito.send(new SignUpCommand({ClientId:process.env.COGNITO_CLIENT_ID,Username:p.phoneNumber,Password:randomBytes(24).toString('base64')+'aA1!',UserAttributes:attributes}));}catch(e){if(e.name!=='UsernameExistsException')throw e;}
  // An existing identity is never edited or re-created by this public endpoint.
  return {success:true,nextStep:'PHONE_OTP'};
 }
 const identity=await authenticate(event),sub=identity.claims.sub;
 const key={pk:'PERSON#'+sub,sk:'PROFILE'};
 const lifecycle={pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+sub,sk:'META'};
 const marker=(await db.send(new GetCommand({TableName:'staging-AccountDeletion',Key:lifecycle,ConsistentRead:true}))).Item;if(marker)throw fail('ACCOUNT_CLOSING',403);
 if(['/auth/order-returns','/auth/order-cancellation'].includes(path))return require('./order_returns').route({db,sub},event,input);
 if(path==='/auth/branch-devices')return require('./device_pairing_verification').route({db,cognito,sub,identity},event,input);
 if(path==='/auth/branch-staff')return require('./branch_staff').route({db,sub,identity,phone},event,input);
 if(path==='/auth/business-changes')return require('./business_changes').route({db,sub},event,input);
 if(path==='/auth/branch-assets')return require('./onboarding_assets').route({db,sub},event,input);
 if(path.startsWith('/auth/branch-drafts'))return require('./onboarding_drafts').route({db,sub,phone},event,input);
 const current=(await db.send(new GetCommand({TableName:TABLE,Key:key,ConsistentRead:true}))).Item;
 if(method==='GET'&&path==='/auth/person-profile'){const c=(await db.send(new GetCommand({TableName:TABLE,Key:{pk:key.pk,sk:'CONTACT_CHANGE'},ConsistentRead:true}))).Item;return {profile:current||null,challenge:c&&!['DONE','FAILED'].includes(c.stage)?{requestId:c.requestId,scope:c.scope,businessId:c.businessId,stage:c.stage,expiresAt:c.expiresAt,maskedPhone:c.target.replace(/\d(?=\d{4})/g,'*')}:null};}
 if(method==='POST'&&path==='/auth/person-profile'&&input.action)return require('./person_profile_changes').route({db,cognito,sub,current,identity,phone,input});
 if(method==='POST'&&path==='/auth/person-profile'){
  if(Object.keys(input).some(k=>k!=='acknowledgementVersion')||input.acknowledgementVersion!==ACK_VERSION)throw fail('ACKNOWLEDGEMENT_REQUIRED');
  if(current)return {profile:current};
  const attrs=Object.fromEntries((identity.user.UserAttributes||[]).map(a=>[a.Name,a.Value]));
  const profile={...key,subjectId:sub,name:attrs.name||[attrs.given_name,attrs.family_name].filter(Boolean).join(' '),phoneNumber:phone(attrs.phone_number),...(attrs.email?{email:attrs.email}:{}),acknowledgementVersion:ACK_VERSION,acknowledgementText:ACK_TEXT,acknowledgedAt:new Date().toISOString(),createdAt:new Date().toISOString(),version:1};
  try{await db.send(new TransactWriteCommand({TransactItems:[{ConditionCheck:{TableName:'staging-AccountDeletion',Key:lifecycle,ConditionExpression:'attribute_not_exists(pk)'}},{Put:{TableName:TABLE,Item:profile,ConditionExpression:'attribute_not_exists(pk)'}}]}));}catch(e){if(e.name==='TransactionCanceledException')throw fail('VERSION_OR_STATE_CONFLICT',409);throw e;}
  return {profile};
 }
 throw fail('NOT_FOUND',404);
}
module.exports={route,registration,phone,TABLE,ACK_VERSION};
