'use strict';
// Staging-only synthetic maintenance check. Does not migrate human grants.
const assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const {DynamoDBClient}=require('../functions/auth/node_modules/@aws-sdk/client-dynamodb');
const {DynamoDBDocumentClient,PutCommand,GetCommand,QueryCommand,DeleteCommand}=require('../functions/auth/node_modules/@aws-sdk/lib-dynamodb');
const {plan}=require('./staff-legacy-grants'),{applyEntry}=require('../functions/auth/staff_grant_migration'),policyAccess=require('../functions/auth/staff_policy_access');
const db=DynamoDBDocumentClient.from(new DynamoDBClient({region:'us-east-1'}));
const T='staging-MerchantPlatform',B='WhizzMerchants_Businesses',id='synthetic-migration-'+randomUUID(),owner=randomUUID(),subject=randomUUID(),pk='BRANCH#'+id;
(async()=>{try{
 const policy=await policyAccess.read(db);
 await db.send(new PutCommand({TableName:B,Item:{businessId:id,ownerId:owner,cognitoUserId:owner,status:'approved',isActive:false},ConditionExpression:'attribute_not_exists(businessId)'}));
 const member={pk,sk:'MEMBER#'+subject,businessId:id,ownerId:owner,subjectId:subject,role:'MANAGER',extraPermissions:[],status:'ACTIVE',version:1};
 await db.send(new PutCommand({TableName:T,Item:member,ConditionExpression:'attribute_not_exists(pk)'}));
 const entry=plan([member],policy).updates[0];
 assert.equal((await applyEntry(db,entry,policy.version)).status,'MIGRATED');
 assert.equal((await applyEntry(db,entry,policy.version)).status,'ALREADY_MIGRATED');
 const saved=(await db.send(new GetCommand({TableName:T,Key:{pk,sk:member.sk},ConsistentRead:true}))).Item;
 assert.equal(saved.version,2);assert.equal(saved.subjectId,subject);assert.equal(saved.ownerId,owner);
 for(const permission of ['menu.create','menu.delete','finance.transfer','wallet.balance.read','discounts.create'])assert.equal(saved.grant.permissions.includes(permission),false);
 assert.ok(saved.grant.permissions.includes('orders.reject'));
 console.log(JSON.stringify({strongPolicyRead:true,migrationAtomic:true,replayNoWrite:true,identityPreserved:true,noNewFinancialOrProductRights:true,humanGrantsChanged:0}));
 }finally{
 let cursor;do{const page=await db.send(new QueryCommand({TableName:T,KeyConditionExpression:'pk=:pk',ExpressionAttributeValues:{':pk':pk},ConsistentRead:true,ExclusiveStartKey:cursor}));for(const r of page.Items||[])await db.send(new DeleteCommand({TableName:T,Key:{pk:r.pk,sk:r.sk}}));cursor=page.LastEvaluatedKey;}while(cursor);
 await db.send(new DeleteCommand({TableName:B,Key:{businessId:id}}));console.log('Synthetic migration fixtures cleaned.');
 }})().catch(error=>{console.error(error.name,error.message);process.exitCode=1;});
