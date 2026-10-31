const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const moduleFixture={exports:{}};vm.runInNewContext(fs.readFileSync(__dirname+'/../functions/auth/onboarding_regions.js','utf8'),{module:moduleFixture,require:()=>({})});const api=moduleFixture.exports;
const base=[0,1,2,3].map(level=>({regionId:'r'+level,level,name_ar:'Area'+level,is_active:true,...(level?{parent_id:'r'+(level-1)}:{})}));
const derived=base.map(r=>({regionId:r.regionId,effective_is_active:1}));
test('reference hierarchy contains only active complete ancestry',()=>{assert.equal(api.hierarchy(base,derived).length,4);assert.equal(api.hierarchy(base.map(r=>r.level===1?{...r,is_active:false}:r),derived).length,1);assert.equal(api.hierarchy(base,derived.map(r=>r.regionId==='r2'?{...r,effective_is_active:0}:r)).length,2);});
test('cross parent or inactive selection cannot be submitted',()=>{assert.equal(api.path(api.hierarchy(base,derived),['r0','r1','r2','r3']).regionId,'r3');assert.throws(()=>api.path(api.hierarchy(base,derived),['r0','r2','r1','r3']),/REGION_UNAVAILABLE/);});
test('GPS must lie within region polygon and outside its holes',()=>{const g={type:'Polygon',coordinates:[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[4,4],[6,4],[6,6],[4,6],[4,4]]]};assert.equal(api.contains(g,2,2),true);assert.equal(api.contains(g,5,5),false);assert.equal(api.contains(g,20,20),false);assert.throws(()=>api.contains(g,'2',2),/INVALID_LOCATION/);});

test('missing derived state never permits merchant registration',()=>assert.equal(api.hierarchy(base,[]).length,0));
function liveValidationFixture(indexAvailable=true){
 const sdk={};for(const name of ['GetCommand','ScanCommand','QueryCommand'])sdk[name]=({[name]:class{constructor(input){this.input=input;}}})[name];
 const shape={type:'Polygon',coordinates:[[[44,31],[45,31],[45,32],[44,32],[44,31]]]},rows=base.map(r=>({...r,geometry:shape,version:2}));
 const effects=rows.map(r=>({regionId:r.regionId,effective_is_active:1,version:2,effective_config:{delivery:true}}));
 const calls=[],db={async send(c){calls.push(c);const q=c.input,table=q.TableName==='WizzCentral_Regions'?rows:effects;if(c instanceof sdk.ScanCommand)return {Items:table};if(c instanceof sdk.GetCommand)return {Item:table.find(r=>r.regionId===q.Key.regionId)};if(c instanceof sdk.QueryCommand)return {Items:indexAvailable?[{regionId:'r3',h3_cell:q.ExpressionAttributeValues[':cell']}]:[]};throw Error(c.constructor.name);}};
 const mod={exports:{}};vm.runInNewContext(fs.readFileSync(__dirname+'/../functions/auth/onboarding_regions.js','utf8'),{module:mod,require:n=>n==='@aws-sdk/lib-dynamodb'?sdk:require('../functions/auth/customer-regions-313')});return {api:mod.exports,db,calls};
}
test('merchant actual validator uses composite index and returns atomic source version checks',async()=>{const f=liveValidationFixture(),r=await f.api.validate(f.db,['r0','r1','r2','r3'],31.5,44.5);assert.equal(r.regionId,'r3');assert.equal(r.checks.length,8);assert(f.calls.some(c=>c.input.IndexName==='h3-index'));assert(r.checks.every(c=>c.ConditionCheck.ConditionExpression.includes('#v=:v')));});
test('merchant cannot accept polygon-only match when canonical index has no coverage',async()=>{const f=liveValidationFixture(false);await assert.rejects(f.api.validate(f.db,['r0','r1','r2','r3'],31.5,44.5),/REGION_NOT_FOUND/);});
