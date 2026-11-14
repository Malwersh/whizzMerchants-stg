'use strict';
// Maintenance-only entry point. Intentionally absent from all HTTP routers.
const {GetCommand,TransactWriteCommand}=require('@aws-sdk/lib-dynamodb');
const policyAccess=require('./staff_policy_access');
const {transaction}=require('../../merchant-platform/staff-legacy-grants');
async function applyEntry(db,entry,expectedPolicyVersion){
 const policy=await policyAccess.read(db);if(policy.version!==expectedPolicyVersion)return {status:'CONFLICT',reason:'POLICY_VERSION_CONFLICT'};
 const current=(await db.send(new GetCommand({TableName:'staging-MerchantPlatform',Key:entry.key,ConsistentRead:true}))).Item;
 if(current?.permissionSchema===2&&current.legacyGrant?.sourceHash===entry.set?.legacyGrant?.sourceHash)return {status:'ALREADY_MIGRATED'};
 let items;try{items=transaction(entry,current,policy);}catch(e){return {status:'CONFLICT',reason:e.code||'MIGRATION_SOURCE_CHANGED'};}
 try{await db.send(new TransactWriteCommand({TransactItems:items}));}catch(e){if(e.name==='TransactionCanceledException')return {status:'CONFLICT',reason:'VERSION_OR_STATE_CONFLICT'};throw e;}
 return {status:'MIGRATED',version:current.version+1};
}
module.exports={applyEntry};
