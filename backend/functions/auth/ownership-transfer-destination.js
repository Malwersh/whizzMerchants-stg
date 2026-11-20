'use strict';

const {createHmac,randomInt,randomUUID,timingSafeEqual}=require('node:crypto');
const {GetCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');

const TABLE='staging-MerchantPlatform';
const fail=(code,status=409)=>{throw Object.assign(new Error(code),{status});};

function createDestination({db,provider,clock=Date.now,Get=GetCommand,Write=TransactWriteCommand}){
 const get=async Key=>(await db.send(new Get({TableName:TABLE,Key,ConsistentRead:true}))).Item;
 return async function destination({request,subjectId,phone,action,challengeId,code}){
  const now=clock();
  if(request?.recipientId!==subjectId||request.status!=='AWAITING_REVIEW'||
     request.expiresAt<=now||!/^\+9647\d{9}$/.test(phone||'')){
   fail('TRANSFER_DESTINATION_RECIPIENT_REQUIRED',403);
  }
  const profile=await get({pk:'PERSON#'+subjectId,sk:'PROFILE'});
  if(profile?.subjectId!==subjectId||profile.phoneNumber!==phone||
     !Number.isSafeInteger(profile.version)||profile.version<1){
   fail('TRANSFER_RECIPIENT_PROFILE_REQUIRED');
  }
  const Key={pk:'ORGANIZATION#'+request.organizationId,sk:'OWNERSHIP_TRANSFER_DESTINATION#'+request.requestId};
  const existing=await get(Key);
  if(existing?.status==='VERIFIED'&&existing.profileVersion===profile.version&&
     existing.requestId===request.requestId&&existing.scopeDigest===request.digest&&
     existing.recipientId===subjectId&&existing.expiresAt>now){
   return {status:'VERIFIED',destination:'••••'+phone.slice(-4)};
  }
  const secret=await provider.secret();
  if(typeof secret!=='string'||!secret)fail('TRANSFER_DESTINATION_UNAVAILABLE',503);
  const signature=(id,value)=>createHmac('sha256',secret)
   .update(JSON.stringify(['merchant-ownership-destination',request.requestId,request.digest,subjectId,profile.version,id,value])).digest('hex');
  async function save(row){
   try{
    await db.send(new Write({TransactItems:[
     {ConditionCheck:{
      TableName:TABLE,Key:{pk:Key.pk,sk:'OWNERSHIP_TRANSFER'},
      ConditionExpression:'requestId=:request AND recipientId=:recipient AND digest=:digest AND #s=:review AND expiresAt>:now',
      ExpressionAttributeNames:{'#s':'status'},
      ExpressionAttributeValues:{':request':request.requestId,':recipient':subjectId,':digest':request.digest,':review':'AWAITING_REVIEW',':now':now},
     }},
     {ConditionCheck:{
      TableName:TABLE,Key:{pk:'PERSON#'+subjectId,sk:'PROFILE'},
      ConditionExpression:'subjectId=:recipient AND phoneNumber=:phone AND #v=:version',
      ExpressionAttributeNames:{'#v':'version'},
      ExpressionAttributeValues:{':recipient':subjectId,':phone':phone,':version':profile.version},
     }},
     {Put:{
      TableName:TABLE,Item:{...row,...Key},
      ConditionExpression:existing?'#v=:old':'attribute_not_exists(pk)',
      ...(existing?{ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':old':existing.version}}:{}),
     }},
    ]}));
   }catch(error){
    if(error.name==='TransactionCanceledException')fail('TRANSFER_STATE_CHANGED');
    throw error;
   }
  }
  if(action==='START_DESTINATION'){
   const withinHour=Number.isSafeInteger(existing?.windowStartedAt)&&existing.windowStartedAt>now-3600000;
   if(existing?.sentAt>now-60000||(withinHour&&existing.sendCount>=5))fail('TRANSFER_DESTINATION_RATE_LIMIT',429);
   const value=String(randomInt(1000000)).padStart(6,'0'),id=randomUUID();
   await save({
    kind:'OWNERSHIP_TRANSFER_DESTINATION',requestId:request.requestId,scopeDigest:request.digest,
    recipientId:subjectId,profileVersion:profile.version,challengeId:id,codeHash:signature(id,value),
    status:'CODE_SENT',attempts:0,version:(existing?.version??0)+1,sentAt:now,
    expiresAt:Math.min(now+300000,request.expiresAt),
    windowStartedAt:withinHour?existing.windowStartedAt:now,sendCount:withinHour?existing.sendCount+1:1,
   });
   await provider.send(phone,value);
   return {status:'CODE_SENT',challengeId:id,destination:'••••'+phone.slice(-4)};
  }
  if(action!=='VERIFY_DESTINATION'||existing?.status!=='CODE_SENT'||
     existing.recipientId!==subjectId||existing.scopeDigest!==request.digest||
     existing.profileVersion!==profile.version||existing.challengeId!==challengeId||
     existing.expiresAt<=now||!Number.isSafeInteger(existing.attempts)||existing.attempts>=5||
     typeof code!=='string'||!/^\d{6}$/.test(code)||!/^[a-f0-9]{64}$/.test(existing.codeHash||'')){
   fail('TRANSFER_DESTINATION_CODE_INVALID',400);
  }
  const matched=timingSafeEqual(Buffer.from(existing.codeHash,'hex'),Buffer.from(signature(challengeId,code),'hex'));
  const next={...existing,attempts:existing.attempts+1,version:existing.version+1};
  if(matched){
   delete next.codeHash;
   next.status='VERIFIED';next.verifiedAt=now;next.expiresAt=request.expiresAt;
  }
  await save(next);
  if(!matched)fail('TRANSFER_DESTINATION_CODE_INVALID',400);
  return {status:'VERIFIED',destination:'••••'+phone.slice(-4)};
 };
}

module.exports={createDestination};
