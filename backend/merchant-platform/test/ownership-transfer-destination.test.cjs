'use strict';
const assert=require('node:assert/strict');
const test=require('node:test');
const {createDestination}=require('../../functions/auth/ownership-transfer-destination');
class Get{constructor(input){this.input=input;}}
class Write{constructor(input){this.input=input;}}
const now=1800000000000,phone='+9647800000000';
const request={requestId:'test-request',organizationId:'org',recipientId:'recipient',digest:'abc',status:'AWAITING_REVIEW',expiresAt:now+600000};

function fixture(){
 let saved,delivered;
 const calls=[];
 const provider={secret:async()=> 'local-fixture',send:async(number,code)=>{assert.equal(number,phone);delivered=code;}};
 const db={send:async command=>{
  calls.push(command);
  if(command instanceof Get){
   return {Item:command.input.Key.sk==='PROFILE'?{subjectId:'recipient',phoneNumber:phone,version:2}:saved};
  }
  saved=command.input.TransactItems[2].Put.Item;
  return {};
 }};
 return {calls,data:()=>saved,code:()=>delivered,run:createDestination({db,provider,Get,Write,clock:()=>now})};
}

test('only the accepted recipient can request settlement phone verification',async()=>{
 const f=fixture();
 await assert.rejects(f.run({request,subjectId:'old-owner',phone,action:'START_DESTINATION'}),/TRANSFER_DESTINATION_RECIPIENT_REQUIRED/);
 assert.equal(f.calls.length,0);
});

test('opening the request reads the masked phone without sending a code or writing',async()=>{
 const f=fixture(),input={request,subjectId:'recipient',phone};
 assert.deepEqual(await f.run({...input,action:'READ_DESTINATION'}),
  {status:'VERIFICATION_REQUIRED',destination:'••••0000'});
 assert.equal(f.code(),undefined);
 assert.ok(f.calls.every(command=>command instanceof Get));
 const sent=await f.run({...input,action:'START_DESTINATION'});
 assert.deepEqual(await f.run({...input,action:'READ_DESTINATION'}),sent);
 await f.run({...input,action:'VERIFY_DESTINATION',challengeId:sent.challengeId,code:f.code()});
 assert.deepEqual(await f.run({...input,action:'READ_DESTINATION'}),
  {status:'VERIFIED',destination:'••••0000'});
});

test('a sent code is rate-limited and bound to the request and current recipient profile',async()=>{
 const f=fixture(),input={request,subjectId:'recipient',phone};
 const started=await f.run({...input,action:'START_DESTINATION'});
 assert.equal(started.status,'CODE_SENT');
 assert.match(f.code(),/^\d{6}$/);
 assert.notEqual(f.data().codeHash,f.code());
 await assert.rejects(f.run({...input,action:'START_DESTINATION'}),/TRANSFER_DESTINATION_RATE_LIMIT/);
 const wrong=f.code()==='000000'?'111111':'000000';
 await assert.rejects(f.run({...input,action:'VERIFY_DESTINATION',challengeId:started.challengeId,code:wrong}),/TRANSFER_DESTINATION_CODE_INVALID/);
 const verified=await f.run({...input,action:'VERIFY_DESTINATION',challengeId:started.challengeId,code:f.code()});
 assert.deepEqual(verified,{status:'VERIFIED',destination:'••••0000'});
 assert.equal(f.data().codeHash,undefined);
 assert.equal(f.data().profileVersion,2);
 const write=f.calls.at(-1).input.TransactItems;
 assert.equal(write[0].ConditionCheck.ExpressionAttributeValues[':digest'],'abc');
 assert.equal(write[1].ConditionCheck.ExpressionAttributeValues[':version'],2);
});
