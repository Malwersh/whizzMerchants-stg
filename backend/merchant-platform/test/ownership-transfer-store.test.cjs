'use strict';

const assert=require('node:assert/strict');
const test=require('node:test');
const {createTransferStore}=require('../../functions/auth/ownership-transfer-store');

class GetCommand{constructor(input){this.input=input;}}
class TransactWriteCommand{constructor(input){this.input=input;}}

const org={organizationId:'org-1',subjectId:'owner-1',version:1};
const branch={
 businessId:'branch-1',brandId:'brand-1',organizationId:org.organizationId,
 ownerId:org.subjectId,cognitoUserId:org.subjectId,status:'approved',
 updatedAt:'2026-11-19T00:00:00Z',
};
const initial={
 actor:{sub:org.subjectId,reverified:true},recipientId:'recipient-1',
 requestId:'transfer-1',organization:org,branches:[branch],
};

function fixture(environment='staging'){
 let current,conflict=false;
 const calls=[];
 const db={async send(command){
  calls.push(command.input);
  if(command instanceof GetCommand)return {Item:current};
  if(conflict)throw Object.assign(Error(),{
   name:'TransactionCanceledException',CancellationReasons:[{Code:'ConditionalCheckFailed'}],
  });
  current=command.input.TransactItems[0].Put.Item;
  return {};
 }};
 return {
  store:createTransferStore({db,GetCommand,TransactWriteCommand,environment,clock:()=>12345}),
  calls,race:()=>{conflict=true;},
 };
}

test('starts only one pending transfer per organization and handles an identical retry',async()=>{
 const {store,calls}=fixture();
 const started=await store.start(initial);
 assert.equal(calls[0].ConsistentRead,true);
 assert.equal(calls[1].TransactItems[0].Put.ConditionExpression,'attribute_not_exists(pk)');
 const pause=calls[1].TransactItems[1].Update;
 assert.equal(pause.TableName,'WhizzMerchants_Businesses');
 assert.equal(pause.ExpressionAttributeValues[':expires'],started.expiresAt);
 assert.match(pause.ConditionExpression,/attribute_not_exists\(orderIntakeDeletionRequestId\)/);
 assert.equal((await store.start(initial)).digest,started.digest);
 await assert.rejects(store.start({...initial,requestId:'transfer-2'}),/TRANSFER_ALREADY_PENDING/);
});

test('acceptance is conditional on the exact stored request and version',async()=>{
 const {store,calls,race}=fixture();
 const started=await store.start(initial);
 const acceptance={
  actor:{sub:initial.recipientId,reverified:true},organizationId:org.organizationId,
  requestId:initial.requestId,expectedDigest:started.digest,agreementVersion:'v1',
 };
 race();
 await assert.rejects(store.accept(acceptance),/TRANSFER_STATE_CHANGED/);
 const put=calls.at(-1).TransactItems[0].Put;
 assert.deepEqual(put.ExpressionAttributeValues,{
  ':requestId':'transfer-1',':version':1,':status':'AWAITING_RECIPIENT',
 });
});

test('production and staging requests use distinct tables',async()=>{
 const production=fixture('production');
 await production.store.start(initial);
 assert.equal(production.calls[0].TableName,'wizz-production-MerchantPlatform');
 assert.throws(()=>fixture('constructor'),/TRANSFER_ENVIRONMENT_NOT_CONFIGURED/);
 assert.throws(()=>fixture('development'),/TRANSFER_ENVIRONMENT_NOT_CONFIGURED/);
});

test('cancelling resumes only branches paused by the same request',async()=>{
 const {store,calls}=fixture();
 await store.start(initial);
 await store.cancel({actor:initial.actor,organizationId:org.organizationId,requestId:initial.requestId});
 const resume=calls.at(-1).TransactItems[1].Update;
 assert.equal(resume.UpdateExpression,'REMOVE orderIntakeTransferRequestId, orderIntakeTransferExpiresAt');
 assert.equal(resume.ConditionExpression,'orderIntakeTransferRequestId=:request');
});

test('owner request loads all authorized organization branches from storage',async()=>{
 class ScanCommand{constructor(input){this.input=input;}}
 const calls=[];
 const db={async send(command){
  const input=command.input;
  calls.push(input);
  if(command instanceof ScanCommand)return input.ExclusiveStartKey
   ? {Items:[{...branch,businessId:'second-branch'}]}
   : {Items:[branch],LastEvaluatedKey:{businessId:'branch-1'}};
  if(command instanceof GetCommand)return input.Key.pk==='PERSON#owner-1'?{Item:org}:{};
  return {};
 }};
 const store=createTransferStore({db,GetCommand,ScanCommand,TransactWriteCommand,environment:'staging',clock:()=>12345});
 const started=await store.startForOrganization({
  organizationId:org.organizationId,actor:initial.actor,recipientId:initial.recipientId,
  requestId:initial.requestId,branches:[branch],
 });
 assert.deepEqual(started.branchIds,['branch-1','second-branch']);
 assert.deepEqual(calls[2].ExclusiveStartKey,{businessId:'branch-1'});
 assert.equal(calls.at(-1).TransactItems.at(-1).ConditionCheck.ExpressionAttributeValues[':version'],org.version);
});
