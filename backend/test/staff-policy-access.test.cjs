'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const policyAccess=require('./staff-policy-fixture.cjs');
test('central policy projection aliases reserved roles attribute and retains strong reads',async()=>{
 let request;
 const access=policyAccess({GetCommand:class{constructor(input){this.input=input;}}},'CENTRAL');
 const policy={version:1,enabledPermissions:['branch.read'],roles:[]};
 const result=await access.read({send:async command=>{
  request=command.input;
  assert.equal(request.ConsistentRead,true);
  assert.equal(request.Key.pk,'OPERATIONAL_SETTINGS#MERCHANT_STAFF_PERMISSIONS');
  const tokens=request.ProjectionExpression.split(',').map(x=>x.trim());
  assert.equal(tokens.includes('roles'),false);
  assert.ok(tokens.some(t=>request.ExpressionAttributeNames[t]==='roles'));
  return {Item:policy};
 }});
 assert.equal(result,policy);
});
