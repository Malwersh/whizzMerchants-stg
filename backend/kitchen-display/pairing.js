'use strict';
const {GetCommand, QueryCommand, TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {randomUUID,randomInt,createHash,timingSafeEqual}=require('node:crypto');
const devices=require('../functions/auth/branch_devices');
const TABLE='staging-MerchantPlatform';
const fail=(code,status=400)=>{throw Object.assign(Error(code),{status});};
const hash=v=>createHash('sha256').update(v).digest('hex');
const equal=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
const publicScreen=r=>({screenId:r.screenId,name:r.name,mode:r.mode,status:r.status,version:r.version,expiresAt:r.expiresAt,createdAt:r.createdAt});
function createService({db,clock=()=>Math.floor(Date.now()/1000),uuid=randomUUID,code=()=>String(randomInt(0,100000000)).padStart(8,'0'),ownerAccess}={}){
 const get=async k=>(await db.send(new GetCommand({TableName:TABLE,Key:k,ConsistentRead:true}))).Item;
 const put=(r,old)=>({Put:{TableName:TABLE,Item:r,ConditionExpression:old?'#v=:v':'attribute_not_exists(pk)',...(old?{ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':old.version}}:{})}});
 const check=r=>({ConditionCheck:{TableName:TABLE,Key:{pk:r.pk,sk:r.sk},ConditionExpression:'#v=:v AND #s=:s AND expiresAt>:now',ExpressionAttributeNames:{'#v':'version','#s':'status'},ExpressionAttributeValues:{':v':r.version,':s':'ACTIVE',':now':clock()}}});
 const transact=async items=>{try{await db.send(new TransactWriteCommand({TransactItems:items}));}catch(e){if(e.name==='TransactionCanceledException')fail('KITCHEN_STATE_CHANGED',409);throw e;}};
 async function rate(key,limit,window){const k={pk:'KITCHEN_RATE#'+hash(key),sk:String(Math.floor(clock()/window))},old=await get(k);if((old?.count||0)>=limit)fail('KITCHEN_RATE_LIMIT',429);await transact([put({...k,count:(old?.count||0)+1,version:(old?.version||0)+1,expiresAt:clock()+window*2},old)]);}
 async function access(ctx,businessId){
  if(ownerAccess)return ownerAccess(ctx,businessId);
  // Reuse the authenticated owner's existing lifecycle/ownership checks.
  await devices.management(ctx,{httpMethod:'GET',queryStringParameters:{businessId}},{});
  const b=(await db.send(new GetCommand({TableName:'WhizzMerchants_Businesses',Key:{businessId},ConsistentRead:true}))).Item;
  if(!b||b.ownerId!==ctx.sub)fail('OWNER_REQUIRED',403);
  if(b.cognitoUserId!==b.ownerId||b.deletionRequestId||String(b.status).toLowerCase()!=='approved')fail('BUSINESS_UNAVAILABLE',409);
  return {businessId,ownerId:b.ownerId,businessName:b.businessName||b.name,guards:devices.guards(b)};
 }
 function fields(input,allowed){if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>!allowed.includes(k)))fail('INVALID_KITCHEN_REQUEST');}
 async function start(input,source){
  fields(input,['clientSecret']);
  if(typeof input.clientSecret!=='string'||!/^[-_A-Za-z0-9]{43}$/.test(input.clientSecret))fail('INVALID_KITCHEN_SECRET');
  if(typeof source!=='string'||!source)fail('KITCHEN_SOURCE_REQUIRED',503);
  await rate('start:'+source,5,60);await rate('start-hour:'+source,60,3600);
  const pairingCode=code(),screenId=uuid();
  const row={pk:'KITCHEN_PAIR#'+pairingCode,sk:'META',screenId,secretHash:hash(input.clientSecret),status:'PENDING',version:1,pairingExpiresAt:clock()+300,expiresAt:clock()+300};
  // No replacement of an existing live code; collision requires another start.
  await transact([put(row)]);
  return {pairingCode,screenId,expiresAt:row.pairingExpiresAt,pollAfterSeconds:3};
 }
 function parse(token){if(typeof token!=='string'||!/^\d{8}:[-_A-Za-z0-9]{43}$/.test(token))fail('KITCHEN_SESSION_REQUIRED',401);return token.split(':');}
 async function authenticate(token,{allowPending=false}={}){
  const [c,secret]=parse(token),row=await get({pk:'KITCHEN_PAIR#'+c,sk:'META'});
  if(!row||!equal(hash(secret),row.secretHash)||row.expiresAt<=clock())fail('KITCHEN_SESSION_EXPIRED',401);
  if(row.status==='PENDING'&&allowPending)return {row,status:'PENDING',expiresAt:row.pairingExpiresAt};
  if(row.status!=='ACTIVE')fail('KITCHEN_SESSION_REVOKED',401);
  return binding(row);
 }
 async function binding(row){
  if(!row||row.status!=='ACTIVE'||row.expiresAt<=clock())fail('KITCHEN_SESSION_REVOKED',401);
  const b=(await db.send(new GetCommand({TableName:'WhizzMerchants_Businesses',Key:{businessId:row.businessId},ConsistentRead:true}))).Item;
  if(!b||b.ownerId!==row.ownerId||b.cognitoUserId!==row.ownerId||b.deletionRequestId||String(b.status).toLowerCase()!=='approved')fail('KITCHEN_SESSION_REVOKED',401);
  for(const pk of ['BUSINESS_LIFECYCLE#MERCHANT#'+b.businessId,'ACCOUNT_LIFECYCLE#MERCHANT#'+b.ownerId])if((await db.send(new GetCommand({TableName:'staging-AccountDeletion',Key:{pk,sk:'META'},ConsistentRead:true}))).Item)fail('KITCHEN_SESSION_REVOKED',401);
  return {row,status:'ACTIVE',businessId:row.businessId,businessName:b.businessName||b.name,screen:publicScreen(row),guards:[...devices.guards(b),check(row)]};
 }
 async function management(ctx,input){
  fields(input,['action','businessId','pairingCode','name','mode','screenId','baseVersion']);
  if(typeof input.businessId!=='string'||!/^[-\w]{1,150}$/.test(input.businessId))fail('INVALID_BUSINESS_ID');
  const b=await access(ctx,input.businessId),pk='BRANCH#'+b.businessId;
  if(input.action==='list'){
   const result=[];let cursor;do{const r=await db.send(new QueryCommand({TableName:TABLE,KeyConditionExpression:'pk=:pk AND begins_with(sk,:sk)',ExpressionAttributeValues:{':pk':pk,':sk':'KITCHEN_SCREEN#'},ConsistentRead:true,Limit:100,...(cursor?{ExclusiveStartKey:cursor}:{})}));result.push(...(r.Items||[]).map(publicScreen));cursor=r.LastEvaluatedKey;if(result.length>100)fail('KITCHEN_SCREEN_LIMIT',409);}while(cursor);
   return {screens:result,...(process.env.KITCHEN_DISPLAY_URL?{displayUrl:process.env.KITCHEN_DISPLAY_URL}:{})};
  }
  const name=typeof input.name==='string'?input.name.trim():'';
  if(['approve','configure'].includes(input.action)&&(!name||name.length>60||!['display','interactive'].includes(input.mode)))fail('INVALID_KITCHEN_CONFIGURATION');
  if(input.action==='approve'){
   // The authenticated owner session is validated by the existing API route.
   await rate('approve:'+ctx.sub,10,60);
   if(typeof input.pairingCode!=='string'||!/^\d{8}$/.test(input.pairingCode))fail('INVALID_PAIRING_CODE');
   const old=await get({pk:'KITCHEN_PAIR#'+input.pairingCode,sk:'META'});
   if(!old||old.status!=='PENDING'||old.pairingExpiresAt<=clock())fail('KITCHEN_PAIRING_EXPIRED',409);
   const row={...old,businessId:b.businessId,ownerId:b.ownerId,name,mode:input.mode,status:'ACTIVE',version:old.version+1,expiresAt:clock()+30*86400,createdAt:new Date(clock()*1000).toISOString()};
   const screen={...row,pk,sk:'KITCHEN_SCREEN#'+old.screenId,pairKey:old.pk};delete screen.secretHash;
   await transact([...(b.guards||[]),put(row,old),put(screen),put({pk,sk:'DEVICE_AUDIT#'+uuid(),action:'KITCHEN_SCREEN_APPROVED',actorId:ctx.sub,screenId:row.screenId,mode:row.mode,createdAt:row.createdAt})]);
   return {screen:publicScreen(row)};
  }
  if(!['configure','revoke'].includes(input.action))fail('UNKNOWN_KITCHEN_ACTION');
  if(typeof input.screenId!=='string'||!Number.isInteger(input.baseVersion))fail('INVALID_KITCHEN_REQUEST');
  const screen=await get({pk,sk:'KITCHEN_SCREEN#'+input.screenId});
  if(!screen||screen.ownerId!==b.ownerId||screen.version!==input.baseVersion)fail('KITCHEN_STATE_CHANGED',409);
  const old=await get({pk:screen.pairKey,sk:'META'});
  if(!old||old.screenId!==screen.screenId||old.ownerId!==b.ownerId||old.businessId!==b.businessId||old.version!==screen.version||old.status!=='ACTIVE'||old.expiresAt<=clock())fail('KITCHEN_STATE_CHANGED',409);
  const patch=input.action==='revoke'?{status:'REVOKED'}:{name,mode:input.mode};
  const next={...old,...patch,version:old.version+1};
  await transact([...(b.guards||[]),put(next,old),put({...screen,...patch,version:next.version},screen),put({pk,sk:'DEVICE_AUDIT#'+uuid(),action:'KITCHEN_SCREEN_'+(input.action==='revoke'?'REVOKED':'CONFIGURED'),actorId:ctx.sub,screenId:old.screenId,createdAt:new Date(clock()*1000).toISOString()})]);
  return {screen:publicScreen(next)};
 }
 async function authorize(token,action){
  const access=await authenticate(token);
  if(!['read','preparing','ready_for_pickup'].includes(action))fail('KITCHEN_ACTION_FORBIDDEN',403);
  if(action!=='read'&&access.screen.mode!=='interactive')fail('KITCHEN_DISPLAY_ONLY',403);
  return access;
 }
 async function authenticateBinding(pairKey,screenId){
  if(typeof pairKey!=='string'||!/^KITCHEN_PAIR#\d{8}$/.test(pairKey))fail('KITCHEN_SESSION_REVOKED',401);
  const row=await get({pk:pairKey,sk:'META'});
  if(!row||row.screenId!==screenId)fail('KITCHEN_SESSION_REVOKED',401);
  return binding(row);
 }
 return {start,authenticate,authenticateBinding,authorize,management};
}
module.exports={createService};
