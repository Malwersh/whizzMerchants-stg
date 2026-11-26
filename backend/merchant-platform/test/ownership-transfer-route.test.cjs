'use strict';
const assert=require('node:assert/strict');
const test=require('node:test');
const {createRoute}=require('../../functions/auth/ownership-transfer-route');

const now=1_800_000_000_000;
const id='12345678-1234-1234-1234-123456789abc';
const organizationId='org-1';
function identity(sub,authTime=now/1000){
 return {
  claims:{sub,token_use:'access',auth_time:authTime},
  user:{UserAttributes:[{Name:'sub',Value:sub},{Name:'phone_number_verified',Value:'true'},{Name:'phone_number',Value:'+9647800000000'}]},
 };
}
const pending={ownerId:'owner',recipientId:'recipient',organizationId,requestId:id,branchIds:['one'],status:'AWAITING_RECIPIENT',digest:'hash',expiresAt:now+60000};
function setup(allowValidSession=false){
 const calls=[];
 const notices=[];
 const store={
  startForOrganization:async input=>{calls.push(input);return pending;},
  organizationForBranch:async ({businessId,subjectId})=>businessId==='one'&&subjectId==='owner'?organizationId:null,
  activeForOwner:async ({subjectId})=>subjectId==='owner'?id:null,
  branchNames:async()=>['مطعم فتوش'],
  incoming:async subjectId=>subjectId==='recipient'?[pending]:[],
  forParticipant:async ({subjectId})=>['owner','recipient'].includes(subjectId)?pending:null,
  accept:async input=>{calls.push(input);return {...pending,status:'AWAITING_REVIEW'};},
 };
 const run=createRoute({store,allowValidSession,clock:()=>now,terms:async()=>({partnershipReady:true,termsVersion:'v3',termsTextAr:'اتفاقية'}),
  resolveRecipient:async phone=>phone==='07800000000'?{id:'recipient',name:'اسم تجريبي',phone}:null,
  notify:async notice=>notices.push(notice),
 });
 return {calls,run,notices};
}

test('opening transfer requires a recent verified session and accepts only an organization id',async()=>{
 const {run,calls}=setup();
 const input={action:'START',organizationId,requestId:id,recipientId:'recipient'};
 const event={httpMethod:'POST'};
 await assert.rejects(run({identity:identity('owner',now/1000-301),event,input}),/RECENT_VERIFICATION_REQUIRED/);
 await assert.rejects(run({identity:identity('owner'),event,input:{...input,branchIds:['one']}}),/INVALID_TRANSFER_REQUEST/);
 assert.equal(calls.length,0);
 await run({identity:identity('owner'),event,input});
 assert.deepEqual(calls[0],{actor:{sub:'owner',reverified:true},recipientId:'recipient',organizationId,requestId:id});
});

test('staging permits an already-validated older session and keeps identity checks',async()=>{
 const {run,calls}=setup(true);
 const event={httpMethod:'POST'};
 const input={action:'START',organizationId,requestId:id,recipientId:'recipient'};
 const valid=identity('owner',now/1000-7200);
 const future=identity('owner',now/1000+60);
 const unverified=identity('owner',now/1000-7200);
 unverified.user.UserAttributes.find(attribute=>attribute.Name==='phone_number_verified').Value='false';
 await assert.rejects(run({identity:future,event,input}),/RECENT_VERIFICATION_REQUIRED/);
 await assert.rejects(run({identity:unverified,event,input}),/UNAUTHORIZED/);
 await run({identity:valid,event,input});
 assert.equal(calls.length,1);
});

test('request reads are limited to the participants and expose agreement to the recipient',async()=>{
 const {run}=setup();
 const event={httpMethod:'GET',queryStringParameters:{organizationId,requestId:id}};
 await assert.rejects(run({identity:identity('stranger'),event}),/TRANSFER_NOT_FOUND/);
 const view=await run({identity:identity('recipient'),event});
 assert.equal(view.request.participant,'RECIPIENT');
 assert.equal(view.request.ownerId,undefined);
 assert.deepEqual(view.request.branchNames,['مطعم فتوش']);
 assert.deepEqual(view.agreement,{version:'v3',textAr:'اتفاقية'});
});

test('recipient acceptance requires the published agreement version and exact scope digest',async()=>{
 const {run,calls,notices}=setup();
 const input={action:'ACCEPT',organizationId,requestId:id,digest:'hash',agreementVersion:'v2'};
 const event={httpMethod:'POST'};
 await assert.rejects(run({identity:identity('recipient'),event,input}),/PARTNERSHIP_AGREEMENT_REQUIRED/);
 assert.equal(calls.length,0);
 assert.deepEqual(notices,[]);
 await run({identity:identity('recipient'),event,input:{...input,agreementVersion:'v3'}});
 assert.equal(calls[0].expectedDigest,'hash');
 assert.equal(calls[0].actor.sub,'recipient');
 assert.deepEqual(notices,[{action:'ownership_accepted',organizationId,requestId:id}]);
});

test('selected branch resolves only to an organization owned by the authenticated merchant',async()=>{
 const {run}=setup(),event={httpMethod:'GET',queryStringParameters:{businessId:'one'}};
 assert.deepEqual(await run({identity:identity('owner'),event}),{organizationId,activeRequestId:id});
 await assert.rejects(run({identity:identity('stranger'),event}),/TRANSFER_ORGANIZATION_UNAVAILABLE/);
});

test('starts an invitation by phone and queues push after storing the request',async()=>{
 const {run,calls,notices}=setup(true);
 const input={action:'START',organizationId,requestId:id,recipientPhone:'07800000000'};
 await run({identity:identity('owner'),event:{httpMethod:'POST'},input});
 assert.equal(calls[0].recipientId,'recipient');
 assert.deepEqual(notices,[{action:'ownership_invitation',organizationId,requestId:id}]);
});

test('only a verified branch owner can preview the recipient and changed recipients cannot start',async()=>{
 const {run,calls,notices}=setup(true);
 const event={httpMethod:'POST'};
 const input={action:'PREVIEW_RECIPIENT',organizationId,requestId:id,businessId:'one',recipientPhone:'07800000000'};
 await assert.rejects(run({identity:identity('stranger'),event,input}),/OWNER_REQUIRED/);
 const preview=await run({identity:identity('owner'),event,input});
 assert.equal(preview.recipient.name,'اسم تجريبي');
 const start={action:'START',organizationId,requestId:id,recipientPhone:input.recipientPhone,expectedRecipientId:'different'};
 await assert.rejects(run({identity:identity('owner'),event,input:start}),/TRANSFER_RECIPIENT_CHANGED/);
 assert.equal(calls.length,0);
 assert.equal(notices.length,0);
});

test('incoming invitations are scoped to the signed-in recipient',async()=>{
 const {run}=setup(true);
 const event={httpMethod:'GET',queryStringParameters:{incoming:'1'}};
 assert.deepEqual(await run({identity:identity('owner'),event}),{invitations:[]});
 const result=await run({identity:identity('recipient'),event});
 assert.equal(result.invitations[0].requestId,id);
 assert.deepEqual(result.invitations[0].branchNames,['مطعم فتوش']);
});
