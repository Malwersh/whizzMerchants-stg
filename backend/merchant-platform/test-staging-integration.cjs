'use strict';
// Storage integration uses isolated synthetic identities. It never sends OTP or changes a real account.
const assert=require('node:assert/strict'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process'),path=require('node:path');
const root=path.resolve(__dirname,'..','functions','auth'),sdk=name=>require(root+'/node_modules/'+name);
const {DynamoDBClient}=sdk('@aws-sdk/client-dynamodb'),{DynamoDBDocumentClient,GetCommand,QueryCommand,ScanCommand,PutCommand,DeleteCommand}=sdk('@aws-sdk/lib-dynamodb'),{S3Client,PutObjectCommand,GetObjectCommand,ListObjectVersionsCommand,DeleteObjectsCommand}=sdk('@aws-sdk/client-s3'),{fromIni}=sdk('@aws-sdk/credential-provider-ini');
assert.equal(execFileSync('aws',['sts','get-caller-identity','--profile','Wizz_stg_UserApp','--query','Account','--output','text'],{encoding:'utf8'}).trim(),'699561669180');
const credentials=fromIni({profile:'Wizz_stg_UserApp'}),db=DynamoDBDocumentClient.from(new DynamoDBClient({region:'us-east-1',credentials}),{marshallOptions:{removeUndefinedValues:true}}),s3=new S3Client({region:'us-east-1',credentials});
const person=require(root+'/person_onboarding'),assets=require(root+'/onboarding_assets'),regions=require(root+'/onboarding_regions'),settings=require(root+'/onboarding_settings'),review=require(path.resolve(__dirname,'..','..','..','whizzCentralPlatform-stg/backend/staff-service/merchant-onboarding'));
const sub=crypto.randomUUID(),pk='PERSON#'+sub,table='staging-MerchantPlatform',bucket=assets.BUCKET,businessIds=[],draftIds=[],keys=[];
const event=(p,body,method='POST',queryStringParameters)=>({path:'/auth/'+p,httpMethod:method,body:JSON.stringify(body||{}),queryStringParameters});
const identity={claims:{sub},user:{UserAttributes:[{Name:'sub',Value:sub},{Name:'name',Value:'ISOLATED ONBOARDING FIXTURE'},{Name:'phone_number',Value:'+9647700000000'}]}};
const ctx={db,cognito:{send:async()=>{throw Error('Cognito writes and OTP are forbidden in this storage fixture');}},authenticate:async()=>identity};
const get=async(TableName,Key)=>(await db.send(new GetCommand({TableName,Key,ConsistentRead:true}))).Item;
async function query(TableName,partition){let all=[],cursor;do{const p=await db.send(new QueryCommand({TableName,KeyConditionExpression:'pk=:pk',ExpressionAttributeValues:{':pk':partition},ConsistentRead:true,ExclusiveStartKey:cursor}));all.push(...p.Items||[]);cursor=p.LastEvaluatedKey;}while(cursor);return all;}
async function businesses(){let all=[],cursor;do{const p=await db.send(new ScanCommand({TableName:'WhizzMerchants_Businesses',ConsistentRead:true,ExclusiveStartKey:cursor}));all.push(...p.Items||[]);cursor=p.LastEvaluatedKey;}while(cursor);return all;}
const canonical=v=>v===null||typeof v!=='object'?v:Array.isArray(v)?v.map(canonical):Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])]));
const digest=v=>crypto.createHash('sha256').update(JSON.stringify(canonical(v))).digest('hex');
async function versions(prefix){let all=[],k,v;do{const p=await s3.send(new ListObjectVersionsCommand({Bucket:bucket,ExpectedBucketOwner:'699561669180',Prefix:prefix,KeyMarker:k,VersionIdMarker:v}));all.push(...p.Versions||[],...p.DeleteMarkers||[]);k=p.NextKeyMarker;v=p.NextVersionIdMarker;if(!p.IsTruncated)break;}while(k);return all;}
const report={syntheticIdentity:true,realOtpSent:false,financialWrites:false};let before;
(async()=>{
 before=await businesses();
 const refs=(await regions.list(db)).items,byId=new Map(refs.map(r=>[r.id,r]));let selection,position;
 for(const leaf of refs.filter(r=>r.level===3)){
  const r2=byId.get(leaf.parentId),r1=byId.get(r2?.parentId),r0=byId.get(r1?.parentId);if(!r0)continue;
  const type=(await settings.readSettings(db,{regionId:leaf.id})).types[0];if(!type)continue;
  const base=await get(regions.BASE,{regionId:leaf.id}),g=base?.geometry;const ring=g?.type==='Polygon'?g.coordinates[0]:g?.type==='MultiPolygon'?g.coordinates[0][0]:null;if(!ring)continue;
  const xs=ring.map(p=>Number(p[0])),ys=ring.map(p=>Number(p[1])),minX=Math.min(...xs),maxX=Math.max(...xs),minY=Math.min(...ys),maxY=Math.max(...ys);
  for(let i=1;i<20&&!position;i++)for(let j=1;j<20&&!position;j++){const lat=minY+(maxY-minY)*i/20,lon=minX+(maxX-minX)*j/20;if(regions.contains(g,lat,lon))position={latitude:lat,longitude:lon};}
  if(position){selection={path:[r0.id,r1.id,r2.id,leaf.id],type:type.id};break;}
 }
 assert.ok(selection,'No open business type with active reference geography is available');
 await person.route(ctx,event('person-profile',{acknowledgementVersion:person.ACK_VERSION}));
 const hours=Array.from({length:7},(_,day)=>({day,closed:day!==0,periods:day===0?[{open:'09:00',close:'20:00'}]:[]}));
 const create=async name=>{const r=await person.route(ctx,event('branch-drafts',{name,businessTypeId:selection.type,address:'ISOLATED FIXTURE ADDRESS',description:'Automated storage integration; remove after run',regionPath:selection.path,...position,openingHours:hours}));draftIds.push(r.draft.draftId);return r.draft;};
 let d1=await create('ISOLATED FIXTURE BRANCH A');
 const bytes=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jWZkAAAAASUVORK5CYII=','base64');
 for(const kind of ['REGISTRATION_CERTIFICATE','BUSINESS_PHOTO']){const r=await assets.route({db,s3,sub},event('branch-assets',{}),{draftId:d1.draftId,assetId:crypto.randomUUID(),kind,contentType:'image/png',base64Data:bytes.toString('base64')});d1=r.draft;}
 const assetId=d1.registrationCertificateAssetId,asset=await get(table,{pk,sk:'ASSET#'+assetId});keys.push(asset.key);
 await s3.send(new PutObjectCommand({Bucket:bucket,ExpectedBucketOwner:'699561669180',Key:asset.key,Body:bytes,ContentType:'image/png',ServerSideEncryption:'AES256'}));
 const file=await assets.route({db,s3,sub},event('branch-assets',{},'GET',{assetId}),{});assert.equal((await fetch(file.url)).status,200);assert.equal((await fetch('https://'+bucket+'.s3.us-east-1.amazonaws.com/'+asset.key)).status,403);
 await assert.rejects(assets.route({db,s3,sub:crypto.randomUUID()},event('branch-assets',{},'GET',{assetId}),{}),/ASSET_UNAVAILABLE/);report.privateFilesAndOwnerIsolation=true;
 const config=await person.route(ctx,event('branch-drafts/config',{},'GET',{draftId:d1.draftId}));assert.equal(config.partnershipReady,true);
 const submit=async d=>{const r=await person.route(ctx,event('branch-drafts/submit',{draftId:d.draftId,baseVersion:d.version,agreementVersion:config.agreementVersion}));return r.draft;};
 d1=await submit(d1);assert.equal(d1.reviewStatus,'SUBMITTED');assert.ok(await get(table,{pk,sk:'SUBMISSION#'+d1.submission.requestId}));
 const actor={employeeId:sub,status:'ACTIVE',roles:['merchant_reviewer'],scope:{allRegions:true},version:1};let index=0;
 const staffCtx={db,table:'staging-PlatformStaff',guard:()=>({ConditionCheck:{TableName:table,Key:{pk,sk:'PROFILE'},ConditionExpression:'#v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':1}}}),audit:(_,action)=>({Put:{TableName:table,Item:{pk,sk:'AUDIT#'+crypto.randomUUID(),subjectId:sub,action}}}),newBusinessId:()=>{const id='business_fixture_'+sub+'_'+(++index);businessIds.push(id);return id;}};
 const approve=async d=>{const key=d.submission.submittedAt+'#'+d.submission.requestId;return review.route(staffCtx,actor,'POST','/staff/merchants/applications/review',{queueKey:key,baseVersion:d.version,decision:'APPROVE',reason:'Isolated integration fixture approval'});};
 const a1=await approve(d1),replay=await approve(d1);assert.equal(a1.businessId,replay.businessId);const b1=await get('WhizzMerchants_Businesses',{businessId:a1.businessId});assert.equal(b1.isActive,false);assert.equal(b1.onboardingComplete,false);report.approvalIsIdempotentAndOffline=true;
 const d2=await submit(await create('ISOLATED FIXTURE BRANCH B WITHOUT CERTIFICATE'));const a2=await approve(d2);assert.ok(a2.businessId);report.optionalCertificateAndMultipleBranches=true;
 const leaseKey={pk:'INTEGRATION_FIXTURE#'+sub,sk:'META'},r={...leaseKey,subjectId:sub,leaseOwner:'fixture',leaseUntil:Math.floor(Date.now()/1000)+300,version:1};await db.send(new PutCommand({TableName:'staging-AccountDeletion',Item:r}));
 const purge=require(path.resolve(__dirname,'..','..','..','whizzCentralPlatform-stg/backend/account-deletion/merchant-onboarding-assets')).purge;
 await purge({db,s3,r,job:{subjectId:sub},draftId:d1.draftId});assert.equal((await versions('persons/'+sub+'/drafts/'+d1.draftId+'/')).length,0);assert.ok(await get(table,{pk,sk:'DRAFT#'+d2.draftId}));report.branchAssetCleanupPreservesSibling=true;
 await purge({db,s3,r,job:{subjectId:sub}});report.accountPrivateAssetCleanup=true;
 await db.send(new DeleteCommand({TableName:'staging-AccountDeletion',Key:leaseKey}));
})().catch(e=>{report.failed=e.message;process.exitCode=1;}).finally(async()=>{
 try{
  const prefix='persons/'+sub+'/';assert.match(sub,/^[a-f0-9-]{36}$/);const objects=await versions(prefix);for(let i=0;i<objects.length;i+=1000)await s3.send(new DeleteObjectsCommand({Bucket:bucket,ExpectedBucketOwner:'699561669180',Delete:{Objects:objects.slice(i,i+1000).map(o=>({Key:o.Key,VersionId:o.VersionId})),Quiet:true}}));
  for(const row of await query(table,pk))await db.send(new DeleteCommand({TableName:table,Key:{pk:row.pk,sk:row.sk},ConditionExpression:'subjectId=:sub',ExpressionAttributeValues:{':sub':sub}}));
  for(const row of await query(table,'REVIEW#MERCHANT'))if(row.subjectId===sub)await db.send(new DeleteCommand({TableName:table,Key:{pk:row.pk,sk:row.sk},ConditionExpression:'subjectId=:sub',ExpressionAttributeValues:{':sub':sub}}));
  for(const id of businessIds){assert.ok(id.startsWith('business_fixture_'+sub+'_'));if(await get('WhizzMerchants_Businesses',{businessId:id}))await db.send(new DeleteCommand({TableName:'WhizzMerchants_Businesses',Key:{businessId:id},ConditionExpression:'ownerId=:sub',ExpressionAttributeValues:{':sub':sub}}));}
  for(const partition of ['INTEGRATION_FIXTURE#'+sub,'ACCOUNT_OPERATION#MERCHANT#'+sub])for(const row of await query('staging-AccountDeletion',partition))await db.send(new DeleteCommand({TableName:'staging-AccountDeletion',Key:{pk:row.pk,sk:row.sk}}));
  report.fixtureRecordsAndObjectVersionsRemoved=(await query(table,pk)).length===0&&(await versions(prefix)).length===0;if(!report.fixtureRecordsAndObjectVersionsRemoved)process.exitCode=1;
  if(before){const after=await businesses(),sort=rows=>rows.sort((a,b)=>a.businessId.localeCompare(b.businessId));report.existingBusinessesPreserved=digest(sort(before))===digest(sort(after));if(!report.existingBusinessesPreserved)process.exitCode=1;}
 }catch(e){report.cleanupFailed=e.message;process.exitCode=1;}
 console.log(JSON.stringify(report));
});
