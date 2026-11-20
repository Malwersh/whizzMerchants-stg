'use strict';
const assert=require('node:assert/strict');
const test=require('node:test');
const {propose,accept,cancel,validateApproval}=require('../../functions/auth/ownership-transfer');

const owner={sub:'current-owner',reverified:true};
const recipient={sub:'new-owner',reverified:true};
const reviewer={sub:'financial-reviewer',reverified:true,canReviewOwnership:true};
const organization={organizationId:'organization-1',subjectId:owner.sub,version:1};
const now=Date.parse('2026-11-19T19:00:00Z');
const branch=businessId=>({
 businessId,brandId:'restaurant-brand',organizationId:organization.organizationId,
 ownerId:owner.sub,cognitoUserId:owner.sub,status:'approved',updatedAt:'2026-11-18T20:00:00Z',
});
const branches=[branch('branch-b'),branch('branch-a')];

function fixture(){
 const pending=propose({actor:owner,recipientId:recipient.sub,requestId:'transfer-1',organization,branches,now});
 const accepted=accept({request:pending,actor:recipient,expectedDigest:pending.digest,agreementVersion:'merchant-terms-1',now:now+1000});
 return {pending,accepted,finance:{
  scopeDigest:accepted.digest,settlementOwnerId:recipient.sub,settlementDestinationApproved:true,
  branchChecks:branches.map(({businessId})=>({businessId,availableBalance:0,lockedBalance:0,unsettledCount:0,openOrdersCount:0})),
 }};
}

function approve({request=fixture().accepted,finance=fixture().finance,...overrides}={}){
 return validateApproval({request,reviewer,organization,branches,finance,now:now+2000,...overrides});
}

test('verified recipient accepts the same scope and independent reviewer approves fully settled branches',()=>{
 const {pending,accepted}=fixture();
 assert.deepEqual(pending.branchIds,['branch-a','branch-b']);
 assert.equal(accepted.version,2);
 assert.equal(approve({branches:[...branches].reverse()}).scopeDigest,accepted.digest);
});

test('changes to the branch inventory or organization after acceptance require a new decision',()=>{
 assert.throws(()=>approve({branches:[...branches,branch('branch-c')]}),/TRANSFER_SCOPE_CHANGED/);
 assert.throws(()=>approve({organization:{...organization,version:2}}),/TRANSFER_SCOPE_CHANGED/);
 assert.throws(()=>approve({branches:[branches[0],{...branches[1],cognitoUserId:'third-party'}]}),/BRANCH_OWNERSHIP_CHANGED/);
});

test('recipient and reviewer must be verified and distinct',()=>{
 const {pending}=fixture();
 const acceptance={request:pending,expectedDigest:pending.digest,agreementVersion:'terms-1',now};
 assert.throws(()=>accept({...acceptance,actor:owner}),/TRANSFER_RECIPIENT_REQUIRED/);
 assert.throws(()=>accept({...acceptance,actor:{...recipient,reverified:false}}),/RECENT_VERIFICATION_REQUIRED/);
 assert.throws(()=>approve({reviewer:{...owner,canReviewOwnership:true}}),/TRANSFER_REVIEWER_REQUIRED/);
});

test('transfer approval requires every branch to have clear financial and operational checks',()=>{
 const {finance}=fixture();
 for(const override of [{availableBalance:-500},{lockedBalance:10},{unsettledCount:1},{openOrdersCount:1},{}]){
  const first=Object.keys(override).length?{...finance.branchChecks[0],...override}:finance.branchChecks[1];
  assert.throws(()=>approve({finance:{...finance,branchChecks:[first,finance.branchChecks[1]]}}),/TRANSFER_FINANCIAL_BLOCKERS/);
 }
 assert.throws(()=>approve({finance:{...finance,settlementOwnerId:owner.sub}}),/TRANSFER_FINANCE_REVIEW_REQUIRED/);
});

test('cancellation and expiration prevent approval',()=>{
 const {accepted}=fixture();
 assert.throws(()=>cancel({request:accepted,actor:recipient,now:now+2000}),/OWNER_REQUIRED/);
 const cancelled=cancel({request:accepted,actor:owner,now:now+2000});
 assert.throws(()=>approve({request:cancelled}),/TRANSFER_STATE_CHANGED/);
 assert.throws(()=>approve({now:accepted.expiresAt}),/TRANSFER_EXPIRED/);
});
