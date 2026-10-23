'use strict';
// Synthetic zero-balance wallet only; no ledger writes, OTP, push or human grants.
const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const {DynamoDBClient}=require('../functions/auth/node_modules/@aws-sdk/client-dynamodb');
const {DynamoDBDocumentClient,PutCommand,QueryCommand,DeleteCommand}=require('../functions/auth/node_modules/@aws-sdk/lib-dynamodb');
const devices=require('../functions/auth/branch_devices'),policyAccess=require('../functions/auth/staff_policy_access');
const db=DynamoDBDocumentClient.from(new DynamoDBClient({region:'us-east-1'}));
const T='staging-MerchantPlatform',B='WhizzMerchants_Businesses',W='staging-Wallets',A='staging-AuditLog';
const businessId='synthetic-wallet-'+randomUUID(),owner=randomUUID(),subject=randomUUID(),pk='BRANCH#'+businessId,walletId='WALLET#MERCHANT#'+businessId;
const save=(TableName,Item,key='pk')=>db.send(new PutCommand({TableName,Item,ConditionExpression:'attribute_not_exists('+key+')'}));
async function rows(partition){let cursor,all=[];do{const p=await db.send(new QueryCommand({TableName:T,KeyConditionExpression:'pk=:pk',ExpressionAttributeValues:{':pk':partition},ConsistentRead:true,ExclusiveStartKey:cursor}));all.push(...p.Items||[]);cursor=p.LastEvaluatedKey;}while(cursor);return all;}
(async()=>{try{
 const policy=await policyAccess.read(db);
 await save(B,{businessId,ownerId:owner,cognitoUserId:owner,status:'approved',isActive:false},'businessId');
 await save(T,{pk:'PERSON#'+subject,sk:'PROFILE',name:'Synthetic wallet employee',version:1});
 const member={pk,sk:'MEMBER#'+subject,businessId,ownerId:owner,subjectId:subject,membershipId:businessId+'#'+subject,displayName:'Synthetic wallet employee',role:'SYNTHETIC_WALLET_VALIDATION',extraPermissions:[],permissionSchema:2,grant:{roleId:'SYNTHETIC_WALLET_VALIDATION',roleNameAr:'اختبار تركيبي',roleVersion:1,policyVersion:policy.version,branchIds:[businessId],permissions:['branch.read','wallet.balance.read','wallet.transactions.read','wallet.export','reports.sales.read','reports.export']},status:'ACTIVE',version:1};
 await save(T,member);await save(W,{walletId,sk:'META',ownerType:'MERCHANT',ownerId:businessId,currency:'IQD',status:'ACTIVE',availableBalance:0,lockedBalance:0},'walletId');
 const manage=(sub,input)=>devices.management({db,sub,identity:{claims:{auth_time:Math.floor(Date.now()/1000)}}},{httpMethod:'POST'},{businessId,...input});
 const pair=await manage(owner,{action:'create_pairing',name:'Synthetic wallet device'}),device=await manage(subject,{action:'claim_pairing',pairingCode:pair.pairingCode});await manage(subject,{action:'set_pin',deviceToken:device.deviceToken,pin:'147258'});
 const unlock=await devices.runtime(db,{httpMethod:'POST',headers:{Authorization:'Bearer '+device.deviceToken}},{action:'unlock',subjectId:subject,pin:'147258'});
 async function call(leaf,query={},expected=200){const r=await fetch('https://z14s5f8oxh.execute-api.us-east-1.amazonaws.com/staging/wallet/branch-device/'+leaf+'?'+new URLSearchParams({businessId,...query}),{headers:{Authorization:'Bearer '+device.deviceToken,'X-Staff-Session':unlock.staffSession}});const data=await r.json();assert.equal(r.status,expected,JSON.stringify({leaf,status:r.status,code:data.code||data.error?.code,message:data.message||data.error?.message}));return data;}
 const balance=await call('balance');assert.ok(JSON.stringify(balance).includes('availableBalance'));
 await call('transactions');const day=new Date(Date.now()-86400000).toISOString().slice(0,10);for(const leaf of ['statement','sales-report'])for(const format of ['json','csv'])await call(leaf,{from:day,to:day,format});
 await call('balance',{businessId:'foreign-branch'},403);
 const audit=(await rows(pk)).filter(r=>r.sk.startsWith('STAFF_AUDIT#OPERATIONS#'));assert.equal(audit.length,6);assert.equal(new Set(audit.map(r=>r.action)).size,6);
 await db.send(new PutCommand({TableName:T,Item:{...member,status:'REVOKED',version:2},ConditionExpression:'#v=:v',ExpressionAttributeNames:{'#v':'version'},ExpressionAttributeValues:{':v':1}}));await call('balance',{},403);
 console.log(JSON.stringify({gatewayAuthorization:true,zeroBalanceRead:true,transactionsRead:true,statementsAndSalesJsonCsv:true,dualAuditEvents:audit.length,foreignBranchDenied:true,liveRevocationDenied:true,ledgerWrites:0,humanDataChanged:0}));
 }finally{
 for(const row of await rows(pk)){
  if(row.sk.startsWith('STAFF_AUDIT#OPERATIONS#')&&row.actorId===subject&&row.action.startsWith('MERCHANT_STAFF_'))await db.send(new DeleteCommand({TableName:A,Key:{datePartition:'date#'+row.createdAt.slice(0,10).replace(/-/g,''),sk:row.sk.slice('STAFF_AUDIT#OPERATIONS#'.length)},ConditionExpression:'actorId=:a',ExpressionAttributeValues:{':a':subject}}));
  await db.send(new DeleteCommand({TableName:T,Key:{pk:row.pk,sk:row.sk}}));
 }
 for(const row of await rows('PERSON#'+subject))await db.send(new DeleteCommand({TableName:T,Key:{pk:row.pk,sk:row.sk}}));
 await db.send(new DeleteCommand({TableName:W,Key:{walletId,sk:'META'}}));await db.send(new DeleteCommand({TableName:B,Key:{businessId}}));console.log('Synthetic zero-wallet and audit fixtures cleaned.');
 }})().catch(e=>{console.error(e.name,e.message);process.exitCode=1;});
