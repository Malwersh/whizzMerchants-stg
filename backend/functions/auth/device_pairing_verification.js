'use strict';
const {InitiateAuthCommand,RespondToAuthChallengeCommand,GetUserCommand}=require('@aws-sdk/client-cognito-identity-provider');
const devices=require('./branch_devices');
const {GetCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const fail=(code,status=400)=>{throw Object.assign(Error(code),{status});};
async function route(ctx,event,input){
 const {identity,sub,cognito}=ctx;
 if(!['pairing_phone_info','pairing_phone_start','pairing_phone_confirm','create_pairing'].includes(input.action))return devices.management(ctx,event,input);
 // Resolve ownership before any SMS; never accept a destination from the client.
 await devices.management(ctx,{...event,httpMethod:'GET',queryStringParameters:{businessId:input.businessId}},{});
 if(input.action==='create_pairing')fail('PAIRING_PHONE_REQUIRED',403);
 const allowed=['action','businessId','name','session','code'];if(Object.keys(input).some(k=>!allowed.includes(k)))fail('INVALID_DEVICE_REQUEST');
 const attrs=Object.fromEntries((identity.user.UserAttributes||[]).map(a=>[a.Name,a.Value]));
 if(attrs.sub!==sub||attrs.phone_number_verified!=='true'||!attrs.phone_number)fail('PHONE_UNAVAILABLE',403);
 if(input.action==='pairing_phone_info')return {maskedPhone:attrs.phone_number.replace(/\d(?=\d{4})/g,'*')};
 if(typeof input.name!=='string'||!input.name.trim()||input.name.length>60)fail('INVALID_DEVICE_NAME');
 const Username=identity.user.Username;const ClientId=process.env.COGNITO_CLIENT_ID;
 if(input.action==='pairing_phone_start'){
  const key={pk:'PERSON#'+sub,sk:'DEVICE_PAIRING_RATE'},table='staging-MerchantPlatform',now=Math.floor(Date.now()/1000);
  const old=(await ctx.db.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true}))).Item;
  const starts=(old?.starts||[]).filter(t=>t>now-3600);
  if(starts.length>=5||starts.some(t=>t>now-60))fail('PHONE_CHANGE_RATE_LIMIT',429);
  try{await ctx.db.send(new TransactWriteCommand({TransactItems:[{ConditionCheck:{TableName:'staging-AccountDeletion',Key:{pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+sub,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}},{Put:{TableName:table,Item:{...key,starts:[...starts,now],version:(old?.version||0)+1},ConditionExpression:old?'#v=:v':'attribute_not_exists(pk)',...(old?{ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':old.version}}:{})}}]}));}catch(e){if(e.name==='TransactionCanceledException')fail('PHONE_CHANGE_RATE_LIMIT',429);throw e;}
  const r=await cognito.send(new InitiateAuthCommand({ClientId,AuthFlow:'CUSTOM_AUTH',AuthParameters:{USERNAME:Username}}));
  if(r.ChallengeName!=='CUSTOM_CHALLENGE'||!r.Session)fail('PHONE_CODE_SEND_FAILED');
  return {session:r.Session,maskedPhone:attrs.phone_number.replace(/\d(?=\d{4})/g,'*')};
 }
 if(typeof input.session!=='string'||input.session.length>4096||typeof input.code!=='string'||!/^\d{6}$/.test(input.code))fail('INVALID_CODE');
 const r=await cognito.send(new RespondToAuthChallengeCommand({ClientId,ChallengeName:'CUSTOM_CHALLENGE',Session:input.session,ChallengeResponses:{USERNAME:Username,ANSWER:input.code}}));
 if(!r.AuthenticationResult?.AccessToken)return {verified:false,session:r.Session||null};
 const user=await cognito.send(new GetUserCommand({AccessToken:r.AuthenticationResult.AccessToken}));
 const verified=Object.fromEntries((user.UserAttributes||[]).map(a=>[a.Name,a.Value]));
 if(verified.sub!==sub||verified.phone_number!==attrs.phone_number||verified.phone_number_verified!=='true')fail('PHONE_UNAVAILABLE',403);
 return devices.management({...ctx,identity:{...identity,claims:{...identity.claims,auth_time:Math.floor(Date.now()/1000)}}},event,{action:'create_pairing',businessId:input.businessId,name:input.name});
}
module.exports={route};
