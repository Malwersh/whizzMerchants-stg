const test=require('node:test'), assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('backend/functions/orders/merchant_order_handler.js','utf8');
const block=source.slice(source.indexOf('                // Read canonical rows'),source.indexOf('                // Merge full data'));
test('canonical reads replace stale index status, use consistent GetItem and bound concurrency',async()=>{
 let active=0,max=0; const reads=[];
 const context={limitedOrders:Array.from({length:19},(_,i)=>({orderId:String(i),status:'pending'})),ORDERS_TABLE:'WizzOrders',GetCommand:class{constructor(input){this.input=input;}},dynamodb:{async send(command){reads.push(command.input);active++;max=Math.max(max,active);await new Promise(r=>setTimeout(r,1));active--;return {Item:{orderId:command.input.Key.PK.slice(6),status:'cancelled'}};}},setTimeout};
 const result=await vm.runInNewContext('(async()=>{'+block+'; return fullOrders;})()',context);
 assert.equal(result.length,19);assert.ok(result.every(row=>row.status==='cancelled'));assert.ok(max<=8);assert.ok(reads.every(read=>read.ConsistentRead===true&&read.Key.SK==='META'));
});
test('canonical read failure propagates instead of passing stale pending orders',async()=>{
 const context={limitedOrders:[{orderId:'1'}],ORDERS_TABLE:'WizzOrders',GetCommand:class{},dynamodb:{async send(){throw Error('unavailable');}}};
 await assert.rejects(vm.runInNewContext('(async()=>{'+block+'})()',context),/unavailable/);
});
