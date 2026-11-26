const {test}=require('node:test'),assert=require('node:assert/strict');
const {execute,revision}=require('./order-reception');
const branch=()=>({businessId:'branch1',ownerId:'owner1',cognitoUserId:'owner1',acceptingOrders:true,lastStatusUpdate:'before'});
const actor={subjectId:'manager1',ownerId:'owner1',role:'MANAGER'};
process.env.MERCHANT_RESPONSE_MODE='REQUIRED';
test('manager settings use CAS and preserve pause timing while recording actual actor',async()=>{
 const b={...branch(),acceptingOrders:false,orderPauseId:'pause1',ordersPausedUntil:'later',lastStatusUpdate:'pausedAt'};let tx;
 const view=await execute({send:async c=>{tx=c.input.TransactItems;}},b,actor,[],{action:'set_order_reception',settings:{autoAccept:true,defaultPreparationMinutes:30},baseRevision:revision(b)});
 assert.equal(view.pausedUntil,'later');assert.equal(tx.length,2);assert(!tx[0].Update.UpdateExpression.includes('lastStatusUpdate'));assert(tx[0].Update.ConditionExpression.includes('#cognito=:owner'));assert.equal(tx[1].Put.Item.actorId,'manager1');assert.equal(view.settings.acceptanceSeconds,300);
});
test('pause and durable resume event are written in the same guarded transaction',async()=>{
 const b=branch();let tx;const r=await execute({send:async c=>{tx=c.input.TransactItems;}},b,actor,[],{action:'pause_orders',minutes:15,baseRevision:revision(b)});
 assert.equal(r.acceptingOrders,false);assert.equal(tx.length,3);assert(tx[0].Update.UpdateExpression.includes('lastStatusUpdate'));const event=tx[1].Put.Item;assert.equal(event.kind,'MERCHANT_RESUME');assert.equal(event.ownerId,'owner1');assert.equal(event.pauseId,tx[2].Put.Item.after.orderPauseId);assert.equal(event.nextAttemptAt,Math.ceil(Date.parse(r.pausedUntil)/1000));
});
test('read-only manager, stale revision and invalid settings cannot write',async()=>{
 const b=branch();let writes=0;const db={send:async()=>writes++};const input={action:'set_order_reception',baseRevision:revision(b),settings:{autoAccept:true,defaultPreparationMinutes:20}};
 await assert.rejects(execute(db,b,actor,[],input,false),e=>e.status===403);
 await assert.rejects(execute(db,b,actor,[],{...input,baseRevision:'old'}),e=>e.status===409);
 for(const settings of [{autoAccept:'true',defaultPreparationMinutes:20},{autoAccept:true,defaultPreparationMinutes:0},{autoAccept:true,defaultPreparationMinutes:20,acceptanceSeconds:60}])await assert.rejects(execute(db,b,actor,[],{...input,settings}),e=>e.code==='INVALID_RECEPTION_REQUEST');
 assert.equal(writes,0);
});

test('minimum is optional, owner-scoped and revision guarded; older clients preserve it',async()=>{
 for(const [current,next,expected] of [[undefined,1500,1500],[1500,null,null],[1500,undefined,1500]]){
  const b={...branch(),minimum_order:current};if(current===undefined)delete b.minimum_order;
  let tx;const settings={autoAccept:false,defaultPreparationMinutes:20};if(next!==undefined)settings.minimumOrderAmountIqd=next;
  const r=await execute({send:async c=>{tx=c.input.TransactItems;}},b,actor,[],{action:'set_order_reception',baseRevision:revision(b),settings});
  assert.equal(r.minimumOrderAmountIqd,expected);assert.equal(tx[0].Update.ExpressionAttributeValues[':minimum'],expected);
  if(next!==undefined)assert.notEqual(r.revision,revision(b));
 }
 for(const v of [-1,1.5,'1500',1000000001]){const b=branch();await assert.rejects(execute({send:async()=>assert.fail('must not write')},b,actor,[],{action:'set_order_reception',baseRevision:revision(b),settings:{autoAccept:false,defaultPreparationMinutes:20,minimumOrderAmountIqd:v}}));}
});
