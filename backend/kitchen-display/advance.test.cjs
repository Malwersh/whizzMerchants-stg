const {test}=require('node:test'),assert=require('node:assert/strict');
const {prepare}=require('./advance');
const base={action:'advance',orderId:'o1',target:'preparing',revision:4};
function deps(order={orderId:'o1',businessId:'b1',status:'confirmed',rev:4}){return {db:{async send(c){assert.equal(c.input.ConsistentRead,true);return {Item:order};}},service:{async authorize(token,target){assert.ok(['preparing','ready_for_pickup'].includes(target));return {businessId:'b1',row:{screenId:'screen1',ownerId:'owner1'},screen:{name:'المطبخ'},guards:[{ConditionCheck:{}}]};}},token:'secret',input:base,table:'orders'};}
 test('kitchen actor scopes canonical writer to exact order, state and revision',async()=>{const actor=await prepare(deps());assert.equal(actor.sub,'KITCHEN#screen1');assert.equal(actor.deviceOrder.expectedRevision,4);assert.equal(actor.deviceOrder.targetStatus,'preparing');assert.equal(actor.kitchenOrder,true);});
 test('cannot alter price, branch, or accept/cancel from kitchen',async()=>{for(const input of [{...base,price:0},{...base,businessId:'b2'},{...base,target:'confirmed'},{...base,target:'cancelled'}])await assert.rejects(prepare({...deps(),input}),/INVALID/);});
 test('foreign order denied before canonical writer',async()=>{await assert.rejects(prepare(deps({businessId:'other',status:'confirmed',rev:4})),/SCOPE/);});
 test('changed revision and wrong transition denied',async()=>{for(const order of [{businessId:'b1',status:'confirmed',rev:5},{businessId:'b1',status:'ready',rev:4},{businessId:'b1',status:'cancelled',rev:4}])await assert.rejects(prepare(deps(order)),/CONFLICT/);});
 test('display-only rejection propagates before order read',async()=>{await assert.rejects(prepare({...deps(),service:{async authorize(){throw Error('KITCHEN_DISPLAY_ONLY');}},db:{send(){throw Error('must not read');}}}),/DISPLAY_ONLY/);});
 test('ready uses current canonical writer ready action',async()=>{const r=await prepare({...deps({businessId:'b1',status:'preparing',rev:4}),input:{...base,target:'ready_for_pickup'}});assert.equal(r.deviceOrder.targetStatus,'ready');});
test('canonical pending cancellation blocks kitchen progression',async()=>{
 await assert.rejects(prepare(deps({businessId:'b1',status:'confirmed',rev:4,exceptionCancellation:{state:'REQUESTED'}})),/CONFLICT/);
});
