const {test}=require('node:test');
const assert=require('node:assert/strict');
const {snapshot,project}=require('./orders');
test('kitchen projection excludes customer, delivery and money fields',()=>{
 const result=project({orderId:'1',status:'confirmed',customerName:'secret',customerPhone:'secret',deliveryAddress:'secret',total:12000,items:[{name:'بيتزا',quantity:2,price:6000,notes:'بدون فطر',selectedOptions:[{name:'كبير',price:500}]}]});
 assert.equal(JSON.stringify(result).includes('secret'),false);
 assert.equal(JSON.stringify(result).includes('price'),false);
 assert.equal(result.items[0].notes,'بدون فطر');
});
test('terminal and handed-over orders are absent from kitchen',()=>{
 for(const status of ['cancelled','delivered','picked_up','pending'])assert.equal(project({status}),null);
 assert.equal(project({status:'ready',merchantHandover:{state:'HANDED_TO_DRIVER'}}),null);
});
test('stale index cannot expose cancellation or another branch; canonical reads are strong',async()=>{
 let auth=0;const db={async send(c){const x=c.input;if(c.constructor.name==='QueryCommand')return {Items:[{orderId:'cancelled'},{orderId:'foreign'},{orderId:'valid'}]};assert.equal(x.ConsistentRead,true);if(x.TableName==='staging-MerchantPlatform')return {Item:{status:'READY'}};const id=x.Key.PK.slice(6);return {Item:{orderId:id,storeId:id==='foreign'?'b2':'b1',status:id==='cancelled'?'cancelled':'confirmed',items:[]}};}};
 const r=await snapshot({db,authorize:async()=>{auth++;return {businessId:'b1',screen:{mode:'display'}};},table:'orders',token:'t'});
 assert.deepEqual(r.orders.map(x=>x.orderId),['valid']);assert.equal(auth,2);
});
test('revocation during snapshot prevents returning data',async()=>{
 let count=0;await assert.rejects(snapshot({db:{async send(c){return c.constructor.name==='GetCommand'?{Item:{status:'READY'}}:{Items:[]};}},authorize:async()=>{if(++count===2)throw Error('REVOKED');return {businessId:'b1'};},table:'orders'}),/REVOKED/);
});
test('index failure fails closed instead of claiming empty kitchen',async()=>{
 await assert.rejects(snapshot({db:{async send(){throw Error('unavailable');}},authorize:async()=>({businessId:'b1'}),table:'orders'}),/unavailable/);
});
test('actual cancellation state and item modifiers project without financial metadata',()=>{
 const r=project({status:'confirmed',exceptionCancellation:{state:'REQUESTED'},items:[{dishName:'بيتزا',quantity:1,modifiers:[{name:'كبير',price:1000}]}]});
 assert.equal(r.cancellationRequested,true);assert.equal(r.items[0].options[0].name,'كبير');assert.equal(project({status:'confirmed',exceptionCancellation:{state:'REJECTED'}}).cancellationRequested,false);
});
test('uninitialized branch projection cannot pretend kitchen is empty',async()=>{
 await assert.rejects(snapshot({db:{async send(){return {};}},authorize:async()=>({businessId:'b1'}),table:'orders'}),/INCOMPLETE/);
});
