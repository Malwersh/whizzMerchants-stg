'use strict';

const test=require('node:test');
const assert=require('node:assert/strict');
const {propose,accept}=require('../../functions/auth/ownership-transfer');
const {planCommit}=require('../ownership-transfer-commit');

function fixture(){
 const organization={pk:'PERSON#old',sk:'ORGANIZATION#org',subjectId:'old',organizationId:'org',version:1};
 const brands=[{pk:'PERSON#old',sk:'BRAND#brand',subjectId:'old',organizationId:'org',brandId:'brand',version:2}];
 const branches=['first','second'].map(businessId=>({
  businessId,brandId:'brand',organizationId:'org',ownerId:'old',cognitoUserId:'old',
  status:'approved',updatedAt:'2026-11-19T00:00:00.000Z',
 }));
 const now=Date.parse('2026-11-19T01:00:00Z');
 const initial=propose({actor:{sub:'old',reverified:true},recipientId:'new',requestId:'request',organization,branches,now});
 const request=accept({request:initial,actor:{sub:'new',reverified:true},expectedDigest:initial.digest,agreementVersion:'v1',now});
 return {
  environment:'production',request,organization,brands,branches,now,
  reviewer:{sub:'reviewer',reverified:true,canReviewOwnership:true},
  recipient:{subjectId:'new',name:'New owner'},
  finance:{
   scopeDigest:request.digest,settlementOwnerId:'new',settlementDestinationApproved:true,
   branchChecks:branches.map(({businessId})=>({businessId,availableBalance:0,lockedBalance:0,unsettledCount:0,openOrdersCount:0})),
  },
  fence:{
   organizationId:'org',requestId:'request',scopeDigest:request.digest,version:3,
   guards:[{ConditionCheck:{TableName:'wizz-production-Wallets',Key:{walletId:'wallet',sk:'META'},ConditionExpression:'availableBalance=:zero',ExpressionAttributeValues:{':zero':0}}}],
  },
 };
}

test('plans a conditional ownership update for every branch, organization and brand in one transaction',()=>{
 const {TransactItems:items}=planCommit(fixture());
 const updates=items.filter(item=>item.Update?.TableName==='wizz-production-Merchants');
 assert.deepEqual(updates.map(item=>item.Update.Key.businessId),['first','second']);
 assert.ok(updates.every(item=>item.Update.ExpressionAttributeValues[':recipient']==='new'));
 assert.equal(items.filter(item=>item.Delete?.Key.pk==='PERSON#old').length,2);
 assert.equal(items.filter(item=>item.Put?.Item.pk==='PERSON#new').length,2);
 assert.ok(items.some(item=>item.Put?.Item.kind==='OWNERSHIP_TRANSFER_COMPLETED'));
 assert.ok(items.some(item=>item.Update?.ExpressionAttributeValues[':completed']==='COMPLETED'));
});

test('missing mutation fence or changed ownership inventory prevents a transaction',()=>{
 const input=fixture();
 assert.throws(()=>planCommit({...input,fence:null}),/TRANSFER_MUTATION_FENCE_REQUIRED/);
 assert.throws(()=>planCommit({...input,brands:[]}),/TRANSFER_BRAND_INVENTORY_REQUIRED/);
 assert.throws(()=>planCommit({...input,branches:input.branches.slice(0,1)}),/TRANSFER_SCOPE_CHANGED/);
 assert.throws(()=>planCommit({...input,recipient:{subjectId:'stranger',name:'Name'}}),/TRANSFER_RECIPIENT_PROFILE_REQUIRED/);
});

test('staging branch writes target only the staging branch table',()=>{
 const input=fixture();
 assert.throws(()=>planCommit({...input,environment:'staging'}),/TRANSFER_MUTATION_FENCE_INVALID/);
 input.fence.guards[0].ConditionCheck.TableName='staging-Wallets';
 const {TransactItems:items}=planCommit({...input,environment:'staging'});
 assert.ok(items.some(item=>item.Update?.TableName==='WhizzMerchants_Businesses'));
 assert.ok(items.every(item=>!Object.values(item)[0].TableName.startsWith('wizz-production-')));
});
