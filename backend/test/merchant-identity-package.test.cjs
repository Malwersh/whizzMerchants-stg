'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
function fixture(){
 const module={exports:{}},calls={policy:0,writes:0};
 class Command{constructor(input){this.input=input;}}
 vm.runInNewContext(fs.readFileSync(__dirname+'/../functions/shared/merchant-lifecycle.js','utf8'),{
  module,Buffer,Date,AbortSignal,
  require:name=>{
   if(name==='./legacy-order-policy'){calls.policy++;throw Object.assign(Error('Policy unavailable'),{code:'MODULE_NOT_FOUND'});}
   if(name.startsWith('node:'))return require(name);
   if(name==='@aws-sdk/lib-dynamodb')return {GetCommand:Command,TransactWriteCommand:Command};
   if(name==='@aws-sdk/client-cognito-identity-provider')return {CognitoIdentityProviderClient:class{},GetUserCommand:Command,AdminGetUserCommand:Command};
   throw Error('Unexpected dependency');
  }
 });
 return {...module.exports,calls};
}
test('identity-only package authenticates through Cognito without the order policy',async()=>{
 const f=fixture(),token='header.'+Buffer.from(JSON.stringify({token_use:'access',sub:'owner'})).toString('base64url')+'.signature';
 let checked=false;
 const identity=await f.liveMerchantIdentity({send:async command=>{assert.equal(command.input.AccessToken,token);checked=true;return {UserAttributes:[{Name:'sub',Value:'owner'}]};}},token);
 assert.equal(checked,true);assert.equal(identity.claims.sub,'owner');assert.equal(f.calls.policy,0);
 await assert.rejects(f.liveMerchantIdentity({send:async()=>{throw Error('Revoked');}},token),/Revoked/);
});
test('missing order policy fails closed before an order mutation is sent',async()=>{
 const f=fixture();class UpdateCommand{constructor(input){this.input=input;}}
 const client=f.merchantLifecycleClient({send:async command=>{
  if(command.input.TableName==='WizzOrders')return {Item:{storeId:'branch',status:'pending'}};
  f.calls.writes++;return {};
 }});
 await assert.rejects(f.merchantRequestContext.run({sub:'owner',businessId:'branch'},()=>client.send(new UpdateCommand({TableName:'WizzOrders',Key:{PK:'ORDER#one',SK:'META'},UpdateExpression:'SET note=:n',ExpressionAttributeValues:{':n':'note'}}))),{code:'MODULE_NOT_FOUND'});
 assert.equal(f.calls.policy,1);assert.equal(f.calls.writes,0);
});
