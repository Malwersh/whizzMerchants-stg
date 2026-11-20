'use strict';

const assert=require('node:assert/strict');
const test=require('node:test');
const {route:staffRoute}=require('../../functions/auth/branch_staff');
const {management:deviceManagement}=require('../../functions/auth/branch_devices');

const branch={
 businessId:'branch-1',ownerId:'owner',cognitoUserId:'owner',status:'approved',
 orderIntakeTransferExpiresAt:Date.now()+60000,
};
const identity={user:{UserAttributes:[{Name:'phone_number',Value:'+9647800000000'}]}};

function fixture(){
 const calls=[];
 const db={async send(command){
  calls.push(command);
  if(command.input.Key?.businessId===branch.businessId)return {Item:branch};
  if(command.input.Key?.sk==='DEVICE#device')return {Item:{pk:'BRANCH#branch-1',sk:'DEVICE#device',ownerId:'owner',version:1,status:'ACTIVE'}};
  return {};
 }};
 return {db,calls};
}

test('an affected branch cannot issue staff invitations or increase staff access',async()=>{
 const {db,calls}=fixture();
 for(const action of ['invite','accept','update']){
  await assert.rejects(staffRoute({db,sub:'owner',identity,phone:value=>value},{httpMethod:'POST'},{action,businessId:branch.businessId}),/OWNERSHIP_TRANSFER_PENDING/);
 }
 assert.ok(calls.every(command=>command.constructor.name==='GetCommand'));
});

test('an affected branch cannot pair devices and can still revoke a device',async()=>{
 const {db,calls}=fixture();
 for(const action of ['create_pairing','claim_pairing','set_pin']){
  await assert.rejects(deviceManagement({db,sub:'owner',identity},{httpMethod:'POST'},{action,businessId:branch.businessId}),/OWNERSHIP_TRANSFER_PENDING/);
 }
 await deviceManagement({db,sub:'owner',identity},{httpMethod:'POST'},{action:'revoke_device',businessId:branch.businessId,deviceId:'device',baseVersion:1});
 const write=calls.at(-1);
 assert.equal(write.constructor.name,'TransactWriteCommand');
 assert.ok(write.input.TransactItems.some(item=>item.Put?.Item.status==='REVOKED'));
});
