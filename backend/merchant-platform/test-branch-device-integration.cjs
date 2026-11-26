'use strict';
// Isolated DynamoDB fixtures. No Cognito, OTP, orders, wallets or real memberships.
const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const {DynamoDBClient}=require('../functions/auth/node_modules/@aws-sdk/client-dynamodb');
const {DynamoDBDocumentClient,PutCommand,GetCommand,QueryCommand,DeleteCommand}=require('../functions/auth/node_modules/@aws-sdk/lib-dynamodb');
const api=require('../functions/auth/branch_devices'),cleanup=require('../../../whizzCentralPlatform-stg/backend/account-deletion/merchant-staff-cleanup');
const db=DynamoDBDocumentClient.from(new DynamoDBClient({region:'us-east-1'})),T='staging-MerchantPlatform',D='staging-AccountDeletion',B='WhizzMerchants_Businesses';
const owner=randomUUID(),subject=randomUUID(),bid='synthetic-device-'+randomUUID(),sibling='synthetic-device-'+randomUUID(),pk='BRANCH#'+bid;
const categoryId='synthetic-device-'+randomUUID(),productId='synthetic-device-'+randomUUID(),weekdays=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
let pushKey;
const partitions=[pk,'BRANCH#'+sibling,'PERSON#'+subject],markers=[];
const put=(table,item)=>db.send(new PutCommand({TableName:table,Item:item,ConditionExpression:'attribute_not_exists('+ (table===B?'businessId':'pk') +')'}));
const rows=async pk=>{const all=[];let cursor;do{const p=await db.send(new QueryCommand({TableName:T,KeyConditionExpression:'pk=:p',ExpressionAttributeValues:{':p':pk},ConsistentRead:true,ExclusiveStartKey:cursor}));all.push(...p.Items||[]);cursor=p.LastEvaluatedKey;}while(cursor);return all;};
const manage=(sub,input)=>api.management({db,sub,identity:{claims:{auth_time:Math.floor(Date.now()/1000)}}},{httpMethod:'POST'},{businessId:bid,...input});
const runtime=(token,input,session)=>api.runtime(db,{httpMethod:'POST',headers:{Authorization:'Bearer '+token,...(session?{'X-Staff-Session':session}:{})}},input);
(async()=>{try{
 for(const businessId of [bid,sibling])await put(B,{businessId,businessName:'Synthetic device test',ownerId:owner,cognitoUserId:owner,status:'approved',testFixture:'branch-device'});
 const member={pk,sk:'MEMBER#'+subject,businessId:bid,ownerId:owner,subjectId:subject,membershipId:bid+'#'+subject,role:'SYNTHETIC_VALIDATION',permissionSchema:2,grant:{roleId:'SYNTHETIC_VALIDATION',roleNameAr:'اختبار تركيبي',roleVersion:1,policyVersion:1,branchIds:[bid],permissions:require('./staff-capabilities').REGISTRY.filter(c=>c.implemented).map(c=>c.id)},extraPermissions:[],displayName:'Synthetic employee',status:'ACTIVE',version:1};
 await put(T,member);await put(T,{pk:'PERSON#'+subject,sk:'PROFILE',name:'Synthetic employee',version:1});await put(T,{pk:'PERSON#'+subject,sk:'MEMBER#'+bid,businessId:bid,ownerId:owner,subjectId:subject,version:1});
 await put(T,{pk:'BRANCH#'+sibling,sk:'DEVICE#sentinel',businessId:sibling,ownerId:owner,deviceId:'sentinel',version:1,status:'ACTIVE'});
 const p=await manage(owner,{action:'create_pairing',name:'Test kitchen'}),d=await manage(subject,{action:'claim_pairing',pairingCode:p.pairingCode});
 await assert.rejects(manage(subject,{action:'claim_pairing',pairingCode:p.pairingCode}),/PAIRING_EXPIRED/);
 await manage(subject,{action:'set_pin',deviceToken:d.deviceToken,pin:'147258'});
 const s=await runtime(d.deviceToken,{action:'unlock',subjectId:subject,pin:'147258'});
 const profile=await runtime(d.deviceToken,{action:'profile'},s.staffSession);assert.equal(profile.capabilities.editHours,true);assert.equal(profile.business.ownerId,undefined);
 if(process.env.LIVE_DEVICE_API){
  const base=process.env.LIVE_DEVICE_API;
  async function http(path,body,session=true,method){const r=await fetch(base+path,{method:method||(body?'POST':'GET'),headers:{'Content-Type':'application/json','Authorization':'Bearer '+d.deviceToken,...(session?{'X-Staff-Session':s.staffSession}:{})},...(body?{body:JSON.stringify(body)}:{})});const data=await r.json();assert.ok([200,201].includes(r.status),JSON.stringify({path,status:r.status,code:data.code,message:data.message}));return data;}
  pushKey='BRANCH_DEVICE#'+d.device.deviceId;
  const pushToken='synthetic-fcm-no-delivery-'+randomUUID();
  await http('/branch-device',{action:'register_push',pushToken,platform:'ios'},false);
  const registered=(await db.send(new GetCommand({TableName:'WizzCentral_PushDeviceTokens_staging',Key:{token:pushKey},ConsistentRead:true}))).Item;
  assert.equal(registered.fcmToken,pushToken);assert.equal(registered.subjectId,pushKey);
  const reception=await http('/branch-device',{action:'reception'},false);assert.equal(reception.pushRegistered,true);
  assert.ok(reception.staff.some(x=>x.subjectId===subject));
  const live=await http('/branch-device',{action:'profile'});assert.equal(live.business.ownerId,undefined);assert.equal(live.capabilities.editMenu,true);
  assert.equal((await http('/branch-device/merchant/orders/'+bid+'?status=pending',undefined,false)).orders.length,0);
  assert.equal((await http('/branch-device/merchant/orders/'+bid+'?status=pending')).orders.length,0);
  await put('WhizzMerchants_Products',{productId,businessId:bid,name:'Synthetic device item',price:1000,isAvailable:true,testFixture:'branch-device'});
  assert.ok((await http('/branch-device/products')).products.some(x=>x.productId===productId));
  const patch={businessId:bid,requestId:randomUUID(),price:1500,isAvailable:false};await http('/branch-device/products/'+productId,patch,true,'PUT');await http('/branch-device/products/'+productId,patch,true,'PUT');
  const product=(await db.send(new GetCommand({TableName:'WhizzMerchants_Products',Key:{productId},ConsistentRead:true}))).Item;assert.equal(product.price,1500);assert.equal(product.isAvailable,false);
  const hours=Object.fromEntries(weekdays.map(day=>[day.toLowerCase(),{isOpen:false,isClosed:true,openTime:'closed',closeTime:'closed'}]));
  await http('/branch-device/businesses/'+bid+'/working-hours',{businessId:bid,workingHours:hours},true,'PUT');
  const saved=await http('/branch-device/businesses/'+bid+'/working-hours');assert.equal(Object.keys(saved.workingHours).length,7);
  const status=await http('/branch-device',{action:'read_status'});await http('/branch-device',{action:'set_status',acceptingOrders:false,baseRevision:status.revision});
  await db.send(new PutCommand({TableName:'WhizzMerchants_Categories',Item:{categoryId,categoryName:'Synthetic category',businessId:bid,isActive:true},ConditionExpression:'attribute_not_exists(categoryId)'}));
  const create={requestId:randomUUID(),name:'Synthetic API product',price:1250,categoryId};const created=await http('/branch-device/products',create,true,'POST');const newId=created.product.productId;
  try{const replay=await http('/branch-device/products',create,true,'POST');assert.equal(replay.product.productId,newId);await http('/branch-device/products/'+newId,{},true,'DELETE');await http('/branch-device/products/'+newId,{},true,'DELETE');}finally{await db.send(new DeleteCommand({TableName:'WhizzMerchants_Products',Key:{productId:newId}}));}
  const discountRequest={action:'discounts_create',requestId:randomUUID(),data:{title:'Synthetic discount',type:'percentage',value:10,validFrom:new Date().toISOString(),validTo:new Date(Date.now()+86400000).toISOString()}};
  const discount=await http('/branch-device',discountRequest);try{const replay=await http('/branch-device',discountRequest);assert.equal(replay.discountId,discount.discountId);let found,cursor;do{const page=await http('/branch-device',{action:'discounts_list',...(cursor?{cursor}:{})});found=page.discounts.find(x=>x.discountId===discount.discountId);cursor=page.nextCursor;}while(!found&&cursor);assert.ok(found);await http('/branch-device',{action:'discounts_delete',requestId:randomUUID(),discountId:found.discountId,baseRevision:found.revision});}finally{await db.send(new DeleteCommand({TableName:'WhizzMerchants_Discounts',Key:{discountId:discount.discountId}}));}
  console.log('Live Gateway: device authorizer, reception, employee profile, order reads, product update and atomic week save passed with synthetic data.');
 }

 await runtime(d.deviceToken,{action:'lock'},s.staffSession);await assert.rejects(runtime(d.deviceToken,{action:'profile'},s.staffSession),/SESSION_REVOKED/);assert.equal((await runtime(d.deviceToken,{action:'reception'})).staff.length,1);
 const active=await runtime(d.deviceToken,{action:'unlock',subjectId:subject,pin:'147258'});
 await db.send(new PutCommand({TableName:T,Item:{...member,status:'REVOKED',version:2},ConditionExpression:'#v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':1}}));
 await assert.rejects(runtime(d.deviceToken,{action:'profile'},active.staffSession),/MEMBERSHIP_REVOKED/);
 const jobKey={pk:'REQUEST#synthetic-device-'+randomUUID(),sk:'META'},r={...jobKey,subjectId:subject,scope:{kind:'ACCOUNT'},leaseOwner:'test-lease',version:1,leaseUntil:Math.floor(Date.now()/1000)+300};markers.push(jobKey);await put(D,r);
 await cleanup.purge({db,r,job:{subjectId:subject},requestTable:D});
 const remaining=await rows(pk);assert.ok(!remaining.some(x=>x.subjectId===subject||x.actorId===subject));assert.ok(remaining.some(x=>x.sk.startsWith('DEVICE#')));
 const branchKey={pk:'REQUEST#synthetic-device-'+randomUUID(),sk:'META'},br={...branchKey,subjectId:owner,scope:{id:bid},leaseOwner:'test-lease',version:1,leaseUntil:Math.floor(Date.now()/1000)+300};markers.push(branchKey);await put(D,br);
 await cleanup.purge({db,r:br,job:{subjectId:owner,businessId:bid},requestTable:D});assert.equal((await rows(pk)).length,0);assert.equal((await rows('BRANCH#'+sibling)).length,1);
 console.log(JSON.stringify({pairingSingleUse:true,privateProjection:true,independentLock:true,liveRevocation:true,personalCleanup:true,branchCleanup:true,siblingIsolated:true,realMessages:0,ordersWritten:0}));
 }finally{if(pushKey)await db.send(new DeleteCommand({TableName:'WizzCentral_PushDeviceTokens_staging',Key:{token:pushKey}}));if(process.env.LIVE_DEVICE_API){await db.send(new DeleteCommand({TableName:'WhizzMerchants_Categories',Key:{categoryId}}));await db.send(new DeleteCommand({TableName:'WhizzMerchants_Products',Key:{productId}}));for(const weekday of weekdays)await db.send(new DeleteCommand({TableName:'WhizzMerchants_BusinessWorkingHours',Key:{businessId:bid,weekday}}));}
 for(const p of partitions)for(const row of await rows(p))await db.send(new DeleteCommand({TableName:T,Key:{pk:row.pk,sk:row.sk}}));for(const businessId of [bid,sibling])await db.send(new DeleteCommand({TableName:B,Key:{businessId}}));for(const Key of markers)await db.send(new DeleteCommand({TableName:D,Key}));console.log('Synthetic device fixtures cleaned.');}})().catch(e=>{console.error(e.name,e.message);process.exitCode=1;});
