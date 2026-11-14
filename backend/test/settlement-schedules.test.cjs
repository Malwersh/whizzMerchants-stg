'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {route}=require('../functions/auth/settlement_schedules');
const event={httpMethod:'GET',headers:{Authorization:'Bearer gateway-fixture','Access-Token':'access-fixture'},queryStringParameters:{branchId:'branch1'}};
test('closed schedule proxy cannot invoke target',async()=>{const old=process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED;delete process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED;try{await assert.rejects(route(event,{},{send:()=>{throw Error('must not invoke');}}),e=>e.status===503);}finally{if(old!==undefined)process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED=old;}});
test('fixed target receives access credential and input only, not client supplied identity or Gateway token',async()=>{const old=process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED;process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED='true';try{let sent;await route(event,{},{send:async c=>{sent=c.input;return {Payload:Buffer.from(JSON.stringify({statusCode:200,result:{proposals:[]}}))};}});const data=JSON.parse(Buffer.from(sent.Payload));assert.equal(data.action,'settlement_schedule_owner');assert.equal(data.accessToken,'access-fixture');assert.deepEqual(data.input,{branchId:'branch1'});assert(!JSON.stringify(data).includes('gateway-fixture'));assert.equal(sent.FunctionName,'arn:aws:lambda:us-east-1:699561669180:function:staging-wizz-staff-service');}finally{if(old===undefined)delete process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED;else process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED=old;}});
test('financial capability is forwarded from a header and cannot be supplied in query or body',async()=>{
 const old=process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED;process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED='true';
 try{let payload;const client={send:async c=>{payload=JSON.parse(Buffer.from(c.input.Payload));return {Payload:Buffer.from(JSON.stringify({statusCode:200,result:{}}))};}};
 const financialAccess={deviceId:'device_12345678901234567890123',token:'t'.repeat(43)};
 await route({...event,headers:{...event.headers,'X-Financial-Session':JSON.stringify(financialAccess)}},{},client);
 assert.deepEqual(payload.input.financialAccess,financialAccess);
 await assert.rejects(route({...event,queryStringParameters:{branchId:'branch1',financialAccess:'forged'}},{},client),e=>e.status===400);
 await assert.rejects(route({...event,headers:{...event.headers,'X-Financial-Session':'invalid-json'}},{},client),e=>e.status===400);
 }finally{if(old===undefined)delete process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED;else process.env.SETTLEMENT_SCHEDULE_ADMIN_ENABLED=old;}
});
