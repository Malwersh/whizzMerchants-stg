'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {createMenuVersionService}=require('../functions/products/menu_versions');
const UUIDS=['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333'];
const requestId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
function fixture({failSnapshot=false,active=null}={}){
 const calls=[];let nonce=0;
 const db={async send(command){const input=command.input,name=command.constructor.name;calls.push({name,input});
  if(name==='GetCommand'&&input.TableName==='staging-MerchantPlatform'){
   if(input.Key.sk==='MENU_VERSION#ACTIVE')return {Item:active||undefined};
   return {};
  }
  if(name==='GetCommand'&&input.TableName==='WhizzMerchants_Categories')return {Item:{categoryId:input.Key.categoryId,businessId:'b',categoryName:'Meals',isActive:true}};
  if(name==='ScanCommand'&&input.TableName==='WhizzMerchants_Products')return {Items:[{productId:'p2',businessId:'b',categoryId:'c',name:'Two',price:2,isAvailable:true},{productId:'p1',businessId:'b',categoryId:'c',name:'One',price:1,isAvailable:true}]};
  if(name==='QueryCommand')return {Items:[]};
  if(name==='TransactWriteCommand'&&input.TransactItems.some(x=>x.Put?.Item?.sk?.includes('#PRODUCT#'))&&failSnapshot)throw Error('snapshot failed');
  return {};
 }};
 return {service:createMenuVersionService(db,{now:()=>new Date('2026-10-25T10:00:00.000Z'),nonce:()=>UUIDS[nonce++]||UUIDS[2],actor:()=>({sub:'owner'})}),calls};
}
test('publish writes complete immutable snapshots before changing active pointer',async()=>{
 const f=fixture(),result=await f.service.publish('b',{requestId});
 assert.equal(result.productCount,2);assert.match(result.publishedVersion,/^1792922400000_/);
 const tx=f.calls.filter(x=>x.name==='TransactWriteCommand');assert.equal(tx.length,2);
 assert.deepEqual(tx[0].input.TransactItems.map(x=>x.Put.Item.product.productId),['p1','p2']);
 assert.equal(tx[1].input.TransactItems.find(x=>x.Put?.Item?.sk==='MENU_VERSION#ACTIVE').Put.Item.sk,'MENU_VERSION#ACTIVE');
 assert.equal(tx[1].input.TransactItems.some(x=>x.Put?.Item?.action==='MENU_VERSION_PUBLISHED'),true);
});
test('failed snapshot never changes the active menu pointer',async()=>{
 const f=fixture({failSnapshot:true});await assert.rejects(f.service.publish('b',{requestId}),/snapshot failed/);
 assert.equal(f.calls.some(x=>x.name==='TransactWriteCommand'&&x.input.TransactItems[0]?.Put?.Item?.sk==='MENU_VERSION#ACTIVE'),false);
});
test('rollback is idempotent and advances the customer cache version',async()=>{
 const old={pk:'BRANCH#b',sk:'MENU_VERSION#ACTIVE',businessId:'b',publishedVersion:'1792922300000_aaaaaaaaaaaa',menuVersion:10};
 const f=fixture({active:old});
 const original=f.calls;
 f.service=createMenuVersionService({async send(command){const input=command.input,name=command.constructor.name;original.push({name,input});if(name==='GetCommand'&&input.Key.sk.startsWith('MENU_ROLLBACK_REQUEST#'))return {};if(name==='GetCommand'&&input.Key.sk.startsWith('MENU_HISTORY#'))return {Item:{businessId:'b',contentHash:'hash',productCount:2}};if(name==='GetCommand'&&input.Key.sk==='MENU_VERSION#ACTIVE')return {Item:old};return {};}},{now:()=>new Date('1970-01-01T00:00:00.001Z'),nonce:()=>UUIDS[0],actor:()=>({sub:'owner'})});
 const result=await f.service.rollback('b',{requestId,version:'1792922200000_bbbbbbbbbbbb'});assert.equal(result.menuVersion,11);assert.equal(result.publishedVersion,'1792922200000_bbbbbbbbbbbb');
 const tx=original.find(x=>x.name==='TransactWriteCommand');assert.equal(tx.input.TransactItems.some(x=>x.Put?.Item?.action==='MENU_VERSION_ROLLED_BACK'),true);
});
test('publication reads a consistent source and fences its draft revision',async()=>{const f=fixture();await f.service.publish('b',{requestId});assert(f.calls.some(c=>c.name==='ScanCommand'&&c.input.ConsistentRead===true));const tx=f.calls.filter(c=>c.name==='TransactWriteCommand').at(-1).input.TransactItems;assert(tx.some(c=>c.ConditionCheck?.Key?.sk==='MENU_DRAFT#META'));});
test('unchanged publication records an idempotent request without changing the active pointer',async()=>{const first=await fixture().service.publish('b',{requestId}),f=fixture({active:first});assert.equal((await f.service.publish('b',{requestId})).unchanged,true);const tx=f.calls.filter(c=>c.name==='TransactWriteCommand').flatMap(c=>c.input.TransactItems);assert(tx.some(c=>c.Put?.Item?.sk==='MENU_PUBLISH_REQUEST#'+requestId));assert(!tx.some(c=>c.Put?.Item?.sk==='MENU_VERSION#ACTIVE'));});
test('a new publication never decreases the customer cache revision',async()=>{const f=fixture({active:{publishedVersion:'old',menuVersion:1792922400100}});const r=await f.service.publish('b',{requestId});assert.equal(r.menuVersion,1792922400101);});
