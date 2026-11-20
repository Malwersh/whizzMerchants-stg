'use strict';

const {propose,accept,cancel,decline}=require('./ownership-transfer');

const tables=Object.freeze({
 staging:{platform:'staging-MerchantPlatform',branches:'WhizzMerchants_Businesses',deletion:'staging-AccountDeletion'},
 production:{platform:'wizz-production-MerchantPlatform',branches:'wizz-production-Merchants',deletion:'wizz-production-AccountDeletion'},
});
const fail=code=>{throw Object.assign(new Error(code),{code});};
const keyOf=organizationId=>({pk:'ORGANIZATION#'+organizationId,sk:'OWNERSHIP_TRANSFER'});
const terminal=new Set(['CANCELLED','COMPLETED','REJECTED']);

// The API supplies verified principals and the live scope from its repository.
function createTransferStore({db,GetCommand,QueryCommand,ScanCommand,TransactWriteCommand,environment,clock=Date.now}){
 if(!Object.hasOwn(tables,environment))fail('TRANSFER_ENVIRONMENT_NOT_CONFIGURED');
 const {platform:table,branches:branchTable,deletion}=tables[environment];

 async function read(organizationId){
  if(typeof organizationId!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(organizationId)){
   fail('INVALID_ORGANIZATION');
  }
  const {Item}=await db.send(new GetCommand({
   TableName:table,Key:keyOf(organizationId),ConsistentRead:true,
  }));
  return Item;
 }

 async function save(next,previous,branchUpdates=[]){
  const key=keyOf(next.organizationId);
  const values=previous?{
   ':requestId':previous.requestId,':version':previous.version,':status':previous.status,
  }:undefined;
  const put={
   TableName:table,Item:{...next,...key},
   ConditionExpression:previous
    ? 'requestId=:requestId AND #version=:version AND #status=:status'
    : 'attribute_not_exists(pk)',
  };
  if(values){
   put.ExpressionAttributeNames={'#version':'version','#status':'status'};
   put.ExpressionAttributeValues=values;
  }
  try{
   if(branchUpdates.length>99)fail('TRANSFER_SCOPE_EXCEEDS_TRANSACTION_LIMIT');
   await db.send(new TransactWriteCommand({TransactItems:[{Put:put},...branchUpdates]}));
  }catch(error){
   if(error.name==='ConditionalCheckFailedException'||(
    error.name==='TransactionCanceledException'&&
    error.CancellationReasons?.some(reason=>reason.Code==='ConditionalCheckFailed')
   ))fail('TRANSFER_STATE_CHANGED');
   throw error;
  }
  return next;
 }

 function accountConditions(ownerId,recipientId){
  return [ownerId,recipientId].flatMap(subjectId=>[
   {ConditionCheck:{TableName:deletion,Key:{pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+subjectId,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}},
   {ConditionCheck:{TableName:deletion,Key:{pk:'SUBJECT#MERCHANT#'+subjectId,sk:'ACTIVE#ACCOUNT#'+subjectId},ConditionExpression:'attribute_not_exists(pk)'}},
  ]);
 }

 async function start({actor,recipientId,requestId,organization,branches}){
  const now=clock();
  const next=propose({actor,recipientId,requestId,organization,branches,now});
  const previous=await read(next.organizationId);
  if(previous?.requestId===requestId){
   if(previous.ownerId!==next.ownerId||previous.recipientId!==recipientId||
      previous.digest!==next.digest)fail('TRANSFER_STATE_CHANGED');
   return previous;
  }
  if(previous&&!terminal.has(previous.status)&&previous.expiresAt>now)fail('TRANSFER_ALREADY_PENDING');
  const pause=branches.map(branch=>({Update:{
   TableName:branchTable,Key:{businessId:branch.businessId},
   UpdateExpression:'SET orderIntakeTransferRequestId=:request, orderIntakeTransferExpiresAt=:expires',
   ConditionExpression:'ownerId=:owner AND cognitoUserId=:owner AND organizationId=:org AND updatedAt=:updated AND attribute_not_exists(deletionRequestId) AND attribute_not_exists(orderIntakeDeletionRequestId) AND (attribute_not_exists(orderIntakeTransferExpiresAt) OR orderIntakeTransferExpiresAt<=:now)',
   ExpressionAttributeValues:{
    ':request':requestId,':expires':next.expiresAt,':owner':next.ownerId,':org':next.organizationId,':updated':branch.updatedAt,':now':now,
   },
  }}));
  const organizationCondition={ConditionCheck:{
   TableName:table,
   Key:{pk:'PERSON#'+next.ownerId,sk:'ORGANIZATION#'+next.organizationId},
   ConditionExpression:'subjectId=:owner AND organizationId=:org AND #v=:version',
   ExpressionAttributeNames:{'#v':'version'},
   ExpressionAttributeValues:{':owner':next.ownerId,':org':next.organizationId,':version':organization.version},
  }};
  const invitation={Put:{
   TableName:table,
   Item:{pk:'PERSON#'+next.recipientId,sk:'OWNERSHIP_INVITE#'+next.organizationId,
    organizationId:next.organizationId,requestId:next.requestId},
  }};
  return save(next,previous,[...pause,...accountConditions(next.ownerId,next.recipientId),invitation,organizationCondition]);
 }

 async function organizationForBranch({businessId,subjectId}){
  if(typeof businessId!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(businessId))fail('INVALID_BUSINESS');
  const {Item}=await db.send(new GetCommand({
   TableName:branchTable,Key:{businessId},ConsistentRead:true,
   ProjectionExpression:'businessId, organizationId, ownerId, cognitoUserId, deletionRequestId',
  }));
  if(!Item||Item.ownerId!==subjectId||Item.cognitoUserId!==subjectId||
     !Item.organizationId||Item.deletionRequestId)return null;
  return Item.organizationId;
 }

 async function forParticipant({organizationId,requestId,subjectId}){
  const row=await read(organizationId);
  if(!row||row.requestId!==requestId||![row.ownerId,row.recipientId].includes(subjectId)){
   return null;
  }
  const {pk,sk,...request}=row;
  return request;
 }

 async function activeForOwner({organizationId,subjectId}){
  const request=await read(organizationId);
  if(request?.ownerId!==subjectId||request.expiresAt<=clock()||
     !['AWAITING_RECIPIENT','AWAITING_REVIEW'].includes(request.status))return null;
  return request.requestId;
 }

 async function branchNames({organizationId,branchIds}){
  return Promise.all(branchIds.map(async businessId=>{
   const {Item}=await db.send(new GetCommand({
    TableName:branchTable,Key:{businessId},ConsistentRead:true,
    ProjectionExpression:'businessId,organizationId,businessName,#name,branchName',
    ExpressionAttributeNames:{'#name':'name'},
   }));
   if(Item?.organizationId!==organizationId)return null;
   return [Item.businessName,Item.name,Item.branchName]
    .find(value=>typeof value==='string'&&value.trim())?.trim()||null;
  }));
 }

 async function incoming(subjectId){
  const requests=[];
  let cursor;
  do{
   const page=await db.send(new QueryCommand({TableName:table,
    KeyConditionExpression:'pk=:person AND begins_with(sk,:prefix)',
    ExpressionAttributeValues:{':person':'PERSON#'+subjectId,':prefix':'OWNERSHIP_INVITE#'},
    ConsistentRead:true,ExclusiveStartKey:cursor,
   }));
   for(const invitation of page.Items||[]){
    const request=await forParticipant({...invitation,subjectId});
    if(request?.recipientId===subjectId&&request.expiresAt>clock()&&
       ['AWAITING_RECIPIENT','AWAITING_REVIEW'].includes(request.status))requests.push(request);
   }
   cursor=page.LastEvaluatedKey;
  }while(cursor);
  return requests;
 }

 async function startForOrganization({actor,recipientId,requestId,organizationId}){
  if(!actor||actor.reverified!==true||typeof actor.sub!=='string'||
     !/^[A-Za-z0-9_-]{1,128}$/.test(actor.sub)){
   fail('RECENT_VERIFICATION_REQUIRED');
  }
  if(typeof organizationId!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(organizationId)){
   fail('INVALID_ORGANIZATION');
  }
  const {Item:organization}=await db.send(new GetCommand({
   TableName:table,ConsistentRead:true,Key:{pk:'PERSON#'+actor.sub,sk:'ORGANIZATION#'+organizationId},
  }));
  if(!organization||organization.subjectId!==actor.sub||organization.organizationId!==organizationId){
   fail('ORGANIZATION_OWNERSHIP_CHANGED');
  }
  if(typeof ScanCommand!=='function')fail('TRANSFER_BRANCH_REPOSITORY_UNAVAILABLE');
  const branches=[];
  let cursor;
  for(let page=0;page<100;page++){
   const result=await db.send(new ScanCommand({
    TableName:branchTable,ConsistentRead:true,ExclusiveStartKey:cursor,
    FilterExpression:'organizationId=:organization',
    ExpressionAttributeValues:{':organization':organizationId},
    ProjectionExpression:'businessId, brandId, organizationId, ownerId, cognitoUserId, #status, updatedAt, deletionRequestId, lifecycleStatus',
    ExpressionAttributeNames:{'#status':'status'},
   }));
   branches.push(...(result.Items||[]));
   if(branches.length>93)fail('TRANSFER_SCOPE_EXCEEDS_TRANSACTION_LIMIT');
   cursor=result.LastEvaluatedKey;
   if(!cursor)return start({actor,recipientId,requestId,organization,branches});
  }
  fail('TRANSFER_BRANCH_INVENTORY_INCOMPLETE');
 }

 async function transition(action,{actor,organizationId,requestId,expectedDigest,agreementVersion}){
  const request=await read(organizationId);
  if(!request||request.requestId!==requestId)fail('TRANSFER_STATE_CHANGED');
  const {pk,sk,...current}=request;
  const next=action({request:current,actor,expectedDigest,agreementVersion,now:clock()});
  const resume=next.status!=='CANCELLED'?[]:current.branchIds.map(businessId=>({Update:{
   TableName:branchTable,Key:{businessId},
   UpdateExpression:'REMOVE orderIntakeTransferRequestId, orderIntakeTransferExpiresAt',
   ConditionExpression:'orderIntakeTransferRequestId=:request',
   ExpressionAttributeValues:{':request':requestId},
  }}));
  return save(next,request,next.status==='AWAITING_REVIEW'?accountConditions(next.ownerId,next.recipientId):resume);
 }

 return {
  organizationForBranch,
  forParticipant,
  activeForOwner,
  branchNames,
  incoming,
  startForOrganization,
  start,
  accept:input=>transition(accept,input),
  cancel:input=>transition(cancel,input),
  decline:input=>transition(decline,input),
 };
}

module.exports={createTransferStore};
