const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
function setup(){let invoked=0;const module={exports:{}},calls=[];class Command{constructor(input){this.input=input;}}
 vm.runInNewContext(fs.readFileSync(__dirname+'/../functions/auth/order_returns.js','utf8'),{module,Buffer,process,require:name=>name==='@aws-sdk/lib-dynamodb'?{GetCommand:Command}:{InvokeCommand:Command,LambdaClient:class{}}});
 const f={sub:'owner1',business:{ownerId:'owner1',cognitoUserId:'owner1'},get invoked(){return invoked;}};
 f.db={async send(c){calls.push(c.input);return {Item:f.business};}};
 f.client={async send(c){invoked++;calls.push(c.input);return {Payload:Buffer.from(JSON.stringify({statusCode:200,result:{success:true,kind:'COD_RETURN'}}))};}};
 f.run=(method='GET',patch={})=>module.exports.route({db:f.db,sub:f.sub},{httpMethod:method,headers:{Authorization:'Bearer original-token'},queryStringParameters:{businessId:'branch1',orderId:'order1',offerId:'offer1',attempt:'1',...patch}},{businessId:'branch1',orderId:'order1',offerId:'offer1',attempt:1,returnId:'ret1',expectedVersion:2,allItemsReceived:true,condition:'INTACT',driverResponsibility:'NONE',cashCollected:false,...patch},f.client);f.calls=calls;return f;
}
const target='arn:aws:lambda:us-east-1:699561669180:function:staging-driver-financial-accept';
test('owner return endpoint defaults closed and never invokes a different financial function',async()=>{
 const old={...process.env};try{delete process.env.FINANCIAL_COD_RETURNS_MODE;const f=setup();await assert.rejects(f.run(),/COD_RETURNS_DISABLED/);assert.equal(f.invoked,0);
 process.env.FINANCIAL_COD_RETURNS_MODE='REQUIRED';process.env.FINANCIAL_ACCEPT_FUNCTION_ARN='other';await assert.rejects(f.run(),/COD_RETURNS_DISABLED/);assert.equal(f.invoked,0);
 }finally{process.env=old;}
});
test('owner confirmation and read forward original credentials, explicit scope/version and no wallet mutation',async()=>{
 const old={...process.env};try{process.env.FINANCIAL_COD_RETURNS_MODE='REQUIRED';process.env.FINANCIAL_ACCEPT_FUNCTION_ARN=target;const f=setup();await f.run();await f.run('POST');
 const payload=JSON.parse(Buffer.from(f.calls.at(-1).Payload));assert.equal(payload.action,'confirm_return');assert.equal(payload.accessToken,'original-token');assert.equal(payload.body.branchId,'branch1');assert.equal(payload.body.expectedVersion,2);assert.equal(payload.body.businessId,undefined);assert.equal(f.calls.at(-1).FunctionName,target);assert.equal(f.invoked,2);
 f.sub='employee';await assert.rejects(f.run(),/OWNER_REQUIRED/);assert.equal(f.invoked,2);
 f.sub='owner1';await assert.rejects(f.run('POST',{amount:100}),/INVALID_COD_RETURN/);assert.equal(f.invoked,2);
 }finally{process.env=old;}
});

test('cancellation only accepts owner POST under its independent gate and forwards no monetary fields',async()=>{
 const old={...process.env};try{process.env.FINANCIAL_ACCEPT_FUNCTION_ARN=target;process.env.FINANCIAL_COD_RETURNS_MODE='REQUIRED';delete process.env.FINANCIAL_COD_ASSIGNMENTS_MODE;
 const f=setup(),input={businessId:'branch1',orderId:'order1',offerId:'offer1',attempt:2,goodsRetainedByBranch:true,cashCollected:false};
 const event={path:'/auth/order-cancellation',httpMethod:'POST',headers:{Authorization:'Bearer original-token'}};
 // Load the same handler with injected SDK clients and a live ownership fixture.
 const module={exports:{}};class Command{constructor(input){this.input=input;}}
 vm.runInNewContext(fs.readFileSync(__dirname+'/../functions/auth/order_returns.js','utf8'),{module,Buffer,process,require:name=>name==='@aws-sdk/lib-dynamodb'?{GetCommand:Command}:{InvokeCommand:Command,LambdaClient:class{}}});
 const run=(ev=event,data=input,sub='owner1')=>module.exports.route({db:f.db,sub},ev,data,f.client);
 await assert.rejects(run(),/COD_RETURNS_DISABLED/);assert.equal(f.invoked,0);
 process.env.FINANCIAL_COD_ASSIGNMENTS_MODE='REQUIRED';await assert.rejects(run({...event,httpMethod:'GET'}),/INVALID_COD_RETURN/);
 await assert.rejects(run(event,input,'employee'),/OWNER_REQUIRED/);
 await assert.rejects(run(event,{...input,amount:100}),/INVALID_COD_RETURN/);
 await run();const p=JSON.parse(Buffer.from(f.calls.at(-1).Payload));assert.equal(p.action,'cancel_before_pickup');assert.equal(p.accessToken,'original-token');assert.equal(p.body.branchId,'branch1');assert.equal(p.body.attempt,2);assert.equal(p.body.businessId,undefined);assert.equal(f.invoked,1);
 }finally{process.env=old;}
});
