'use strict';
const {DynamoDBClient}=require('@aws-sdk/client-dynamodb');
const {DynamoDBDocumentClient,ScanCommand,GetCommand,QueryCommand,PutCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const {S3Client,ListObjectVersionsCommand,DeleteObjectsCommand}=require('@aws-sdk/client-s3');
const TABLE='staging-MerchantPlatform',BUCKET='staging-merchant-onboarding-699561669180';
async function sweep({db,s3,clock=()=>Date.now(),remaining=()=>300000}){
 const policy=(await db.send(new GetCommand({TableName:'staging-PlatformStaff',Key:{pk:'OPERATIONAL_SETTINGS#MERCHANT_ONBOARDING',sk:'CURRENT'},ConsistentRead:true}))).Item;
 const days=policy?.values?.orphanUploadDays;if(!Number.isSafeInteger(days)||days<1||days>35)throw Error('RETENTION_POLICY_UNAVAILABLE');
 const checkpoint={pk:'MAINTENANCE#ASSET_RETENTION',sk:'CURSOR'},saved=(await db.send(new GetCommand({TableName:TABLE,Key:checkpoint,ConsistentRead:true}))).Item;
 let cursor=saved?.cursor,deleted=0,checked=0;
 do{
  const page=await db.send(new ScanCommand({TableName:TABLE,ExclusiveStartKey:cursor,Limit:25,FilterExpression:'begins_with(sk,:prefix)',ExpressionAttributeValues:{':prefix':'ASSET#'}}));
  for(const candidate of page.Items||[]){
   checked++;const asset=(await db.send(new GetCommand({TableName:TABLE,Key:{pk:candidate.pk,sk:candidate.sk},ConsistentRead:true}))).Item;
   if(!asset||!['PENDING','READY','PURGING'].includes(asset.status)||!Number.isFinite(Date.parse(asset.createdAt))||Date.parse(asset.createdAt)>clock()-days*86400000||asset.legalHold||asset.retentionHold)continue;
   if(!/^[a-f0-9-]{36}$/i.test(asset.subjectId)||!asset.key?.startsWith('persons/'+asset.subjectId+'/drafts/'+asset.draftId+'/'))throw Error('ASSET_SCOPE_INVALID');
   const records=[];let next;do{const p=await db.send(new QueryCommand({TableName:TABLE,KeyConditionExpression:'pk=:pk',ExpressionAttributeValues:{':pk':asset.pk},ConsistentRead:true,ExclusiveStartKey:next}));records.push(...p.Items||[]);next=p.LastEvaluatedKey;}while(next);
   if(records.some(r=>(r.sk.startsWith('DRAFT#')||r.sk.startsWith('SUBMISSION#'))&&JSON.stringify(r).includes(asset.assetId)))continue;
   const draft=records.find(r=>r.sk==='DRAFT#'+asset.draftId),now=Math.floor(clock()/1000);
   const guards=[{ConditionCheck:{TableName:'staging-AccountDeletion',Key:{pk:'ACCOUNT_LIFECYCLE#MERCHANT#'+asset.subjectId,sk:'META'},ConditionExpression:'attribute_not_exists(pk)'}},{ConditionCheck:{TableName:'staging-AccountDeletion',Key:{pk:'ACCOUNT_OPERATION#MERCHANT#'+asset.subjectId,sk:'ONBOARDING_ASSET#'+asset.assetId},ConditionExpression:'attribute_not_exists(pk) OR expiresAt<:now',ExpressionAttributeValues:{':now':now}}},{ConditionCheck:{TableName:TABLE,Key:{pk:asset.pk,sk:'DRAFT#'+asset.draftId},ConditionExpression:draft?'#v=:v':'attribute_not_exists(pk)',...(draft?{ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':draft.version}}:{})}}];
   try{await db.send(new TransactWriteCommand({TransactItems:[...guards,{Put:{TableName:TABLE,Item:{...asset,status:'PURGING'},ConditionExpression:'#s=:s AND sha256=:sha AND (attribute_not_exists(legalHold) OR legalHold=:no) AND (attribute_not_exists(retentionHold) OR retentionHold=:no)',ExpressionAttributeNames:{'#s':'status'},ExpressionAttributeValues:{':s':asset.status,':sha':asset.sha256,':no':false}}}]}));}catch(e){if(e.name==='TransactionCanceledException')continue;throw e;}
   let keyMarker,versionMarker;do{const p=await s3.send(new ListObjectVersionsCommand({Bucket:BUCKET,ExpectedBucketOwner:'699561669180',Prefix:asset.key,KeyMarker:keyMarker,VersionIdMarker:versionMarker}));const objects=[...p.Versions||[],...p.DeleteMarkers||[]].filter(v=>v.Key===asset.key).map(v=>({Key:v.Key,VersionId:v.VersionId}));if(objects.length){const result=await s3.send(new DeleteObjectsCommand({Bucket:BUCKET,ExpectedBucketOwner:'699561669180',Delete:{Objects:objects,Quiet:true}}));if(result.Errors?.length)throw Error('ASSET_DELETE_RETRY_REQUIRED');}keyMarker=p.NextKeyMarker;versionMarker=p.NextVersionIdMarker;if(!p.IsTruncated)break;}while(keyMarker);
   await db.send(new TransactWriteCommand({TransactItems:[{Delete:{TableName:TABLE,Key:{pk:asset.pk,sk:asset.sk},ConditionExpression:'#s=:s AND sha256=:sha',ExpressionAttributeNames:{'#s':'status'},ExpressionAttributeValues:{':s':'PURGING',':sha':asset.sha256}}}]}));deleted++;
  }
  cursor=page.LastEvaluatedKey;
  await db.send(new PutCommand({TableName:TABLE,Item:{...checkpoint,cursor:cursor||null,updatedAt:new Date(clock()).toISOString()}}));
  if(!cursor||remaining()<15000)break;
 }while(cursor);
 return {checked,deleted,more:!!cursor};
}
exports.sweep=sweep;
exports.handler=async(_,context)=>{if(process.env.ENVIRONMENT!=='staging')throw Error('STAGING_ONLY');return sweep({db:DynamoDBDocumentClient.from(new DynamoDBClient({})),s3:new S3Client({}),remaining:()=>context.getRemainingTimeInMillis()});};
