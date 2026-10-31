const {test}=require('node:test');const assert=require('node:assert/strict');const vm=require('node:vm');const fs=require('node:fs');
function load(item){let writes=0;const inputs=[];const db={send:async c=>{inputs.push(c.input);if(c.kind!=='GetCommand')writes++;return item?{Item:item,Attributes:{...item,...(c.input.ExpressionAttributeValues?.[':optionGroups']?{optionGroups:c.input.ExpressionAttributeValues[':optionGroups']}: {})}}:{}}};const sdk={DynamoDBClient:class{},DynamoDBDocumentClient:{from:()=>db},CognitoIdentityProviderClient:class{},v4:()=> 'unused',merchantLifecycleClient:x=>x,merchantHandler:h=>h};for(const n of ['GetCommand','PutCommand','DeleteCommand','UpdateCommand','QueryCommand','ScanCommand'])sdk[n]=class{constructor(input){this.kind=n;this.input=input}};const ctx={module:{exports:{}},require:n=>n.endsWith('branch-product-options')?require('../functions/shared/branch-product-options'):sdk,process:{env:{}},console:{log(){},error(){}}};vm.runInNewContext(fs.readFileSync('backend/functions/products/product_management_handler.js','utf8')+'\ngetBusinessId=async()=>"b";this.create=handleCreateProduct;this.update=handleUpdateProduct;',ctx);return {ctx,writes:()=>writes,inputs};}
test('creation rejects nonexistent synthetic category before writing a global or branch product',async()=>{const {ctx,writes}=load();const r=await ctx.create({body:JSON.stringify({name:'كباب',price:3500,categoryId:'fb-main-courses-002'})});assert.equal(r.statusCode,400);assert.equal(writes(),0)});
test('category edit rejects unknown reference before writing',async()=>{const {ctx,writes}=load();const r=await ctx.update({pathParameters:{productId:'p'},body:JSON.stringify({categoryId:'fb-main-courses-002'})});assert.equal(r.statusCode,400);assert.equal(writes(),0)});

test('invalid option catalog is rejected before any global or branch write',async()=>{
 for(const action of ['create','update']){
  const f=load();const r=await f.ctx[action]({pathParameters:{productId:'p'},body:JSON.stringify({name:'Food',price:1000,optionGroups:[{id:'bad'}]})});
  assert.equal(r.statusCode,400);assert.equal(JSON.parse(r.body).message,'INVALID_BRANCH_PRODUCT_OPTIONS');assert.equal(f.inputs.length,0);assert.equal(f.writes(),0);
 }
});
test('branch options update only the owned branch product with an atomic ownership fence',async()=>{
 const f=load({productId:'p',businessId:'b'}),groups=[{id:'sides',title:'Sides',required:false,maxSelections:1,options:[{id:'salad',name:'Salad',extraPrice:250,isAvailable:true}]}];
 const r=await f.ctx.update({pathParameters:{productId:'p'},body:JSON.stringify({optionGroups:groups})});
 assert.equal(r.statusCode,200,r.body);assert.equal(f.writes(),1);
 const write=f.inputs.at(-1);assert.match(write.ConditionExpression,/#branchOwner = :branchOwner/);assert.match(write.ConditionExpression,/attribute_not_exists\(#previousUpdatedAt\)/);assert.equal(write.ExpressionAttributeValues[':branchOwner'],'b');
 assert.deepEqual(JSON.parse(JSON.stringify(write.ExpressionAttributeValues[':optionGroups'])),groups);
});
