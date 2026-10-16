const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
function transform(order){
 const source=fs.readFileSync('backend/functions/orders/merchant_order_handler.js','utf8');
 const start=source.indexOf('const transformedOrders = limitedOrders.map(order => {');
 const end=source.indexOf('\n        return createResponse(200,',start);
 const ctx={limitedOrders:[order],businessId:'branch',console:{log(){}}};
 const helper=source.slice(source.indexOf('function financialOrderAssignment('),source.indexOf('// Helper: normalize order shape'));
 vm.runInNewContext(helper+source.slice(start,end)+'\nthis.result=transformedOrders[0];',ctx);
 return ctx.result;
}
function pos(order){
 const s=fs.readFileSync('backend/functions/orders/pos_forwarding_service.js','utf8');
 const start=s.indexOf('function resolveTotalAmount('),end=s.indexOf('/**',start);
 const ctx={order};vm.runInNewContext(s.slice(start,end)+'\nthis.result=[resolveTotalAmount(order),resolveDeliveryFee(order)];',ctx);return Array.from(ctx.result);
}
for(const [name,order,total,fee] of [
 ['minor pricing',{pricing:{total:6250125,deliveryFee:2500000}},6250.125,2500],
 ['zero fee',{pricing:{total:3500000,deliveryFee:0},deliveryFee:2500},3500,0],
 ['legacy IQD',{total:2500000,deliveryFee:2500},2500000,2500],
])test(name+' converts exactly once for merchant API and POS',()=>{
 const result=transform(order);assert.equal(result.totalAmount,total);assert.equal(result.deliveryFee,fee);assert.deepEqual(pos(order),[total,fee]);
});

test('merchant list exposes assignment selectors and return state without frozen private finance terms',()=>{
 const result=transform({orderId:'o',financialAcceptance:{offerId:'offer2',privateTerms:'hidden'},assignmentAttemptCounter:2,returnCaseId:'return2',returnStatus:'ARRIVED_AT_BRANCH',financialSnapshot:{secret:'hidden'},commercialPricing:{secret:'hidden'}});
 assert.equal(result.financialAssignment.offerId,'offer2');assert.equal(result.financialAssignment.attempt,2);assert.equal(result.financialAssignment.returnId,'return2');assert.equal(result.financialAssignment.returnStatus,'ARRIVED_AT_BRANCH');
 for(const key of ['financialSnapshot','commercialPricing','financialAcceptance'])assert.equal(result[key],undefined);
});
